import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'bert_tokenizer.dart';

/// On-device text embedding service running all-MiniLM-L6-v2 via TFLite.
///
/// 100% offline, zero network or Mac server dependency.
class LocalEmbeddingService {
  static final LocalEmbeddingService _instance = LocalEmbeddingService._internal();
  factory LocalEmbeddingService() => _instance;
  LocalEmbeddingService._internal();

  static LocalEmbeddingService get instance => _instance;

  static const String modelAssetPath = 'assets/ml/embedding_model.tflite';
  static const String vocabAssetPath = 'assets/ml/vocab.txt';
  static const int maxSeqLength = 128;
  static const int embeddingDim = 384;

  final BertTokenizer _tokenizer = BertTokenizer();
  Interpreter? _interpreter;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized && _interpreter != null;

  /// Initializes the TFLite interpreter and tokenizer.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize tokenizer
      await _tokenizer.initialize(vocabPath: vocabAssetPath);

      // 2. Load TFLite interpreter
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        modelAssetPath,
        options: options,
      );

      _interpreter?.allocateTensors();
      _isInitialized = true;
      debugPrint('[LocalEmbeddingService] all-MiniLM-L6-v2 TFLite initialized.');
    } catch (e, stack) {
      debugPrint('[LocalEmbeddingService] Initialization failed: $e\n$stack');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Encodes [text] into a normalized 384-dimensional embedding vector.
  Future<List<double>> embedQuery(String text) async {
    if (!_isInitialized || _interpreter == null) {
      await initialize();
    }

    final encoded = _tokenizer.encode(text, maxLength: maxSeqLength);

    // Prepare 2D input tensors [1, 128]
    final inputIds = [encoded.inputIds];
    final attentionMask = [encoded.attentionMask];

    // Some models take input_ids, attention_mask as int32/int64
    final inputs = [inputIds, attentionMask];

    // Output tensor [1, 384] or [1, 128, 384]
    final outputTensor = List.generate(
      1,
      (_) => List<double>.filled(embeddingDim, 0.0),
    );

    final outputs = {0: outputTensor};

    _interpreter!.runForMultipleInputs(inputs, outputs);

    // L2 Normalize
    final rawEmb = List<double>.from(outputTensor[0]);
    return _l2Normalize(rawEmb);
  }

  /// Normalizes vector to unit length (for exact cosine similarity via dot product).
  List<double> _l2Normalize(List<double> vec) {
    double sumSq = 0.0;
    for (final v in vec) {
      sumSq += v * v;
    }
    final norm = math.sqrt(sumSq);
    if (norm < 1e-9) return vec;
    return vec.map((v) => v / norm).toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
