import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/alert_model.dart';
import '../models/detection_record.dart';
import '../models/farm_model.dart';
import '../models/field_assessment.dart';
import '../models/user_profile.dart';
import '../screens/assistant/models/chat_message.dart';

/// Central API service connecting the mobile application to the NestJS + Prisma MongoDB backend.
/// Replaces all Firebase Auth and Cloud Firestore dependencies with pure MongoDB storage.
class BackendApiService {
  static final BackendApiService _instance = BackendApiService._internal();
  factory BackendApiService() => _instance;
  BackendApiService._internal();

  static BackendApiService get instance => _instance;

  static const String _prefKeyJwt = 'krishi_jwt_token';
  static const String _prefKeyUserJson = 'krishi_user_json';
  static const String _prefKeyBackendUrl = 'krishi_backend_url';

  String? _jwtToken;
  UserProfile? _currentUser;
  String? _activeBaseUrl;

  final ValueNotifier<UserProfile?> currentUserNotifier = ValueNotifier<UserProfile?>(null);

  String? get jwtToken => _jwtToken;
  UserProfile? get currentUser => _currentUser;
  String? get currentUid => _currentUser?.uid;
  bool get isAuthenticated => _jwtToken != null && _jwtToken!.isNotEmpty && _currentUser != null;

  String get baseUrl => _activeBaseUrl ?? AppConfig.backendBaseUrl;

