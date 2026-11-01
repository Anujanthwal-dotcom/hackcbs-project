import 'timestamp_compat.dart';
import 'package:flutter/material.dart';

/// Represents a single crop detection event saved in `users/{uid}/detections/{detectionId}`.
class DetectionRecord {
  final String id;
  final String userId;
  final String crop;
  final String prediction;
  final String condition;
  final double confidence;
  final double margin;
  final double blurScore;
  final String status; // 'validTarget', 'uncertain', 'negative', 'imageUnclear'
  final String? imageUrl;
  final String? notes;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? farmId;
  final DateTime createdAt;

  // ── Progressive assessment lifecycle (updated on each field inspection) ──
  /// Latest severity level from the most recent field assessment.
  final String? latestSeverity;       // 'early' | 'moderate' | 'worsening' | 'severe'
  /// Short summary of the most recent recommendation.
  final String? latestRecommendation;
  /// Total number of field assessments completed at this point.
  final int reviewCount;
  /// Timestamp of the most recent field assessment.
  final DateTime? lastReviewedAt;

  const DetectionRecord({
    required this.id,
    required this.userId,
    required this.crop,
    required this.prediction,
    required this.condition,
    required this.confidence,
    this.margin = 0.0,
    this.blurScore = 0.0,
    required this.status,
    this.imageUrl,
    this.notes,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.farmId,
    required this.createdAt,
    this.latestSeverity,
    this.latestRecommendation,
    this.reviewCount = 0,
    this.lastReviewedAt,
  });

  /// True if valid GPS coordinates are attached.
  bool get hasLocation => latitude != null && longitude != null;

  /// Formatted confidence percentage string (e.g. "94.5%").
  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';

  DetectionRecord copyWith({
    String? id,
    String? userId,
    String? crop,
    String? prediction,
    String? condition,
    double? confidence,
    double? margin,
    double? blurScore,
    String? status,
    String? imageUrl,
    String? notes,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    String? farmId,
    DateTime? createdAt,
    String? latestSeverity,
    String? latestRecommendation,
    int? reviewCount,
    DateTime? lastReviewedAt,
  }) {
    return DetectionRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      crop: crop ?? this.crop,
      prediction: prediction ?? this.prediction,
      condition: condition ?? this.condition,
      confidence: confidence ?? this.confidence,
      margin: margin ?? this.margin,
      blurScore: blurScore ?? this.blurScore,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      farmId: farmId ?? this.farmId,
      createdAt: createdAt ?? this.createdAt,
      latestSeverity: latestSeverity ?? this.latestSeverity,
      latestRecommendation: latestRecommendation ?? this.latestRecommendation,
      reviewCount: reviewCount ?? this.reviewCount,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }

  /// True if detection is a valid target disease/pest.
  bool get isValid => status == 'validTarget';

  /// Title for UI card.
  String get displayTitle {
    if (status == 'imageUnclear') return 'Image Unclear';
    if (status == 'uncertain') return 'Uncertain Detection';
    if (status == 'negative') return 'Unsupported Crop / Plant';
    return '$crop • $condition';
  }

  /// Theme color for status badge.
  Color get statusColor {
    switch (status) {
      case 'imageUnclear':
        return Colors.deepOrange;
      case 'uncertain':
        return Colors.orange;
      case 'negative':
        return Colors.blueGrey;
      case 'validTarget':
      default:
        if (condition == 'Healthy') return const Color(0xFF2E7D32);
        return const Color(0xFFC62828);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'crop': crop,
      'prediction': prediction,
      'condition': condition,
      'confidence': confidence,
      'margin': margin,
      'blurScore': blurScore,
      'status': status,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (notes != null) 'notes': notes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
      if (farmId != null) 'farmId': farmId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (latestSeverity != null) 'latestSeverity': latestSeverity,
      if (latestRecommendation != null) 'latestRecommendation': latestRecommendation,
      'reviewCount': reviewCount,
      if (lastReviewedAt != null) 'lastReviewedAt': Timestamp.fromDate(lastReviewedAt!),
    };
  }

  factory DetectionRecord.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return DetectionRecord(
      id: id,
      userId: map['userId'] as String? ?? '',
      crop: map['crop'] as String? ?? 'Crop',
      prediction: map['prediction'] as String? ?? '',
      condition: map['condition'] as String? ?? '',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      margin: (map['margin'] as num?)?.toDouble() ?? 0.0,
      blurScore: (map['blurScore'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'validTarget',
      imageUrl: map['imageUrl'] as String?,
      notes: map['notes'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble(),
      farmId: map['farmId'] as String?,
      createdAt: parseTimestamp(map['createdAt']),
      latestSeverity: map['latestSeverity'] as String?,
      latestRecommendation: map['latestRecommendation'] as String?,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      lastReviewedAt: map['lastReviewedAt'] != null
          ? parseTimestamp(map['lastReviewedAt'])
          : null,
    );
  }
}
