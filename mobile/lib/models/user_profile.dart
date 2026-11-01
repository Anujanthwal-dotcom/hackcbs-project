import 'timestamp_compat.dart';

/// Represents a farmer / user profile stored in Firestore `users/{uid}`.
class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String? location;
  final String preferredLanguage;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName => name;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.location,
    this.preferredLanguage = 'English',
    this.role = 'Farmer',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory helper to build a new profile on user registration.
  factory UserProfile.newProfile({
    required String uid,
    required String name,
    required String email,
    String? phone,
    String? location,
    String preferredLanguage = 'English',
    String role = 'Farmer',
  }) {
    final now = DateTime.now();
    return UserProfile(
      uid: uid,
      name: name,
      email: email,
      phone: phone,
      location: location,
      preferredLanguage: preferredLanguage,
      role: role,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Converts profile to a Firestore-friendly Map (uses FieldValue for timestamps where appropriate).
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      if (phone != null) 'phone': phone,
      if (location != null) 'location': location,
      'preferredLanguage': preferredLanguage,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Deserializes a Firestore DocumentSnapshot or data map.
  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    DateTime parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return UserProfile(
      uid: uid,
      name: map['name'] as String? ?? 'Farmer',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String?,
      location: map['location'] as String?,
      preferredLanguage: map['preferredLanguage'] as String? ?? 'English',
      role: map['role'] as String? ?? 'Farmer',
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? location,
    String? preferredLanguage,
    String? role,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
