import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img_lib;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import '../models/prediction_result.dart';

/// Preprocessed payload returned by background isolate.
class _PreprocessedData {
  final List<List<List<List<double>>>> tensor;
  final double blurScore;
  _PreprocessedData(this.tensor, this.blurScore);
}

/// Service managing TensorFlow Lite V4 model loading, image quality analysis (blur detection),
/// frame preprocessing, and on-device inference with rejection logic.
class MLInferenceService {
  static final MLInferenceService _instance = MLInferenceService._internal();
  factory MLInferenceService() => _instance;
  MLInferenceService._internal();

  static const String modelAssetPath = 'assets/ml/plant_pest_classifier_final_v4.tflite';
  static const String classMappingAssetPath = 'assets/ml/class_mapping_v4.json';
  static const String configAssetPath = 'assets/ml/inference_config_v4.json';

  static const int inputWidth = 320;
  static const int inputHeight = 320;
  static const int inputChannels = 3;
  static const int numClasses = 6;

  /// Default 6-class mapping for Kisaan Bandhu V4.
  static const Map<int, String> fallbackClassMapping = {
    0: 'Soybean_Healthy',
    1: 'Soybean_Caterpillar',
    2: 'Soybean_Bacterial_Blight',
    3: 'Cotton_Healthy',
    4: 'Cotton_Bacterial_Blight',
    5: 'Cotton_Pink_Bollworm',
  };

  Interpreter? _interpreter;
  Map<int, String> _classMapping = fallbackClassMapping;
  bool _isInitialized = false;

  // V4 Thresholds (loaded from inference_config_v4.json or fallback defaults)
  double _confidenceThreshold = 0.55;
  double _marginThreshold = 0.05;
  double _blurThreshold = 1293.81396484375;
  bool isBlurCheckEnabled = true;

  double get confidenceThreshold => _confidenceThreshold;
  double get marginThreshold => _marginThreshold;
  double get blurThreshold => _blurThreshold;

  set confidenceThreshold(double value) {
    _confidenceThreshold = value.clamp(0.0, 1.0);
  }

  set marginThreshold(double value) {
    _marginThreshold = value.clamp(0.0, 1.0);
  }

  set blurThreshold(double value) {
    _blurThreshold = value.clamp(0.0, 10000.0);
  }

  bool get isInitialized => _isInitialized && _interpreter != null;
  Map<int, String> get classMapping => Map.unmodifiable(_classMapping);

  /// Initializes the TFLite V4 interpreter and loads config assets.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Load class mapping and inference config
      await _loadClassMapping();
      await _loadInferenceConfig();

      // 2. Initialize TFLite Interpreter
      final options = InterpreterOptions()..threads = Platform.isAndroid ? 4 : 2;

      _interpreter = await Interpreter.fromAsset(
        modelAssetPath,
        options: options,
      );

