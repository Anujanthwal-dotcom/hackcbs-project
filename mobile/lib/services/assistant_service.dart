import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/assistant_response.dart';
import '../models/detection_record.dart';
import '../models/farm_model.dart';
import '../models/field_point_context.dart';
import '../models/prediction_result.dart';
import '../models/weather_model.dart';
import 'backend_api_service.dart';
import 'detection_repository.dart';
import 'farm_repository.dart';
import 'gemini_service.dart';
import 'language_service.dart';
import 'llm_service.dart';
import 'location_geocoding_service.dart';
import 'location_service.dart';
import 'ml_inference_service.dart';
import 'rag_service.dart';
import 'weather_service.dart';

/// Orchestrates the full KisaanBandhu intelligence pipeline:
///   User question + optional image
///   → vague-query classifier (returns clarification if too short/ambiguous)
///   → ML inference (if image)
///   → RAG retrieval
///   → Current device location + reverse geocoding (separate from farm name)
///   → Farm context
///   → Weather context (injected only when query is weather-relevant)
///   → LLM prompt construction (grounding rules + plain-text instruction)
///   → Gemma 3 1B on-device response (English) / Gemini API (Hindi/Hinglish)
///   → AssistantResponse
class AssistantService {
  static final AssistantService _instance = AssistantService._internal();
  factory AssistantService() => _instance;
  AssistantService._internal();

  static AssistantService get instance => _instance;

  final _mlService = MLInferenceService();
  final _ragService = RagService.instance;
  final _llmService = LlmService.instance;
  final _geminiService = GeminiService.instance;
  final _weatherService = WeatherService.instance;
  final _farmRepo = FarmRepository.instance;
  final _detectionRepo = DetectionRepository.instance;
  final _geocoding = LocationGeocodingService.instance;

