import 'package:flutter/services.dart';

/// Pure Dart WordPiece Tokenizer compatible with BERT / all-MiniLM-L6-v2.
class BertTokenizer {
  static const int defaultMaxLength = 128;
  static const String clsToken = '[CLS]';
  static const String sepToken = '[SEP]';
  static const String unkToken = '[UNK]';
  static const String padToken = '[PAD]';

  final Map<String, int> _vocab = {};
  bool _isInitialized = false;

  int _clsId = 101;
  int _sepId = 102;
  int _unkId = 100;
  int _padId = 0;

  bool get isInitialized => _isInitialized;

  /// Loads vocab from assets/ml/vocab.txt.
  Future<void> initialize({String vocabPath = 'assets/ml/vocab.txt'}) async {
    if (_isInitialized) return;

    final content = await rootBundle.loadString(vocabPath);
    final lines = content.split('\n');

    _vocab.clear();
    for (int i = 0; i < lines.length; i++) {
      final token = lines[i].trim();
      if (token.isNotEmpty) {
        _vocab[token] = i;
      }
    }

    _clsId = _vocab[clsToken] ?? 101;
    _sepId = _vocab[sepToken] ?? 102;
    _unkId = _vocab[unkToken] ?? 100;
    _padId = _vocab[padToken] ?? 0;

    _isInitialized = true;
  }

  /// Synchronous initialization from a string list of tokens (useful for testing).
  void initializeFromList(List<String> tokens) {
    _vocab.clear();
    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i].trim();
      if (token.isNotEmpty) {
        _vocab[token] = i;
      }
    }
    _clsId = _vocab[clsToken] ?? 101;
    _sepId = _vocab[sepToken] ?? 102;
    _unkId = _vocab[unkToken] ?? 100;
    _padId = _vocab[padToken] ?? 0;
    _isInitialized = true;
  }

  /// Encodes [text] into fixed-length input_ids and attention_mask.
  ({List<int> inputIds, List<int> attentionMask}) encode(
    String text, {
    int maxLength = defaultMaxLength,
  }) {
    if (!_isInitialized) {
      throw StateError('BertTokenizer must be initialized before calling encode().');
    }

    final tokens = _tokenize(text);
    final subTokens = <int>[_clsId];

    // Truncate to leave room for [CLS] and [SEP]
    final maxContentLength = maxLength - 2;
    final truncatedTokens = tokens.length > maxContentLength ? tokens.sublist(0, maxContentLength) : tokens;

    for (final token in truncatedTokens) {
      final pieces = _wordPieceTokenize(token);
      for (final piece in pieces) {
        if (subTokens.length < maxLength - 1) {
          subTokens.add(_vocab[piece] ?? _unkId);
        }
      }
    }

    subTokens.add(_sepId);

    final inputIds = List<int>.filled(maxLength, _padId);
    final attentionMask = List<int>.filled(maxLength, 0);

    for (int i = 0; i < subTokens.length && i < maxLength; i++) {
      inputIds[i] = subTokens[i];
      attentionMask[i] = 1;
    }

    return (inputIds: inputIds, attentionMask: attentionMask);
  }

  /// Basic clean, lower-casing, whitespace and punctuation splitting.
  List<String> _tokenize(String text) {
    final clean = text.toLowerCase().trim();
    final tokens = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < clean.length; i++) {
      final char = clean[i];
      if (_isWhitespace(char)) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
      } else if (_isPunctuation(char)) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        tokens.add(char);
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens;
  }

  /// WordPiece greedy longest-match tokenization.
  List<String> _wordPieceTokenize(String word) {
    if (word.length > 100) return [unkToken];

    final outputTokens = <String>[];
    int start = 0;

    while (start < word.length) {
      int end = word.length;
      String? curSubstr;

      while (start < end) {
        String substr = word.substring(start, end);
        if (start > 0) {
          substr = '##$substr';
        }

        if (_vocab.containsKey(substr)) {
          curSubstr = substr;
          break;
        }
        end--;
      }

      if (curSubstr == null) {
        return [unkToken];
      }

      outputTokens.add(curSubstr);
      start = end;
    }

    return outputTokens;
  }

  bool _isWhitespace(String char) {
    final code = char.codeUnitAt(0);
    return code == 32 || code == 9 || code == 10 || code == 13;
  }

  bool _isPunctuation(String char) {
    final code = char.codeUnitAt(0);
    if ((code >= 33 && code <= 47) ||
        (code >= 58 && code <= 64) ||
        (code >= 91 && code <= 96) ||
        (code >= 123 && code <= 126)) {
      return true;
    }
    return false;
  }
}
