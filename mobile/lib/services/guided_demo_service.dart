import 'dart:async';
import 'package:flutter/material.dart';
import 'global_context_engine.dart';
import 'language_service.dart';
import 'semantic_ui_registry.dart';
import 'voice_service.dart';

/// Single step definition for the KisaanBandhu Guided Demo Experience.
class DemoStep {
  final int id;
  final String screenName;
  final int tabIndex; // 0: Scan, 1: Map, 2: Help Desk, 3: Profile
  final String? elementId; // SemanticUiRegistry element ID
  final Rect? fallbackRect; // If element is not rendered
  final String titleEn;
  final String titleHi;
  final String icon;
  final List<String> highlightsEn;
  final List<String> highlightsHi;
  final String speechEn;
  final String speechHi;
  final int durationSeconds;

  const DemoStep({
    required this.id,
    required this.screenName,
    required this.tabIndex,
    this.elementId,
    this.fallbackRect,
    required this.titleEn,
    required this.titleHi,
    required this.icon,
    required this.highlightsEn,
    required this.highlightsHi,
    required this.speechEn,
    required this.speechHi,
    this.durationSeconds = 14,
  });
}

/// Global Engine that powers the automated, controlled, interactive "Start Demo"
/// environment for judges and farmers alike.
///
/// Features:
/// - Fully automated step-by-step navigation across all 4 app tabs.
/// - Live background voice narration in Hindi or English (via [VoiceService]).
/// - Animated pulsing spotlight and glowing light tint focus boxes.
/// - Pause & Resume functionality anytime so the presenter can address judges.
/// - Previous / Next navigation controls for manual override.
/// - Synchronized on-screen subtitles and bulleted key takeaways.
class GuidedDemoService extends ChangeNotifier {
  static final GuidedDemoService _instance = GuidedDemoService._internal();
  factory GuidedDemoService() => _instance;
  GuidedDemoService._internal();

  static GuidedDemoService get instance => _instance;

  final GlobalContextEngine _contextEngine = GlobalContextEngine.instance;
  final VoiceService _voiceService = VoiceService.instance;
  final SemanticUiRegistry _registry = SemanticUiRegistry.instance;

  bool _isRunning = false;
  bool _isPaused = false;

  /// Set to true the instant the user confirms the demo launch,
  /// before the 300ms sheet-pop delay. Prevents wake-word listener
  /// from re-opening the mascot sheet during the transition window.
  bool _isLaunching = false;
  int _currentStepIndex = 0;
  String _languageCode = 'hi'; // 'hi' or 'en'
  Timer? _stepCountdownTimer;
  int _remainingSeconds = 0;
  int _totalStepSeconds = 0;

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;

  /// True while demo is running OR in the pre-launch transition window.
  /// Use this to block wake-word listener from re-opening the mascot sheet.
  bool get isRunningOrLaunching => _isRunning || _isLaunching;

  /// Call this synchronously the moment the user confirms demo launch,
  /// before the sheet pop + 300ms delay, so wake-word is suppressed immediately.
  void reserveLaunch() {
    _isLaunching = true;
  }
  int get currentStepIndex => _currentStepIndex;
  int get totalSteps => _demoSteps.length;
  String get languageCode => _languageCode;
  double get stepProgress => _totalStepSeconds > 0
      ? (1.0 - (_remainingSeconds / _totalStepSeconds)).clamp(0.0, 1.0)
      : 0.0;

  DemoStep? get currentStep {
    if (!_isRunning || _currentStepIndex < 0 || _currentStepIndex >= _demoSteps.length) {
      return null;
    }
    return _demoSteps[_currentStepIndex];
  }

