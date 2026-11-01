import 'detection_record.dart';
import 'field_assessment.dart';
import 'farm_model.dart';
import 'weather_model.dart';

/// Context object passed from Map → FieldAssistantScreen when the farmer
/// taps "Inspect Field Point" on a red detection marker.
///
/// Carries all information the assistant needs to provide a
/// point-specific, progression-aware response without reloading from Firestore.
class FieldPointContext {
  final String detectionId;
  final String? farmId;
  final String userId;

  // Physical location
  final GeoCoordinate coordinates;
  final double? gpsAccuracyMeters;

  // Original detection
  final String crop;
  final String previousCondition;
  final String previousPrediction;
  final double previousConfidence;

  // Progressive assessment history (newest first, max 5 for context efficiency)
  final List<FieldAssessment> previousAssessments;

  // Summary of last assessment (null if first visit)
  final String? lastSeverity;
  final String? lastRecommendation;
  final int reviewCount;
  final DateTime? lastReviewedAt;

  // Live weather at time of opening inspector (optional)
  final WeatherData? currentWeather;

  const FieldPointContext({
    required this.detectionId,
    this.farmId,
    required this.userId,
    required this.coordinates,
    this.gpsAccuracyMeters,
    required this.crop,
    required this.previousCondition,
    required this.previousPrediction,
    required this.previousConfidence,
    required this.previousAssessments,
    this.lastSeverity,
    this.lastRecommendation,
    required this.reviewCount,
    this.lastReviewedAt,
    this.currentWeather,
  });

  /// True if this is the farmer's first inspection of this field point.
  bool get isFirstVisit => reviewCount == 0 || previousAssessments.isEmpty;

  /// The most recent assessment at this point (null if first visit).
  FieldAssessment? get latestAssessment =>
      previousAssessments.isNotEmpty ? previousAssessments.first : null;

  /// Human-readable coordinates string.
  String get coordsLabel =>
      '${coordinates.latitude.toStringAsFixed(5)}, ${coordinates.longitude.toStringAsFixed(5)}';

  /// Builds this from a DetectionRecord + loaded assessments.
  factory FieldPointContext.fromRecord({
    required DetectionRecord record,
    required List<FieldAssessment> assessments,
    required String userId,
    WeatherData? weather,
  }) {
    return FieldPointContext(
      detectionId: record.id,
      farmId: record.farmId,
      userId: userId,
      coordinates: GeoCoordinate(
        latitude: record.latitude ?? 0,
        longitude: record.longitude ?? 0,
        accuracyMeters: record.accuracyMeters,
      ),
      gpsAccuracyMeters: record.accuracyMeters,
      crop: record.crop,
      previousCondition: record.condition,
      previousPrediction: record.prediction,
      previousConfidence: record.confidence,
      previousAssessments: assessments.take(5).toList(), // cap for context budget
      lastSeverity: record.latestSeverity,
      lastRecommendation: record.latestRecommendation,
      reviewCount: record.reviewCount,
      lastReviewedAt: record.lastReviewedAt,
      currentWeather: weather,
    );
  }
}
