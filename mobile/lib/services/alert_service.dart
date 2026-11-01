import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/alert_model.dart';
import '../models/weather_model.dart';
import 'backend_api_service.dart';
import 'llm_service.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'rag_service.dart';
import 'weather_service.dart';
import 'language_service.dart';

/// Background agricultural alert system.
///
/// Polls weather every 30 minutes.
/// Uses rule-based evaluation (NOT LLM) to determine whether an alert condition exists.
/// LLM generates the concise farmer-friendly alert message.
/// Deduplicates alerts using SharedPreferences (cooldown per alert type per user).
class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  static AlertService get instance => _instance;

  Timer? _pollingTimer;
  bool _isRunning = false;

  final _weatherService = WeatherService.instance;
  final _ragService = RagService.instance;
  final _llmService = LlmService.instance;
  final _notificationService = NotificationService.instance;

  /// Start background weather polling with 30-minute interval.
  void startPolling() {
    if (_isRunning) return;
    _isRunning = true;

    // Run immediately on start, then repeat
    _checkAndAlert();
    _pollingTimer = Timer.periodic(AppConfig.weatherCacheTtl, (_) => _checkAndAlert());
    debugPrint('[AlertService] Polling started (every ${AppConfig.weatherCacheTtl.inMinutes} min).');
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isRunning = false;
    debugPrint('[AlertService] Polling stopped.');
  }

  /// Core evaluation cycle — runs periodically.
  Future<void> _checkAndAlert() async {
    final uid = BackendApiService.instance.currentUid;
    if (uid == null) {
      debugPrint('[AlertService] No authenticated user, skipping check.');
      return;
    }

    final lastPos = LocationService.instance.lastKnownPosition;
    if (lastPos == null) {
      debugPrint('[AlertService] No GPS position, skipping weather check.');
      return;
    }

    // ── 1. Fetch weather ─────────────────────────────────────────────────────
    final weather = await _weatherService.getWeather(lastPos.latitude, lastPos.longitude);
    if (weather == null) {
      debugPrint('[AlertService] Weather unavailable, skipping alert check.');
      return;
    }

    // ── 2. Rule-based evaluation (NO LLM here) ───────────────────────────────
    if (!weather.shouldAlert) {
      debugPrint('[AlertService] No alert condition detected (risk: ${weather.diseaseRiskLevel}).');
      return;
    }

    final alertType = weather.alertTypeKey;

    // ── 3. Deduplication check ───────────────────────────────────────────────
    final isDuplicate = await _isRecentAlert(uid, alertType);
    if (isDuplicate) {
      debugPrint('[AlertService] Alert type "$alertType" already issued recently, skipping.');
      return;
    }

    debugPrint('[AlertService] Alert condition detected: $alertType');

    // ── 4. Retrieve relevant RAG knowledge ───────────────────────────────────
    final ragQuery = _buildAlertRagQuery(weather);
    final chunks = await _ragService.retrieve(ragQuery, topK: 3);

    // ── 5. LLM generates the alert message ───────────────────────────────────
    final alertMessage = await _generateAlertMessage(weather, chunks);
    final alertTitle = _alertTitle(alertType);

    // ── 6. Save alert to Firestore ───────────────────────────────────────────
    final alertId = await _saveAlert(
      uid: uid,
      type: alertType,
      title: alertTitle,
      message: alertMessage,
      weather: weather,
    );

    // ── 7. Record deduplication timestamp ────────────────────────────────────
    await _recordAlertTime(uid, alertType);

    // ── 8. Show local notification ───────────────────────────────────────────
    await _notificationService.showAlert(
      title: alertTitle,
      body: alertMessage.length > 200 ? '${alertMessage.substring(0, 197)}…' : alertMessage,
      payload: 'alert:$alertId',
      id: alertType.hashCode.abs() % 100,
    );

    debugPrint('[AlertService] Alert sent: "$alertTitle"');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _buildAlertRagQuery(WeatherData weather) {
    if (weather.temperatureC >= 40) {
      return 'crop management during extreme heat stress high temperature';
    }
    if (weather.precipitation >= 10) {
      return 'disease risk management after heavy rainfall wet conditions';
    }
    return 'disease prevention high humidity warm temperature bacterial fungal risk';
  }

  String _alertTitle(String alertType) {
    final isHindi = LanguageService.instance.isHindi;
    switch (alertType) {
      case 'extreme_heat':
        return isHindi ? '🌡️ भीषण गर्मी की चेतावनी' : '🌡️ Extreme Heat Alert';
      case 'heavy_rain':
        return isHindi ? '🌧️ भारी वर्षा — रोग का जोखिम' : '🌧️ Heavy Rain — Disease Risk';
      case 'disease_risk':
        return isHindi ? '⚠️ फसल रोग का उच्च जोखिम' : '⚠️ High Disease Risk Conditions';
      default:
        return isHindi ? '🌾 कृषि मौसम चेतावनी' : '🌾 Agricultural Weather Alert';
    }
  }

  Future<String> _generateAlertMessage(WeatherData weather, List<RagChunk> chunks) async {
    final isHindi = LanguageService.instance.isHindi;
    // Build a short prompt for the alert message
    final ragContext = chunks.map((c) {
      final preview = c.text.length > 300 ? c.text.substring(0, 300) : c.text;
      return '[${c.section}]\n$preview';
    }).join('\n\n');

    final langDirective = isHindi
        ? 'उत्तर केवल हिंदी में दें। देवनागरी लिपि का प्रयोग करें। हिंग्लिश का प्रयोग न करें। किसानों के लिए 2-3 वाक्यों में सरल और स्पष्ट चेतावनी लिखें।'
        : 'Write a concise, practical agricultural alert message (2-3 sentences) in clear English.';

    final prompt = '<start_of_turn>system\n'
        'You are KisaanBandhu. $langDirective '
        'Be specific about what weather condition exists and what the farmer should watch out for. '
        'Do not invent pesticide names or doses.\n<end_of_turn>\n'
        '<start_of_turn>user\n'
        'Weather: ${weather.toContextString()}\n'
        'Disease risk: ${weather.diseaseRiskLevel}\n\n'
        'Agricultural knowledge:\n$ragContext\n\n'
        'Write a 2-3 sentence practical alert for the farmer.\n<end_of_turn>\n'
        '<start_of_turn>model\n';

    final llmText = await _llmService.generate(prompt);

    if (llmText != null && llmText.isNotEmpty) {
      return llmText;
    }

    // Fallback: compose without LLM
    return _buildFallbackAlertMessage(weather);
  }

  String _buildFallbackAlertMessage(WeatherData weather) {
    final isHindi = LanguageService.instance.isHindi;
    if (weather.temperatureC >= 40) {
      return isHindi
          ? 'भीषण तापमान (${weather.temperatureC.toStringAsFixed(0)}°C) दर्ज किया गया है। फसलों में नमी बनाए रखने के लिए सुबह या शाम हल्की सिंचाई करें।'
          : 'Extreme heat (${weather.temperatureC.toStringAsFixed(0)}°C) detected. Ensure adequate irrigation and protect sensitive crops.';
    }
    if (weather.precipitation >= 10) {
      return isHindi
          ? 'भारी वर्षा (${weather.precipitation.toStringAsFixed(0)} मिमी) के कारण खेत में जलभराव न होने दें और फफूंद जनित रोगों की निगरानी करें।'
          : 'Heavy rainfall (${weather.precipitation.toStringAsFixed(0)} mm) recorded. Ensure proper field drainage and monitor for fungal infections.';
    }
    if (weather.humidity >= 80) {
      return isHindi
          ? 'उच्च आर्द्रता (${weather.humidity.toStringAsFixed(0)}%) और अनुकूल तापमान के कारण कीट व रोगों का जोखिम बढ़ गया है। नियमित निगरानी रखें।'
          : 'High humidity (${weather.humidity.toStringAsFixed(0)}%) creates favorable conditions for fungal and bacterial disease spread. Monitor fields closely.';
    }
    return isHindi
        ? 'वर्तमान मौसम की स्थिति सामान्य है। फसल की नियमित निगरानी जारी रखें।'
        : 'Current conditions are within normal ranges. Continue regular field monitoring.';
  }

  Future<String> _saveAlert({
    required String uid,
    required String type,
    required String title,
    required String message,
    required WeatherData weather,
  }) async {
    try {
      final alertId = 'alert_${DateTime.now().millisecondsSinceEpoch}';
      final alert = AlertModel(
        id: alertId,
        userId: uid,
        type: type,
        title: title,
        message: message,
        severity: weather.diseaseRiskLevel,
        weatherContext: {
          'temperature': weather.temperatureC,
          'humidity': weather.humidity,
          'precipitation': weather.precipitation,
          'windSpeed': weather.windSpeedKmh,
          'description': weather.description,
          'riskLevel': weather.diseaseRiskLevel,
        },
        createdAt: DateTime.now(),
      );
      await BackendApiService.instance.saveAlert(alert);
      return alertId;
    } catch (e) {
      debugPrint('[AlertService] MongoDB alert save error: $e');
      return 'local';
    }
  }

  Future<bool> _isRecentAlert(String uid, String alertType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'alert_${uid}_$alertType';
      final lastMs = prefs.getInt(key);
      if (lastMs == null) return false;
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastMs;
      return elapsed < AppConfig.alertCooldown.inMilliseconds;
    } catch (e) {
      return false;
    }
  }

  Future<void> _recordAlertTime(String uid, String alertType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'alert_${uid}_$alertType';
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[AlertService] Prefs write error: $e');
    }
  }

  void dispose() => stopPolling();
}