      _interpreter?.allocateTensors();
      _isInitialized = true;
      debugPrint('[V4] model loaded');
      debugPrint('[V4] input shape = ${_interpreter?.getInputTensor(0).shape}');
      debugPrint('[V4] output shape = ${_interpreter?.getOutputTensor(0).shape}');
    } catch (e, stack) {
      debugPrint('[MLInferenceService] V4 Initialization failed: $e\n$stack');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> _loadClassMapping() async {
    try {
      final jsonString = await rootBundle.loadString(classMappingAssetPath);
      final Map<String, dynamic> rawMap = json.decode(jsonString);
      final mapped = <int, String>{};
      rawMap.forEach((key, value) {
        final intIndex = int.tryParse(key);
        if (intIndex != null) {
          mapped[intIndex] = value.toString();
        }
      });
      if (mapped.length == numClasses) {
        _classMapping = mapped;
      } else {
        _classMapping = fallbackClassMapping;
      }
    } catch (e) {
      debugPrint('[MLInferenceService] Failed loading class_mapping_v4.json ($e), using fallback.');
      _classMapping = fallbackClassMapping;
    }
  }

  Future<void> _loadInferenceConfig() async {
    try {
      final jsonString = await rootBundle.loadString(configAssetPath);
      final Map<String, dynamic> config = json.decode(jsonString);
      if (config.containsKey('confidence_threshold')) {
        _confidenceThreshold = (config['confidence_threshold'] as num).toDouble();
      }
      if (config.containsKey('margin_threshold')) {
        _marginThreshold = (config['margin_threshold'] as num).toDouble();
      }
      if (config.containsKey('blur_threshold')) {
        _blurThreshold = (config['blur_threshold'] as num).toDouble();
      }
      debugPrint('[MLInferenceService] Config loaded: conf=$_confidenceThreshold, margin=$_marginThreshold, blur=$_blurThreshold');
    } catch (e) {
      debugPrint('[MLInferenceService] Failed loading inference_config_v4.json ($e), using default thresholds.');
    }
  }

  /// Runs inference on an image [File] with full V4 rejection evaluation.
  Future<PredictionResult> classifyImageFile(File imageFile) async {
    if (!_isInitialized || _interpreter == null) {
      await initialize();
    }

    final bytes = await imageFile.readAsBytes();
    return classifyImageBytes(bytes);
  }

  /// Runs inference on raw image bytes (e.g. JPEG/PNG).
  Future<PredictionResult> classifyImageBytes(Uint8List bytes) async {
    if (!_isInitialized || _interpreter == null) {
      await initialize();
    }

    final stopwatch = Stopwatch()..start();

    final preprocessed = await compute(_preprocessImageBytes, bytes);
    if (preprocessed == null) {
      throw Exception('Failed to decode or preprocess image bytes.');
    }

    final outputTensor = List.generate(
      1,
      (_) => List<double>.filled(numClasses, 0.0),
    );

    _interpreter!.run(preprocessed.tensor, outputTensor);
    stopwatch.stop();

    final probabilities = List<double>.from(outputTensor[0]);

    final result = PredictionResult.evaluate(
      probabilities: probabilities,
      classMapping: _classMapping,
      blurScore: isBlurCheckEnabled ? preprocessed.blurScore : _blurThreshold + 1.0,
      confidenceThreshold: _confidenceThreshold,
      marginThreshold: _marginThreshold,
      blurThreshold: _blurThreshold,
      inferenceTimeMs: stopwatch.elapsedMilliseconds,
    );

    debugPrint('[V4] raw output = $probabilities');
    debugPrint('[V4] predicted index = ${result.classIndex}');
    debugPrint('[V4] predicted class = ${result.predictedClass}');
    debugPrint('[V4] confidence = ${result.confidencePercentage}');
    debugPrint('[V4] inference time = ${stopwatch.elapsedMilliseconds} ms');

    return result;
  }

  /// Runs inference on a live [CameraImage] frame stream with fast direct sampling.
  Future<PredictionResult> classifyCameraImage(CameraImage cameraImage) async {
    if (!_isInitialized || _interpreter == null) {
      await initialize();
    }

    final stopwatch = Stopwatch()..start();

    final preprocessed = _preprocessCameraImage(cameraImage);
    if (preprocessed == null) {
      throw Exception('Unsupported camera image format.');
    }

    final outputTensor = List.generate(
      1,
      (_) => List<double>.filled(numClasses, 0.0),
    );

    _interpreter!.run(preprocessed.tensor, outputTensor);
    stopwatch.stop();

    final probabilities = List<double>.from(outputTensor[0]);

    final result = PredictionResult.evaluate(
      probabilities: probabilities,
      classMapping: _classMapping,
      blurScore: isBlurCheckEnabled ? preprocessed.blurScore : _blurThreshold + 1.0,
      confidenceThreshold: _confidenceThreshold,
      marginThreshold: _marginThreshold,
      blurThreshold: _blurThreshold,
      inferenceTimeMs: stopwatch.elapsedMilliseconds,
    );

    debugPrint('[V4] raw output = $probabilities');
    debugPrint('[V4] predicted index = ${result.classIndex}');
    debugPrint('[V4] predicted class = ${result.predictedClass}');
    debugPrint('[V4] confidence = ${result.confidencePercentage}');
    debugPrint('[V4] inference time = ${stopwatch.elapsedMilliseconds} ms');

    return result;
  }

  /// Converts a [CameraImage] directly to a 320x320 RGB tensor and computes blur score.
  _PreprocessedData? _preprocessCameraImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    if (width <= 0 || height <= 0) return null;

    final tensor = List.generate(
      1,
      (_) => List.generate(
        inputHeight,
        (y) => List.generate(
          inputWidth,
          (x) => List<double>.filled(3, 0.0),
        ),
      ),
    );

    if (image.format.group == ImageFormatGroup.yuv420 && image.planes.length >= 3) {
      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];

      final int yRowStride = yPlane.bytesPerRow;
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

      for (int tY = 0; tY < inputHeight; tY++) {
        final int srcY = (tY * height) ~/ inputHeight;
        final int yRowOffset = srcY * yRowStride;
        final int uvYOffset = (srcY >> 1) * uvRowStride;

        for (int tX = 0; tX < inputWidth; tX++) {
          final int srcX = (tX * width) ~/ inputWidth;
          final int uvIndex = uvYOffset + (srcX >> 1) * uvPixelStride;
          final int yIndex = yRowOffset + srcX;

          final int yVal = yPlane.bytes[yIndex];
          final int uVal = uPlane.bytes[uvIndex];
          final int vVal = vPlane.bytes[uvIndex];

          final double r = (yVal + (1.370705 * (vVal - 128))).clamp(0, 255).toDouble();
          final double g = (yVal - (0.337633 * (uVal - 128)) - (0.698001 * (vVal - 128))).clamp(0, 255).toDouble();
          final double b = (yVal + (1.732446 * (uVal - 128))).clamp(0, 255).toDouble();

          tensor[0][tY][tX][0] = r;
          tensor[0][tY][tX][1] = g;
          tensor[0][tY][tX][2] = b;
        }
      }
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      final plane = image.planes[0];
      final bytes = plane.bytes;
      final int rowStride = plane.bytesPerRow;

      for (int tY = 0; tY < inputHeight; tY++) {
        final int srcY = (tY * height) ~/ inputHeight;
        final int rowOffset = srcY * rowStride;

        for (int tX = 0; tX < inputWidth; tX++) {
          final int srcX = (tX * width) ~/ inputWidth;
          final int pixelIndex = rowOffset + (srcX * 4);

          final double b = bytes[pixelIndex].toDouble();
          final double g = bytes[pixelIndex + 1].toDouble();
          final double r = bytes[pixelIndex + 2].toDouble();

          tensor[0][tY][tX][0] = r;
          tensor[0][tY][tX][1] = g;
          tensor[0][tY][tX][2] = b;
        }
      }
    } else {
      final decoded = img_lib.decodeImage(image.planes[0].bytes);
      if (decoded == null) return null;
      final resized = img_lib.copyResize(decoded, width: inputWidth, height: inputHeight);
      return _PreprocessedData(_imageToTensor(resized), computeLaplacianVariance(resized));
    }

    // Fast Laplacian on sampled 320x320 grid
    double sumLap = 0.0;
    double sumSqLap = 0.0;
    int countLap = 0;

    for (int y = 1; y < inputHeight - 1; y++) {
      for (int x = 1; x < inputWidth - 1; x++) {
        final double center = 0.299 * tensor[0][y][x][0] + 0.587 * tensor[0][y][x][1] + 0.114 * tensor[0][y][x][2];
        final double top = 0.299 * tensor[0][y - 1][x][0] + 0.587 * tensor[0][y - 1][x][1] + 0.114 * tensor[0][y - 1][x][2];
        final double bottom = 0.299 * tensor[0][y + 1][x][0] + 0.587 * tensor[0][y + 1][x][1] + 0.114 * tensor[0][y + 1][x][2];
        final double left = 0.299 * tensor[0][y][x - 1][0] + 0.587 * tensor[0][y][x - 1][1] + 0.114 * tensor[0][y][x - 1][2];
        final double right = 0.299 * tensor[0][y][x + 1][0] + 0.587 * tensor[0][y][x + 1][1] + 0.114 * tensor[0][y][x + 1][2];
        final double topLeft = 0.299 * tensor[0][y - 1][x - 1][0] + 0.587 * tensor[0][y - 1][x - 1][1] + 0.114 * tensor[0][y - 1][x - 1][2];
        final double topRight = 0.299 * tensor[0][y - 1][x + 1][0] + 0.587 * tensor[0][y - 1][x + 1][1] + 0.114 * tensor[0][y - 1][x + 1][2];
        final double bottomLeft = 0.299 * tensor[0][y + 1][x - 1][0] + 0.587 * tensor[0][y + 1][x - 1][1] + 0.114 * tensor[0][y + 1][x - 1][2];
        final double bottomRight = 0.299 * tensor[0][y + 1][x + 1][0] + 0.587 * tensor[0][y + 1][x + 1][1] + 0.114 * tensor[0][y + 1][x + 1][2];

        final double d2x = (topLeft - 2.0 * top + topRight) + 2.0 * (left - 2.0 * center + right) + (bottomLeft - 2.0 * bottom + bottomRight);
        final double d2y = (topLeft - 2.0 * left + bottomLeft) + 2.0 * (top - 2.0 * center + bottom) + (topRight - 2.0 * right + bottomRight);
        final double lap = d2x + d2y;

        sumLap += lap;
        sumSqLap += lap * lap;
        countLap++;
      }
    }

    final double mean = countLap > 0 ? (sumLap / countLap) : 0.0;
    final double blurScore = countLap > 0 ? ((sumSqLap / countLap) - (mean * mean)) : 0.0;

    return _PreprocessedData(tensor, blurScore);
  }

  /// Releases model resources and closes interpreter.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

