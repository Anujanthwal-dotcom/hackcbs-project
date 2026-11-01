import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import 'local_embedding_service.dart';

/// A single retrieved agricultural knowledge chunk.
class RagChunk {
  final String text;
  final String section;
  final String part;
  final String chunkId;
  final double score;

  const RagChunk({
    required this.text,
    required this.section,
    required this.part,
    required this.chunkId,
    required this.score,
  });

  factory RagChunk.fromJson(Map<String, dynamic> json, {double score = 0.0}) {
    return RagChunk(
      text: json['text'] as String? ?? '',
      section: json['section'] as String? ?? '',
      part: json['part'] as String? ?? '',
      chunkId: json['id'] as String? ?? (json['chunk_id'] as String? ?? ''),
      score: score > 0 ? score : ((json['score'] as num?)?.toDouble() ?? 0.0),
    );
  }
}

class _PrecomputedChunk {
  final String id;
  final String section;
  final String part;
  final String source;
  final String document;
  final String text;
  final List<double> embedding;

  const _PrecomputedChunk({
    required this.id,
    required this.section,
    required this.part,
    required this.source,
    required this.document,
    required this.text,
    required this.embedding,
  });

  factory _PrecomputedChunk.fromJson(Map<String, dynamic> json) {
    final rawEmb = json['embedding'] as List<dynamic>? ?? [];
    final emb = rawEmb.map((v) => (v as num).toDouble()).toList();
    return _PrecomputedChunk(
      id: json['id'] as String? ?? '',
      section: json['section'] as String? ?? '',
      part: json['part'] as String? ?? '',
      source: json['source'] as String? ?? 'data.md',
      document: json['document'] as String? ?? 'agricultural_knowledge',
      text: json['text'] as String? ?? '',
      embedding: emb,
    );
  }
}

/// Standalone on-device RAG retrieval service.
///
/// Executes 100% on the mobile device with ZERO network requests.
/// 1. Query is embedded on-device using all-MiniLM-L6-v2 TFLite.
/// 2. Cosine similarity is computed against 109 precomputed knowledge vectors.
/// 3. Top-k semantically relevant chunks are returned.
class RagService {
  static final RagService _instance = RagService._internal();
  factory RagService() => _instance;
  RagService._internal();

  static RagService get instance => _instance;

  static const String knowledgeAssetPath = 'assets/rag/knowledge_base.json';

  final _embeddingService = LocalEmbeddingService.instance;
  List<_PrecomputedChunk> _knowledgeBase = [];
  bool _isLoaded = false;

  bool get isReady => _isLoaded;
  int get totalKnowledgeChunks => _knowledgeBase.length;

  /// Loads the 109 precomputed knowledge chunks into memory.
  Future<void> initialize() async {
    if (_isLoaded && _knowledgeBase.isNotEmpty) return;

    try {
      final jsonString = await rootBundle.loadString(knowledgeAssetPath);
      final List<dynamic> rawList = jsonDecode(jsonString);
      _knowledgeBase = rawList
          .map((item) => _PrecomputedChunk.fromJson(item as Map<String, dynamic>))
          .toList();
      _isLoaded = true;
      debugPrint('[RagService] Loaded ${_knowledgeBase.length} on-device knowledge chunks.');
    } catch (e, stack) {
      debugPrint('[RagService] Failed loading knowledge base asset: $e\n$stack');
      _isLoaded = false;
      rethrow;
    }
  }

  static final Map<String, String> _hindiToEnglishTerms = {
    'कपास': 'cotton',
    'सोयाबीन': 'soybean',
    'टमाटर': 'tomato',
    'गुलाबी सुंडी': 'pink bollworm',
    'गुलाबी इल्ली': 'pink bollworm',
    'सुंडी': 'bollworm caterpillar',
    'सफेद मक्खी': 'whitefly',
    'मक्खी': 'fly insect',
    'जीवाणु झुलसा': 'bacterial blight',
    'बैक्टीरियल ब्लाइट': 'bacterial blight',
    'झुलसा': 'blight',
    'रोग': 'disease',
    'कीट': 'pest insect',
    'कीटनाशक': 'pesticide insecticide',
    'उर्वरक': 'fertilizer nutrients',
    'खाद': 'manure organic fertilizer',
    'रोकथाम': 'prevention control management',
    'नियंत्रण': 'control management',
    'उपचार': 'treatment cure',
    'दवा': 'spray medicine treatment',
    'छिड़काव': 'spray application',
    'सिंचाई': 'irrigation water',
    'मिट्टी': 'soil',
    'मौसम': 'weather climate',
    'पत्तियां': 'leaves foliage',
    'पत्ती': 'leaf',
    'स्वस्थ': 'healthy',
    'निगरानी': 'monitoring inspection',
    'नुकसान': 'damage crop loss',
  };

