import 'timestamp_compat.dart';

/// User-specific settings stored in `users/{uid}/settings/preferences`.
class UserSettings {
  final String userId;
  final double confidenceThreshold;
  final double marginThreshold;
  final double blurThreshold;
  final bool blurCheckEnabled;
  final String preferredLanguage;
  final DateTime updatedAt;

  const UserSettings({
    required this.userId,
    this.confidenceThreshold = 0.55,
    this.marginThreshold = 0.05,
    this.blurThreshold = 1293.81396484375,
    this.blurCheckEnabled = true,
    this.preferredLanguage = 'English',
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'confidenceThreshold': confidenceThreshold,
      'marginThreshold': marginThreshold,
      'blurThreshold': blurThreshold,
      'blurCheckEnabled': blurCheckEnabled,
      'preferredLanguage': preferredLanguage,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserSettings.fromMap(Map<String, dynamic> map, String userId) {
    DateTime parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return UserSettings(
      userId: userId,
      confidenceThreshold: (map['confidenceThreshold'] as num?)?.toDouble() ?? 0.55,
      marginThreshold: (map['marginThreshold'] as num?)?.toDouble() ?? 0.05,
      blurThreshold: (map['blurThreshold'] as num?)?.toDouble() ?? 1293.81396484375,
      blurCheckEnabled: map['blurCheckEnabled'] as bool? ?? true,
      preferredLanguage: map['preferredLanguage'] as String? ?? 'English',
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }
}
