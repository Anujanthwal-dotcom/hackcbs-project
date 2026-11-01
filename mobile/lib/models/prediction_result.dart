import 'package:flutter/material.dart';
import '../l10n/agricultural_translations.dart';

/// Rejection / classification state of the V4 agriculture ML model.
enum InferenceState {
  /// Valid target detection belonging to one of the 6 supported agriculture classes.
  validTarget,

  /// Image is too blurry or low quality (Laplacian variance < blurThreshold).
  imageUnclear,

  /// Prediction confidence is below confidenceThreshold.
  uncertainLowConfidence,

  /// Difference between Top-1 and Top-2 probabilities is below marginThreshold.
  uncertainAmbiguousMargin,

  /// Negative class (non-target plant, unrelated object, or unsupported crop).
  negativeUnsupported,
}

/// Represents the V4 classification result produced by the ML model with full rejection logic.
class PredictionResult {
  /// The raw class string, e.g., 'soybean_whitefly', 'negative', 'unknown', 'image_unclear'.
  final String predictedClass;

  /// The class index (0 to 6), or -1 for rejection states.
  final int classIndex;

  /// Probability score (0.0 to 1.0) for the top predicted class.
  final double confidence;

  /// Margin between Top-1 and Top-2 probabilities (0.0 to 1.0).
  final double margin;

  /// Second highest class name.
  final String? secondClass;

  /// Second highest class probability.
  final double? secondConfidence;

  /// Computed blur / image-quality score (Laplacian variance).
  final double blurScore;

  /// The evaluated inference state.
  final InferenceState state;

  /// Identified crop name: 'Soybean', 'Cotton', 'Unsupported', 'Unknown', or 'Unclear'.
  final String crop;

  /// Identified condition: 'Healthy', 'Bacterial Blight', 'Whitefly', 'Pink Bollworm', 'Negative', 'Unknown', or 'Image Unclear'.
  final String condition;

  /// Active thresholds used for inference.
  final double confidenceThreshold;
  final double marginThreshold;
  final double blurThreshold;

  /// Probabilities for all 7 classes, keyed by class name.
  final Map<String, double> allProbabilities;

  /// Timestamp when inference completed.
  final DateTime timestamp;

  /// Time taken for inference in milliseconds.
  final int inferenceTimeMs;

  const PredictionResult({
    required this.predictedClass,
    required this.classIndex,
    required this.confidence,
    required this.margin,
    this.secondClass,
    this.secondConfidence,
    required this.blurScore,
    required this.state,
    required this.crop,
    required this.condition,
    required this.confidenceThreshold,
    required this.marginThreshold,
    required this.blurThreshold,
    required this.allProbabilities,
    required this.timestamp,
    this.inferenceTimeMs = 0,
  });

  /// True if the detection is a valid target crop condition (not rejected or negative).
  bool get isValid => state == InferenceState.validTarget;

  /// True if supported soybean or cotton crop.
  bool get isSupported => state == InferenceState.validTarget;

  /// True if confidence passes the threshold.
  bool get isConfident => confidence >= confidenceThreshold;

  /// True if the image was flagged as blurry.
  bool get isBlurry => state == InferenceState.imageUnclear;

  /// True if the prediction is ambiguous.
  bool get isAmbiguous => state == InferenceState.uncertainAmbiguousMargin;

  /// Formatted confidence percentage string (e.g. "94.5%").
  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Formatted margin percentage string (e.g. "12.4%").
  String get marginPercentage => '${(margin * 100).toStringAsFixed(1)}%';

  /// Clean display title for UI (dynamically localized for active language).
  String get displayTitle {
    return AgriculturalTranslations.getDisplayTitle(
      crop: crop,
      condition: condition,
      isValid: isValid,
      isBlurry: isBlurry,
      isNegative: state == InferenceState.negativeUnsupported,
      isAmbiguous: isAmbiguous,
      isUncertain: state == InferenceState.uncertainLowConfidence,
    );
  }

  /// Clean display subtitle with status and actionable guidance (dynamically localized).
  String get displaySubtitle {
    return AgriculturalTranslations.getDisplaySubtitle(
      isValid: isValid,
      isBlurry: isBlurry,
      isNegative: state == InferenceState.negativeUnsupported,
      isAmbiguous: isAmbiguous,
      isUncertain: state == InferenceState.uncertainLowConfidence,
      confidencePercentage: confidencePercentage,
      marginPercentage: marginPercentage,
      confidenceThreshold: confidenceThreshold,
      marginThreshold: marginThreshold,
    );
  }

  /// Visual theme color for status badges.
  Color get statusColor {
    switch (state) {
      case InferenceState.imageUnclear:
        return Colors.deepOrange;
      case InferenceState.uncertainLowConfidence:
      case InferenceState.uncertainAmbiguousMargin:
        return Colors.orange;
      case InferenceState.negativeUnsupported:
        return Colors.blueGrey;
      case InferenceState.validTarget:
        if (condition == 'Healthy') {
          return const Color(0xFF2E7D32); // Deep green
        }
        return const Color(0xFFC62828); // Deep red / alert for pest/disease
    }
  }

  /// Status icon representing the finding.
  IconData get statusIcon {
    switch (state) {
      case InferenceState.imageUnclear:
        return Icons.blur_on;
      case InferenceState.uncertainLowConfidence:
      case InferenceState.uncertainAmbiguousMargin:
        return Icons.help_outline;
      case InferenceState.negativeUnsupported:
        return Icons.do_not_disturb_on_outlined;
      case InferenceState.validTarget:
        if (condition == 'Healthy') {
          return Icons.check_circle_outline;
        }
        if (condition == 'Caterpillar' || condition == 'Whitefly' || condition == 'Pink Bollworm') {
          return Icons.pest_control_outlined;
        }
        return Icons.coronavirus_outlined; // Bacterial blight
    }
  }