  /// Process a farmer's question with optional image attachment.
  ///
  /// [query]       – The farmer's text question.
  /// [imageFile]   – Optional image to run through the ML classifier.
  /// [mlResult]    – Pre-computed ML result (if image was already classified).
  Future<AssistantResponse> respond({
    required String query,
    File? imageFile,
    PredictionResult? mlResult,
  }) async {
    final uid = BackendApiService.instance.currentUid;

    // ── 0. Vague query detection — short-circuit before Gemma ────────────────
    final clarification = _checkVagueQuery(query, hasImage: imageFile != null || mlResult != null);
    if (clarification != null) {
      return AssistantResponse(
        text: clarification,
        ragSources: const [],
        mlSummary: null,
        weatherUsed: false,
        ragUsed: false,
        llmUsed: false,
        llmAvailable: true,
        timestamp: DateTime.now(),
      );
    }

    // ── 1. Run ML inference if an image is attached and no result given ──────
    PredictionResult? prediction = mlResult;
    if (imageFile != null && prediction == null) {
      try {
        prediction = await _mlService.classifyImageFile(imageFile);
        debugPrint('[AssistantService] ML: ${prediction.displayTitle} (${prediction.confidencePercentage})');
      } catch (e) {
        debugPrint('[AssistantService] ML failed: $e');
      }
    }

    // ── 2. Language routing decision ──────────────────────────────────────────
    // Hindi/Hinglish queries bypass the English RAG pipeline entirely and go
    // straight to Gemini API. English queries follow the existing RAG path unchanged.
    final isHindiQuery = _isHindiOrHinglish(query);
    debugPrint('[AssistantService] Language routing: ${isHindiQuery ? "HINDI → Gemini API" : "ENGLISH → RAG pipeline"}');

    if (isHindiQuery) {
      // ── HINDI PATH: skip RAG, send directly to Gemini API ─────────────────
      // All context other than English RAG chunks is preserved.

      // Run minimal diagnostic test to identify auth/network/model failures early
      await runGeminiDiagnosticTest();

      // GPS location
      final currentPos = LocationService.instance.lastKnownPosition;
      String? geocodedLocation;
      if (currentPos != null) {
        geocodedLocation = await _geocoding.reverseGeocode(
            currentPos.latitude, currentPos.longitude);
      }

      // Farm context
      String farmContext = '';
      if (uid != null) {
        try {
          final farms = await _farmRepo.streamUserFarms(uid).first;
          if (farms.isNotEmpty) {
            final farm = farms.first;
            farmContext = 'Farm name: ${farm.name}';
            if (farm.cropType != null) farmContext += ', Crop: ${farm.cropType}';
            farmContext += ', Area: ${farm.formattedArea}';
          }
        } catch (e) {
          debugPrint('[AssistantService] Farm context error (Hindi path): $e');
        }
      }

      // Weather (only when relevant)
      WeatherData? weather;
      if (_isWeatherRelevantQuery(query) && currentPos != null) {
        try {
          weather = await _weatherService.getWeather(
              currentPos.latitude, currentPos.longitude);
        } catch (_) {}
      }

      final prompt = _buildHindiDirectPrompt(
        query: query,
        prediction: prediction,
        weather: weather,
        farmContext: farmContext,
        geocodedLocation: geocodedLocation,
      );
      debugPrint('[AssistantService] [HINDI_GEMINI] Prompt length: ${prompt.length} chars');

      String? geminiText;
      try {
        debugPrint('[AssistantService] [HINDI_GEMINI] Calling Gemini API...');
        geminiText = await _geminiService.generateHindiResponse(prompt: prompt);
        debugPrint('[AssistantService] [HINDI_GEMINI] Result: ${geminiText != null ? "SUCCESS (${geminiText.length} chars)" : "NULL/FAILED"}');
      } catch (e, stack) {
        debugPrint('[AssistantService] [HINDI_GEMINI] Exception: $e\n$stack');
      }

      final mlSummary = prediction != null ? _buildMlSummary(prediction) : null;

      if (geminiText != null && geminiText.isNotEmpty) {
        return AssistantResponse(
          text: geminiText,
          ragSources: const [],
          mlSummary: mlSummary,
          weatherUsed: weather != null,
          ragUsed: false,
          llmUsed: true,
          llmAvailable: true,
          timestamp: DateTime.now(),
        );
      }

      // Gemini failure fallback (Hindi localized error message)
      const fallbackReason = 'अभी AI सेवा से उत्तर नहीं मिल पाया। कृपया इंटरनेट कनेक्शन जांचकर दोबारा कोशिश करें।';

      return AssistantResponse(
        text: prediction != null && prediction.isValid
            ? 'निदान: ${prediction.crop} — ${prediction.condition} (${prediction.confidencePercentage})\n\n$fallbackReason'
            : fallbackReason,
        ragSources: const [],
        mlSummary: prediction != null ? _buildMlSummary(prediction) : null,
        weatherUsed: false,
        ragUsed: false,
        llmUsed: false,
        llmAvailable: false,
        timestamp: DateTime.now(),
      );
    }

    // ── ENGLISH PATH: existing RAG pipeline — completely unchanged ─────────────

    // ── 2b. Build enriched query for RAG ─────────────────────────────────────
    String ragQuery = query;
    if (prediction != null && prediction.isValid) {
      ragQuery = '${prediction.crop} ${prediction.condition} $query';
    }

    // ── 3. Retrieve agricultural knowledge ───────────────────────────────────
    final chunks = await _ragService.retrieve(ragQuery, topK: AppConfig.ragTopK);
    final ragUsed = chunks.isNotEmpty;
    debugPrint('[AssistantService] RAG: ${chunks.length} chunks retrieved.');

    // ── 4. Get current device GPS position ───────────────────────────────────
    final currentPos = LocationService.instance.lastKnownPosition;
    String? geocodedLocation;
    if (currentPos != null) {
      // Reverse-geocode on demand (10-min cache)
      geocodedLocation = await _geocoding.reverseGeocode(
          currentPos.latitude, currentPos.longitude);
    }

    // ── 5. Fetch farm context (UID-isolated, separate from device location) ──
    String farmContext = '';
    List<DetectionRecord> recentDetections = [];
    if (uid != null) {
      try {
        final farms = await _farmRepo.streamUserFarms(uid).first;
        if (farms.isNotEmpty) {
          final farm = farms.first;
          farmContext = 'Farm name: ${farm.name}';
          if (farm.cropType != null) farmContext += ', Crop: ${farm.cropType}';
          farmContext += ', Area: ${farm.formattedArea}';
        }

        // Latest 5 detections for history context
        recentDetections = await _detectionRepo
            .streamUserDetections(uid)
            .first
            .then((list) => list.take(5).toList());
      } catch (e) {
        debugPrint('[AssistantService] Farm context error: $e');
      }
    }

    // ── 6. Fetch weather context (only when query is weather-relevant) ────────
    WeatherData? weather;
    final weatherNeeded = _isWeatherRelevantQuery(query);
    if (weatherNeeded && currentPos != null) {
      weather = await _weatherService.getWeather(
          currentPos.latitude, currentPos.longitude);
    }
    debugPrint('[AssistantService] Weather injected: ${weather != null}');

    // ── 7. Build LLM prompt ───────────────────────────────────────────────────
    final prompt = _buildPrompt(
      query: query,
      prediction: prediction,
      chunks: chunks,
      weather: weather,
      farmContext: farmContext,
      currentPos: currentPos,
      geocodedLocation: geocodedLocation,
      recentDetections: recentDetections,
    );
    debugPrint('[AssistantService] Prompt length: ${prompt.length} chars');

    // ── 8. Generate LLM response ──────────────────────────────────────────────
    final llmText = await _llmService.generate(prompt);
    final llmAvailable = _llmService.isAvailable;
    final ragSources =
        chunks.map((c) => c.section).where((s) => s.isNotEmpty).toList();
    final mlSummary =
        prediction != null ? _buildMlSummary(prediction) : null;

    if (llmText != null && llmText.isNotEmpty) {
      return AssistantResponse(
        text: llmText,
        ragSources: ragSources,
        mlSummary: mlSummary,
        weatherUsed: weather != null,
        ragUsed: ragUsed,
        llmUsed: true,
        llmAvailable: true,
        timestamp: DateTime.now(),
      );
    }

    // ── 9. RAG-only fallback (LLM unavailable) ────────────────────────────────
    if (ragUsed) {
      final fallbackText = _buildRagOnlyFallback(
        query: query,
        prediction: prediction,
        chunks: chunks,
        weather: weather,
      );
      return AssistantResponse(
        text: fallbackText,
        ragSources: ragSources,
        mlSummary: mlSummary,
        weatherUsed: weather != null,
        ragUsed: true,
        llmUsed: false,
        llmAvailable: llmAvailable,
        timestamp: DateTime.now(),
      );
    }

    // ── 10. Full offline fallback ─────────────────────────────────────────────
    return AssistantResponse.unavailable(
      'The agricultural knowledge base is currently loading. Please try your question again in a moment.',
    );
  }

