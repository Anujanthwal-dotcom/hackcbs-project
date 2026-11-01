import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../models/detection_record.dart';
import '../../../models/prediction_result.dart';
import '../../../services/auth_service.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/camera_service.dart';
import '../../../services/detection_repository.dart';
import '../../../services/farm_repository.dart';
import '../../../services/geometry_service.dart';
import '../../../services/language_service.dart';
import '../../../services/location_service.dart';
import '../../../services/ml_inference_service.dart';
import '../../../services/semantic_ui_registry.dart';
import 'widgets/prediction_card.dart';

enum CameraPermissionState {
  initial,
  requesting,
  granted,
  denied,
  permanentlyDenied,
  unavailable,
  error,
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  final MLInferenceService _mlService = MLInferenceService();

  CameraPermissionState _permissionState = CameraPermissionState.initial;
  String? _statusMessage;

  // ML inference states
  PredictionResult? _livePredictionResult;
  PredictionResult? _capturedPredictionResult;
  bool _isLiveInferring = false;
  bool _isDeepInferring = false;
  bool _isLiveScanEnabled = true;

  XFile? _capturedImage;
  Map<String, dynamic>? _capturedImageMetadata;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraService.addListener(_onCameraServiceUpdated);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.removeListener(_onCameraServiceUpdated);
    _cameraService.dispose();
    _mlService.dispose();
    super.dispose();
  }

  void _onCameraServiceUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraService.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _cameraService.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      if (_permissionState == CameraPermissionState.granted) {
        _startLiveCameraFeed();
      }
    }
  }

  Future<void> _initializeServices() async {
    // 1. Initialize ML model
    try {
      await _mlService.initialize();
    } catch (e) {
      debugPrint('[ScanScreen] ML initialization warning: $e');
    }

    // 2. Initialize Camera permissions & hardware
    await _checkAndRequestCameraPermission();
  }

  Future<void> _checkAndRequestCameraPermission() async {
    setState(() {
      _permissionState = CameraPermissionState.requesting;
      _statusMessage = 'Checking camera permission...';
    });

    final status = await Permission.camera.status;

    if (status.isGranted) {
      await _onPermissionGranted();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _permissionState = CameraPermissionState.permanentlyDenied;
        _statusMessage =
            'Camera permission is permanently disabled. Please enable it from device settings.';
      });
    } else {
      final requestResult = await Permission.camera.request();
      if (requestResult.isGranted) {
        await _onPermissionGranted();
      } else if (requestResult.isPermanentlyDenied) {
        setState(() {
          _permissionState = CameraPermissionState.permanentlyDenied;
          _statusMessage =
              'Camera permission is permanently disabled. Please enable it from device settings.';
        });
      } else {
        setState(() {
          _permissionState = CameraPermissionState.denied;
          _statusMessage = 'Camera permission is required to scan your crop.';
        });
      }
    }
  }

  Future<void> _onPermissionGranted() async {
    setState(() {
      _permissionState = CameraPermissionState.granted;
      _statusMessage = 'Initializing camera hardware...';
    });

    try {
      await _cameraService.initializeCameras();

      if (!_cameraService.isInitialized) {
        setState(() {
          _permissionState = CameraPermissionState.error;
          _statusMessage = _cameraService.initError ?? 'Failed to initialize camera hardware.';
        });
        return;
      }

      await _startLiveCameraFeed();
    } catch (e) {
      setState(() {
        _permissionState = CameraPermissionState.error;
        _statusMessage = 'Error accessing camera: $e';
      });
    }
  }

  Future<void> _startLiveCameraFeed() async {
    if (!_cameraService.isInitialized) return;

    if (_isLiveScanEnabled && !_cameraService.isStreaming) {
      await _cameraService.startImageStream(_handleLiveCameraFrame);
    }
  }

  /// Throttled callback receiving live camera frames from CameraService (~2 frames/sec)
  Future<void> _handleLiveCameraFrame(CameraImage image) async {
    if (!mounted || !_isLiveScanEnabled || _isLiveInferring) return;

    try {
      setState(() {
        _isLiveInferring = true;
      });

      final result = await _mlService.classifyCameraImage(image);

      if (mounted) {
        setState(() {
          _livePredictionResult = result;
          _isLiveInferring = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiveInferring = false;
        });
      }
    }
  }

  Future<void> _toggleLiveScan() async {
    setState(() {
      _isLiveScanEnabled = !_isLiveScanEnabled;
    });

    if (_isLiveScanEnabled) {
      await _cameraService.startImageStream(_handleLiveCameraFrame);
    } else {
      await _cameraService.stopImageStream();
      setState(() {
        _livePredictionResult = null;
        _isLiveInferring = false;
      });
    }
  }

  Future<void> _capturePhotoAndDeepScan() async {
    if (!_cameraService.isInitialized || _cameraService.isTakingPicture) return;

    try {
      setState(() {
        _isDeepInferring = true;
      });

      final XFile? imageFile = await _cameraService.capturePhoto();
      if (imageFile == null) return;

      final File file = File(imageFile.path);
      final int fileSizeBytes = await file.length();
      final DateTime timestamp = DateTime.now();

      // Read image metadata
      final metadata = {
        'path': imageFile.path,
        'name': imageFile.name,
        'timestamp': timestamp.toIso8601String(),
        'fileSizeBytes': fileSizeBytes,
        'resolutionPreset': _cameraService.controller?.resolutionPreset.name ?? 'medium',
      };

      // Run high-resolution deep classification
      final prediction = await _mlService.classifyImageFile(file);
      debugPrint('[SCAN] ML RESULT:\n  crop=${prediction.crop}\n  condition=${prediction.condition}\n  confidence=${prediction.confidence}');

      // Set prediction result immediately and exit inferring state
      if (mounted) {
        setState(() {
          _capturedImage = imageFile;
          _capturedImageMetadata = metadata;
          _capturedPredictionResult = prediction;
          _isDeepInferring = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              prediction.isValid
                  ? 'Diagnosis: ${prediction.displayTitle} (${prediction.confidencePercentage})'
                  : '${prediction.displayTitle}: ${prediction.displaySubtitle}',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: prediction.statusColor,
          ),
        );
      }

      // Acquire real device GPS coordinates at the time of scan and persist to Firestore
      try {
        final gpsCoord = await LocationService.instance.getCurrentPosition();
        debugPrint('[SCAN] GPS:\n  latitude=${gpsCoord?.latitude}\n  longitude=${gpsCoord?.longitude}\n  accuracy=${gpsCoord?.accuracyMeters}');

        final currentUid = AuthService.instance.currentUid;
        String? matchedFarmId;
        String? matchedFarmName;
        bool isInside = false;
        if (gpsCoord != null && currentUid != null) {
          try {
            final farms = await FarmRepository.instance.getUserFarms(currentUid);
            for (final farm in farms) {
              final inside = farm.boundary.length >= 3 &&
                  GeometryService.isPointInsidePolygon(gpsCoord, farm.boundary);
              if (inside) {
                matchedFarmId = farm.id;
                matchedFarmName = farm.name;
                isInside = true;
                break;
              }
            }
          } catch (e) {
            debugPrint('[SCAN] Farm lookup error: $e');
          }
        }
        debugPrint('[SCAN] FARM:\n  farmId=$matchedFarmId\n  farmName=$matchedFarmName\n  inside=$isInside');

        if (currentUid != null) {
          final record = DetectionRecord(
            id: '',
            userId: currentUid,
            crop: prediction.crop,
            prediction: prediction.predictedClass,
            condition: prediction.condition,
            confidence: prediction.confidence,
            margin: prediction.margin,
            blurScore: prediction.blurScore,
            status: prediction.state.name,
            imageUrl: imageFile.path,
            latitude: gpsCoord?.latitude,
            longitude: gpsCoord?.longitude,
            accuracyMeters: gpsCoord?.accuracyMeters,
            farmId: matchedFarmId,
            createdAt: DateTime.now(),
          );
          final savedId = await DetectionRepository.instance.saveDetection(record);
          debugPrint('[SCAN] Detection saved successfully with ID: $savedId');

          // Check if this detection is a critical pest or disease outbreak
          final isPestOrDisease = prediction.condition.toLowerCase().contains('disease') ||
              prediction.condition.toLowerCase().contains('pest') ||
              prediction.predictedClass.toLowerCase().contains('blight') ||
              prediction.predictedClass.toLowerCase().contains('spot') ||
              prediction.predictedClass.toLowerCase().contains('rust') ||
              prediction.predictedClass.toLowerCase().contains('rot') ||
              prediction.predictedClass.toLowerCase().contains('mildew') ||
              prediction.predictedClass.toLowerCase().contains('borer') ||
              prediction.predictedClass.toLowerCase().contains('virus') ||
              prediction.predictedClass.toLowerCase().contains('mite') ||
              !prediction.condition.toLowerCase().contains('healthy');

          if (isPestOrDisease && prediction.isValid) {
            debugPrint('[SCAN] Outbreak identified as CRITICAL. Dispatching to NestJS MongoDB backend...');
            BackendApiService.instance.sendCriticalDetection(record, isCritical: true);
          }
        } else {
          debugPrint('[SCAN] Warning: currentUid is null, cannot save detection to Firestore');
        }
      } catch (geoError, stack) {
        debugPrint('[SCAN] Geotagging/Firestore error: $geoError\n$stack');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Classification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeepInferring = false;
        });
      }
    }
  }

  void _clearCapturedImage() {
    setState(() {
      _capturedImage = null;
      _capturedImageMetadata = null;
      _capturedPredictionResult = null;
    });

    // Re-enable live stream if active
    if (_isLiveScanEnabled && !_cameraService.isStreaming) {
      _cameraService.startImageStream(_handleLiveCameraFrame);
    }
  }

  void _showConfidenceThresholdDialog() {
    double currentConf = _mlService.confidenceThreshold;
    double currentMargin = _mlService.marginThreshold;
    double currentBlur = _mlService.blurThreshold;
    bool blurEnabled = _mlService.isBlurCheckEnabled;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAFCF5),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 24.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'V4 Rejection Parameters',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF27421D),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27421D),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'V4 Rules',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 1. Confidence Threshold
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Confidence Threshold',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          '${(currentConf * 100).toInt()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: Color(0xFF27421D),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF27421D),
                        thumbColor: const Color(0xFF27421D),
                      ),
                      child: Slider(
                        value: currentConf,
                        min: 0.30,
                        max: 0.90,
                        divisions: 12,
                        onChanged: (val) {
                          setSheetState(() => currentConf = val);
                          setState(() => _mlService.confidenceThreshold = val);
                        },
                      ),
                    ),

                    // 2. Margin Threshold
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Top-1 / Top-2 Margin',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          '${(currentMargin * 100).toInt()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: Color(0xFF27421D),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF27421D),
                        thumbColor: const Color(0xFF27421D),
                      ),
                      child: Slider(
                        value: currentMargin,
                        min: 0.01,
                        max: 0.20,
                        divisions: 19,
                        onChanged: (val) {
                          setSheetState(() => currentMargin = val);
                          setState(() => _mlService.marginThreshold = val);
                        },
                      ),
                    ),

                    // 3. Blur Quality Check
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Blur / Image Quality Filter',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Threshold: ${currentBlur.toInt()} Laplacian variance',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF5A7250)),
                      ),
                      value: blurEnabled,
                      activeThumbColor: const Color(0xFF27421D),
                      onChanged: (val) {
                        setSheetState(() => blurEnabled = val);
                        setState(() => _mlService.isBlurCheckEnabled = val);
                      },
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF27421D),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Apply Parameters'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Current active prediction to display in diagnostics card
    final activeResult = _capturedPredictionResult ?? _livePredictionResult;
    final l10n = AppLocalizations.of(context)!;
    final isHindi = LanguageService.instance.isHindi;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          l10n.scanHeader,
          style: const TextStyle(
            color: Color(0xFF27421D),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          // Flash toggle
          if (_permissionState == CameraPermissionState.granted &&
              _cameraService.isInitialized)
            IconButton(
              icon: Icon(
                _cameraService.isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: const Color(0xFF27421D),
              ),
              tooltip: _cameraService.isFlashOn ? l10n.flashOff : l10n.flashOn,
              onPressed: _cameraService.toggleFlash,
            ),
          // Threshold settings
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFF27421D)),
            tooltip: isHindi ? 'विश्वास स्तर सेटिंग' : 'Confidence Settings',
            onPressed: _showConfidenceThresholdDialog,
          ),
          // Camera Switch
          if (_cameraService.cameras.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: IconButton(
                icon: const Icon(Icons.flip_camera_ios, color: Color(0xFF27421D)),
                tooltip: l10n.switchCamera,
                onPressed: _cameraService.switchCamera,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Live Camera Viewport with Real-Time Scanning Overlays
            _buildCameraViewport(),
            const SizedBox(height: 14),

            // 2. Camera Action & Inference Mode Controls
            _buildCameraControls(),
            const SizedBox(height: 16),

            // 3. Captured Image Preview (if present)
            if (_capturedImage != null) ...[
              _buildCapturedImageSection(),
              const SizedBox(height: 16),
            ],

            // 4. Diagnostic Card & 7-Class Probability Visualizer
            PredictionCard(
              result: activeResult,
              isInferring: _isLiveInferring || _isDeepInferring,
              onAdjustThreshold: _showConfidenceThresholdDialog,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraViewport() {
    final theme = Theme.of(context);

    // Permission requesting
    if (_permissionState == CameraPermissionState.requesting) {
      return _buildPlaceholderContainer(
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Checking camera permissions...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    // Permission denied
    if (_permissionState == CameraPermissionState.denied) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.no_photography_outlined,
              size: 52,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Camera Permission Required',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Camera access is required for real-time crop disease detection.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _checkAndRequestCameraPermission,
              icon: const Icon(Icons.refresh),
              label: const Text('Grant Camera Permission'),
            ),
          ],
        ),
      );
    }

    // Permission permanently denied
    if (_permissionState == CameraPermissionState.permanentlyDenied) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.settings_outlined,
              size: 52,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Permission Disabled',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Camera permission is disabled in system settings. Please enable it to proceed.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    // Hardware unavailable or error
    if (_permissionState == CameraPermissionState.unavailable ||
        _permissionState == CameraPermissionState.error) {
      return _buildPlaceholderContainer(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orangeAccent),
            const SizedBox(height: 12),
            Text(
              _statusMessage ?? 'Camera unavailable on this device.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _checkAndRequestCameraPermission,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Active Camera Preview
    if (_cameraService.isInitialized && _cameraService.controller != null) {
      return Container(
        height: 360,
        decoration: BoxDecoration(
          color: const Color(0xFF1D3B16),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_cameraService.controller!),

              // Viewfinder scanning target guide
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _livePredictionResult?.statusColor.withValues(alpha: 0.85) ??
                          Colors.white.withValues(alpha: 0.7),
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),

              // Live Status Tag (Top-left)
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isLiveScanEnabled
                              ? const Color(0xFF66BB6A)
                              : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isLiveScanEnabled ? 'Live ML Scanning' : 'Preview Paused',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Live Inference Overlay Banner (Bottom)
              if (_isLiveScanEnabled && _livePredictionResult != null)
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _livePredictionResult!.statusColor.withValues(alpha: 0.8),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _livePredictionResult!.statusIcon,
                          color: _livePredictionResult!.statusColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _livePredictionResult!.displayTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _livePredictionResult!.displaySubtitle,
                                style: TextStyle(
                                  color: _livePredictionResult!.isConfident
                                      ? Colors.white70
                                      : Colors.orangeAccent,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (_livePredictionResult!.isConfident)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _livePredictionResult!.statusColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _livePredictionResult!.confidencePercentage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return _buildPlaceholderContainer(
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 12),
          Text(
            'Starting camera preview...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderContainer({required Widget child}) {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: const Color(0xFF1F3D17),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(child: child),
    );
  }

  Widget _buildCameraControls() {
    if (_permissionState != CameraPermissionState.granted) {
      return const SizedBox.shrink();
    }

    final isCapturing = _cameraService.isTakingPicture || _isDeepInferring;
    final l10n = AppLocalizations.of(context)!;
    final isHindi = LanguageService.instance.isHindi;

    return Row(
      children: [
        // Capture & Deep Scan Button
        Expanded(
          flex: 3,
          child: AgentUiElement(
            id: 'scan_capture_button',
            label: 'Capture & Diagnose Crop',
            description: 'Takes a high-resolution photo and runs on-device ML crop disease classification',
            screen: 'Scan',
            onTrigger: (_cameraService.isInitialized && !isCapturing) ? _capturePhotoAndDeepScan : null,
            child: FilledButton.icon(
              onPressed: (_cameraService.isInitialized && !isCapturing)
                  ? _capturePhotoAndDeepScan
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF27421D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: isCapturing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              label: Text(isCapturing ? l10n.analyzingCrop : l10n.takePhoto),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Live Scan Toggle Button
        Expanded(
          flex: 2,
          child: AgentUiElement(
            id: 'scan_toggle_live',
            label: 'Toggle Live Scan Sensor',
            description: 'Enables or disables continuous real-time crop disease detection preview',
            screen: 'Scan',
            onTrigger: _toggleLiveScan,
            child: OutlinedButton.icon(
              onPressed: _toggleLiveScan,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF27421D),
                side: const BorderSide(color: Color(0xFF27421D), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: Icon(
                _isLiveScanEnabled ? Icons.sensors : Icons.sensors_off,
                size: 20,
              ),
              label: Text(_isLiveScanEnabled
                  ? (isHindi ? 'लाइव: चालू' : 'Live: ON')
                  : (isHindi ? 'लाइव: बंद' : 'Live: OFF')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCapturedImageSection() {
    final metadata = _capturedImageMetadata;
    final prediction = _capturedPredictionResult;
    final isHindi = LanguageService.instance.isHindi;

    return Card(
      color: const Color(0xFFFAFCF5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E9D4), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.image_outlined, color: Color(0xFF27421D)),
            title: Text(
              isHindi ? 'ली गई तस्वीर' : 'Captured Photograph',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF27421D),
              ),
            ),
            subtitle: Text(
              prediction != null
                  ? '${isHindi ? "निदान" : "Diagnosis"}: ${prediction.displayTitle}'
                  : '${isHindi ? "सहेजा गया" : "Saved at"} ${metadata?['timestamp'] ?? ''}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: isHindi ? 'हटाएं' : 'Clear image',
              onPressed: _clearCapturedImage,
            ),
          ),
          if (_capturedImage != null)
            Image.file(
              File(_capturedImage!.path),
              height: 200,
              fit: BoxFit.cover,
            ),
        ],
      ),
    );
  }
}