  /// Factory evaluator applying the full V4 rejection rules:
  /// 1. Image quality / Blur threshold check (Laplacian variance >= blurThreshold)
  /// 2. Confidence threshold check (top1 >= confidenceThreshold)
  /// 3. Top-1 vs Top-2 margin check ((top1 - top2) >= marginThreshold)
  /// 4. Negative class rejection (if present)
  /// 5. Valid target extraction (classes 0..5)
  factory PredictionResult.evaluate({
    required List<double> probabilities,
    required Map<int, String> classMapping,
    required double blurScore,
    required double confidenceThreshold,
    required double marginThreshold,
    required double blurThreshold,
    int inferenceTimeMs = 0,
  }) {
    if (probabilities.isEmpty) {
      throw ArgumentError('Probabilities list cannot be empty.');
    }

    // Sort indices by probability descending
    final indexedProbs = List.generate(
      probabilities.length,
      (i) => MapEntry(i, probabilities[i]),
    )..sort((a, b) => b.value.compareTo(a.value));

    final topEntry = indexedProbs[0];
    final secondEntry = indexedProbs.length > 1 ? indexedProbs[1] : null;

    final bestIndex = topEntry.key;
    final maxProb = topEntry.value;
    final secondProb = secondEntry?.value ?? 0.0;
    final margin = maxProb - secondProb;

    final rawClass = classMapping[bestIndex] ?? 'Soybean_Healthy';
    final secondRawClass = secondEntry != null ? classMapping[secondEntry.key] : null;

    final allProbs = <String, double>{};
    for (int i = 0; i < probabilities.length; i++) {
      final className = classMapping[i] ?? 'class_$i';
      allProbs[className] = probabilities[i];
    }

    // Evaluate rejection logic according to V4 rules
    InferenceState state;
    String crop;
    String condition;

    // Rule 1: Check image quality / blur first
    if (blurScore > 0 && blurScore < blurThreshold) {
      state = InferenceState.imageUnclear;
      crop = 'Unclear';
      condition = 'Image Unclear';
    }
    // Rule 2: Check confidence threshold
    else if (maxProb < confidenceThreshold) {
      state = InferenceState.uncertainLowConfidence;
      crop = 'Unknown';
      condition = 'Uncertain';
    }
    // Rule 3: Check Top-1 / Top-2 margin
    else if (margin < marginThreshold) {
      state = InferenceState.uncertainAmbiguousMargin;
      crop = 'Unknown';
      condition = 'Ambiguous';
    }
    // Rule 4: Check negative class
    else if (rawClass.toLowerCase().contains('negative')) {
      state = InferenceState.negativeUnsupported;
      crop = 'Unsupported';
      condition = 'Negative';
    }
    // Rule 5: Valid agriculture target
    else {
      state = InferenceState.validTarget;
      final parsed = parseClassDetails(bestIndex, rawClass);
      crop = parsed.crop;
      condition = parsed.condition;
    }

    return PredictionResult(
      predictedClass: rawClass,
      classIndex: bestIndex,
      confidence: maxProb,
      margin: margin,
      secondClass: secondRawClass,
      secondConfidence: secondProb,
      blurScore: blurScore,
      state: state,
      crop: crop,
      condition: condition,
      confidenceThreshold: confidenceThreshold,
      marginThreshold: marginThreshold,
      blurThreshold: blurThreshold,
      allProbabilities: allProbs,
      timestamp: DateTime.now(),
      inferenceTimeMs: inferenceTimeMs,
    );
  }

  /// Parses the exact 6 V4 classes into human-friendly crop & condition metadata.
  static ({String crop, String condition, bool isSupported}) parseClassDetails(
    int index,
    String rawClass,
  ) {
    final lower = rawClass.toLowerCase();
    if (lower.contains('caterpillar') || index == 1) {
      return (crop: 'Soybean', condition: 'Caterpillar', isSupported: true);
    }
    if (lower.contains('pink') || lower.contains('bollworm') || index == 5) {
      return (crop: 'Cotton', condition: 'Pink Bollworm', isSupported: true);
    }
    if (lower.contains('soybean') && (lower.contains('blight') || index == 2)) {
      return (crop: 'Soybean', condition: 'Bacterial Blight', isSupported: true);
    }
    if (lower.contains('cotton') && (lower.contains('blight') || index == 4)) {
      return (crop: 'Cotton', condition: 'Bacterial Blight', isSupported: true);
    }
    if (lower.contains('soybean') && (lower.contains('healthy') || index == 0)) {
      return (crop: 'Soybean', condition: 'Healthy', isSupported: true);
    }
    if (lower.contains('cotton') && (lower.contains('healthy') || index == 3)) {
      return (crop: 'Cotton', condition: 'Healthy', isSupported: true);
    }
    if (lower.contains('whitefly')) {
      return (crop: 'Soybean', condition: 'Whitefly', isSupported: true);
    }
    switch (index) {
      case 0:
        return (crop: 'Soybean', condition: 'Healthy', isSupported: true);
      case 1:
        return (crop: 'Soybean', condition: 'Caterpillar', isSupported: true);
      case 2:
        return (crop: 'Soybean', condition: 'Bacterial Blight', isSupported: true);
      case 3:
        return (crop: 'Cotton', condition: 'Healthy', isSupported: true);
      case 4:
        return (crop: 'Cotton', condition: 'Bacterial Blight', isSupported: true);
      case 5:
        return (crop: 'Cotton', condition: 'Pink Bollworm', isSupported: true);
      default:
        return (crop: 'Unsupported', condition: 'Negative', isSupported: false);
    }
  }
}
