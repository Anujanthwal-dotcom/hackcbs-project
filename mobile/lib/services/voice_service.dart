import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'language_service.dart';

/// Centralized voice interaction service providing Speech-to-Text (STT)
/// and Text-to-Speech (TTS) for KisaanBandhu.
///
/// Designed for field resilience:
/// - Supports Hindi (`hi_IN` / `hi-IN`) and English (`en_IN` / `en_US`).
/// - Auto-selects voice engine configuration matching response language.
/// - Non-blocking: assistant text conversation works seamlessly even if audio fails.
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  static VoiceService get instance => _instance;

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isSpeechInitialized = false;
  bool _isTtsInitialized = false;

  final ValueNotifier<bool> isListeningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> spokenMessageIdNotifier = ValueNotifier<String>('');

  bool get isListening => isListeningNotifier.value;
  bool get isSpeaking => isSpeakingNotifier.value;

  /// Initializes STT and TTS engines.
  Future<void> initialize() async {
    await _initTts();
    await _initStt();
  }

  Future<void> _initTts() async {
    if (_isTtsInitialized) return;
    try {
      await _tts.awaitSynthCompletion(true);
      await _tts.setSpeechRate(0.45); // Slightly slower for clarity in field
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        isSpeakingNotifier.value = true;
      });

      _tts.setCompletionHandler(() {
        isSpeakingNotifier.value = false;
        spokenMessageIdNotifier.value = '';
      });

      _tts.setCancelHandler(() {
        isSpeakingNotifier.value = false;
        spokenMessageIdNotifier.value = '';
      });

      _tts.setErrorHandler((msg) {
        debugPrint('[VoiceService] TTS Error: $msg');
        isSpeakingNotifier.value = false;
        spokenMessageIdNotifier.value = '';
      });

      _isTtsInitialized = true;
      debugPrint('[VoiceService] TTS initialized successfully');
    } catch (e) {
      debugPrint('[VoiceService] TTS initialization warning: $e');
    }
  }

  Future<bool> _initStt() async {
    if (_isSpeechInitialized) return true;
    try {
      // Explicitly check and request microphone runtime permission for Android/iOS
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        final req = await Permission.microphone.request();
        if (!req.isGranted) {
          debugPrint('[VoiceService] Microphone permission was not granted by user');
          return false;
        }
      }

      _isSpeechInitialized = await _speech.initialize(
        onError: (err) {
          debugPrint('[VoiceService] STT Error: ${err.errorMsg}');
          isListeningNotifier.value = false;
          if (_isWakeWordListening) {
            _scheduleWakeWordRestart();
          }
        },
        onStatus: (status) {
          debugPrint('[VoiceService] STT Status: $status');
          if (status == 'notListening' || status == 'done') {
            isListeningNotifier.value = false;
            if (_isWakeWordListening) {
              _scheduleWakeWordRestart();
            }
          }
        },
      );
      debugPrint('[VoiceService] STT initialized: $_isSpeechInitialized');
      return _isSpeechInitialized;
    } catch (e) {
      debugPrint('[VoiceService] STT initialization warning: $e');
      _isSpeechInitialized = false;
      return false;
    }
  }

  /// Detects wake words like "Hey, Bandhu", "Hey Bandhu", "हे बंधु", "नमस्ते बंधु"
  static bool detectWakeWord(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return false;

    // English / Romanized variations
    if (lower.contains('hey bandhu') ||
        lower.contains('hey, bandhu') ||
        lower.contains('hey,bandhu') ||
        lower.contains('hey bandu') ||
        lower.contains('hey badhu') ||
        lower.contains('hai bandhu') ||
        lower.contains('ay bandhu') ||
        lower.contains('kisaan bandhu') ||
        lower.contains('kisan bandhu') ||
        lower.contains('wake up bandhu') ||
        lower.contains('bandhu')) {
      return true;
    }

    // Hindi (Devanagari) variations
    if (lower.contains('हे बंधु') ||
        lower.contains('हे बन्धु') ||
        lower.contains('हे बंधू') ||
        lower.contains('नमस्ते बंधु') ||
        lower.contains('नमस्ते बन्धु') ||
        lower.contains('किसान बंधु') ||
        lower.contains('किसान बन्धु') ||
        lower.contains('उठो बंधु') ||
        lower.contains('बंधु') ||
        lower.contains('बन्धु')) {
      return true;
    }
    return false;
  }

  /// Strips the wake word prefix so the AI receives the clean question
  static String stripWakeWord(String text) {
    return text
        .replaceFirst(
          RegExp(
            r'^(hey[\s,-]*bandhu|hey[\s,-]*bandu|hey[\s,-]*badhu|hai[\s,-]*bandhu|ay[\s,-]*bandhu|wake[\s,-]*up[\s,-]*bandhu|हे[\s,-]*बंधु|हे[\s,-]*बन्धु|हे[\s,-]*बंधू|नमस्ते[\s,-]*बंधु|नमस्ते[\s,-]*बन्धु|kisaan[\s,-]*bandhu|kisan[\s,-]*bandhu|किसान[\s,-]*बंधु|किसान[\s,-]*बन्धु|उठो[\s,-]*बंधु|bandhu|बन्धु)\s*[:,-]?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  /// Resolves the optimal speech recognition locale for the desired language
  Future<String> _resolveLocaleId(bool isHindi) async {
    try {
      final locales = await _speech.locales();
      if (isHindi) {
        // Look for exact hi_IN or hi-IN first, then any Hindi locale
        for (final l in locales) {
          if (l.localeId == 'hi_IN' || l.localeId == 'hi-IN') {
            return l.localeId;
          }
        }
        for (final l in locales) {
          if (l.localeId.toLowerCase().startsWith('hi')) {
            return l.localeId;
          }
        }
        return 'hi_IN';
      } else {
        for (final l in locales) {
          if (l.localeId == 'en_IN' || l.localeId == 'en-IN') {
            return l.localeId;
          }
        }
        for (final l in locales) {
          if (l.localeId.toLowerCase().startsWith('en')) {
            return l.localeId;
          }
        }
        return 'en_IN';
      }
    } catch (_) {
      return isHindi ? 'hi_IN' : 'en_IN';
    }
  }

  /// Starts speech recognition in the designated or detected locale.
  /// When [preferredLanguageCode] is 'hi', it forces Google Speech Recognizer
  /// to transcribe in native Hindi (Devanagari) script rather than Latin transliteration.
  Future<bool> startListening({
    required Function(String recognizedWords, double confidence) onResult,
    String? preferredLanguageCode,
  }) async {
    final ready = await _initStt();
    if (!ready) {
      debugPrint('[VoiceService] Speech recognition unavailable on this device');
      return false;
    }

    if (isSpeaking) {
      await stopSpeaking();
    }

    // Default to Hindi ('hi') if preferredLanguageCode is 'hi' or app is in Hindi.
    // If not specified, default to Hindi for authentic Indian farmer experience!
    final isHi = preferredLanguageCode == 'hi' ||
        (preferredLanguageCode == null && LanguageService.instance.isHindi) ||
        preferredLanguageCode == null;

    final resolvedLocale = await _resolveLocaleId(isHi);
    debugPrint('[VoiceService] Starting SpeechToText with locale: $resolvedLocale (isHindi: $isHi)');

    try {
      isListeningNotifier.value = true;
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.confidence);
          if (result.finalResult) {
            isListeningNotifier.value = false;
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false, // Don't crash out on slight pauses
          partialResults: true,
          onDevice: false, // Use cloud Google speech for maximum Hindi accuracy
          localeId: resolvedLocale,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[VoiceService] Listen error: $e');
      isListeningNotifier.value = false;
      return false;
    }
  }

  bool _isWakeWordListening = false;
  bool get isWakeWordListening => _isWakeWordListening;
  Timer? _wakeWordRestartTimer;
  Function(String trigger)? _onWakeWordCallback;
  String? _wakeWordPreferredLanguage;

  /// Starts ambient wake-word detection in the background when the mascot is floating.
  /// Listens continuously for "Hey Bandhu", "हे बंधु", etc. with auto-restart on pauses.
  Future<bool> startWakeWordListening({
    required Function(String trigger) onWakeWordDetected,
    String? preferredLanguageCode,
  }) async {
    _onWakeWordCallback = onWakeWordDetected;
    _wakeWordPreferredLanguage = preferredLanguageCode;
    _isWakeWordListening = true;
    return _armWakeWordListener();
  }

  Future<bool> _armWakeWordListener() async {
    if (!_isWakeWordListening || isSpeaking || isListening) return false;

    final ready = await _initStt();
    if (!ready) {
      _scheduleWakeWordRestart(delayMs: 3000);
      return false;
    }

    final isHi = _wakeWordPreferredLanguage == 'hi' ||
        (_wakeWordPreferredLanguage == null && LanguageService.instance.isHindi) ||
        _wakeWordPreferredLanguage == null;
    final resolvedLocale = await _resolveLocaleId(isHi);

    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          if (detectWakeWord(words)) {
            debugPrint('[VoiceService] Ambient wake word detected: "$words"');
            stopWakeWordListening();
            _onWakeWordCallback?.call(words);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          onDevice: false,
          localeId: resolvedLocale,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[VoiceService] Wake word listen error: $e');
      _scheduleWakeWordRestart();
      return false;
    }
  }

  void _scheduleWakeWordRestart({int delayMs = 600}) {
    _wakeWordRestartTimer?.cancel();
    if (!_isWakeWordListening || isSpeaking || isListening) return;
    _wakeWordRestartTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_isWakeWordListening && !isSpeaking && !isListening) {
        _armWakeWordListener();
      }
    });
  }

  void stopWakeWordListening() {
    _isWakeWordListening = false;
    _wakeWordRestartTimer?.cancel();
    _wakeWordRestartTimer = null;
    if (_speech.isListening) {
      _speech.stop();
    }
  }

  /// Stops active speech recognition.
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    isListeningNotifier.value = false;
  }

  /// Speaks the given text using appropriate Hindi or English voice.
  Future<void> speak(
    String text, {
    String? messageId,
    String? languageCode,
  }) async {
    await _initTts();

    // Clean Markdown formatting for clean TTS narration
    final cleanText = _cleanMarkdownForSpeech(text);
    if (cleanText.isEmpty) return;

    // Determine voice language: if text has Devanagari script, use Hindi voice
    final isHindiText = LanguageService.isTextHindi(cleanText) || languageCode == 'hi';
    final ttsLanguage = isHindiText ? 'hi-IN' : 'en-IN';

    try {
      await _tts.stop();
      spokenMessageIdNotifier.value = messageId ?? '';
      await _tts.setLanguage(ttsLanguage);
      await _tts.speak(cleanText);
    } catch (e) {
      debugPrint('[VoiceService] Speak error: $e');
      isSpeakingNotifier.value = false;
      spokenMessageIdNotifier.value = '';
    }
  }

  /// Stops any currently playing speech audio.
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    isSpeakingNotifier.value = false;
    spokenMessageIdNotifier.value = '';
  }

  /// Strips Markdown symbols and URLs so TTS sounds natural and farmer-friendly.
  String _cleanMarkdownForSpeech(String input) {
    var text = input;
    // Remove Markdown headers (#, ##, etc.)
    text = text.replaceAll(RegExp(r'#+\s*'), '');
    // Remove bold/italic stars and underscores
    text = text.replaceAll(RegExp(r'[*_~`]+'), '');
    // Remove links [text](url) -> text
    text = text.replaceAllMapped(
        RegExp(r'\[(.*?)\]\(.*?\)'), (match) => match.group(1) ?? '');
    // Remove bullet dashes and symbols
    text = text.replaceAll(RegExp(r'^\s*[-•*]\s*', multiLine: true), '');
    // Replace colons followed by newlines with periods
    text = text.replaceAll(RegExp(r':\s*\n'), '. ');
    return text.trim();
  }
}