  /// All 7 structured steps covering the entire KisaanBandhu platform
  static const List<DemoStep> _demoSteps = [
    // ── Step 1: Scan Screen - Crop Disease AI Scanner ────────────────────────
    DemoStep(
      id: 1,
      screenName: 'Scan',
      tabIndex: 0,
      elementId: 'scan_capture_button',
      icon: '🔬',
      titleEn: 'Crop Disease AI Scanner',
      titleHi: 'फसल रोग AI स्कैनर',
      highlightsEn: [
        'EfficientNet-B0 vision architecture',
        '25+ crop disease & pest classifications',
        'Instant severity grading & organic cures',
      ],
      highlightsHi: [
        'ऑन-डिवाइस EfficientNet-B0 AI मॉडल',
        '25 से अधिक फसलों के रोगों की पहचान',
        'सटीक गंभीरता स्तर व जैविक/रासायनिक उपचार',
      ],
      speechEn:
          'Welcome to KisaanBandhu! Our platform empowers farmers with instant on-device crop disease diagnosis. Simply point your phone camera at an infected leaf and tap the capture button. The deep-learning model diagnoses the issue in milliseconds with severity ratings and exact cure recommendations.',
      speechHi:
          'किसान बंधु में आपका स्वागत है! हमारा प्लेटफॉर्म किसानों को खेत में ही पत्तियों के रोग की त्वरित पहचान की सुविधा देता है। बस प्रभावित पत्ती पर कैमरा रखकर कैप्चर दबाएं। हमारा AI मॉडल पलक झपकते ही रोग की पहचान, गंभीरता और सटीक उपचार बता देता है।',
      durationSeconds: 15,
    ),

    // ── Step 2: Scan Screen - Live Sensor Edge Preview ───────────────────────
    DemoStep(
      id: 2,
      screenName: 'Scan',
      tabIndex: 0,
      elementId: 'scan_toggle_live',
      icon: '⚡',
      titleEn: 'Real-time Live Sensor',
      titleHi: 'लाइव फील्ड सेंसर',
      highlightsEn: [
        'Continuous camera stream inference',
        'Zero cloud dependency / 100% on-device',
        'Sub-100ms real-time bounding boxes',
      ],
      highlightsHi: [
        'कैमरा स्ट्रीम पर लगातार लाइव डिटेक्शन',
        'बिना इंटरनेट शत-प्रतिशत ऑन-डिवाइस',
        'खेत में तेज़ी से फसलों का त्वरित सर्वे',
      ],
      speechEn:
          'For rapid field surveys, toggle the Live Scan Sensor. It runs continuous on-device inference directly across the camera viewfinder, drawing bounding boxes around affected foliage with zero cloud upload and complete data privacy.',
      speechHi:
          'खेत में तेजी से सर्वे करने के लिए आप लाइव स्कैन सेंसर चालू कर सकते हैं। यह बिना इंटरनेट के कैमरे के सामने आते ही रोगग्रस्त पत्तियों को स्क्रीन पर सीधे मार्क कर देता है।',
      durationSeconds: 13,
    ),

    // ── Step 3: Map Screen - Satellite GPS Boundary Mapping ──────────────────
    DemoStep(
      id: 3,
      screenName: 'Map',
      tabIndex: 1,
      elementId: 'mark_farm_boundary',
      icon: '🗺️',
      titleEn: 'Satellite Field Mapping',
      titleHi: 'उपग्रह खेत मैपिंग',
      highlightsEn: [
        'Interactive GPS polygon delineation',
        'Automated acreage in hectares & bighas',
        'Multi-plot management for every farmer',
      ],
      highlightsHi: [
        'जीपीएस पॉलीगॉन से खेत की सटीक सीमाएं',
        'एकड़, हेक्टेयर और बीघा में क्षेत्रफल गणना',
        'एक साथ कई खेतों का अलग-अलग प्रबंधन',
      ],
      speechEn:
          'Now switching to the Map Screen. Farmers can accurately draw GPS polygon boundaries for each of their fields using satellite imagery. The platform automatically computes the exact acreage in hectares, acres, and local bighas.',
      speechHi:
          'अब चलते हैं खेत के नक्शे पर! किसान उपग्रह चित्रों और जीपीएस की मदद से अपने खेतों की सीमाओं को आसानी से मार्क कर सकते हैं। सिस्टम अपने-आप खेत का सटीक रकबा एकड़, हेक्टेयर और बीघा में निकाल देता है।',
      durationSeconds: 15,
    ),

    // ── Step 4: Map Screen - Autonomous Voice Management ─────────────────────
    DemoStep(
      id: 4,
      screenName: 'Map',
      tabIndex: 1,
      elementId: 'rename_farm',
      icon: '🤖',
      titleEn: 'Autonomous Voice Management',
      titleHi: 'आवाज से खेत प्रबंधन',
      highlightsEn: [
        'Autonomous field rename via voice',
        'Human-in-the-Loop confirmation card',
        'Zero-bureaucracy in-app polygon updates',
      ],
      highlightsHi: [
        'आवाज से खेत का नाम बदलने की सुविधा',
        'सुरक्षा हेतु पुष्टि कार्ड (Human-in-the-Loop)',
        'त्वरित व सुरक्षित इन-ऐप प्रबंधन',
      ],
      speechEn:
          'Notice how seamless field management is. Krishi Mitra Mascot can autonomously rename fields or switch active plots via natural voice commands. For safety, a Human-in-the-Loop card always asks for farmer confirmation before making any changes.',
      speechHi:
          'खेत का प्रबंधन बेहद आसान है! कृषि मित्र मैस्कॉट आपकी आवाज सुनकर खेत का नाम बदल सकता है। सुरक्षा के लिए ऐप हर बदलाव से पहले किसान से पुष्टि कार्ड पर हाँ या ना पूछता है।',
      durationSeconds: 14,
    ),

    // ── Step 5: Help Desk - Extension Services & KVK Network ─────────────────
    DemoStep(
      id: 5,
      screenName: 'Help Desk',
      tabIndex: 2,
      elementId: 'help_desk_refresh',
      icon: '🏢',
      titleEn: 'Help Desk & KVK Network',
      titleHi: 'हेल्प डेस्क व विशेषज्ञ सहायता',
      highlightsEn: [
        'Nearby Krishi Vigyan Kendras & Labs',
        'Proximity-based expert contact info',
        'Weather alerts & PM-Kisan scheme guidance',
      ],
      highlightsHi: [
        'नजदीकी कृषि विज्ञान केंद्र व टेस्टिंग लैब',
        'जीपीएस आधारित विशेषज्ञों के संपर्क सूत्र',
        'मौसम अलर्ट और पीएम-किसान योजना सहायता',
      ],
      speechEn:
          'Next, the Help Desk connects farmers directly to nearby Krishi Vigyan Kendras, government soil testing labs, and agricultural officers based on their live GPS location, alongside real-time weather forecasts and scheme benefits.',
      speechHi:
          'हेल्प डेस्क की मदद से किसान अपने पास के कृषि विज्ञान केंद्र, मिट्टी परीक्षण प्रयोगशाला और कृषि वैज्ञानिकों से सीधे संपर्क कर सकते हैं। साथ ही मौसम के अलर्ट और सरकारी योजनाओं की जानकारी भी उपलब्ध है।',
      durationSeconds: 15,
    ),

    // ── Step 6: Profile Screen - Digital Health Records ──────────────────────
    DemoStep(
      id: 6,
      screenName: 'Profile',
      tabIndex: 3,
      elementId: 'profile_history',
      icon: '📋',
      titleEn: 'Digital Health Records',
      titleHi: 'डिजिटल फसल स्वास्थ्य रिकॉर्ड',
      highlightsEn: [
        'Complete chronological scan audit trail',
        'Severity analytics and treatment logs',
        'Seamless Hindi & English localization',
      ],
      highlightsHi: [
        'पुरानी सभी जांचों का संपूर्ण डिजिटल ऑडिट',
        'रोग गंभीरता रिकॉर्ड व उपचार की जानकारी',
        'हिन्दी व अंग्रेज़ी में पूर्ण स्थानीयकरण',
      ],
      speechEn:
          'Here in the Profile screen, every farmer maintains a tamper-free digital record of all previous crop scans. This allows farmers and insurance adjusters to review disease progression, treatment history, and field recovery over time.',
      speechHi:
          'प्रोफ़ाइल स्क्रीन पर किसान की सभी पिछली जांचों का डिजिटल रिकॉर्ड सुरक्षित रहता है। इससे किसान और कृषि अधिकारी फसल में आए रोगों, दवा के असर और सुधार को समय के साथ देख सकते हैं।',
      durationSeconds: 14,
    ),

    // ── Step 7: Wrap-up - Krishi Mitra & Ambient Voice Wake-Up ───────────────
    DemoStep(
      id: 7,
      screenName: 'Scan',
      tabIndex: 0,
      elementId: 'scan_capture_button',
      icon: '🌱',
      titleEn: 'Krishi Mitra & On-Device RAG',
      titleHi: 'कृषि मित्र और ऑन-डिवाइस AI',
      highlightsEn: [
        'Ambient "Hey Bandhu" wake-word detection',
        'On-device Gemma 3 1B + local RAG offline',
        'Cloud Gemini 2.5 Flash when connected',
      ],
      highlightsHi: [
        'हैंड्स-फ्री "हे बंधु" वेक-वर्ड सपोर्ट',
        'बिना इंटरनेट ऑन-डिवाइस Gemma-3 व लोकल RAG',
        'इंटरनेट होने पर आधुनिक Gemini 2.5 AI',
      ],
      speechEn:
          'And that completes our tour! Farmers can activate Krishi Mitra anytime simply by saying "Hey Bandhu". Powered by cloud Gemini online and on-device Gemma 3 with local RAG offline, KisaanBandhu is the ultimate companion for Indian agriculture. Thank you!',
      speechHi:
          'और यह हमारा संपूर्ण डेमो पूरा हुआ! किसान कभी भी "हे बंधु" बोलकर कृषि मित्र से मदद ले सकते हैं। यह ऑनलाइन और पूरी तरह से ऑफलाइन दोनों मोड में काम करता है। किसान बंधु का अनुभव करने के लिए बहुत-बहुत धन्यवाद!',
      durationSeconds: 15,
    ),
  ];

