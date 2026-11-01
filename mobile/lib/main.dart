import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'app/app.dart';
import 'config/map_config.dart';
import 'services/notification_service.dart';
import 'services/alert_service.dart';
import 'services/backend_api_service.dart';
import 'services/language_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Mapbox Access Token
  try {
    mapbox.MapboxOptions.setAccessToken(MapConfig.mapboxAccessToken);
    debugPrint('[Mapbox] Access token set.');
  } catch (e) {
    debugPrint('[Mapbox] Init error: $e');
  }

  // Initialize language preferences
  try {
    await LanguageService.instance.initialize();
  } catch (e) {
    debugPrint('[LanguageService] Init error: $e');
  }

  // Register on-device inference engines (LiteRT-LM FFI & MediaPipe).
  // This is a one-time registration at startup — it does NOT load model weights.
  // Lazy model loading and memory management are handled by LlmService.
  try {
    FlutterGemma.initialize(
      inferenceEngines: [
        LiteRtLmEngine(),
        MediaPipeEngine(),
      ],
    );
    debugPrint('[FlutterGemma] On-device inference engines (LiteRT-LM + MediaPipe) registered.');
  } catch (e) {
    debugPrint('[FlutterGemma] Engine registration note: $e');
  }

  // Initialize notification infrastructure
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('[Notifications] Init error: $e');
  }

  // Initialize Backend API service (JWT session)
  try {
    await BackendApiService.instance.initialize();
  } catch (e) {
    debugPrint('[BackendAPI] Init error: $e');
  }

  // Start background weather alert polling
  try {
    AlertService.instance.startPolling();
  } catch (e) {
    debugPrint('[AlertService] Start error: $e');
  }

  runApp(const App());
}