  /// Minimal Gemini diagnostic: sends "नमस्ते। हिंदी में उत्तर दें।" directly
  /// to Gemini bypassing ALL application context (RAG, ML, weather, GPS, field history).
  /// Logs the exact result or failure reason.
  /// Called automatically the first time a Hindi query is submitted.
  Future<void> runGeminiDiagnosticTest() async {
    debugPrint('[GeminiDiag] ════════════════════════════════════════════');
    debugPrint('[GeminiDiag] MINIMAL GEMINI DIAGNOSTIC TEST START');
    debugPrint('[GeminiDiag] Prompt: "नमस्ते। हिंदी में उत्तर दें।"');
    debugPrint('[GeminiDiag] No RAG / No ML / No weather / No GPS');
    try {
      final result = await _geminiService.generateHindiResponse(
        prompt: 'नमस्ते। हिंदी में उत्तर दें।',
        timeout: const Duration(seconds: 20),
      );
      if (result != null && result.isNotEmpty) {
        debugPrint('[GeminiDiag] ✓ DIAGNOSTIC SUCCESS — Gemini responded (${result.length} chars)');
        debugPrint('[GeminiDiag] Response preview: ${result.substring(0, result.length.clamp(0, 200))}');
      } else {
        debugPrint('[GeminiDiag] ✗ DIAGNOSTIC FAILED — Gemini returned null/empty');
      }
    } catch (e, stack) {
      debugPrint('[GeminiDiag] ✗ DIAGNOSTIC EXCEPTION: $e\n$stack');
    }
    debugPrint('[GeminiDiag] ════════════════════════════════════════════');
  }

  // ── Vague query classifier ─────────────────────────────────────────────────

  /// Returns a clarification question if the query is too vague or ambiguous.
  /// Returns null if the query is specific enough to proceed.
  String? _checkVagueQuery(String query, {bool hasImage = false}) {
    if (hasImage) return null; // Image always provides context

    final q = query.trim().toLowerCase();
    final words = q.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();

    // Allow through: location/weather questions (even if short)
    if (_isLocationQuery(q) || _isWeatherRelevantQuery(q)) return null;

    // Allow through: Hindi Devanagari text always (language detection is responsible,
    // not vague-query classifier — Hindi questions are inherently meaningful)
    if (LanguageService.isTextHindi(query)) return null;

    // Allow through: Hinglish Romanised Hindi keywords commonly used by farmers
    final hinglishKeywords = [
      'kaise', 'kya', 'kyu', 'kyun', 'kab', 'kitna', 'karo', 'karu',
      'meri', 'mera', 'mere', 'fasal', 'bimari', 'keede', 'kida',
      'ilaj', 'upay', 'dawa', 'spray', 'rog', 'neem', 'jankari',
      'soybean', 'kapas', 'gehun', 'dhan', 'makka',
    ];
    if (hinglishKeywords.any((kw) => q.contains(kw))) return null;

    // Allow through: questions with English question words or meaningful content
    final hasMeaningfulContent = words.length >= 3 ||
        q.contains('how') ||
        q.contains('why') ||
        q.contains('what') ||
        q.contains('when') ||
        q.contains('where') ||
        q.contains('which') ||
        q.contains('should') ||
        q.contains('disease') ||
        q.contains('pest') ||
        q.contains('spray') ||
        q.contains('fertilize') ||
        q.contains('water') ||
        q.contains('irrigat') ||
        q.contains('harvest') ||
        q.contains('sow') ||
        q.contains('diagnos') ||
        q.contains('symptom') ||
        q.contains('treatment') ||
        q.contains('manage') ||
        q.contains('control') ||
        q.contains('detect') ||
        // Hindi Devanagari keywords already handled above, these are kept for completeness
        q.contains('रोग') ||
        q.contains('कीट') ||
        q.contains('दवा') ||
        q.contains('इल्ली') ||
        q.contains('सुंडी') ||
        q.contains('मक्खी') ||
        q.contains('उपचार') ||
        q.contains('खाद') ||
        q.contains('उर्वरक') ||
        q.contains('रोकथाम') ||
        q.contains('नियंत्रण') ||
        q.contains('छिड़काव') ||
        q.contains('पानी') ||
        q.contains('सिंचाई') ||
        q.contains('फसल') ||
        q.contains('कपास') ||
        q.contains('सोयाबीन') ||
        q.contains('टमाटर') ||
        q.contains('मौसम');

    if (!hasMeaningfulContent) {
      final queryLang = LanguageService.instance.detectQueryLanguage(query);
      final isHindi = queryLang == 'hi';
      // Build a crop-aware clarification when possible
      final crop = _extractCropName(q);
      if (crop != null) {
        if (isHindi) {
          return 'जी अवश्य! आप $crop के बारे में क्या जानना चाहते हैं? '
              'जैसे: रोग की पहचान, कीट रोकथाम, खाद-उर्वरक, सिंचाई या फसल प्रबंधन।';
        }
        return 'Sure! What would you like to know about $crop? '
            'For example: disease identification, pest control, irrigation, '
            'fertilizer, weather risk, or general crop management.';
      }
      if (isHindi) {
        return 'कृपया अपना प्रश्न थोड़ा और स्पष्ट करें। आप फसल में रोग की पहचान, कीट रोकथाम, '
            'खाद-उर्वरक का उपयोग, सिंचाई या मौसम के जोखिम के बारे में पूछ सकते हैं।';
      }
      return 'Could you be more specific? For example, you can ask about '
          'disease identification, pest control, irrigation, fertilizer use, '
          'weather risk, or general crop management for your field.';
    }

    return null;
  }

  /// Detects a crop name in the query for richer clarification messages.
  String? _extractCropName(String q) {
    const crops = [
      'soybean', 'soya', 'cotton', 'wheat', 'rice', 'maize', 'corn',
      'sugarcane', 'groundnut', 'tomato', 'potato', 'onion', 'chili',
      'mango', 'mustard', 'gram', 'lentil', 'chickpea', 'sunflower',
      'कपास', 'सोयाबीन', 'टमाटर', 'गेहूं', 'धान', 'चावल', 'गन्ना', 'चना',
    ];
    for (final crop in crops) {
      if (q.contains(crop)) return crop;
    }
    return null;
  }

