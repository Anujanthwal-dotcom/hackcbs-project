import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/bert_tokenizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BertTokenizer tokenizer;

  setUpAll(() {
    tokenizer = BertTokenizer();
    final vocabFile = File('assets/ml/vocab.txt');
    final vocabLines = vocabFile.readAsLinesSync();
    tokenizer.initializeFromList(vocabLines);
  });

  test('Tokenizes agricultural question with exact match', () {
    const text = 'How do I control whitefly in soybean crops?';
    final res = tokenizer.encode(text, maxLength: 128);

    expect(res.inputIds.sublist(0, 14), [
      101, 2129, 2079, 1045, 2491, 2317, 14151, 1999, 25176, 4783, 2319, 8765, 1029, 102
    ]);
    expect(res.attentionMask.sublist(0, 14), List.filled(14, 1));
    expect(res.attentionMask[14], 0);
  });

  test('Tokenizes cotton bacterial blight query with exact match', () {
    const text = 'What are the early angular leaf lesion symptoms of cotton bacterial blight?';
    final res = tokenizer.encode(text, maxLength: 128);

    expect(res.inputIds.sublist(0, 15), [
      101, 2054, 2024, 1996, 2220, 16108, 7053, 4649, 3258, 8030, 1997, 6557, 17341, 1038, 7138
    ]);
    expect(res.attentionMask.take(17).toList(), List.filled(17, 1));
  });
}
