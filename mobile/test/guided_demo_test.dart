import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/guided_demo_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GuidedDemoService Tests', () {
    final service = GuidedDemoService.instance;

    setUp(() {
      service.stopDemo();
    });

    test('isDemoTrigger detects English and Hindi action phrases accurately', () {
      expect(GuidedDemoService.isDemoTrigger('start demo'), isTrue);
      expect(GuidedDemoService.isDemoTrigger('Start Demo'), isTrue);
      expect(GuidedDemoService.isDemoTrigger('please start the demo'), isTrue);
      expect(GuidedDemoService.isDemoTrigger('run demo'), isTrue);
      expect(GuidedDemoService.isDemoTrigger('demo'), isTrue);

      // Hindi & Hinglish
      expect(GuidedDemoService.isDemoTrigger('डेमो शुरू करो'), isTrue);
      expect(GuidedDemoService.isDemoTrigger('डेमो चालू करो'), isTrue);
      expect(GuidedDemoService.isDemoTrigger('लाइव डेमो'), isTrue);
      expect(GuidedDemoService.isDemoTrigger('demo shuru karo'), isTrue);

      // Negative triggers
      expect(GuidedDemoService.isDemoTrigger('what is the weather today?'), isFalse);
      expect(GuidedDemoService.isDemoTrigger('how to rename my farm'), isFalse);
      expect(GuidedDemoService.isDemoTrigger(''), isFalse);
    });

    test('startDemo initializes demo state at Step 1 and total 7 steps', () {
      expect(service.isRunning, isFalse);

      service.startDemo(languageCode: 'en');
      expect(service.isRunning, isTrue);
      expect(service.isPaused, isFalse);
      expect(service.currentStepIndex, 0);
      expect(service.totalSteps, 7);

      final step1 = service.currentStep;
      expect(step1, isNotNull);
      expect(step1!.screenName, 'Scan');
      expect(step1.tabIndex, 0);
      expect(step1.elementId, 'scan_capture_button');
    });

    test('pause and resume correctly update pause state and speech', () {
      service.startDemo(languageCode: 'hi');
      expect(service.isPaused, isFalse);

      service.pause();
      expect(service.isPaused, isTrue);

      service.resume();
      expect(service.isPaused, isFalse);

      service.togglePause();
      expect(service.isPaused, isTrue);
      service.togglePause();
      expect(service.isPaused, isFalse);
    });

    test('nextStep and previousStep correctly navigate through steps', () {
      service.startDemo(languageCode: 'en');
      expect(service.currentStepIndex, 0);

      service.nextStep();
      expect(service.currentStepIndex, 1);
      expect(service.currentStep!.screenName, 'Scan');

      service.nextStep();
      expect(service.currentStepIndex, 2);
      expect(service.currentStep!.screenName, 'Map');

      service.nextStep();
      expect(service.currentStepIndex, 3);
      expect(service.currentStep!.screenName, 'Map');

      service.nextStep();
      expect(service.currentStepIndex, 4);
      expect(service.currentStep!.screenName, 'Help Desk');

      service.nextStep();
      expect(service.currentStepIndex, 5);
      expect(service.currentStep!.screenName, 'Profile');

      service.previousStep();
      expect(service.currentStepIndex, 4);
      expect(service.currentStep!.screenName, 'Help Desk');
    });

    test('toggleLanguage toggles between Hindi and English', () {
      service.startDemo(languageCode: 'hi');
      expect(service.languageCode, 'hi');

      service.toggleLanguage();
      expect(service.languageCode, 'en');

      service.toggleLanguage();
      expect(service.languageCode, 'hi');
    });

    test('stopDemo cleanly terminates the automated environment', () {
      service.startDemo(languageCode: 'en');
      expect(service.isRunning, isTrue);

      service.stopDemo();
      expect(service.isRunning, isFalse);
      expect(service.isPaused, isFalse);
      expect(service.currentStep, isNull);
    });
  });
}