  /// True when the query is specifically about location/GPS/position.
  bool _isLocationQuery(String q) {
    return q.contains('locat') ||
        q.contains('where am i') ||
        q.contains('my location') ||
        q.contains('current place') ||
        q.contains('which place') ||
        q.contains('which city') ||
        q.contains('which village') ||
        q.contains('which district') ||
        q.contains('which state') ||
        q.contains('address') ||
        q.contains('gps') ||
        q.contains('coordinates') ||
        q.contains('latitude') ||
        q.contains('longitude') ||
        q.contains('near') ||
        q.contains('am i in') ||
        q.contains('which area');
  }

  /// True when weather context is relevant to the query.
  bool _isWeatherRelevantQuery(String q) {
    final lower = q.toLowerCase();
    return lower.contains('weather') ||
        lower.contains('temperature') ||
        lower.contains('rain') ||
        lower.contains('humid') ||
        lower.contains('wind') ||
        lower.contains('forecast') ||
        lower.contains('climate') ||
        lower.contains('celsius') ||
        lower.contains('degree') ||
        lower.contains('hot') ||
        lower.contains('cold') ||
        lower.contains('wet') ||
        lower.contains('dry') ||
        lower.contains('monsoon') ||
        lower.contains('storm') ||
        lower.contains('drought') ||
        lower.contains('flood') ||
        lower.contains('irrigation') ||
        lower.contains('irrigat') ||
        lower.contains('today') ||
        lower.contains('tonight') ||
        lower.contains('right now') ||
        lower.contains('disease risk') ||
        lower.contains('spray') && (lower.contains('day') || lower.contains('time') || lower.contains('when'));
  }

  // ── Prompt builder ─────────────────────────────────────────────────────────

  String _buildPrompt({
    required String query,
    required PredictionResult? prediction,
    required List<RagChunk> chunks,
    required WeatherData? weather,
    required String farmContext,
    required GeoCoordinate? currentPos,
    required String? geocodedLocation,
    required List<DetectionRecord> recentDetections,
  }) {
    final buf = StringBuffer();

    final queryLang = LanguageService.instance.detectQueryLanguage(query);
    final isHindi = queryLang == 'hi';

    // ── LANGUAGE MANDATE — placed FIRST so a small 1B model cannot miss it ───
    // For Gemma 3 1B INT4, the language instruction must be the very first
    // token stream seen. Writing part of the mandate IN the target language
    // dramatically increases compliance in small quantized models.
    if (isHindi) {
      buf.writeln('निर्देश: आप KisaanBandhu हैं — भारतीय किसानों के लिए एक कृषि सहायक।');
      buf.writeln('महत्वपूर्ण: किसान ने हिंदी में प्रश्न पूछा है। आपको हिंदी में उत्तर देना अनिवार्य है।');
      buf.writeln('प्राकृतिक हिंदी उपयोग करें। कृषि तकनीकी शब्द (जैसे stage, monitoring, spray, caterpillar, affected area, control) अंग्रेज़ी में रख सकते हैं।');
      buf.writeln('किताबी या कठिन हिंदी न उपयोग करें। किसान से सरल और व्यावहारिक भाषा में बात करें।');
      buf.writeln('अंग्रेज़ी में उत्तर देना मना है जब किसान हिंदी में पूछे।');
    } else {
      buf.writeln('You are KisaanBandhu, an expert agricultural decision-support assistant for Indian farmers.');
      buf.writeln('LANGUAGE INSTRUCTION: The farmer asked in English. Respond in clear, practical, farmer-friendly English.');
      buf.writeln('Do NOT respond in Hindi when the farmer asked in English.');
    }
    buf.writeln();

    buf.writeln('AGRICULTURAL GROUNDING & SAFETY RULES:');
    buf.writeln('1. Use ONLY the retrieved agricultural knowledge provided below as your factual source.');
    buf.writeln('2. Do NOT invent synthetic pesticide names, chemical doses, or unverified treatment claims.');
    if (prediction != null && prediction.isValid) {
      buf.writeln('3. "इस बीमारी" / "this disease" / "इसको" / "this" in the farmer question refers to the ATTACHED IMAGE DIAGNOSIS below.');
    }
    buf.writeln('4. Follow IPM: Prevention/Monitoring -> Cultural -> Biological (neem oil/NPV) -> Chemical (only if grounded).');
    buf.writeln('5. If previous remedy failed or symptoms are spreading: acknowledge, escalate, or advise KVK expert consultation.');
    buf.writeln('6. Output clean readable text without excessive markdown symbols.');
    buf.writeln();

    // ── ML detection result ──────────────────────────────────────────────────
    if (prediction != null) {
      buf.writeln('ATTACHED IMAGE DIAGNOSIS (Subject of farmer query — "इस बीमारी" refers to this):');
      buf.writeln('Crop: ${prediction.crop}');
      buf.writeln('Condition: ${prediction.condition}');
      buf.writeln('Confidence: ${prediction.confidencePercentage}');
      buf.writeln('Diagnostic State: ${prediction.state.name}');
      buf.writeln();
    }

    // ── Retrieved agricultural knowledge (grounding source) ──────────────────
    if (chunks.isNotEmpty) {
      buf.writeln('RETRIEVED AGRICULTURAL KNOWLEDGE (primary factual source):');
      int charsUsed = 0;
      for (final chunk in chunks) {
        final entry = '[${chunk.section}]\n${chunk.text}\n\n';
        if (charsUsed + entry.length > AppConfig.maxContextChars) break;
        buf.write(entry);
        charsUsed += entry.length;
      }
      buf.writeln();
    }

    // ── Current device location (GPS + reverse-geocoded) ─────────────────────
    if (currentPos != null) {
      buf.writeln('CURRENT DEVICE LOCATION:');
      buf.writeln('Latitude: ${currentPos.latitude.toStringAsFixed(5)}, Longitude: ${currentPos.longitude.toStringAsFixed(5)}');
      if (geocodedLocation != null) buf.writeln('Location: $geocodedLocation');
      buf.writeln();
    }

    // ── Farm context ──────────────────────────────────────────────────────────
    if (farmContext.isNotEmpty) {
      buf.writeln('REGISTERED FARM: $farmContext');
      buf.writeln();
    }

    // ── Weather context ───────────────────────────────────────────────────────
    if (weather != null) {
      buf.writeln('CURRENT WEATHER: ${weather.toContextString()} | Risk: ${weather.diseaseRiskLevel}');
      buf.writeln();
    }

    // ── Farmer question — labelled in both scripts for maximum clarity ────────
    if (isHindi) {
      buf.writeln('किसान का प्रश्न (Farmer Question):');
    } else {
      buf.writeln('FARMER QUESTION:');
    }
    buf.writeln(query);
    buf.writeln();

    // ── Final reinforcement of language mandate ───────────────────────────────
    if (isHindi) {
      buf.writeln('ऊपर दी गई जानकारी के आधार पर किसान के प्रश्न का हिंदी में स्पष्ट उत्तर दें।');
    } else {
      buf.writeln('Answer the question accurately in English using only the information above.');
    }

    return buf.toString();
  }