  /// Checks if a spoken or typed text matches the "Start Demo" action intent
  static bool isDemoTrigger(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return false;

    // English variations
    if (lower.contains('start demo') ||
        lower.contains('start the demo') ||
        lower.contains('run demo') ||
        lower.contains('launch demo') ||
        lower.contains('guided tour') ||
        lower.contains('app demo') ||
        lower == 'demo' ||
        lower == 'tour') {
      return true;
    }

    // Hindi & Hinglish variations
    if (lower.contains('डेमो शुरू') ||
        lower.contains('डेमो चालू') ||
        lower.contains('डेमो दिखाओ') ||
        lower.contains('लाइव डेमो') ||
        lower.contains('demo shuru') ||
        lower.contains('demo chalu') ||
        lower == 'डेमो') {
      return true;
    }

    return false;
  }

  /// Starts the automated demo tour from Step 1
  void startDemo({String? languageCode}) {
    _stepCountdownTimer?.cancel();
    _isRunning = true;
    _isLaunching = false; // Clear pre-launch flag — _isRunning takes over
    _isPaused = false;
    _currentStepIndex = 0;
    _languageCode = languageCode ?? (LanguageService.instance.isHindi ? 'hi' : 'en');

    // Notify listeners so overlay appears immediately
    notifyListeners();

    // Trigger first step
    _executeCurrentStep();
  }

