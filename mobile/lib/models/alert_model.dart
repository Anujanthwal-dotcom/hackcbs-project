import 'timestamp_compat.dart';

/// Represents a weather-based agricultural alert stored in
/// `users/{uid}/alerts/{alertId}`.
class AlertModel {
  final String id;
  final String userId;
  final String type;       // 'extreme_heat', 'heavy_rain', 'disease_risk'
  final String title;
  final String message;
  final String severity;   // 'low', 'medium', 'high'
  final String? farmId;
  final Map<String, dynamic> weatherContext;
  final String? relatedDetectionId;
  final DateTime createdAt;
  final bool read;

  const AlertModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    this.farmId,
    this.weatherContext = const {},
    this.relatedDetectionId,
    required this.createdAt,
    this.read = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'severity': severity,
      if (farmId != null) 'farmId': farmId,
      'weatherContext': weatherContext,
      if (relatedDetectionId != null) 'relatedDetectionId': relatedDetectionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'read': read,
      'source': 'weather_monitor',
    };
  }

  factory AlertModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return AlertModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      type: map['type'] as String? ?? 'general',
      title: map['title'] as String? ?? 'Agricultural Alert',
      message: map['message'] as String? ?? '',
      severity: map['severity'] as String? ?? 'medium',
      farmId: map['farmId'] as String?,
      weatherContext: Map<String, dynamic>.from(map['weatherContext'] as Map? ?? {}),
      relatedDetectionId: map['relatedDetectionId'] as String?,
      createdAt: parseTimestamp(map['createdAt']),
      read: map['read'] as bool? ?? false,
    );
  }
}