  String _buildMlSummary(PredictionResult r) {
    if (!r.isValid) return 'Image diagnosis uncertain (${r.state.name})';
    return '${r.crop} - ${r.condition} — ${r.confidencePercentage} confidence';
  }

  // ── Language routing helper ────────────────────────────────────────────────

  /// Returns true when the query is Hindi (Devanagari) or clearly Hinglish
  /// (Romanised Hindi used by Indian farmers). These queries bypass English RAG
  /// and go directly to Gemma for response generation.
  bool _isHindiOrHinglish(String query) {
    // Devanagari script — unambiguous Hindi
    if (LanguageService.isTextHindi(query)) return true;

    // Romanised Hinglish: common Hindi question/topic words used by farmers.
    // Keep this list small and high-precision — we only want clearly Hindi-intent
    // queries, not English sentences that happen to share a syllable.
    final q = query.toLowerCase();
    const hinglishMarkers = [
      'kaise', 'kyu ', 'kyun', ' kya ', 'kya karu', 'kab ', 'kitna',
      'karo ', 'karu', 'meri ', 'mera ', 'mere ', 'mujhe',
      'fasal', 'bimari', 'keede', ' kida', 'ilaj', 'upay',
      ' dawa', 'rog ', 'jankari', 'kapas', 'gehun', ' dhan',
      'makka', 'fail ra', 'lag gaye', 'lag gaya', 'lag rahi',
      'kab tak', 'ab kya', 'kaise kare', 'kaise roke', 'kya hai',
      'kya kare', 'dalni', 'dalna chahiye', 'iska ilaj', 'isme ',
    ];
    return hinglishMarkers.any((marker) => q.contains(marker));
  }

  // ── Hindi direct-Gemma prompt (no RAG chunks) ──────────────────────────────

  /// Builds a clean, Hindi-optimised prompt for Gemma when English RAG is bypassed.
  /// Includes ML result + farm context + weather — everything except RAG chunks.
  String _buildHindiDirectPrompt({
    required String query,
    required PredictionResult? prediction,
    required WeatherData? weather,
    required String farmContext,
    required String? geocodedLocation,
  }) {
    final buf = StringBuffer();

    buf.writeln('निर्देश: आप KisaanBandhu हैं - भारतीय किसानों के लिए एक कृषि सहायक।');
    buf.writeln('उपयोगकर्ता के प्रश्न का उत्तर सरल, प्राकृतिक और किसान-अनुकूल हिंदी में दें।');
    buf.writeln();

    if (prediction != null && prediction.isValid) {
      buf.writeln('फसल रोग निदान (Image Diagnosis):');
      buf.writeln('फसल: ${prediction.crop}');
      buf.writeln('रोग/स्थिति: ${prediction.condition}');
      buf.writeln('सटीकता: ${prediction.confidencePercentage}');
      buf.writeln('नोट: "इस बीमारी" या "इसको" इसी निदान को दर्शाता है।');
      buf.writeln();
    }

    if (farmContext.isNotEmpty) {
      buf.writeln('खेत की जानकारी: $farmContext');
      buf.writeln();
    }

    if (geocodedLocation != null) {
      buf.writeln('स्थान: $geocodedLocation');
      buf.writeln();
    }

    if (weather != null) {
      buf.writeln('मौसम: ${weather.toContextString()} | जोखिम: ${weather.diseaseRiskLevel}');
      buf.writeln();
    }

    buf.writeln('किसान का प्रश्न:');
    buf.writeln(query);
    buf.writeln();
    buf.writeln('उत्तर (हिंदी में):');

    return buf.toString();
  }

  // ── Hindi field-point prompt (no RAG chunks) ───────────────────────────────

