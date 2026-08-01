import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../models/app_models.dart';
import 'api_service.dart';

enum ScadaConnectionState {
  idle,
  connecting,
  live,
  reconnecting,
  disconnected,
  error,
}

class ScadaService extends ChangeNotifier {
  ScadaService({
    required this.plantId,
    required this.expectedSiteId,
  });

  final int plantId;
  final String expectedSiteId;

  ScadaConnectionState state = ScadaConnectionState.idle;
  String? errorMessage;
  ScadaViewData? data;
  DateTime? lastUpdated;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  ScadaConnectionConfig? _config;
  bool _disposed = false;
  int _reconnectAttempt = 0;
  DateTime? _lastSnapshotSave;

  Future<void> start() async {
    if (_disposed) return;
    await _loadCachedSnapshot();

    try {
      _config = await ApiService.instance.getScadaConfig(plantId);
      if (!_config!.enabled) {
        state = ScadaConnectionState.disconnected;
        errorMessage = 'Live SCADA is disabled for this plant.';
        notifyListeners();
        return;
      }
      await _connect();
    } catch (error) {
      state = ScadaConnectionState.error;
      errorMessage = error.toString();
      notifyListeners();
      _scheduleReconnect();
    }
  }

  Future<void> retryNow() async {
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;
    await _connect();
  }

  Future<void> _loadCachedSnapshot() async {
    try {
      final snapshot =
          await ApiService.instance.getLatestScadaSnapshot(plantId);
      if (snapshot != null) {
        final parsed = ScadaNormalizer.parse(
          snapshot,
          expectedSiteId: expectedSiteId,
        );
        if (parsed != null) {
          data = parsed;
          lastUpdated = parsed.receivedAt;
          notifyListeners();
        }
      }
    } catch (_) {
      // Cached data is optional; live connection still proceeds.
    }
  }

  Future<void> _connect() async {
    if (_disposed) return;
    final config = _config ??
        await ApiService.instance.getScadaConfig(plantId);
    _config = config;

    await _closeSocket();

    state = _reconnectAttempt == 0
        ? ScadaConnectionState.connecting
        : ScadaConnectionState.reconnecting;
    errorMessage = null;
    notifyListeners();

    try {
      final channel = WebSocketChannel.connect(
        Uri.parse(config.websocketUrl),
      );
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 12));

      final subscriptionPayload = _replaceSiteId(
        config.subscriptionPayload,
        config.siteId,
      );
      channel.sink.add(jsonEncode(subscriptionPayload));

      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (Object error) {
          if (_disposed) return;
          state = ScadaConnectionState.error;
          errorMessage = 'WebSocket error: $error';
          notifyListeners();
          _scheduleReconnect();
        },
        onDone: () {
          if (_disposed) return;
          state = ScadaConnectionState.disconnected;
          errorMessage = 'Live SCADA connection closed.';
          notifyListeners();
          _scheduleReconnect();
        },
        cancelOnError: false,
      );

      state = ScadaConnectionState.live;
      _reconnectAttempt = 0;
      notifyListeners();
    } catch (error) {
      state = ScadaConnectionState.error;
      errorMessage = 'Unable to connect to live SCADA: $error';
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic event) {
    if (_disposed) return;

    try {
      dynamic decoded = event;
      if (event is String) {
        decoded = jsonDecode(event);
      } else if (event is List<int>) {
        decoded = jsonDecode(utf8.decode(event));
      }

      final parsed = ScadaNormalizer.parse(
        decoded,
        expectedSiteId: _config?.siteId ?? expectedSiteId,
      );
      if (parsed == null) return;

      data = parsed;
      lastUpdated = parsed.receivedAt;
      state = ScadaConnectionState.live;
      errorMessage = null;
      notifyListeners();
      _saveSnapshotOccasionally(parsed.raw);
    } catch (error) {
      errorMessage = 'A SCADA message could not be parsed: $error';
      notifyListeners();
    }
  }

  Future<void> _saveSnapshotOccasionally(
    Map<String, dynamic> payload,
  ) async {
    final now = DateTime.now();
    if (_lastSnapshotSave != null &&
        now.difference(_lastSnapshotSave!) <
            const Duration(seconds: 30)) {
      return;
    }
    _lastSnapshotSave = now;

    try {
      await ApiService.instance.saveScadaSnapshot(plantId, payload);
    } catch (_) {
      // Live UI should not fail if snapshot persistence is unavailable.
    }
  }

  Map<String, dynamic> _replaceSiteId(
    Map<String, dynamic> input,
    String siteId,
  ) {
    dynamic replace(dynamic value) {
      if (value is String) {
        return value.replaceAll('{{site_id}}', siteId);
      }
      if (value is List) {
        return value.map(replace).toList();
      }
      if (value is Map) {
        return value.map(
          (key, item) => MapEntry(key.toString(), replace(item)),
        );
      }
      return value;
    }

    return Map<String, dynamic>.from(replace(input) as Map);
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer?.isActive == true) return;

    _reconnectAttempt += 1;
    final exponent = _reconnectAttempt.clamp(1, 5).toInt() - 1;
    final seconds = (1 << exponent)
        .clamp(2, AppConfig.socketReconnectMax.inSeconds)
        .toInt();

    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (!_disposed) _connect();
    });
  }

  Future<void> _closeSocket() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

