import 'timestamp_compat.dart';
import '../l10n/agricultural_translations.dart';

/// Severity ladder for progressive disease/pest management.
enum AssessmentSeverity {
  unknown,
  early,       // Low occurrence, controlled
  moderate,    // Spreading, needs attention
  worsening,   // Condition escalating
  severe,      // Urgent intervention or expert consultation needed
}

/// Progression status compared to previous assessment at the same field point.
enum ProgressionStatus {
  initial,    // First assessment at this point
  improved,   // Condition better than last time
  stable,     // No meaningful change
  worsening,  // Condition worse than last time
}

/// Action level for IPM escalation.
enum ActionLevel {
  monitor,      // Watch, cultural/organic measures
  integrated,   // Integrated pest management, biological control
  chemical,     // Chemical intervention (only if RAG-supported)
  expert,       // Laboratory or agricultural expert consultation
}

/// A single structured assessment event stored at:
/// users/{uid}/detections/{detectionId}/assessments/{assessmentId}
///
/// Each assessment represents one inspection visit to a field detection point.
/// Multiple assessments per point enable progressive disease management reasoning.
class FieldAssessment {
  final String id;
  final String detectionId;
  final String userId;
  final DateTime createdAt;

  // ML result for this visit
  final String crop;
  final String condition;
  final String mlPrediction;
  final double mlConfidence;

  // Agronomic assessment
  final AssessmentSeverity severity;
  final ProgressionStatus progressionStatus;
  final String recommendationSummary;
  final ActionLevel actionLevel;
  final int followUpDays;

  // Context
  final String farmerQuestion;
  final String? weatherSnapshot; // JSON snapshot of WeatherData
  final String? imagePath;       // Local file path to scan image

  const FieldAssessment({
    required this.id,
    required this.detectionId,
    required this.userId,
    required this.createdAt,
    required this.crop,
    required this.condition,
    required this.mlPrediction,
    required this.mlConfidence,
    required this.severity,
    required this.progressionStatus,
    required this.recommendationSummary,
    required this.actionLevel,
    required this.followUpDays,
    required this.farmerQuestion,
    this.weatherSnapshot,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'detectionId': detectionId,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'crop': crop,
      'condition': condition,
      'mlPrediction': mlPrediction,
      'mlConfidence': mlConfidence,
      'severity': severity.name,
      'progressionStatus': progressionStatus.name,
      'recommendationSummary': recommendationSummary,
      'actionLevel': actionLevel.name,
      'followUpDays': followUpDays,
      'farmerQuestion': farmerQuestion,
      if (weatherSnapshot != null) 'weatherSnapshot': weatherSnapshot,
      if (imagePath != null) 'imagePath': imagePath,
    };
  }

  factory FieldAssessment.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseTs(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    AssessmentSeverity parseSeverity(String? s) {
      return AssessmentSeverity.values.firstWhere(
        (e) => e.name == s,
        orElse: () => AssessmentSeverity.unknown,
      );
    }

    ProgressionStatus parseProgression(String? s) {
      return ProgressionStatus.values.firstWhere(
        (e) => e.name == s,
        orElse: () => ProgressionStatus.initial,
      );
    }

    ActionLevel parseAction(String? s) {
      return ActionLevel.values.firstWhere(
        (e) => e.name == s,
        orElse: () => ActionLevel.monitor,
      );
    }

    return FieldAssessment(
      id: id,
      detectionId: map['detectionId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      createdAt: parseTs(map['createdAt']),
      crop: map['crop'] as String? ?? '',
      condition: map['condition'] as String? ?? '',
      mlPrediction: map['mlPrediction'] as String? ?? '',
      mlConfidence: (map['mlConfidence'] as num?)?.toDouble() ?? 0.0,
      severity: parseSeverity(map['severity'] as String?),
      progressionStatus: parseProgression(map['progressionStatus'] as String?),
      recommendationSummary: map['recommendationSummary'] as String? ?? '',
      actionLevel: parseAction(map['actionLevel'] as String?),
      followUpDays: (map['followUpDays'] as num?)?.toInt() ?? 7,
      farmerQuestion: map['farmerQuestion'] as String? ?? '',
      weatherSnapshot: map['weatherSnapshot'] as String?,
      imagePath: map['imagePath'] as String?,
    );
  }

  /// Human-readable severity label for UI display (dynamically localized).
  String get severityLabel => AgriculturalTranslations.getSeverityLabel(severity.name);

  /// Human-readable progression status for UI display (dynamically localized).
  String get progressionLabel => AgriculturalTranslations.getProgressionLabel(progressionStatus.name);
}