  /// Builds a Hindi-optimised prompt for Gemma for Field Assistant progression
  /// queries when English RAG is bypassed. Includes full field case context.
  String _buildHindiFieldPointPrompt({
    required FieldPointContext fieldContext,
    required String query,
    required PredictionResult? currentPrediction,
    required WeatherData? weather,
  }) {
    final buf = StringBuffer();

    buf.writeln('निर्देश: आप KisaanBandhu हैं - किसान के खेत के एक GPS-tagged detection point का निरीक्षण कर रहे हैं।');
    buf.writeln('उत्तर सरल, प्राकृतिक और किसान-अनुकूल हिंदी में दें। तकनीकी शब्द (stage, monitoring, spray) स्वाभाविक रूप से रख सकते हैं।');
    buf.writeln();

    buf.writeln('Field Point Identity:');
    buf.writeln('फसल/रोग: ${fieldContext.crop} - ${fieldContext.previousCondition} (${(fieldContext.previousConfidence * 100).toStringAsFixed(1)}%)');
    buf.writeln('पिछली जांच: ${fieldContext.reviewCount} बार');
    buf.writeln();

    if (fieldContext.previousAssessments.isNotEmpty) {
      buf.writeln('पिछली जांच का इतिहास:');
      for (int i = 0; i < fieldContext.previousAssessments.length; i++) {
        final a = fieldContext.previousAssessments[i];
        buf.writeln('#${fieldContext.previousAssessments.length - i} (${a.createdAt.toIso8601String().split("T").first}): ${a.crop} - ${a.condition} | ${a.severityLabel} / ${a.progressionLabel}');
        if (a.recommendationSummary.isNotEmpty) {
          buf.writeln('  पुरानी सलाह: ${a.recommendationSummary}');
        }
      }
      buf.writeln();
    }

    if (currentPrediction != null) {
      buf.writeln('अभी का Image Diagnosis:');
      buf.writeln('फसल: ${currentPrediction.crop} | रोग: ${currentPrediction.condition} | सटीकता: ${currentPrediction.confidencePercentage}');
      buf.writeln('नोट: "इस बीमारी" या "इसको" इसी निदान को दर्शाता है।');
      buf.writeln();
    }

    if (weather != null) {
      buf.writeln('मौसम: ${weather.toContextString()} | जोखिम: ${weather.diseaseRiskLevel}');
      buf.writeln();
    }

    buf.writeln('किसान का प्रश्न / Visit Notes:');
    buf.writeln(query.isNotEmpty ? query : 'इस field point की वर्तमान स्थिति का मूल्यांकन करें और आगे की सलाह दें।');
    buf.writeln();
    buf.writeln('उत्तर (हिंदी में):');

    return buf.toString();
  }

  /// Compose a readable answer from on-device RAG chunks when local LLM is
  /// initializing or offline. Honours the user's language.
  String _buildRagOnlyFallback({
    required String query,
    required PredictionResult? prediction,
    required List<RagChunk> chunks,
    required WeatherData? weather,
  }) {
    final buf = StringBuffer();
    final isHindi = LanguageService.instance.detectQueryLanguage(query) == 'hi';

    if (prediction != null && prediction.isValid) {
      if (isHindi) {
        buf.writeln('निदान: ${prediction.crop} - ${prediction.condition} (${prediction.confidencePercentage} सटीकता)');
      } else {
        buf.writeln('Diagnosis: ${prediction.crop} - ${prediction.condition} (${prediction.confidencePercentage} confidence)');
      }
      buf.writeln();
    }

    if (isHindi) {
      buf.writeln('कृषि जानकारी:');
    } else {
      buf.writeln('Verified Agricultural Information:');
    }
    buf.writeln();

    for (int i = 0; i < chunks.length.clamp(0, 3); i++) {
      final chunk = chunks[i];
      final preview =
          chunk.text.length > 450 ? '${chunk.text.substring(0, 450)}...' : chunk.text;
      buf.writeln('${chunk.section}:');
      buf.writeln(preview);
      buf.writeln();
    }

    if (weather != null) {
      if (isHindi) {
        buf.writeln('मौसम: ${weather.toContextString()} | जोखिम: ${weather.diseaseRiskLevel}');
      } else {
        buf.writeln('Field Weather: ${weather.toContextString()} (Risk: ${weather.diseaseRiskLevel})');
      }
      buf.writeln();
    }

    if (isHindi) {
      buf.writeln('(On-device AI अभी load हो रहा है। कृपया थोड़ी देर बाद दोबारा पूछें।)');
    } else {
      buf.writeln('(On-device AI is initializing. Please ask again in a moment.)');
    }

    return buf.toString();
  }

