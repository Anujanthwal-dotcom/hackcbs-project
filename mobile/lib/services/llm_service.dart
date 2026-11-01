import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import '../config/app_config.dart';
import 'llm_provisioning_service.dart';

enum LlmStatus { uninitialized, ready, generating, unavailable }

/// Manages local, on-device Gemma 3 1B INT4 inference via Google LiteRT-LM (`dart:ffi`).
///
/// Architecture:
/// - Engine: LiteRtLmEngine (direct C++ FFI bindings, zero JNI overhead)
/// - Backend: PreferredBackend.cpu (XNNPACK multi-threaded CPU)
/// - Storage: application-private directory via flutter_gemma file system service
/// - Network: ZERO (100% on-device local execution)
///
/// Lifecycle:
/// - Lazy initialization: weights loaded only on first inference request
/// - Memory release: RAM released when leaving Assistant tab
/// - Session isolation: clean session per query, safely closed in finally block
class LlmService {
  static final LlmService _instance = LlmService._internal();
  factory LlmService() => _instance;
  LlmService._internal();

  static LlmService get instance => _instance;

  LlmStatus _status = LlmStatus.uninitialized;
  InferenceModel? _model;
  Future<bool>? _initFuture;

  LlmStatus get status => _status;
  bool get isAvailable => _status == LlmStatus.ready || _status == LlmStatus.generating;

  /// Ensures that Gemma is fully initialized and ready for inference.
  /// If the model is currently downloading or initializing, awaits completion.
  Future<bool> ensureReady({Duration timeout = const Duration(seconds: 30)}) async {
    return initialize(timeout: timeout);
  }

  /// Lazy-initializes the on-device LiteRT-LM runtime using CPU backend.
  /// Uses an in-flight Future mutex lock to prevent concurrent initialization races.
  Future<bool> initialize({Duration timeout = const Duration(seconds: 30)}) async {
    if (_model != null && _status == LlmStatus.ready) return true;
    if (_initFuture != null) return _initFuture!;

    _initFuture = _doInitialize(timeout: timeout);
    try {
      final res = await _initFuture!;
      return res;
    } finally {
      _initFuture = null;
    }
  }

  Future<bool> _doInitialize({required Duration timeout}) async {
    debugPrint('[GEMMA] model initialization started (current status: $_status)');

    // If currently downloading or checking provisioning, wait for state transition
    final provState = LlmProvisioningService.instance.state;
    if (provState == ModelDownloadState.downloading || provState == ModelDownloadState.checking) {
      debugPrint('[GEMMA] Model is currently being provisioned ($provState). Awaiting completion...');
      try {
        await LlmProvisioningService.instance.stateStream
            .firstWhere((s) =>
                s == ModelDownloadState.ready ||
                s == ModelDownloadState.error ||
                s == ModelDownloadState.notDownloaded)
            .timeout(timeout);
      } catch (e) {
        debugPrint('[GEMMA] Provisioning wait timeout or error: $e');
      }
    }

    try {
      final provisioned = await LlmProvisioningService.instance.checkModelStatus();
      if (!provisioned) {
        debugPrint('[GEMMA] model not provisioned on device — skipping init.');
        _status = LlmStatus.unavailable;
        return false;
      }

      _model = await FlutterGemma.getActiveModel(
        maxTokens: AppConfig.llmMaxTokens,
        preferredBackend: PreferredBackend.cpu,
      );

      _status = LlmStatus.ready;
      debugPrint('[GEMMA] model initialization completed (engine: LiteRT-LM / CPU, maxTokens: ${AppConfig.llmMaxTokens})');
      debugPrint('[GEMMA] inference engine created');
      return true;
    } catch (e, stack) {
      debugPrint('[GEMMA] initialization error: $e\n$stack');
      _model = null;
      _status = LlmStatus.unavailable;
      return false;
    }
  }

  /// Generates agricultural advice fully on-device using local Gemma weights.
  /// Includes one controlled recovery and retry attempt if the session is stale.
  Future<String?> generate(String prompt, {bool allowRetry = true}) async {
    final ready = await initialize();
    if (!ready || _model == null) {
      debugPrint('[GEMMA] skipping generation — model not ready (status: $_status).');
      return null;
    }

    try {
      final text = await _executeInference(prompt);
      if (text != null && text.isNotEmpty) return text;
    } catch (e, stack) {
      debugPrint('[GEMMA] generation exception: $e\n$stack');
    }

    // Controlled single recovery attempt on recoverable failure
    if (allowRetry) {
      debugPrint('[GEMMA] Attempting controlled single recovery & reinitialization...');
      try {
        await _model?.close();
      } catch (_) {}
      _model = null;
      _status = LlmStatus.uninitialized;

      final reinitOk = await initialize();
      if (reinitOk && _model != null) {
        debugPrint('[GEMMA] Retrying inference after recovery...');
        try {
          final retryText = await _executeInference(prompt);
          if (retryText != null && retryText.isNotEmpty) {
            debugPrint('[GEMMA] Retry generation succeeded (${retryText.length} chars).');
            return retryText;
          }
        } catch (e, stack) {
          debugPrint('[GEMMA] Retry generation failed: $e\n$stack');
        }
      }
    }

    return null;
  }

  Future<String?> _executeInference(String prompt) async {
    _status = LlmStatus.generating;
    final stopwatch = Stopwatch()..start();

    final approxTokens = (prompt.length / 4).round();
    debugPrint('[GEMMA] prompt chars=${prompt.length}, approx tokens=$approxTokens');
    debugPrint('[GEMMA] generation started');

    InferenceModelSession? session;

    try {
      debugPrint('[FP_GEMMA] SESSION START');
      session = await _model!.createSession();
      debugPrint('[FP_GEMMA] SESSION CREATED SUCCESSFULLY');

      debugPrint('[FP_GEMMA] Adding query chunk (${prompt.length} chars)...');
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      debugPrint('[FP_GEMMA] Query chunk added. Awaiting Gemma generation (timeout: ${AppConfig.llmTimeout.inSeconds}s)...');

      final response = await session.getResponse().timeout(AppConfig.llmTimeout);
      final text = response.trim();

      stopwatch.stop();
      _status = LlmStatus.ready;

      if (text.isNotEmpty) {
        debugPrint('[GEMMA] generation completed: ${text.length} chars in ${stopwatch.elapsedMilliseconds}ms');
        return text;
      }

      debugPrint('[GEMMA] generation produced 0 characters in ${stopwatch.elapsedMilliseconds}ms');
      return null;
    } catch (e, stack) {
      stopwatch.stop();
      _status = LlmStatus.ready;
      debugPrint('[GEMMA] _executeInference exception: $e\n$stack');
      rethrow;
    } finally {
      if (session != null) {
        try {
          await session.close();
          debugPrint('[GEMMA] session disposed');
        } catch (e) {
          debugPrint('[GEMMA] session close notice: $e');
        }
      }
    }
  }

  /// Minimal diagnostic test sending "Hello" directly to the local model.
  Future<String?> testMinimalPrompt(String testPrompt) async {
    debugPrint('[GEMMA-DIAGNOSTIC] Running minimal test prompt: "$testPrompt"');
    return generate(testPrompt);
  }

  /// Releases model weights from RAM when user leaves the Assistant screen.
  Future<void> releaseMemory() async {
    if (_model == null) return;
    try {
      debugPrint('[GEMMA] releasing on-device Gemma RAM resources...');
      await _model?.close();
      _model = null;
      _status = LlmStatus.uninitialized;
      debugPrint('[GEMMA] memory released');
    } catch (e) {
      debugPrint('[GEMMA] release error: $e');
    }
  }
}
