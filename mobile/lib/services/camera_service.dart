import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Service managing device camera hardware lifecycle, preview, frame streaming,
/// and inference throttling.
class CameraService extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isStreaming = false;
  bool _isTakingPicture = false;
  bool _isFlashOn = false;

  // Throttling state for live camera inference
  DateTime _lastFrameProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isFrameProcessing = false;
  int _throttleIntervalMs = 450; // Throttle to ~2 frames/sec for smooth UI & battery

  String? _initError;

  CameraController? get controller => _controller;
  List<CameraDescription> get cameras => _cameras;
  int get selectedCameraIndex => _selectedCameraIndex;
  bool get isInitialized => _isInitialized && _controller != null && _controller!.value.isInitialized;
  bool get isStreaming => _isStreaming;
  bool get isTakingPicture => _isTakingPicture;
  bool get isFlashOn => _isFlashOn;
  int get throttleIntervalMs => _throttleIntervalMs;
  String? get initError => _initError;

  set throttleIntervalMs(int ms) {
    _throttleIntervalMs = ms.clamp(100, 2000);
  }

  /// Discovers available cameras and initializes the default (usually primary back camera).
  Future<void> initializeCameras() async {
    _initError = null;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _isInitialized = false;
        _initError = 'No cameras found on device.';
        notifyListeners();
        return;
      }

      // Default to the first back camera if available
      int backIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _selectedCameraIndex = backIndex >= 0 ? backIndex : 0;

      await _initController();
    } catch (e) {
      debugPrint('[CameraService] Error initializing cameras: $e');
      _isInitialized = false;
      _initError = e.toString();
      notifyListeners();
    }
  }

  Future<void> _initController() async {
    await _disposeController();

    if (_cameras.isEmpty) return;

    final camera = _cameras[_selectedCameraIndex];
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    _controller = controller;

    try {
      await controller.initialize();
      _isInitialized = true;
      _isFlashOn = false;
      _initError = null;
      notifyListeners();
    } catch (e) {
      debugPrint('[CameraService] Controller init failed: $e');
      _isInitialized = false;
      _initError = e.toString();
      notifyListeners();
    }
  }

  /// Switches between front and rear cameras.
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    final wasStreaming = _isStreaming;

    if (wasStreaming) {
      await stopImageStream();
    }

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initController();
  }

  /// Toggles the camera torch / flashlight.
  Future<void> toggleFlash() async {
    if (!isInitialized) return;
    try {
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
        _isFlashOn = false;
      } else {
        await _controller!.setFlashMode(FlashMode.torch);
        _isFlashOn = true;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[CameraService] Toggle flash failed: $e');
    }
  }

  /// Starts live camera image streaming with built-in frame throttling.
  Future<void> startImageStream(Future<void> Function(CameraImage image) onFrame) async {
    if (!isInitialized || _isStreaming) return;

    try {
      _isStreaming = true;
      notifyListeners();

      await _controller!.startImageStream((CameraImage image) async {
        if (!_isStreaming) return;

        final now = DateTime.now();
        if (_isFrameProcessing ||
            now.difference(_lastFrameProcessed).inMilliseconds < _throttleIntervalMs) {
          return; // Skip frame to maintain smooth 60fps UI and avoid thermal throttling
        }

        _isFrameProcessing = true;
        _lastFrameProcessed = now;

        try {
          await onFrame(image);
        } catch (e) {
          debugPrint('[CameraService] Live frame callback error: $e');
        } finally {
          _isFrameProcessing = false;
        }
      });
    } catch (e) {
      debugPrint('[CameraService] Start image stream failed: $e');
      _isStreaming = false;
      notifyListeners();
    }
  }

  /// Stops the live camera image stream.
  Future<void> stopImageStream() async {
    if (!isInitialized || !_isStreaming) return;

    try {
      await _controller?.stopImageStream();
    } catch (e) {
      debugPrint('[CameraService] Stop image stream failed: $e');
    } finally {
      _isStreaming = false;
      _isFrameProcessing = false;
      notifyListeners();
    }
  }

  /// Captures a high-resolution photo for deep scanning.
  Future<XFile?> capturePhoto() async {
    if (!isInitialized || _isTakingPicture) return null;

    final wasStreaming = _isStreaming;
    if (wasStreaming) {
      await stopImageStream();
    }

    try {
      _isTakingPicture = true;
      notifyListeners();

      final XFile file = await _controller!.takePicture();
      return file;
    } catch (e) {
      debugPrint('[CameraService] Capture photo failed: $e');
      return null;
    } finally {
      _isTakingPicture = false;
      notifyListeners();
    }
  }

  Future<void> _disposeController() async {
    if (_controller != null) {
      final old = _controller;
      _controller = null;
      _isInitialized = false;
      _isStreaming = false;
      try {
        await old?.dispose();
      } catch (e) {
        debugPrint('[CameraService] Error disposing old controller: $e');
      }
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }
}
