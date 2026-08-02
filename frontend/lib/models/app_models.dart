class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.companyId,
    this.companyName,
    this.plantId,
    this.plantName,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final int? companyId;
  final String? companyName;
  final int? plantId;
  final String? plantName;

  bool get isSupport => role == 'support_engineer' || role == 'nuclei_admin';

  bool get canRaise => role == 'company_admin' || role == 'plant_user';

  String get roleLabel => prettyLabel(role);

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      companyId: _nullableInt(json['company_id']),
      companyName: json['company_name']?.toString(),
      plantId: _nullableInt(json['plant_id']),
      plantName: json['plant_name']?.toString(),
    );
  }
}

class Plant {
  const Plant({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.companyCode,
    required this.plantCode,
    required this.plantName,
    required this.scadaSiteId,
    required this.websocketUrl,
    required this.scadaEnabled,
    required this.totalTickets,
    required this.activeTickets,
    required this.solvedTickets,
    this.capacityMw,
  });

  final int id;
  final int companyId;
  final String companyName;
  final String companyCode;
  final String plantCode;
  final String plantName;
  final double? capacityMw;
  final String scadaSiteId;
  final String websocketUrl;
  final bool scadaEnabled;
  final int totalTickets;
  final int activeTickets;
  final int solvedTickets;

  String get capacityLabel => capacityMw == null
      ? 'Capacity not set'
      : '${_formatNumber(capacityMw!)} MW';

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: int.parse(json['id'].toString()),
      companyId: int.parse(json['company_id'].toString()),
      companyName: json['company_name']?.toString() ?? '',
      companyCode: json['company_code']?.toString() ?? '',
      plantCode: json['plant_code']?.toString() ?? '',
      plantName: json['plant_name']?.toString() ?? '',
      capacityMw: _nullableDouble(json['capacity_mw']),
      scadaSiteId: json['scada_site_id']?.toString() ?? '',
      websocketUrl: json['websocket_url']?.toString() ?? '',
      scadaEnabled: _toBool(json['scada_enabled']),
      totalTickets: int.tryParse(json['total_tickets'].toString()) ?? 0,
      activeTickets: int.tryParse(json['active_tickets'].toString()) ?? 0,
      solvedTickets: int.tryParse(json['solved_tickets'].toString()) ?? 0,
    );
  }
}

class TicketSummary {
  const TicketSummary({
    required this.id,
    required this.ticketNumber,
    required this.subject,
    required this.category,
    required this.priority,
    required this.status,
    required this.companyName,
    required this.plantName,
    required this.createdAt,
    required this.attachmentCount,
    this.capacityMw,
    this.scadaSiteId,
  });

  final int id;
  final String ticketNumber;
  final String subject;
  final String category;
  final String priority;
  final String status;
  final String companyName;
  final String plantName;
  final String createdAt;
  final int attachmentCount;
  final double? capacityMw;
  final String? scadaSiteId;

  factory TicketSummary.fromJson(Map<String, dynamic> json) {
    return TicketSummary(
      id: int.parse(json['id'].toString()),
      ticketNumber: json['ticket_number']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      priority: json['priority']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      plantName: json['plant_name']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      attachmentCount: int.tryParse(json['attachment_count'].toString()) ?? 0,
      capacityMw: _nullableDouble(json['capacity_mw']),
      scadaSiteId: json['scada_site_id']?.toString(),
    );
  }
}

class ScadaConnectionConfig {
  const ScadaConnectionConfig({
    required this.plantId,
    required this.siteId,
    required this.websocketUrl,
    required this.subscriptionPayload,
    required this.enabled,
  });

  final int plantId;
  final String siteId;
  final String websocketUrl;
  final Map<String, dynamic> subscriptionPayload;
  final bool enabled;

  factory ScadaConnectionConfig.fromJson(Map<String, dynamic> json) {
    return ScadaConnectionConfig(
      plantId: int.parse(json['plant_id'].toString()),
      siteId: json['site_id']?.toString() ?? '',
      websocketUrl: json['websocket_url']?.toString() ?? '',
      subscriptionPayload:
          Map<String, dynamic>.from(json['subscription_payload'] ?? {}),
      enabled: _toBool(json['enabled']),
    );
  }
}

class ScadaMetric {
  const ScadaMetric({
    required this.label,
    required this.value,
    this.unit = '',
  });

  final String label;
  final String value;
  final String unit;
}

class ScadaDevice {
  const ScadaDevice({
    required this.name,
    required this.status,
    required this.values,
  });

  final String name;
  final String status;
  final Map<String, String> values;
}

class ScadaViewData {
  const ScadaViewData({
    required this.overview,
    required this.inverters,
    required this.vcbs,
    required this.raw,
    required this.receivedAt,
  });

  final List<ScadaMetric> overview;
  final List<ScadaDevice> inverters;
  final List<ScadaDevice> vcbs;
  final Map<String, dynamic> raw;
  final DateTime receivedAt;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  return int.tryParse(value.toString());
}

double? _nullableDouble(dynamic value) {
  if (value == null || value.toString().isEmpty) return null;
  return double.tryParse(value.toString());
}

bool _toBool(dynamic value) {
  if (value is bool) return value;
  return value == 1 ||
      value?.toString() == '1' ||
      value?.toString().toLowerCase() == 'true';
}

String prettyLabel(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2);
}