/// Standalone top-level isolate function for decoding, blur calculation, and preprocessing.
_PreprocessedData? _preprocessImageBytes(Uint8List bytes) {
  final decoded = img_lib.decodeImage(bytes);
  if (decoded == null) return null;

  final blurScore = computeLaplacianVariance(decoded);

  final resized = img_lib.copyResize(
    decoded,
    width: MLInferenceService.inputWidth,
    height: MLInferenceService.inputHeight,
    interpolation: img_lib.Interpolation.linear,
  );

  final tensor = _imageToTensor(resized);
  return _PreprocessedData(tensor, blurScore);
}

/// Computes the variance of the Laplacian over a grayscale image.
/// Higher values mean crisp, high-frequency edges; lower values indicate blur/smoothness.
double computeLaplacianVariance(img_lib.Image image) {
  final width = image.width;
  final height = image.height;
  if (width < 3 || height < 3) return 0.0;

  // Compute grayscale luminance values
  final gray = Float64List(width * height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final p = image.getPixel(x, y);
      gray[y * width + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
    }
  }

  double sum = 0.0;
  double sumSq = 0.0;
  int count = 0;

  // OpenCV cv2.Laplacian(gray, cv2.CV_64F, ksize=3) formula:
  // d2x = (topLeft - 2*top + topRight) + 2*(left - 2*center + right) + (bottomLeft - 2*bottom + bottomRight)
  // d2y = (topLeft - 2*left + bottomLeft) + 2*(top - 2*center + bottom) + (topRight - 2*right + bottomRight)
  // lap = d2x + d2y
  for (int y = 1; y < height - 1; y++) {
    for (int x = 1; x < width - 1; x++) {
      final center = gray[y * width + x];
      final topLeft = gray[(y - 1) * width + (x - 1)];
      final top = gray[(y - 1) * width + x];
      final topRight = gray[(y - 1) * width + (x + 1)];
      final left = gray[y * width + (x - 1)];
      final right = gray[y * width + (x + 1)];
      final bottomLeft = gray[(y + 1) * width + (x - 1)];
      final bottom = gray[(y + 1) * width + x];
      final bottomRight = gray[(y + 1) * width + (x + 1)];

      final d2x = (topLeft - 2.0 * top + topRight) +
          2.0 * (left - 2.0 * center + right) +
          (bottomLeft - 2.0 * bottom + bottomRight);
      final d2y = (topLeft - 2.0 * left + bottomLeft) +
          2.0 * (top - 2.0 * center + bottom) +
          (topRight - 2.0 * right + bottomRight);
      final lap = d2x + d2y;

      sum += lap;
      sumSq += lap * lap;
      count++;
    }
  }

  if (count == 0) return 0.0;
  final mean = sum / count;
  final variance = (sumSq / count) - (mean * mean);
  return variance;
}

/// Converts an [img_lib.Image] into 4D tensor `[1, 224, 224, 3]` with RGB values in `[0.0, 255.0]`.
List<List<List<List<double>>>> _imageToTensor(img_lib.Image image) {
  final tensor = List.generate(
    1,
    (_) => List.generate(
      MLInferenceService.inputHeight,
      (y) => List.generate(
        MLInferenceService.inputWidth,
        (x) {
          final pixel = image.getPixel(x, y);
          return [
            pixel.r.toDouble(),
            pixel.g.toDouble(),
            pixel.b.toDouble(),
          ];
        },
      ),
    ),
  );
  return tensor;
}
