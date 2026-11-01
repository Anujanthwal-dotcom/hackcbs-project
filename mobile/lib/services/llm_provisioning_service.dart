import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

enum ModelDownloadState { notDownloaded, checking, downloading, ready, error }

/// Provisions the Gemma 3 1B INT4 LiteRT-LM model onto the physical Android device.
///
/// Features:
/// - Direct LiteRT-LM engine execution via `dart:ffi`
/// - Persistent HuggingFace authentication token management
/// - Local file auto-detection (detects both .litertlm and .task files)
/// - Diagnostic logging with `[GEMMA-DOWNLOAD]` prefix
class LlmProvisioningService {
  static final LlmProvisioningService _instance = LlmProvisioningService._internal();
  factory LlmProvisioningService() => _instance;
  LlmProvisioningService._internal();

  static LlmProvisioningService get instance => _instance;

  static const String modelFileName = 'gemma3-1b-it-int4.task';
  static const String modelFileNameLitert = 'Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm';
  static const String modelUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm';
  static const int expectedSizeBytes = 555 * 1024 * 1024; // ~555 MB
  static const String _prefKeyHfToken = 'krishi_hf_token';

  ModelDownloadState _state = ModelDownloadState.notDownloaded;
  double _progress = 0.0;
  int _downloadedBytes = 0;
  final int _totalBytes = expectedSizeBytes;
  String? _errorMessage;

  final _stateController = StreamController<ModelDownloadState>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  ModelDownloadState get state => _state;
  double get progress => _progress;
  int get downloadedBytes => _downloadedBytes;
  int get totalBytes => _totalBytes;
  String? get errorMessage => _errorMessage;
  bool get isModelReady => _state == ModelDownloadState.ready;

  Stream<ModelDownloadState> get stateStream => _stateController.stream;
  Stream<double> get progressStream => _progressController.stream;

