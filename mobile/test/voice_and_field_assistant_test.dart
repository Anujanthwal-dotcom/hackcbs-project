import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/prediction_result.dart';
import 'package:app/models/field_assessment.dart';
import 'package:app/models/field_point_context.dart';
import 'package:app/models/farm_model.dart';
import 'package:app/screens/assistant/models/chat_message.dart';
import 'package:app/services/language_service.dart';

void main() {
  group('Language Auto-Detection & Hybrid Multilingual Tests', () {
    test('Detects Hindi text containing Devanagari characters accurately', () {
      expect(LanguageService.isTextHindi('मेरी फसल में कीड़े लग गए हैं'), isTrue);
      expect(LanguageService.isTextHindi('सोयाबीन में इल्ली का उपचार क्या है?'), isTrue);
      expect(LanguageService.isTextHindi('What should I spray on cotton?'), isFalse);
    });

    test('detectQueryLanguage dynamically identifies active conversational language', () {
      final langService = LanguageService.instance;

      expect(langService.detectQueryLanguage('मेरी फसल में पत्तियां पीली हो रही हैं'), 'hi');
      expect(langService.detectQueryLanguage('How to cure bacterial blight in soybean?'), 'en');
      expect(langService.detectQueryLanguage('कपास में pink bollworm का क्या समाधान है?'), 'hi');
    });
  });

  group('ChatMessage Serialization & Persistence Tests', () {
    test('Serializes and deserializes ChatMessage with ML prediction result without loss', () {
      final prediction = PredictionResult(
        predictedClass: 'Soybean_Caterpillar',
        classIndex: 1,
        confidence: 0.92,
        margin: 0.45,
        blurScore: 2400.0,
        state: InferenceState.validTarget,
        crop: 'Soybean',
        condition: 'Caterpillar',
        confidenceThreshold: 0.55,
        marginThreshold: 0.05,
        blurThreshold: 1293.0,
        allProbabilities: const {'Soybean_Caterpillar': 0.92},
        timestamp: DateTime(2026, 8, 30, 10, 0),
      );

      final originalMsg = ChatMessage(
        id: 'msg_001',
        text: 'How do I cure this?',
        sender: MessageSender.user,
        timestamp: DateTime(2026, 8, 30, 10, 0),
        imagePath: '/data/user/0/app/cache/leaf.jpg',
        mlResult: prediction,
        ragSources: const ['Soybean_Caterpillar_Management'],
        llmUsed: true,
      );

      final map = originalMsg.toMap();
      final restoredMsg = ChatMessage.fromMap(map, originalMsg.id);

      expect(restoredMsg.id, 'msg_001');
      expect(restoredMsg.text, 'How do I cure this?');
      expect(restoredMsg.sender, MessageSender.user);
      expect(restoredMsg.imagePath, '/data/user/0/app/cache/leaf.jpg');
      expect(restoredMsg.mlResult, isNotNull);
      expect(restoredMsg.mlResult!.crop, 'Soybean');
      expect(restoredMsg.mlResult!.condition, 'Caterpillar');
      expect(restoredMsg.mlResult!.confidence, 0.92);
      expect(restoredMsg.ragSources, contains('Soybean_Caterpillar_Management'));
      expect(restoredMsg.llmUsed, isTrue);
    });
  });

  group('Field Case Point Isolation & Progression Tests', () {
    test('Point A and Point B maintain isolated context without cross-contamination', () {
      final pointA = FieldPointContext(
        detectionId: 'point_A',
        userId: 'user_123',
        coordinates: const GeoCoordinate(latitude: 22.7196, longitude: 75.8577),
        crop: 'Soybean',
        previousCondition: 'Caterpillar',
        previousPrediction: 'Soybean_Caterpillar',
        previousConfidence: 0.91,
        previousAssessments: [
          FieldAssessment(
            id: 'assess_A1',
            detectionId: 'point_A',
            userId: 'user_123',
            createdAt: DateTime.now(),
            crop: 'Soybean',
            condition: 'Caterpillar',
            mlPrediction: 'Soybean_Caterpillar',
            mlConfidence: 0.91,
            severity: AssessmentSeverity.moderate,
            progressionStatus: ProgressionStatus.initial,
            recommendationSummary: 'Apply botanical neem spray and monitor.',
            actionLevel: ActionLevel.integrated,
            followUpDays: 3,
            farmerQuestion: 'What should I do?',
          ),
        ],
        reviewCount: 1,
      );

      final pointB = FieldPointContext(
        detectionId: 'point_B',
        userId: 'user_123',
        coordinates: const GeoCoordinate(latitude: 22.7250, longitude: 75.8600),
        crop: 'Cotton',
        previousCondition: 'Bacterial Blight',
        previousPrediction: 'Cotton_Bacterial_Blight',
        previousConfidence: 0.88,
        previousAssessments: [
          FieldAssessment(
            id: 'assess_B1',
            detectionId: 'point_B',
            userId: 'user_123',
            createdAt: DateTime.now(),
            crop: 'Cotton',
            condition: 'Bacterial Blight',
            mlPrediction: 'Cotton_Bacterial_Blight',
            mlConfidence: 0.88,
            severity: AssessmentSeverity.early,
            progressionStatus: ProgressionStatus.initial,
            recommendationSummary: 'Avoid overhead irrigation and monitor leaf lesions.',
            actionLevel: ActionLevel.monitor,
            followUpDays: 7,
            farmerQuestion: 'How to manage?',
          ),
        ],
        reviewCount: 1,
      );

      // Verify point identities and assessment isolation
      expect(pointA.detectionId, isNot(pointB.detectionId));
      expect(pointA.crop, 'Soybean');
      expect(pointB.crop, 'Cotton');
      expect(pointA.previousAssessments.first.detectionId, 'point_A');
      expect(pointB.previousAssessments.first.detectionId, 'point_B');
    });
  });

  group('Hindi / Hinglish Gemini Routing Tests', () {
    test('Devanagari queries are identified as Hindi', () {
      expect(LanguageService.isTextHindi('सोयाबीन में सफेद मक्खी से बचाव कैसे करें?'), isTrue);
      expect(LanguageService.isTextHindi('क्या करूं?'), isTrue);
      expect(LanguageService.isTextHindi('इस बीमारी का इलाज बताएं'), isTrue);
    });

    test('Language switching sequence routes independently per query', () {
      final langService = LanguageService.instance;
      // English -> Hindi -> English
      expect(langService.detectQueryLanguage('How to treat caterpillar in soybean?'), 'en');
      expect(langService.detectQueryLanguage('सोयाबीन में इल्ली का क्या इलाज है?'), 'hi');
      expect(langService.detectQueryLanguage('What is the dosage of neem oil?'), 'en');
    });
  });
}
