import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img_lib;
import 'package:app/models/prediction_result.dart';
import 'package:app/services/ml_inference_service.dart';

void main() {
  group('V4 PredictionResult Rejection & Evaluation Tests', () {
    final mapping = MLInferenceService.fallbackClassMapping;
    const double testBlurGood = 2000.0;
    const double testBlurBad = 500.0;
    const double confThreshold = 0.55;
    const double marginThreshold = 0.05;
    const double blurThreshold = 1293.81;

    test('Class 0: Soybean_Healthy passes all checks as valid target', () {
      final probs = [0.95, 0.01, 0.01, 0.01, 0.01, 0.01];
      final result = PredictionResult.evaluate(
        probabilities: probs,
        classMapping: mapping,
        blurScore: testBlurGood,
        confidenceThreshold: confThreshold,
        marginThreshold: marginThreshold,
        blurThreshold: blurThreshold,
      );

      expect(result.state, InferenceState.validTarget);
      expect(result.isValid, isTrue);
      expect(result.classIndex, 0);
      expect(result.predictedClass, 'Soybean_Healthy');
      expect(result.crop, 'Soybean');
      expect(result.condition, 'Healthy');
      expect(result.displayTitle, 'Soybean • Healthy');
    });

    test('Class 1: Soybean_Caterpillar passes as valid target', () {
      final probs = [0.02, 0.90, 0.02, 0.02, 0.02, 0.02];
      final result = PredictionResult.evaluate(
        probabilities: probs,
        classMapping: mapping,
        blurScore: testBlurGood,
        confidenceThreshold: confThreshold,
        marginThreshold: marginThreshold,
        blurThreshold: blurThreshold,
      );

      expect(result.state, InferenceState.validTarget);
      expect(result.isValid, isTrue);
      expect(result.classIndex, 1);
      expect(result.predictedClass, 'Soybean_Caterpillar');
      expect(result.crop, 'Soybean');
      expect(result.condition, 'Caterpillar');
    });

    test('Class 2: Soybean_Bacterial_Blight passes as valid target', () {
      final probs = [0.01, 0.02, 0.92, 0.01, 0.02, 0.02];
      final result = PredictionResult.evaluate(
        probabilities: probs,
        classMapping: mapping,
        blurScore: testBlurGood,
        confidenceThreshold: confThreshold,
        marginThreshold: marginThreshold,
        blurThreshold: blurThreshold,
      );

      expect(result.state, InferenceState.validTarget);
      expect(result.isValid, isTrue);
      expect(result.classIndex, 2);
      expect(result.predictedClass, 'Soybean_Bacterial_Blight');
      expect(result.crop, 'Soybean');
      expect(result.condition, 'Bacterial Blight');
    });

    test('Class 3: Cotton_Healthy passes as valid target', () {
      final probs = [0.01, 0.02, 0.01, 0.88, 0.04, 0.04];
      final result = PredictionResult.evaluate(
        probabilities: probs,
        classMapping: mapping,
        blurScore: testBlurGood,
        confidenceThreshold: confThreshold,
        marginThreshold: marginThreshold,
        blurThreshold: blurThreshold,
      );

      expect(result.state, InferenceState.validTarget);
      expect(result.isValid, isTrue);
      expect(result.classIndex, 3);
      expect(result.predictedClass, 'Cotton_Healthy');
      expect(result.crop, 'Cotton');
      expect(result.condition, 'Healthy');
    });

    test('Class 4: Cotton_Bacterial_Blight passes as valid target', () {
      final probs = [0.01, 0.02, 0.01, 0.02, 0.89, 0.05];
      final result = PredictionResult.evaluate(
        probabilities: probs,
        classMapping: mapping,
        blurScore: testBlurGood,
        confidenceThreshold: confThreshold,
        marginThreshold: marginThreshold,
        blurThreshold: blurThreshold,
      );

      expect(result.state, InferenceState.validTarget);
      expect(result.isValid, isTrue);
      expect(result.classIndex, 4);
      expect(result.predictedClass, 'Cotton_Bacterial_Blight');
      expect(result.crop, 'Cotton');
      expect(result.condition, 'Bacterial Blight');
    });

    test('Class 5: Cotton_Pink_Bollworm passes as valid target', () {
      final probs = [0.01, 0.01, 0.02, 0.01, 0.02, 0.93];
      final result = PredictionResult.evaluate(
        probabilities: probs,
        classMapping: mapping,
        blurScore: testBlurGood,
        confidenceThreshold: confThreshold,
        marginThreshold: marginThreshold,
        blurThreshold: blurThreshold,
      );

      expect(result.state, InferenceState.validTarget);
      expect(result.isValid, isTrue);
      expect(result.classIndex, 5);
      expect(result.predictedClass, 'Cotton_Pink_Bollworm');
      expect(result.crop, 'Cotton');
      expect(result.condition, 'Pink Bollworm');
    });

    test('Rejection Rule 1: Blurry image is rejected with image_unclear', () {
      final probs = [0.95, 0.01, 0.01, 0.01, 0.01, 0.01];
      final result = PredictionResult.evaluate(
        probabilities: probs,
        classMapping: mapping,
        blurScore: testBlurBad, // 500.0 < 1293.81
        confidenceThreshold: confThreshold,
        marginThreshold: marginThreshold,
        blurThreshold: blurThreshold,
      );

      expect(result.state, InferenceState.imageUnclear);
      expect(result.isValid, isFalse);
      expect(result.isBlurry, isTrue);
      expect(result.displayTitle, 'Image Unclear');
      expect(result.displaySubtitle, 'Image unclear — please focus the camera.');
    });

    test('Rejection Rule 2: Low confidence (< 0.55) is rejected with uncertainLowConfidence', () {
      final probs = [0.48, 0.20, 0.12, 0.10, 0.05, 0.05];
      final result = PredictionResult.evaluate(
        probabilities: probs,
        classMapping: mapping,
        blurScore: testBlurGood,
        confidenceThreshold: confThreshold,
        marginThreshold: marginThreshold,
        blurThreshold: blurThreshold,
      );

      expect(result.state, InferenceState.uncertainLowConfidence);
      expect(result.isValid, isFalse);
      expect(result.isConfident, isFalse);
      expect(result.displayTitle, 'Uncertain Detection');
    });

    test('Rejection Rule 3: Ambiguous top-1/top-2 margin (< 0.05) is rejected', () {
      // Top-1 is 0.56 (> 0.55), Top-2 is 0.53 -> Margin 0.03 < 0.05
      final probs = [0.56, 0.53, 0.0, 0.0, 0.0, 0.0];
      final result = PredictionResult.evaluate(
        probabilities: probs,
        classMapping: mapping,
        blurScore: testBlurGood,
        confidenceThreshold: confThreshold,
        marginThreshold: marginThreshold,
        blurThreshold: blurThreshold,
      );

      expect(result.state, InferenceState.uncertainAmbiguousMargin);
      expect(result.isValid, isFalse);
      expect(result.isAmbiguous, isTrue);
      expect(result.margin, closeTo(0.03, 0.001));
      expect(result.displayTitle, 'Uncertain Detection');
    });

    test('Laplacian variance blur calculation produces correct variance on sharp image', () {
      // Create a sharp image with high edge contrasts
      final img = img_lib.Image(width: 50, height: 50);
      for (int y = 0; y < 50; y++) {
        for (int x = 0; x < 50; x++) {
          if (x < 25) {
            img.setPixelRgb(x, y, 255, 255, 255);
          } else {
            img.setPixelRgb(x, y, 0, 0, 0);
          }
        }
      }

      final score = computeLaplacianVariance(img);
      expect(score, greaterThan(1000.0));
    });
  });
}
