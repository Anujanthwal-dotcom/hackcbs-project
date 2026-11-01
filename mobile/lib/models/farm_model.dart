import 'timestamp_compat.dart';

/// Represents a single geographic point (latitude, longitude) with optional metadata.
class GeoCoordinate {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime? timestamp;

  const GeoCoordinate({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
      if (timestamp != null) 'timestamp': Timestamp.fromDate(timestamp!),
    };
  }

  factory GeoCoordinate.fromMap(Map<String, dynamic> map) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return GeoCoordinate(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble(),
      timestamp: parseTimestamp(map['timestamp']),
    );
  }

  @override
  String toString() => 'GeoCoordinate(lat: $latitude, lng: $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoCoordinate &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

/// Represents an authentic farm boundary created by the farmer.
/// Stored in Firestore at `users/{uid}/farms/{farmId}`.
class FarmModel {
  final String id;
  final String userId;
  final String name;
  final List<GeoCoordinate> boundary;
  final GeoCoordinate center;
  final double areaSquareMeters;
  final String? cropType;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FarmModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.boundary,
    required this.center,
    required this.areaSquareMeters,
    this.cropType,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Formatted area in Hectares (ha) and Acres (ac).
  String get formattedArea {
    if (areaSquareMeters <= 0) return '0.0 ha';
    final hectares = areaSquareMeters / 10000.0;
    final acres = areaSquareMeters / 4046.86;
    if (hectares < 0.1) {
      return '${areaSquareMeters.toStringAsFixed(0)} m² (${acres.toStringAsFixed(2)} ac)';
    }
    return '${hectares.toStringAsFixed(2)} ha (${acres.toStringAsFixed(2)} ac)';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'boundary': boundary.map((p) => p.toMap()).toList(),
      'center': center.toMap(),
      'areaSquareMeters': areaSquareMeters,
      if (cropType != null) 'cropType': cropType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory FarmModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawBoundary = map['boundary'] as List<dynamic>? ?? [];
    final boundaryPoints = rawBoundary
        .map((p) => GeoCoordinate.fromMap(Map<String, dynamic>.from(p as Map)))
        .toList();

    final centerMap = Map<String, dynamic>.from(map['center'] as Map? ?? {});
    final centerCoord = centerMap.isNotEmpty
        ? GeoCoordinate.fromMap(centerMap)
        : (boundaryPoints.isNotEmpty
            ? boundaryPoints.first
            : const GeoCoordinate(latitude: 0, longitude: 0));

    return FarmModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? 'My Farm',
      boundary: boundaryPoints,
      center: centerCoord,
      areaSquareMeters: (map['areaSquareMeters'] as num?)?.toDouble() ?? 0.0,
      cropType: map['cropType'] as String?,
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }
}
