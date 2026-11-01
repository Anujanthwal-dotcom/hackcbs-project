import '../../../models/prediction_result.dart';

enum MessageSender { user, assistant }

class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  /// Absolute path to an attached image (user messages only).
  final String? imagePath;

  /// ML inference result from attached image (user messages only).
  final PredictionResult? mlResult;

  /// RAG knowledge section names used to generate this response (assistant messages).
  final List<String> ragSources;

  /// True if the LLM generated this response (vs. RAG-only fallback).
  final bool llmUsed;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.imagePath,
    this.mlResult,
    this.ragSources = const [],
    this.llmUsed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'sender': sender.name,
      'timestamp': timestamp.toIso8601String(),
      'imagePath': imagePath,
      'ragSources': ragSources,
      'llmUsed': llmUsed,
      if (mlResult != null)
        'mlResult': {
          'predictedClass': mlResult!.predictedClass,
          'crop': mlResult!.crop,
          'condition': mlResult!.condition,
          'confidence': mlResult!.confidence,
          'state': mlResult!.state.name,
        },
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, [String? docId]) {
    PredictionResult? parsedMl;
    if (map['mlResult'] is Map<String, dynamic>) {
      final mlMap = map['mlResult'] as Map<String, dynamic>;
      parsedMl = PredictionResult(
        predictedClass: mlMap['predictedClass'] as String? ?? 'negative',
        classIndex: 0,
        confidence: (mlMap['confidence'] as num?)?.toDouble() ?? 0.0,
        margin: 0.1,
        blurScore: 2000.0,
        state: InferenceState.values.firstWhere(
          (s) => s.name == mlMap['state'],
          orElse: () => InferenceState.validTarget,
        ),
        crop: mlMap['crop'] as String? ?? 'Unknown',
        condition: mlMap['condition'] as String? ?? 'Unknown',
        confidenceThreshold: 0.55,
        marginThreshold: 0.05,
        blurThreshold: 1293.0,
        allProbabilities: const {},
        timestamp: DateTime.now(),
      );
    }

    return ChatMessage(
      id: docId ?? map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: map['text'] as String? ?? '',
      sender: map['sender'] == 'user' ? MessageSender.user : MessageSender.assistant,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      imagePath: map['imagePath'] as String?,
      mlResult: parsedMl,
      ragSources: (map['ragSources'] as List<dynamic>?)?.cast<String>() ?? const [],
      llmUsed: map['llmUsed'] as bool? ?? false,
    );
  }
}