  /// Loads saved HuggingFace token from persistent storage.
  Future<String?> getSavedHfToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKeyHfToken);
    } catch (_) {
      return null;
    }
  }

  /// Saves HuggingFace token securely in SharedPreferences.
  Future<void> saveHfToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token.trim().isEmpty) {
        await prefs.remove(_prefKeyHfToken);
      } else {
        await prefs.setString(_prefKeyHfToken, token.trim());
      }
    } catch (_) {}
  }

  /// Checks whether the model is already installed on this device.
  Future<bool> checkModelStatus() async {
    _setState(ModelDownloadState.checking);
    debugPrint('[GEMMA-DOWNLOAD] checking model status...');

    try {
      final hasActive = FlutterGemma.hasActiveModel();
      if (hasActive) {
        _progress = 1.0;
        _downloadedBytes = _totalBytes;
        _setState(ModelDownloadState.ready);
        debugPrint('[GEMMA-DOWNLOAD] model already active in session.');
        return true;
      }

      // Check if file exists in app directory or external storage directly
      final localFileInstalled = await _checkLocalFileAndRegister();
      if (localFileInstalled) {
        _progress = 1.0;
        _downloadedBytes = _totalBytes;
        _setState(ModelDownloadState.ready);
        return true;
      }

      final installed = await FlutterGemma.isModelInstalled(modelFileNameLitert) ||
          await FlutterGemma.isModelInstalled(modelFileName);
      if (installed) {
        _progress = 1.0;
        _downloadedBytes = _totalBytes;
        _setState(ModelDownloadState.ready);
        debugPrint('[GEMMA-DOWNLOAD] model verified installed in registry.');
        return true;
      }

      _setState(ModelDownloadState.notDownloaded);
      return false;
    } catch (e) {
      debugPrint('[GEMMA-DOWNLOAD] checkModelStatus exception: $e');
      _setState(ModelDownloadState.notDownloaded);
      return false;
    }
  }

  /// Checks if a pre-existing local model file is on disk and registers it.
  Future<bool> _checkLocalFileAndRegister() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final pathsToCheck = [
        '${docsDir.path}/$modelFileNameLitert',
        '${docsDir.path}/$modelFileName',
        '${docsDir.path}/models/$modelFileNameLitert',
        '${docsDir.path}/models/$modelFileName',
        '/sdcard/Download/$modelFileNameLitert',
        '/sdcard/Download/$modelFileName',
      ];

      for (final p in pathsToCheck) {
        final f = File(p);
        if (await f.exists()) {
          final size = await f.length();
          if (size > 100 * 1024 * 1024) {
            debugPrint('[GEMMA-DOWNLOAD] local file found at $p ($size bytes). Registering...');
            // Register with LiteRtLmEngine
            await FlutterGemma.installModel(
              modelType: ModelType.gemmaIt,
              fileType: ModelFileType.litertlm,
            ).fromFile(p).install();
            debugPrint('[GEMMA-DOWNLOAD] local file registered successfully as LiteRT-LM model.');
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('[GEMMA-DOWNLOAD] local file check note: $e');
    }
    return false;
  }

  /// Downloads the Gemma 3 1B INT4 LiteRT-LM model (~555 MB) over HTTPS using the HuggingFace token.
  Future<bool> startDownload({String? hfToken}) async {
    if (_state == ModelDownloadState.downloading) {
      debugPrint('[GEMMA-DOWNLOAD] download already in progress.');
      return false;
    }

    final token = hfToken?.trim() ?? await getSavedHfToken();

    debugPrint('[GEMMA-DOWNLOAD] download started');
    debugPrint('[GEMMA-DOWNLOAD] URL: $modelUrl');
    debugPrint('[GEMMA-DOWNLOAD] authentication configured: ${token != null && token.isNotEmpty ? 'YES' : 'NO'}');

    if (token == null || token.isEmpty) {
      final err = 'Hugging Face Access Token required. Gemma 3 1B is a gated model. Please accept license terms at https://huggingface.co/litert-community/Gemma3-1B-IT and enter your HF token.';
      debugPrint('[GEMMA-DOWNLOAD] ERROR: $err');
      _errorMessage = err;
      _setState(ModelDownloadState.error);
      return false;
    }

    // Save valid token for future sessions
    await saveHfToken(token);

    _setState(ModelDownloadState.downloading);
    _progress = 0.0;
    _downloadedBytes = 0;
    _errorMessage = null;
    _progressController.add(_progress);

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      debugPrint('[GEMMA-DOWNLOAD] destination directory: ${docsDir.path}');

      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      )
        .fromNetwork(
          modelUrl,
          token: token,
          foreground: false,
        )
        .withProgress((progressPercent) {
          _progress = (progressPercent / 100.0).clamp(0.0, 1.0);
          _downloadedBytes = (_totalBytes * _progress).round();
          debugPrint('[GEMMA-DOWNLOAD] progress: $progressPercent% (${(_downloadedBytes / 1024 / 1024).toStringAsFixed(1)} MB / ${(_totalBytes / 1024 / 1024).toStringAsFixed(1)} MB)');
          _progressController.add(_progress);
        })
        .install();

      debugPrint('[GEMMA-DOWNLOAD] completed');

      _progress = 1.0;
      _downloadedBytes = _totalBytes;
      _setState(ModelDownloadState.ready);
      debugPrint('[GEMMA-DOWNLOAD] on-device LiteRT AI ready for inference.');
      return true;
    } catch (e, stack) {
      final errMsg = e.toString();
      debugPrint('[GEMMA-DOWNLOAD] ERROR: $errMsg\n$stack');

      if (errMsg.contains('401') || errMsg.contains('Authentication required') || errMsg.contains('restricted')) {
        _errorMessage = 'Authentication failed (HTTP 401). Ensure you have accepted the Gemma 3 license at https://huggingface.co/litert-community/Gemma3-1B-IT and that your token has Read permissions.';
      } else if (errMsg.contains('403')) {
        _errorMessage = 'Access Forbidden (HTTP 403). Please accept the license terms at https://huggingface.co/litert-community/Gemma3-1B-IT before downloading.';
      } else {
        _errorMessage = errMsg;
      }

      _setState(ModelDownloadState.error);
      return false;
    }
  }

  void _setState(ModelDownloadState s) {
    _state = s;
    _stateController.add(s);
  }

  void dispose() {
    _stateController.close();
    _progressController.close();
  }
}
