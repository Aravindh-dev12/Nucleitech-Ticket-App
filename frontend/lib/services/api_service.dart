import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/app_models.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  String? _token;
  AppUser? currentUser;

  Future<bool> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    _token = preferences.getString('auth_token');
    if (_token == null || _token!.isEmpty) {
      return false;
    }

    try {
      final result = await _request('me');
      currentUser = AppUser.fromJson(result['user']);
      return true;
    } catch (_) {
      await clearSession();
      return false;
    }
  }

  Future<AppUser> login(String email, String password) async {
    final result = await _request(
      'login',
      method: 'POST',
      body: {'email': email.trim(), 'password': password},
    );

    _token = result['token']?.toString();
    currentUser = AppUser.fromJson(result['user']);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('auth_token', _token!);
    return currentUser!;
  }

  Future<void> logout() async {
    try {
      await _request('logout', method: 'POST');
    } catch (_) {
      // Local logout must still complete if the server is unavailable.
    }
    await clearSession();
  }

  Future<void> clearSession() async {
    _token = null;
    currentUser = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('auth_token');
  }

  Future<List<Plant>> getPlants() async {
    final result = await _request('plants');
    final rows = result['plants'] as List<dynamic>? ?? [];
    return rows
        .map((row) => Plant.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<ScadaConnectionConfig> getScadaConfig(int plantId) async {
    final result = await _request(
      'scada_config',
      query: {'plant_id': '$plantId'},
    );
    return ScadaConnectionConfig.fromJson(result['config']);
  }

  Future<Map<String, dynamic>?> getLatestScadaSnapshot(int plantId) async {
    final result = await _request(
      'scada_snapshot',
      query: {'plant_id': '$plantId'},
    );
    final snapshot = result['snapshot'];
    if (snapshot is! Map<String, dynamic>) return null;
    final payload = snapshot['payload'];
    return payload is Map<String, dynamic> ? payload : null;
  }

  Future<void> saveScadaSnapshot(
    int plantId,
    Map<String, dynamic> payload,
  ) async {
    await _request(
      'save_scada_snapshot',
      method: 'POST',
      body: {'plant_id': plantId, 'payload': payload},
    );
  }

  Future<List<TicketSummary>> getTickets({
    int? plantId,
    String? status,
  }) async {
    final query = <String, String>{};
    if (plantId != null) query['plant_id'] = '$plantId';
    if (status != null && status.isNotEmpty) query['status'] = status;

    final result = await _request('tickets', query: query);
    final rows = result['tickets'] as List<dynamic>? ?? [];
    return rows
        .map((row) => TicketSummary.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getTicket(int ticketId) {
    return _request('ticket', query: {'id': '$ticketId'});
  }

  Future<Map<String, dynamic>> createTicket({
    required int plantId,
    required String category,
    required String subject,
    required String description,
    required String priority,
    required List<XFile> images,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}?action=create_ticket',
    );

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers())
      ..fields['plant_id'] = '$plantId'
      ..fields['category'] = category
      ..fields['subject'] = subject
      ..fields['description'] = description
      ..fields['priority'] = priority;

    for (final image in images) {
      final Uint8List bytes = await image.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'images[]',
          bytes,
          filename: image.name,
        ),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<void> addComment({
    required int ticketId,
    required String comment,
    bool isInternal = false,
  }) async {
    await _request(
      'add_comment',
      method: 'POST',
      body: {
        'ticket_id': ticketId,
        'comment': comment,
        'is_internal': isInternal,
      },
    );
  }

  Future<void> updateStatus({
    required int ticketId,
    required String status,
    String resolutionNotes = '',
  }) async {
    await _request(
      'update_status',
      method: 'POST',
      body: {
        'ticket_id': ticketId,
        'status': status,
        'resolution_notes': resolutionNotes,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final result = await _request('notifications');
    return (result['notifications'] as List<dynamic>? ?? [])
        .map((item) => item as Map<String, dynamic>)
        .toList();
  }

  Future<void> markNotificationRead(int notificationId) async {
    await _request(
      'mark_notification_read',
      method: 'POST',
      body: {'notification_id': notificationId},
    );
  }

  Map<String, String> _headers() {
    return {
      'Accept': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Future<Map<String, dynamic>> _request(
    String action, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse(AppConfig.apiBaseUrl).replace(
      queryParameters: {'action': action, ...?query},
    );

    final headers = {
      ..._headers(),
      'Content-Type': 'application/json',
    };

    final http.Response response;
    if (method == 'POST') {
      response = await http
          .post(uri, headers: headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 30));
    } else {
      response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));
    }

    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'The server returned an invalid response (${response.statusCode}).',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      throw ApiException(
        data['message']?.toString() ??
            'Request failed (${response.statusCode}).',
      );
    }

    return data;
  }
}