  /// Executes the active step: navigates tab, targets UI highlight, speaks narration
  void _executeCurrentStep() {
    _stepCountdownTimer?.cancel();
    final step = currentStep;
    if (step == null) {
      stopDemo();
      return;
    }

    _totalStepSeconds = step.durationSeconds;
    _remainingSeconds = step.durationSeconds;

    // 1. Switch to the step's tab
    _contextEngine.switchTab(step.tabIndex);

    // 2. Highlight semantic UI element if present
    if (step.elementId != null) {
      // Delay slightly for screen transition rendering
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!_isRunning || _isPaused) return;
        _registry.highlightElement(
          step.elementId!,
          explanation: _languageCode == 'hi' ? step.titleHi : step.titleEn,
          duration: Duration(seconds: step.durationSeconds + 2),
        );
      });
    }

    // 3. Start voice narration with a 200ms settling delay
    final speechText = _languageCode == 'hi' ? step.speechHi : step.speechEn;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!_isRunning || _isPaused) return;
      _voiceService.speak(
        speechText,
        languageCode: _languageCode,
        messageId: 'demo_step_${step.id}',
      );
    });

    // 4. Start countdown timer
    _stepCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }
      if (_isPaused) return; // Do not decrement while paused!

      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        // Advance to next step automatically
        nextStep();
      }
    });

    notifyListeners();
  }

  /// Pauses the demo: stops current speech and holds screen state for presenter to talk to judges
  void pause() {
    if (!_isRunning || _isPaused) return;
    _isPaused = true;
    _voiceService.stopSpeaking();
    notifyListeners();
  }

  /// Resumes the demo from the paused position
  void resume() {
    if (!_isRunning || !_isPaused) return;
    _isPaused = false;

    // Re-speak or continue narration
    final step = currentStep;
    if (step != null) {
      final speechText = _languageCode == 'hi' ? step.speechHi : step.speechEn;
      _voiceService.speak(
        speechText,
        languageCode: _languageCode,
        messageId: 'demo_step_${step.id}_resumed',
      );
    }
    notifyListeners();
  }

  /// Toggles between paused and running states
  void togglePause() {
    if (_isPaused) {
      resume();
    } else {
      pause();
    }
  }

  /// Advance to the next step
  void nextStep() {
    if (!_isRunning) return;
    _voiceService.stopSpeaking();
    _registry.clearHighlight();

    if (_currentStepIndex < _demoSteps.length - 1) {
      _currentStepIndex++;
      _executeCurrentStep();
    } else {
      // Finished all steps
      stopDemo();
    }
  }

  /// Go back to the previous step
  void previousStep() {
    if (!_isRunning) return;
    _voiceService.stopSpeaking();
    _registry.clearHighlight();

    if (_currentStepIndex > 0) {
      _currentStepIndex--;
      _executeCurrentStep();
    }
  }

  /// Toggles voice language between Hindi and English during live demo
  void toggleLanguage() {
    _languageCode = _languageCode == 'hi' ? 'en' : 'hi';
    if (_isRunning) {
      _voiceService.stopSpeaking();
      final step = currentStep;
      if (step != null && !_isPaused) {
        final speechText = _languageCode == 'hi' ? step.speechHi : step.speechEn;
        _voiceService.speak(
          speechText,
          languageCode: _languageCode,
          messageId: 'demo_step_${step.id}_lang_switched',
        );
      }
    }
    notifyListeners();
  }

  /// Exits the automated demo environment cleanly
  void stopDemo() {
    _stepCountdownTimer?.cancel();
    _stepCountdownTimer = null;
    _isRunning = false;
    _isLaunching = false; // Safety: clear pre-launch flag too
    _isPaused = false;
    _voiceService.stopSpeaking();
    _registry.clearHighlight();
    notifyListeners();
  }
}