  /// Normalizes queries containing Hindi Devanagari terms to bridge with English RAG vectors.
  static String normalizeQueryForEmbedding(String query) {
    if (!RegExp(r'[\u0900-\u097F]').hasMatch(query)) {
      return query;
    }
    String normalized = query;
    for (final entry in _hindiToEnglishTerms.entries) {
      if (normalized.contains(entry.key)) {
        normalized += ' ${entry.value}';
      }
    }
    return normalized;
  }

  /// Retrieve the most semantically relevant agricultural chunks for [query].
  ///
  /// Completely offline, fast (<10ms).
  Future<List<RagChunk>> retrieve(String query, {int topK = AppConfig.ragTopK}) async {
    if (!_isLoaded) {
      await initialize();
    }

    if (_knowledgeBase.isEmpty) {
      debugPrint('[RagService] Warning: Knowledge base is empty.');
      return [];
    }

    final effectiveEmbeddingQuery = normalizeQueryForEmbedding(query);

    try {
      // 1. Embed query on-device
      List<double> queryVector;
      try {
        queryVector = await _embeddingService.embedQuery(effectiveEmbeddingQuery);
      } catch (embErr) {
        debugPrint('[RagService] On-device TFLite embedding note: $embErr');
        // If TFLite interpreter fails on specific arch, fallback to keyword TF-IDF scoring
        return _fallbackKeywordRetrieval(effectiveEmbeddingQuery, topK);
      }

      // 2. Compute cosine similarity against all 109 precomputed chunk embeddings
      final scored = <({_PrecomputedChunk chunk, double score})>[];
      for (final chunk in _knowledgeBase) {
        final score = _cosineSimilarity(queryVector, chunk.embedding);
        scored.add((chunk: chunk, score: score));
      }

      // 3. Sort by relevance descending
      scored.sort((a, b) => b.score.compareTo(a.score));

      // 4. Return top-k results
      final topResults = scored.take(topK).map((item) {
        return RagChunk(
          text: item.chunk.text,
          section: item.chunk.section,
          part: item.chunk.part,
          chunkId: item.chunk.id,
          score: double.parse(item.score.toStringAsFixed(4)),
        );
      }).toList();

      debugPrint('[RagService] Local search retrieved ${topResults.length} chunks. Top score: ${topResults.isNotEmpty ? topResults.first.score : 0}');
      return topResults;
    } catch (e) {
      debugPrint('[RagService] Retrieval error: $e');
      return _fallbackKeywordRetrieval(query, topK);
    }
  }

  /// Fast cosine similarity (dot product of L2-normalized vectors).
  double _cosineSimilarity(List<double> a, List<double> b) {
    final len = a.length < b.length ? a.length : b.length;
    double dot = 0.0;
    for (int i = 0; i < len; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }

  /// Deterministic keyword scoring fallback if TFLite hardware delegate is unavailable.
  List<RagChunk> _fallbackKeywordRetrieval(String query, int topK) {
    final terms = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.length > 2).toSet();
    if (terms.isEmpty) return [];

    final scored = <({_PrecomputedChunk chunk, double score})>[];
    for (final chunk in _knowledgeBase) {
      final textLower = chunk.text.toLowerCase();
      final sectionLower = chunk.section.toLowerCase();
      int matches = 0;
      for (final t in terms) {
        if (sectionLower.contains(t)) matches += 3;
        if (textLower.contains(t)) matches += 1;
      }
      if (matches > 0) {
        scored.add((chunk: chunk, score: matches.toDouble()));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).map((item) {
      return RagChunk(
        text: item.chunk.text,
        section: item.chunk.section,
        part: item.chunk.part,
        chunkId: item.chunk.id,
        score: item.score,
      );
    }).toList();
  }

  /// Health check — always true on device once assets are present.
  Future<bool> isHealthy() async {
    if (!_isLoaded) {
      try {
        await initialize();
      } catch (_) {
        return false;
      }
    }
    return _isLoaded && _knowledgeBase.isNotEmpty;
  }
}
