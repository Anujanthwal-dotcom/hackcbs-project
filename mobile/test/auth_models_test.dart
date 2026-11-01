import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/user_profile.dart';
import 'package:app/models/detection_record.dart';
import 'package:app/models/field_assessment.dart';
import 'package:app/models/field_point_context.dart';
import 'package:app/models/user_settings.dart';
import 'package:app/models/rag_models.dart';
import 'package:app/services/auth_service.dart';

void main() {
  group('Auth & User Data Architecture Tests', () {
    test('UserProfile model serialization and immutability', () {
      final now = DateTime(2026, 8, 25, 10, 0, 0);
      final profile = UserProfile(
        uid: 'test_uid_12345',
        name: 'Ramesh Patel',
        email: 'ramesh@farm.in',
        phone: '+91 9876543210',
        location: 'Nagpur, Maharashtra',
        preferredLanguage: 'Hindi',
        role: 'Farmer',
        createdAt: now,
        updatedAt: now,
      );

      final map = profile.toMap();
      expect(map['uid'], 'test_uid_12345');
      expect(map['name'], 'Ramesh Patel');
      expect(map['email'], 'ramesh@farm.in');
      expect(map['phone'], '+91 9876543210');
      expect(map['location'], 'Nagpur, Maharashtra');
      expect(map['preferredLanguage'], 'Hindi');

      final reconstructed = UserProfile.fromMap(map, 'test_uid_12345');
      expect(reconstructed.uid, 'test_uid_12345');
      expect(reconstructed.name, 'Ramesh Patel');
      expect(reconstructed.email, 'ramesh@farm.in');

      final updated = profile.copyWith(name: 'Ramesh K. Patel');
      expect(updated.name, 'Ramesh K. Patel');
      expect(updated.email, 'ramesh@farm.in');
    });

    test('DetectionRecord model serialization and status handling', () {
      final now = DateTime(2026, 8, 25, 11, 30, 0);
      final record = DetectionRecord(
        id: 'det_987',
        userId: 'test_uid_12345',
        crop: 'Soybean',
        prediction: 'soybean_whitefly',
        condition: 'Whitefly',
        confidence: 0.945,
        margin: 0.12,
        blurScore: 1850.5,
        status: 'validTarget',
        imageUrl: '/images/leaf1.jpg',
        notes: 'Observed on lower leaves',
        createdAt: now,
      );

      expect(record.isValid, isTrue);
      expect(record.confidencePercentage, '94.5%');
      expect(record.displayTitle, 'Soybean • Whitefly');

      final map = record.toMap();
      expect(map['id'], 'det_987');
      expect(map['userId'], 'test_uid_12345');
      expect(map['crop'], 'Soybean');
      expect(map['confidence'], 0.945);

      final reconstructed = DetectionRecord.fromMap(map, 'det_987');
      expect(reconstructed.userId, 'test_uid_12345');
      expect(reconstructed.condition, 'Whitefly');
      expect(reconstructed.status, 'validTarget');
    });

    test('UserSettings model correctly stores thresholds and preferences', () {
      final now = DateTime(2026, 8, 25);
      final settings = UserSettings(
        userId: 'test_uid_12345',
        confidenceThreshold: 0.60,
        marginThreshold: 0.08,
        blurThreshold: 1300.0,
        blurCheckEnabled: true,
        preferredLanguage: 'Marathi',
        updatedAt: now,
      );

      final map = settings.toMap();
      expect(map['userId'], 'test_uid_12345');
      expect(map['confidenceThreshold'], 0.60);
      expect(map['marginThreshold'], 0.08);

      final fromMap = UserSettings.fromMap(map, 'test_uid_12345');
      expect(fromMap.confidenceThreshold, 0.60);
      expect(fromMap.marginThreshold, 0.08);
      expect(fromMap.preferredLanguage, 'Marathi');
    });

    test('RagConversation and RagMessage models serialize correctly', () {
      final now = DateTime(2026, 8, 25);
      final convo = RagConversation(
        id: 'conv_123',
        userId: 'test_uid_12345',
        title: 'Soybean pest advisory',
        detectionId: 'det_987',
        createdAt: now,
        updatedAt: now,
      );

      final msg = RagMessage(
        id: 'msg_1',
        conversationId: 'conv_123',
        sender: 'assistant',
        text: 'Apply neem oil spray early morning.',
        retrievedSources: ['ICAR Soybean Pest Guide (2025)'],
        timestamp: now,
      );

      final convoMap = convo.toMap();
      expect(convoMap['title'], 'Soybean pest advisory');
      expect(convoMap['detectionId'], 'det_987');

      final msgMap = msg.toMap();
      expect(msgMap['sender'], 'assistant');
      expect(msgMap['retrievedSources'], contains('ICAR Soybean Pest Guide (2025)'));
    });

    test('AuthService error message translations provide clean user-friendly descriptions', () {
      expect(AuthService.getFriendlyErrorMessage('Invalid email or password'), 'Invalid email or password. Please verify your credentials.');
      expect(AuthService.getFriendlyErrorMessage('An account already exists for this email address'), 'An account already exists for this email address.');
      expect(AuthService.getFriendlyErrorMessage('SocketException: Connection refused'), 'Cannot connect to backend server. Make sure the server is running.');
      expect(AuthService.getFriendlyErrorMessage('TimeoutException'), 'Request timed out. Please check your network connection.');
    });

    test('FieldAssessment serialization, severity and progression labels', () {
      final now = DateTime(2026, 8, 25, 12, 0, 0);
      final assessment = FieldAssessment(
        id: 'asm_001',
        detectionId: 'det_987',
        userId: 'test_uid_12345',
        createdAt: now,
        crop: 'Cotton',
        condition: 'Bacterial Blight',
        mlPrediction: 'cotton_bacterial_blight',
        mlConfidence: 0.96,
        severity: AssessmentSeverity.moderate,
        progressionStatus: ProgressionStatus.worsening,
        recommendationSummary: 'Apply copper oxychloride spray per verified guidelines.',
        actionLevel: ActionLevel.chemical,
        followUpDays: 3,
        farmerQuestion: 'The spots have spread to more leaves. What should I do?',
      );

      expect(assessment.severityLabel, 'Moderate');
      expect(assessment.progressionLabel, 'Worsening');

      final map = assessment.toMap();
      expect(map['detectionId'], 'det_987');
      expect(map['severity'], 'moderate');
      expect(map['progressionStatus'], 'worsening');
      expect(map['actionLevel'], 'chemical');
      expect(map['followUpDays'], 3);

      final reconstructed = FieldAssessment.fromMap(map, 'asm_001');
      expect(reconstructed.id, 'asm_001');
      expect(reconstructed.crop, 'Cotton');
      expect(reconstructed.severity, AssessmentSeverity.moderate);
      expect(reconstructed.progressionStatus, ProgressionStatus.worsening);
    });

    test('FieldPointContext constructs properly from DetectionRecord and previous assessments', () {
      final now = DateTime(2026, 8, 25, 12, 0, 0);
      final record = DetectionRecord(
        id: 'det_987',
        userId: 'test_uid_12345',
        crop: 'Soybean',
        prediction: 'soybean_whitefly',
        condition: 'Whitefly',
        confidence: 0.92,
        status: 'validTarget',
        latitude: 21.1458,
        longitude: 79.0882,
        accuracyMeters: 4.5,
        farmId: 'farm_abc',
        createdAt: now,
        latestSeverity: 'moderate',
        latestRecommendation: 'Monitor yellow sticky traps',
        reviewCount: 2,
        lastReviewedAt: now,
      );

      final assessments = [
        FieldAssessment(
          id: 'asm_002',
          detectionId: 'det_987',
          userId: 'test_uid_12345',
          createdAt: now,
          crop: 'Soybean',
          condition: 'Whitefly',
          mlPrediction: 'soybean_whitefly',
          mlConfidence: 0.92,
          severity: AssessmentSeverity.moderate,
          progressionStatus: ProgressionStatus.stable,
          recommendationSummary: 'Monitor yellow sticky traps',
          actionLevel: ActionLevel.monitor,
          followUpDays: 7,
          farmerQuestion: 'Checking again',
        ),
      ];

      final ctx = FieldPointContext.fromRecord(
        record: record,
        assessments: assessments,
        userId: 'test_uid_12345',
      );

      expect(ctx.isFirstVisit, isFalse);
      expect(ctx.reviewCount, 2);
      expect(ctx.lastSeverity, 'moderate');
      expect(ctx.coordsLabel, '21.14580, 79.08820');
      expect(ctx.latestAssessment?.id, 'asm_002');
    });
  });
}