  /// Process a field point inspection with structured progression context.
  Future<AssistantResponse> respondToFieldPoint({
    required FieldPointContext fieldContext,
    required String query,
    File? imageFile,
    PredictionResult? mlResult,
  }) async {
    debugPrint('[FP_GEMMA] ENTER progression method');
    debugPrint('[FP_GEMMA] previous detection loaded\n  condition=${fieldContext.crop} • ${fieldContext.previousCondition}\n  confidence=${fieldContext.previousConfidence}');
    debugPrint('[FP_GEMMA] current ML result loaded\n  prediction=${mlResult?.predictedClass ?? "none"}');

    // 1. Run ML inference on follow-up image if provided
    PredictionResult? prediction = mlResult;
    if (imageFile != null && prediction == null) {
      try {
        debugPrint('[FIELD_GEMMA] ML started');
        prediction = await _mlService.classifyImageFile(imageFile);
        debugPrint('[FIELD_GEMMA] ML completed:\n  crop=${prediction.crop}\n  condition=${prediction.condition}\n  confidence=${prediction.confidence}');
      } catch (e) {
        debugPrint('[FIELD_GEMMA] ERROR: Field ML failed: $e');
      }
    } else if (prediction != null) {
      debugPrint('[FIELD_GEMMA] ML completed:\n  crop=${prediction.crop}\n  condition=${prediction.condition}\n  confidence=${prediction.confidence}');
    }

    // 2. Language routing decision
    final isHindiQuery = _isHindiOrHinglish(query);
    debugPrint('[FP_GEMMA] Language routing: ${isHindiQuery ? "HINDI → direct Gemma" : "ENGLISH → RAG pipeline"}');

    // 3. RAG retrieval — English only
    List<RagChunk> chunks = const [];
    bool ragUsed = false;
    if (!isHindiQuery) {
      // Build enriched English query for RAG
      String ragQuery = query;
      if (prediction != null && prediction.isValid) {
        ragQuery = '${prediction.crop} ${prediction.condition} $query';
      } else {
        ragQuery = '${fieldContext.crop} ${fieldContext.previousCondition} $query';
      }
      debugPrint('[FP_GEMMA] RAG START (query="$ragQuery")');
      chunks = await _ragService.retrieve(ragQuery, topK: AppConfig.ragTopK);
      debugPrint('[FP_GEMMA] RAG COMPLETE\n  chunks=${chunks.length}');
      ragUsed = chunks.isNotEmpty;
    } else {
      debugPrint('[FP_GEMMA] RAG SKIPPED — Hindi/Hinglish query detected');
    }

    // 4. Fetch/use weather
    WeatherData? weather = fieldContext.currentWeather;
    if (weather == null && fieldContext.coordinates.latitude != 0) {
      try {
        weather = await _weatherService.getWeather(
          fieldContext.coordinates.latitude,
          fieldContext.coordinates.longitude,
        );
      } catch (_) {}
    }

    // 5. Build prompt
    final prompt = isHindiQuery
        ? _buildHindiFieldPointPrompt(
            fieldContext: fieldContext,
            query: query,
            currentPrediction: prediction,
            weather: weather,
          )
        : _buildFieldPointPrompt(
            fieldContext: fieldContext,
            query: query,
            currentPrediction: prediction,
            chunks: chunks,
            weather: weather,
          );
    debugPrint('[FP_GEMMA] PROMPT CREATED\n  chars=${prompt.length}\n  approxTokens=${(prompt.length / 4).round()}');

    final mlSummary =
        prediction != null ? _buildMlSummary(prediction) : null;

    // ── 6a. HINDI / HINGLISH: Direct Gemini API path (no RAG, no local Gemma) ─
    if (isHindiQuery) {
      String? geminiText;
      try {
        debugPrint('[FP_GEMMA] [HINDI_GEMINI] Calling Gemini API for Field Point...');
        geminiText = await _geminiService.generateHindiResponse(prompt: prompt);
        debugPrint('[FP_GEMMA] [HINDI_GEMINI] Result: ${geminiText != null ? "SUCCESS (${geminiText.length} chars)" : "NULL/FAILED"}');
      } catch (e, stack) {
        debugPrint('[FP_GEMMA] [HINDI_GEMINI] Exception: $e\n$stack');
      }

      if (geminiText != null && geminiText.isNotEmpty) {
        return AssistantResponse(
          text: geminiText,
          ragSources: const [],
          mlSummary: mlSummary,
          weatherUsed: weather != null,
          ragUsed: false,
          llmUsed: true,
          llmAvailable: true,
          timestamp: DateTime.now(),
        );
      }

      // Gemini failure fallback (Hindi localized error message)
      const fallbackReason = 'अभी AI सेवा से उत्तर नहीं मिल पाया। कृपया इंटरनेट कनेक्शन जांचकर दोबारा कोशिश करें।';
      return AssistantResponse(
        text: fallbackReason,
        ragSources: const [],
        mlSummary: mlSummary,
        weatherUsed: weather != null,
        ragUsed: false,
        llmUsed: false,
        llmAvailable: false,
        timestamp: DateTime.now(),
      );
    }

    // ── 6b. ENGLISH: Existing on-device Gemma + RAG pipeline (unchanged) ─────
    debugPrint('[FP_GEMMA] LLM SERVICE ENTER');
    debugPrint('[FP_GEMMA] engine=LiteRT-LM / FFI\n  runtime=flutter_gemma (1.6.5)\n  model=gemma3-1b-it-int4\n  backend=cpu');
    debugPrint('[FP_GEMMA] GEMMA INIT START');
    final llmAvailable = await _llmService.initialize();
    debugPrint('[FP_GEMMA] GEMMA INIT COMPLETE: ready=$llmAvailable');

    String? llmText;
    if (llmAvailable) {
      try {
        llmText = await _llmService.generate(prompt);
      } catch (e, stack) {
        debugPrint('[FP_GEMMA] ERROR: $e\n$stack');
      }
    }

    final ragSources =
        chunks.map((c) => c.section).where((s) => s.isNotEmpty).toList();

    if (llmText != null && llmText.isNotEmpty) {
      return AssistantResponse(
        text: llmText,
        ragSources: ragSources,
        mlSummary: mlSummary,
        weatherUsed: weather != null,
        ragUsed: ragUsed,
        llmUsed: true,
        llmAvailable: true,
        timestamp: DateTime.now(),
      );
    }

    // 7. RAG fallback (English path only — Hindi path already handled above)
    if (ragUsed) {
      debugPrint('[FP_GEMMA] Fallback to RAG response');
      final fallbackText = _buildRagOnlyFallback(
        query: query,
        prediction: prediction,
        chunks: chunks,
        weather: weather,
      );
      return AssistantResponse(
        text: fallbackText,
        ragSources: ragSources,
        mlSummary: mlSummary,
        weatherUsed: weather != null,
        ragUsed: true,
        llmUsed: false,
        llmAvailable: llmAvailable,
        timestamp: DateTime.now(),
      );
    }

    final fallbackReason = isHindiQuery
        ? (!llmAvailable
            ? 'On-device AI मॉडल अभी लोड हो रहा है या डिवाइस पर डाउनलोड नहीं हुआ है। कृपया थोड़ी देर बाद पुनः प्रयास करें।'
            : 'AI उत्तर तैयार करने में समस्या आई। कृपया अपना प्रश्न दोबारा पूछें।')
        : 'Knowledge base is loading. Please try again.';

    return AssistantResponse.unavailable(fallbackReason);
  }