class ScadaNormalizer {
  static ScadaViewData? parse(
    dynamic input, {
    required String expectedSiteId,
  }) {
    final normalizedRoot = _asMap(input);
    if (normalizedRoot == null) return null;

    final messageSite = _findFirstScalar(
      normalizedRoot,
      const [
        'siteid',
        'site_id',
        'site',
        'plantid',
        'plant_id',
        'plant',
      ],
    );

    if (messageSite != null &&
        expectedSiteId.isNotEmpty &&
        messageSite.toString().toLowerCase() !=
            expectedSiteId.toLowerCase()) {
      return null;
    }

    final searchable = _preferredDataRoot(normalizedRoot);
    final flat = <String, dynamic>{};
    _flatten(searchable, '', flat);

    final overview = <ScadaMetric>[];
    _addMetric(
      overview,
      flat,
      'Active Power',
      const [
        'total_active_power',
        'active_power',
        'current_power',
        'ac_power',
        'pac',
        'plant_power',
      ],
      'kW',
    );
    _addMetric(
      overview,
      flat,
      'Today Energy',
      const [
        'today_energy',
        'daily_energy',
        'day_energy',
        'yield_today',
        'today_generation',
      ],
      'kWh',
    );
    _addMetric(
      overview,
      flat,
      'Total Energy',
      const [
        'total_energy',
        'lifetime_energy',
        'yield_total',
        'cumulative_energy',
        'total_generation',
      ],
      'kWh',
    );
    _addMetric(
      overview,
      flat,
      'Irradiance',
      const ['irradiance', 'irradiation', 'poa', 'solar_irradiance'],
      'W/m²',
    );
    _addMetric(
      overview,
      flat,
      'Grid Voltage',
      const ['grid_voltage', 'line_voltage', 'voltage'],
      'V',
    );
    _addMetric(
      overview,
      flat,
      'Grid Frequency',
      const ['grid_frequency', 'frequency', 'freq'],
      'Hz',
    );
    _addMetric(
      overview,
      flat,
      'Performance Ratio',
      const ['performance_ratio', 'plant_pr', 'pr'],
      '%',
    );
    _addMetric(
      overview,
      flat,
      'Plant Status',
      const ['plant_status', 'site_status', 'status'],
      '',
    );

    final inverters = _extractDevices(
      searchable,
      keyWords: const ['inverter', 'inverters', 'inv'],
      typeWords: const ['inverter', 'inv'],
      defaultName: 'Inverter',
    );
    final vcbs = _extractDevices(
      searchable,
      keyWords: const ['vcb', 'vcbs', 'breaker', 'breakers'],
      typeWords: const ['vcb', 'breaker'],
      defaultName: 'VCB',
    );

    return ScadaViewData(
      overview: overview,
      inverters: inverters,
      vcbs: vcbs,
      raw: normalizedRoot,
      receivedAt: DateTime.now(),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic input) {
    if (input is Map<String, dynamic>) return input;
    if (input is Map) {
      return input.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    if (input is List) {
      return {'data': input};
    }
    return null;
  }

  static dynamic _preferredDataRoot(Map<String, dynamic> root) {
    for (final key in ['data', 'payload', 'result', 'message']) {
      final value = _caseInsensitiveValue(root, key);
      if (value is Map || value is List) return value;
    }
    return root;
  }

  static dynamic _caseInsensitiveValue(Map map, String key) {
    for (final entry in map.entries) {
      if (entry.key.toString().toLowerCase() == key.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  static dynamic _findFirstScalar(
    dynamic node,
    List<String> keys,
  ) {
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString().toLowerCase();
        if (keys.contains(key) && _isScalar(entry.value)) {
          return entry.value;
        }
      }
      for (final value in node.values) {
        final found = _findFirstScalar(value, keys);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _findFirstScalar(value, keys);
        if (found != null) return found;
      }
    }
    return null;
  }

  static void _flatten(
    dynamic node,
    String path,
    Map<String, dynamic> output,
  ) {
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString().toLowerCase();
        final childPath = path.isEmpty ? key : '$path.$key';
        _flatten(entry.value, childPath, output);
      }
    } else if (node is List) {
      for (var index = 0; index < node.length; index++) {
        _flatten(node[index], '$path.$index', output);
      }
    } else if (_isScalar(node)) {
      output[path] = node;
    }
  }

  static void _addMetric(
    List<ScadaMetric> output,
    Map<String, dynamic> flat,
    String label,
    List<String> aliases,
    String unit,
  ) {
    final found = _findAlias(flat, aliases);
    if (found == null) return;
    output.add(
      ScadaMetric(
        label: label,
        value: _formatValue(found),
        unit: unit,
      ),
    );
  }

  static dynamic _findAlias(
    Map<String, dynamic> flat,
    List<String> aliases,
  ) {
    for (final alias in aliases) {
      for (final entry in flat.entries) {
        final last = entry.key.split('.').last;
        if (last == alias) return entry.value;
      }
    }
    for (final alias in aliases) {
      for (final entry in flat.entries) {
        if (entry.key.contains(alias)) return entry.value;
      }
    }
    return null;
  }

  static List<ScadaDevice> _extractDevices(
    dynamic node, {
    required List<String> keyWords,
    required List<String> typeWords,
    required String defaultName,
  }) {
    final candidates = <Map<String, dynamic>>[];
    _collectDeviceCandidates(
      node,
      candidates,
      keyWords: keyWords,
      typeWords: typeWords,
    );

    final devices = <ScadaDevice>[];
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      final name = _firstText(candidate, const [
            'name',
            'device_name',
            'devicename',
            'inverter_name',
            'invertername',
            'vcb_name',
            'breaker_name',
            'id',
            'device_id',
            'inverter_id',
            'vcb_id',
          ]) ??
          '$defaultName ${index + 1}';
      final status = _firstText(candidate, const [
            'status',
            'state',
            'online',
            'communication_status',
            'comm_status',
          ]) ??
          'Unknown';

      final values = <String, String>{};
      for (final entry in candidate.entries) {
        if (!_isScalar(entry.value)) continue;
        final key = entry.key.toString();
        if (_isIdentityKey(key)) continue;
        values[prettyLabel(key)] = _formatValue(entry.value);
        if (values.length >= 8) break;
      }

      devices.add(
        ScadaDevice(name: name, status: status, values: values),
      );
    }

    final unique = <String, ScadaDevice>{};
    for (final device in devices) {
      unique['${device.name}|${device.status}|${device.values}'] = device;
    }
    return unique.values.toList();
  }