  List<String> get _candidateHosts {
    final list = <String>[];
    if (_activeBaseUrl != null && _activeBaseUrl!.isNotEmpty) {
      list.add(_activeBaseUrl!);
    }
    final configUrl = AppConfig.backendBaseUrl;
    if (!list.contains(configUrl)) list.add(configUrl);

    // Standard local development hosts: USB reverse, Android Emulator, Wi-Fi fallback
    for (final host in [
      'http://127.0.0.1:3000',
      'http://10.0.2.2:3000',
      'http://localhost:3000',
      'http://192.168.1.7:3000',
    ]) {
      if (!list.contains(host)) list.add(host);
    }
    return list;
  }

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_jwtToken != null) 'Authorization': 'Bearer $_jwtToken',
      };

  /// Initializes cached JWT session and custom backend URL from local storage on app start
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _jwtToken = prefs.getString(_prefKeyJwt);
      _activeBaseUrl = prefs.getString(_prefKeyBackendUrl);
      final userRaw = prefs.getString(_prefKeyUserJson);
      if (userRaw != null) {
        final map = jsonDecode(userRaw) as Map<String, dynamic>;
        _currentUser = UserProfile.fromMap(map, map['id'] ?? map['uid'] ?? '');
        currentUserNotifier.value = _currentUser;
        debugPrint('[BackendAPI] Restored MongoDB session for: ${_currentUser?.email} (${_currentUser?.uid})');
      }
      debugPrint('[BackendAPI] Initialized with baseUrl: $baseUrl');
    } catch (e) {
      debugPrint('[BackendAPI] Init error: $e');
    }
  }

  Future<void> setCustomBackendUrl(String url) async {
    _activeBaseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    debugPrint('[BackendAPI] Updated active backend URL to: $_activeBaseUrl');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyBackendUrl, _activeBaseUrl!);
    } catch (_) {}
  }

  // ── Network request helpers with multi-host fallback ────────────────────────

  Future<http.Response> _post(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Duration timeoutPerHost = const Duration(seconds: 4),
  }) async {
    dynamic lastError;
    for (final host in _candidateHosts) {
      final url = Uri.parse('$host$path');
      try {
        debugPrint('[BackendAPI] POST -> $url');
        final res = await http.post(
          url,
          headers: headers ?? _authHeaders,
          body: body,
        ).timeout(timeoutPerHost);

        // Server responded! Lock onto this host if changed
        if (_activeBaseUrl != host) {
          _activeBaseUrl = host;
          _persistActiveHost(host);
        }
        return res;
      } catch (e) {
        debugPrint('[BackendAPI] POST $url failed: $e');
        lastError = e;
      }
    }
    throw lastError ?? Exception('Failed to connect to backend server');
  }

  Future<http.Response> _get(
    String path, {
    Map<String, String>? headers,
    Duration timeoutPerHost = const Duration(seconds: 4),
  }) async {
    dynamic lastError;
    for (final host in _candidateHosts) {
      final url = Uri.parse('$host$path');
      try {
        debugPrint('[BackendAPI] GET -> $url');
        final res = await http.get(
          url,
          headers: headers ?? _authHeaders,
        ).timeout(timeoutPerHost);

        if (_activeBaseUrl != host) {
          _activeBaseUrl = host;
          _persistActiveHost(host);
        }
        return res;
      } catch (e) {
        debugPrint('[BackendAPI] GET $url failed: $e');
        lastError = e;
      }
    }
    throw lastError ?? Exception('Failed to connect to backend server');
  }

  Future<http.Response> _delete(
    String path, {
    Map<String, String>? headers,
    Duration timeoutPerHost = const Duration(seconds: 4),
  }) async {
    dynamic lastError;
    for (final host in _candidateHosts) {
      final url = Uri.parse('$host$path');
      try {
        debugPrint('[BackendAPI] DELETE -> $url');
        final res = await http.delete(
          url,
          headers: headers ?? _authHeaders,
        ).timeout(timeoutPerHost);

        if (_activeBaseUrl != host) {
          _activeBaseUrl = host;
          _persistActiveHost(host);
        }
        return res;
      } catch (e) {
        debugPrint('[BackendAPI] DELETE $url failed: $e');
        lastError = e;
      }
    }
    throw lastError ?? Exception('Failed to connect to backend server');
  }

  Future<http.Response> _patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Duration timeoutPerHost = const Duration(seconds: 4),
  }) async {
    dynamic lastError;
    for (final host in _candidateHosts) {
      final url = Uri.parse('$host$path');
      try {
        debugPrint('[BackendAPI] PATCH -> $url');
        final res = await http.patch(
          url,
          headers: headers ?? _authHeaders,
          body: body,
        ).timeout(timeoutPerHost);

        if (_activeBaseUrl != host) {
          _activeBaseUrl = host;
          _persistActiveHost(host);
        }
        return res;
      } catch (e) {
        debugPrint('[BackendAPI] PATCH $url failed: $e');
        lastError = e;
      }
    }
    throw lastError ?? Exception('Failed to connect to backend server');
  }

  void _persistActiveHost(String host) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyBackendUrl, host);
    } catch (_) {}
  }

  // ── Authentication ──────────────────────────────────────────────────────────

  Future<UserProfile?> register({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      final res = await _post(
        '/auth/register',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
          'name': name.trim(),
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final token = data['accessToken'] as String?;
        final userMap = data['user'] as Map<String, dynamic>;
        final profile = UserProfile.fromMap(userMap, userMap['id'] ?? '');

        if (token != null) {
          await _saveSession(token, profile);
          return profile;
        }
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['message'] ?? 'Registration failed');
      }
    } catch (e) {
      debugPrint('[BackendAPI] Register exception: $e');
      rethrow;
    }
    return null;
  }

  Future<UserProfile?> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _post(
        '/auth/login',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final token = data['accessToken'] as String?;
        final userMap = data['user'] as Map<String, dynamic>;
        final profile = UserProfile.fromMap(userMap, userMap['id'] ?? '');

        if (token != null) {
          await _saveSession(token, profile);
          return profile;
        }
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['message'] ?? 'Invalid email or password');
      }
    } catch (e) {
      debugPrint('[BackendAPI] Login exception: $e');
      rethrow;
    }
    return null;
  }

  Future<void> logout() async {
    _jwtToken = null;
    _currentUser = null;
    currentUserNotifier.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyJwt);
      await prefs.remove(_prefKeyUserJson);
    } catch (_) {}
  }

  Future<void> updateDisplayName(String name) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(name: name);
      currentUserNotifier.value = _currentUser;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyUserJson, jsonEncode(_currentUser!.toMap()));
    }
  }

  // ── Detections (MongoDB) ───────────────────────────────────────────────────

  Future<String> saveDetection(DetectionRecord record, {bool isCritical = false}) async {
    try {
      final payload = {
        'crop': record.crop,
        'predictedClass': record.prediction,
        'condition': record.condition,
        'confidence': record.confidence,
        'severity': isCritical ? 'CRITICAL' : 'LOW',
        'isCritical': isCritical,
        'margin': record.margin,
        'blurScore': record.blurScore,
        'status': record.status,
        'imageUrl': record.imageUrl,
        'notes': record.notes,
        'latitude': record.latitude,
        'longitude': record.longitude,
        'accuracyMeters': record.accuracyMeters,
        'farmId': record.farmId,
      };

      final res = await _post(
        '/detections',
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data['detection']['id'] ?? '';
      }
    } catch (e) {
      debugPrint('[BackendAPI] saveDetection error: $e');
    }
    return '';
  }

  Future<List<DetectionRecord>> getDetections() async {
    try {
      final res = await _get('/detections');
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((item) => DetectionRecord.fromMap(Map<String, dynamic>.from(item), item['id'])).toList();
      }
    } catch (e) {
      debugPrint('[BackendAPI] getDetections error: $e');
    }
    return [];
  }

  Future<DetectionRecord?> getDetection(String id) async {
    try {
      final res = await _get('/detections/$id');
      if (res.statusCode == 200) {
        final item = jsonDecode(res.body) as Map<String, dynamic>;
        return DetectionRecord.fromMap(item, item['id']);
      }
    } catch (e) {
      debugPrint('[BackendAPI] getDetection error: $e');
    }
    return null;
  }

  Future<bool> sendCriticalDetection(DetectionRecord record, {bool isCritical = true}) async {
    final id = await saveDetection(record, isCritical: isCritical);
    return id.isNotEmpty;
  }

  // ── Field Assessments & Point Messages (MongoDB) ───────────────────────────

  Future<void> saveAssessment(FieldAssessment assessment) async {
    try {
      final payload = {
        'crop': assessment.crop,
        'condition': assessment.condition,
        'mlPrediction': assessment.mlPrediction,
        'mlConfidence': assessment.mlConfidence,
        'severity': assessment.severity.name,
        'progressionStatus': assessment.progressionStatus.name,
        'recommendationSummary': assessment.recommendationSummary,
        'actionLevel': assessment.actionLevel.name,
        'followUpDays': assessment.followUpDays,
        'farmerQuestion': assessment.farmerQuestion,
        'weatherSnapshot': assessment.weatherSnapshot,
        'imagePath': assessment.imagePath,
      };

      await _post(
        '/detections/${assessment.detectionId}/assessments',
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('[BackendAPI] saveAssessment error: $e');
    }
  }

  Future<void> saveChatMessage(String detectionId, ChatMessage msg) async {
    try {
      await _post(
        '/detections/$detectionId/messages',
        body: jsonEncode({
          'text': msg.text,
          'sender': msg.sender.name,
        }),
      );
    } catch (e) {
      debugPrint('[BackendAPI] saveChatMessage error: $e');
    }
  }

  Future<List<ChatMessage>> getChatMessages(String detectionId) async {
    try {
      final res = await _get('/detections/$detectionId/messages');
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((item) {
          return ChatMessage(
            id: item['id'] ?? '',
            text: item['text'] ?? '',
            sender: item['sender'] == 'assistant' ? MessageSender.assistant : MessageSender.user,
            timestamp: item['timestamp'] != null ? DateTime.tryParse(item['timestamp']) ?? DateTime.now() : DateTime.now(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[BackendAPI] getChatMessages error: $e');
    }
    return [];
  }

  // ── Farms (MongoDB) ────────────────────────────────────────────────────────

  Future<String> saveFarm(FarmModel farm) async {
    try {
      final payload = {
        'name': farm.name,
        'boundary': farm.boundary.map((p) => p.toMap()).toList(),
        'center': farm.center.toMap(),
        'areaSquareMeters': farm.areaSquareMeters,
        'cropType': farm.cropType,
      };

      // Use PATCH if the farm already has a server-assigned ID (update),
      // otherwise POST to create a new farm.
      final http.Response res;
      if (farm.id.isNotEmpty) {
        res = await _patch(
          '/farms/${farm.id}',
          body: jsonEncode(payload),
        );
      } else {
        res = await _post(
          '/farms',
          body: jsonEncode(payload),
        );
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data['id'] ?? '';
      }
    } catch (e) {
      debugPrint('[BackendAPI] saveFarm error: $e');
    }
    return '';
  }

  Future<List<FarmModel>> getFarms() async {
    try {
      final res = await _get('/farms');
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((item) => FarmModel.fromMap(Map<String, dynamic>.from(item), item['id'])).toList();
      }
    } catch (e) {
      debugPrint('[BackendAPI] getFarms error: $e');
    }
    return [];
  }

  Future<void> deleteFarm(String farmId) async {
    try {
      await _delete('/farms/$farmId');
    } catch (e) {
      debugPrint('[BackendAPI] deleteFarm error: $e');
    }
  }

  // ── Alerts (MongoDB) ───────────────────────────────────────────────────────

  Future<void> saveAlert(AlertModel alert) async {
    try {
      await _post(
        '/alerts',
        body: jsonEncode({
          'type': alert.type,
          'title': alert.title,
          'message': alert.message,
          'severity': alert.severity,
          'farmId': alert.farmId,
          'weatherContext': jsonEncode(alert.weatherContext),
          'relatedDetectionId': alert.relatedDetectionId,
          'read': alert.read,
        }),
      );
    } catch (e) {
      debugPrint('[BackendAPI] saveAlert error: $e');
    }
  }

  Future<List<AlertModel>> getAlerts() async {
    try {
      final res = await _get('/alerts');
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((item) => AlertModel.fromMap(Map<String, dynamic>.from(item), item['id'])).toList();
      }
    } catch (e) {
      debugPrint('[BackendAPI] getAlerts error: $e');
    }
    return [];
  }

  // ── Global Ambient AI Agent (NestJS + Gemini + Meko) ─────────────────────

  /// Checks if backend AI agent service is reachable and configured
  Future<bool> checkAgentHealth() async {
    try {
      final res = await _get('/agent/health');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['available'] == true;
      }
    } catch (e) {
      debugPrint('[BackendAPI] checkAgentHealth error: $e');
    }
    return false;
  }

  /// Sends a context-aware chat message to the NestJS Ambient Agent
  Future<Map<String, dynamic>?> queryOnlineAgent({
    required String message,
    required Map<String, dynamic> context,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final res = await _post(
        '/agent/chat',
        body: jsonEncode({
          'message': message,
          'context': context,
          'history': history,
        }),
        timeoutPerHost: const Duration(seconds: 25), // LLM queries need sufficient processing time
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        debugPrint('[BackendAPI] queryOnlineAgent failed with status ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('[BackendAPI] queryOnlineAgent error: $e');
    }
    return null;
  }

  /// Dispatches confirmed human-in-the-loop action to backend
  Future<Map<String, dynamic>?> confirmAgentAction({
    required String actionType,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final res = await _post(
        '/agent/action/confirm',
        body: jsonEncode({
          'actionType': actionType,
          'payload': payload,
        }),
        timeoutPerHost: const Duration(seconds: 15),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[BackendAPI] confirmAgentAction error: $e');
    }
    return null;
  }

  Future<void> _saveSession(String token, UserProfile user) async {
    _jwtToken = token;
    _currentUser = user;
    currentUserNotifier.value = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyJwt, token);
      await prefs.setString(_prefKeyUserJson, jsonEncode(user.toMap()));
    } catch (_) {}
  }
}