  String _buildFieldPointPrompt({
    required FieldPointContext fieldContext,
    required String query,
    required PredictionResult? currentPrediction,
    required List<RagChunk> chunks,
    required WeatherData? weather,
  }) {
    final buf = StringBuffer();

    final queryLang = LanguageService.instance.detectQueryLanguage(query);
    final isHindi = queryLang == 'hi';

    // ── LANGUAGE MANDATE — first, for reliable compliance in a 1B model ──────
    if (isHindi) {
      buf.writeln('निर्देश: आप KisaanBandhu हैं — किसान के खेत के एक GPS-tagged point का निरीक्षण कर रहे हैं।');
      buf.writeln('महत्वपूर्ण: किसान ने हिंदी में प्रश्न पूछा है। हिंदी में उत्तर देना अनिवार्य है।');
      buf.writeln('प्राकृतिक हिंदी उपयोग करें। कृषि तकनीकी शब्द (stage, monitoring, spray, affected area, control) अंग्रेज़ी में रख सकते हैं।');
      buf.writeln('अंग्रेज़ी में उत्तर न दें।');
    } else {
      buf.writeln('You are KisaanBandhu, an expert agricultural assistant inspecting a geotagged field detection point.');
      buf.writeln('LANGUAGE INSTRUCTION: The farmer asked in English. Respond in clear, practical, farmer-friendly English only.');
    }
    buf.writeln();

    buf.writeln('GROUNDING & PROGRESSION RULES:');
    buf.writeln('1. Use ONLY verified facts from the RETRIEVED AGRICULTURAL KNOWLEDGE section below.');
    buf.writeln('2. Do NOT invent pesticide names, chemical doses, or unverified treatments.');
    buf.writeln('3. This is an ongoing field case — compare with previous assessment history:');
    buf.writeln('   - Worsening/spreading/failed remedy: do NOT repeat the same advice. Escalate (IPM or KVK).');
    buf.writeln('   - Improving: encourage monitoring and cultural care.');
    buf.writeln('   - Severe/uncontrollable: recommend Krishi Vigyan Kendra (KVK) or agricultural officer.');
    if (currentPrediction != null && currentPrediction.isValid) {
      buf.writeln('4. "इस बीमारी" / "इसको" / "this disease" in the farmer question refers to the CURRENT RE-SCAN DIAGNOSIS below.');
    }
    buf.writeln();

    // Field point identity
    buf.writeln('FIELD POINT:');
    buf.writeln('Target: ${fieldContext.crop} - ${fieldContext.previousCondition} (${(fieldContext.previousConfidence * 100).toStringAsFixed(1)}%)');
    buf.writeln('Coordinates: ${fieldContext.coordsLabel} | Previous Visits: ${fieldContext.reviewCount}');
    buf.writeln();

    // Previous assessment history
    if (fieldContext.previousAssessments.isNotEmpty) {
      buf.writeln('PREVIOUS ASSESSMENTS (newest first):');
      for (int i = 0; i < fieldContext.previousAssessments.length; i++) {
        final a = fieldContext.previousAssessments[i];
        buf.writeln('#${fieldContext.previousAssessments.length - i} (${a.createdAt.toIso8601String().split("T").first}): ${a.crop} • ${a.condition} — ${a.severityLabel} / ${a.progressionLabel}');
        if (a.recommendationSummary.isNotEmpty) {
          buf.writeln('  Prev advice: ${a.recommendationSummary}');
        }
      }
      buf.writeln();
    } else {
      buf.writeln('PREVIOUS ASSESSMENTS: None (Initial Inspection).');
      buf.writeln();
    }

    // Current visit ML prediction
    if (currentPrediction != null) {
      buf.writeln('CURRENT RE-SCAN DIAGNOSIS ("इस बीमारी" refers to this):');
      buf.writeln('Crop: ${currentPrediction.crop} | Condition: ${currentPrediction.condition} | Confidence: ${currentPrediction.confidencePercentage}');
      buf.writeln();
    }

    // Weather
    if (weather != null) {
      buf.writeln('FIELD WEATHER: ${weather.toContextString()} | Risk: ${weather.diseaseRiskLevel}');
      buf.writeln();
    }

    // Retrieved RAG
    if (chunks.isNotEmpty) {
      buf.writeln('RETRIEVED AGRICULTURAL KNOWLEDGE:');
      int charCount = 0;
      for (final chunk in chunks) {
        if (charCount + chunk.text.length > AppConfig.maxContextChars) break;
        buf.writeln('--- [${chunk.section}] ---');
        buf.writeln(chunk.text);
        buf.writeln();
        charCount += chunk.text.length;
      }
    }

    // Farmer's question
    if (isHindi) {
      buf.writeln('किसान का प्रश्न / Visit Notes:');
    } else {
      buf.writeln('FARMER QUESTION / VISIT NOTES:');
    }
    buf.writeln(query.isNotEmpty ? query : (isHindi
        ? 'इस field point की वर्तमान स्थिति का मूल्यांकन करें और आगे की सलाह दें।'
        : 'Evaluate the current progression of this field point and provide actionable follow-up advice.'));
    buf.writeln();

    // Final reinforcement
    if (isHindi) {
      buf.writeln('ऊपर दी गई जानकारी के आधार पर हिंदी में स्पष्ट और व्यावहारिक सलाह दें।');
    } else {
      buf.writeln('Provide a concise, grounded, progression-aware recommendation in English.');
    }

    return buf.toString();
  }
}