  static void _collectDeviceCandidates(
    dynamic node,
    List<Map<String, dynamic>> output, {
    required List<String> keyWords,
    required List<String> typeWords,
    String parentKey = '',
  }) {
    if (node is Map) {
      final map = node.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final lowerParent = parentKey.toLowerCase();
      final type = _firstText(map, const [
        'type',
        'device_type',
        'devicetype',
        'category',
      ]);
      final name = _firstText(map, const [
        'name',
        'device_name',
        'devicename',
        'id',
      ]);
      final matchesParent =
          keyWords.any((word) => lowerParent.contains(word));
      final matchesType = type != null &&
          typeWords.any((word) => type.toLowerCase().contains(word));
      final matchesName = name != null &&
          typeWords.any((word) => name.toLowerCase().contains(word));

      if ((matchesParent || matchesType || matchesName) &&
          map.values.any(_isScalar)) {
        output.add(map);
      }

      for (final entry in map.entries) {
        final childKey = entry.key.toLowerCase();
        final child = entry.value;

        if (child is Map &&
            keyWords.any((word) => childKey.contains(word))) {
          for (final nested in child.entries) {
            if (nested.value is Map) {
              final deviceMap = Map<String, dynamic>.from(
                (nested.value as Map).map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              );
              deviceMap.putIfAbsent('name', () => nested.key.toString());
              output.add(deviceMap);
            }
          }
        }

        _collectDeviceCandidates(
          child,
          output,
          keyWords: keyWords,
          typeWords: typeWords,
          parentKey: childKey,
        );
      }
    } else if (node is List) {
      for (final child in node) {
        _collectDeviceCandidates(
          child,
          output,
          keyWords: keyWords,
          typeWords: typeWords,
          parentKey: parentKey,
        );
      }
    }
  }

  static String? _firstText(
    Map<String, dynamic> map,
    List<String> aliases,
  ) {
    for (final alias in aliases) {
      for (final entry in map.entries) {
        if (entry.key.toLowerCase() == alias &&
            _isScalar(entry.value)) {
          return entry.value.toString();
        }
      }
    }
    return null;
  }

  static bool _isIdentityKey(String key) {
    final lower = key.toLowerCase();
    return lower == 'name' ||
        lower == 'device_name' ||
        lower == 'devicename' ||
        lower == 'status' ||
        lower == 'state' ||
        lower == 'online' ||
        lower == 'id' ||
        lower == 'device_id' ||
        lower == 'type' ||
        lower == 'device_type';
  }

  static bool _isScalar(dynamic value) {
    return value == null ||
        value is String ||
        value is num ||
        value is bool;
  }

  static String _formatValue(dynamic value) {
    if (value == null) return '--';
    if (value is double) {
      return value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(2);
    }
    if (value is num) {
      final number = value.toDouble();
      return number == number.roundToDouble()
          ? number.toInt().toString()
          : number.toStringAsFixed(2);
    }
    if (value is bool) return value ? 'Online' : 'Offline';
    return value.toString();
  }
}
