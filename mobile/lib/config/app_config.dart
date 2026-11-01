/// Standalone runtime configuration for KisaanBandhu on-device intelligence layer.
///
/// Zero development computer or local HTTP server dependencies.
class AppConfig {
  AppConfig._();

  // ── Gemini API (Multilingual Hindi/Hinglish Generation) ───────────────────
  /// Gemini API Key configured via `--dart-define=GEMINI_API_KEY=your_key`.
  /// Seamlessly falls back to GOOGLE_API_KEY or GOOGLE_PLACES_API_KEY.
  static String get geminiApiKey {
    const direct = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (direct.isNotEmpty) return direct;
    const googleKey = String.fromEnvironment('GOOGLE_API_KEY', defaultValue: '');
    if (googleKey.isNotEmpty) return googleKey;
    return const String.fromEnvironment('GOOGLE_PLACES_API_KEY', defaultValue: '');
  }

  // ── Geocoding ─────────────────────────────────────────────────────────────
  /// Cache TTL for reverse-geocoded location strings (Mapbox Geocoding v6).
  static const Duration geocodingCacheTtl = Duration(minutes: 10);

  // ── On-Device RAG Retrieval ───────────────────────────────────────────────
  /// Number of knowledge chunks retrieved per farmer query.
  static const int ragTopK = 3;

  /// Knowledge base asset path (109 chunks with precomputed 384d vectors).
  static const String ragKnowledgeAsset = 'assets/rag/knowledge_base.json';

  /// Text embedding model asset path (all-MiniLM-L6-v2 TFLite).
  static const String embeddingModelAsset = 'assets/ml/embedding_model.tflite';

  /// WordPiece tokenizer vocab asset path.
  static const String tokenizerVocabAsset = 'assets/ml/vocab.txt';

  // ── On-Device Local LLM (Google LiteRT-LM / MediaPipe / Gemma 3 1B INT4) ───
  /// Model identifier tag for on-device inference.
  static const String llmModel = 'gemma3-1b-it-int4';

  /// Maximum total sequence length (prompt + output tokens).
  /// Sized to 2048 to support full RAG context and detailed agricultural answers.
  static const int llmMaxTokens = 2048;

  /// Inference execution timeout (90s accommodates on-device CPU token decoding).
  static const Duration llmTimeout = Duration(seconds: 90);

  // ── Weather (Open-Meteo — free cloud API, no key) ─────────────────────────
  static const String weatherBaseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Cache TTL for weather observations before re-fetching.
  /// 10 minutes ensures assistant responses reflect current conditions.
  static const Duration weatherCacheTtl = Duration(minutes: 10);

  // ── Alert system ─────────────────────────────────────────────────────────
  /// Minimum cooldown between two consecutive alerts of the same type.
  static const Duration alertCooldown = Duration(hours: 6);

  // ── Context budget ────────────────────────────────────────────────────────
  /// Max characters for retrieved RAG knowledge in prompt (~400 tokens).
  static const int maxContextChars = 1600;

  // ── NestJS MongoDB Backend ────────────────────────────────────────────────
  /// Base URL for the NestJS + Prisma MongoDB backend.
  /// On Physical device via USB reverse: http://127.0.0.1:3000
  /// On Android emulator: http://10.0.2.2:3000
  /// Can be overridden via `--dart-define=BACKEND_URL=...`
  static String get backendBaseUrl {
    const override = String.fromEnvironment('BACKEND_URL', defaultValue: '');
    if (override.isNotEmpty) return override;
    return 'http://127.0.0.1:3000';
  }
}
