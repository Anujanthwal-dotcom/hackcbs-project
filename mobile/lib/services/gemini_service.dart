import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Lightweight, dedicated Gemini API service for multilingual (Hindi/Hinglish)
/// agricultural reasoning in KisaanBandhu.
///
/// Auth strategy:
/// - All keys (AIza API keys AND AQ OAuth tokens) are sent via `x-goog-api-key` header.
///   This is Google's canonical header for both formats and avoids 401 issues
///   caused by incorrectly using Authorization: Bearer for AQ keys.
///
/// Model strategy:
/// - Uses latest-alias models (gemini-flash-latest, gemini-pro-latest) that stay
///   available regardless of which versioned model is deprecated for this account.
class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  static GeminiService get instance => _instance;

  /// Ordered list of models to try. Uses alias names that resolve to the latest
  /// available version and don't go stale when Google deprecates specific versions.
  static const List<String> _models = [
    'gemini-flash-latest',        // Resolves to the latest Gemini Flash variant
    'gemini-pro-latest',          // Fallback: latest Pro variant
    'gemini-2.5-flash-lite',      // Lighter fallback
    'gemini-flash-lite-latest',   // Alias fallback
  ];

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Generates a natural, farmer-friendly Hindi agricultural response.
  Future<String?> generateHindiResponse({
    required String prompt,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final apiKey = AppConfig.geminiApiKey;

    // ── Diagnostic: key presence ─────────────────────────────────────────────
    if (apiKey.isEmpty) {
      debugPrint('[GeminiService] DIAG: API key EMPTY — set --dart-define=GEMINI_API_KEY=...');
      return null;
    }
    final prefix = apiKey.length > 6 ? apiKey.substring(0, 6) : apiKey;
    debugPrint('[GeminiService] DIAG: key present=true, length=${apiKey.length}, prefix=$prefix...');
    debugPrint('[GeminiService] DIAG: auth=x-goog-api-key header (works for both AIza and AQ keys)');
    // ─────────────────────────────────────────────────────────────────────────

    for (final model in _models) {
      debugPrint('[GeminiService] DIAG: Trying model=$model...');
      final result = await _callModel(model, prompt, apiKey, timeout);
      if (result != null && result.isNotEmpty) {
        debugPrint('[GeminiService] DIAG: SUCCESS with model=$model (${result.length} chars)');
        return result;
      }
    }

    debugPrint('[GeminiService] DIAG: ALL models exhausted. Returning null.');
    return null;
  }

  Future<String?> _callModel(
    String model,
    String prompt,
    String apiKey,
    Duration timeout,
  ) async {
    // Use x-goog-api-key header — canonical for both AIza API keys and AQ tokens.
    // This is what Google AI Studio's own curl examples use.
    final url = Uri.parse('$_baseUrl/$model:generateContent');
    final headers = {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    };

    debugPrint('[GeminiService] DIAG: POST $url');

    final payload = {
      'systemInstruction': {
        'parts': [
          {
            'text': 'आप KisaanBandhu (किसान बंधु) हैं — भारतीय किसानों के लिए एक व्यावहारिक, '
                'भरोसेमंद और मित्रवत कृषि सहायक। '
                'किसान आपसे हिंदी या हिंग्लिश में प्रश्न पूछ रहे हैं। '
                'सरल, प्राकृतिक, स्पष्ट और व्यावहारिक हिंदी में उत्तर दें। '
                'आम बोलचाल के तकनीकी शब्द स्वाभाविक रूप से इस्तेमाल कर सकते हैं। '
                'किसान के प्रश्न का सीधा और मददगार उत्तर दें।'
          }
        ]
      },
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 1024,
      }
    };

    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(timeout);

      debugPrint('[GeminiService] DIAG: HTTP ${response.statusCode} for model=$model');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts.first['text'] as String?;
            if (text != null && text.trim().isNotEmpty) {
              return text.trim();
            }
          }
        }
        debugPrint('[GeminiService] DIAG: 200 OK but no candidate text.');
        return null;
      } else {
        final bodyPreview = response.body.length > 600
            ? response.body.substring(0, 600)
            : response.body;
        debugPrint('[GeminiService] DIAG: Error body: $bodyPreview');
        if (response.statusCode == 401 || response.statusCode == 403) {
          debugPrint('[GeminiService] DIAG: AUTH FAILURE');
        } else if (response.statusCode == 404) {
          debugPrint('[GeminiService] DIAG: MODEL NOT FOUND — skipping to next model');
        } else if (response.statusCode == 429) {
          debugPrint('[GeminiService] DIAG: RATE LIMITED');
        }
        return null;
      }
    } on http.ClientException catch (e) {
      debugPrint('[GeminiService] DIAG: Network/DNS failure for model=$model: $e');
      return null;
    } catch (e, stack) {
      debugPrint('[GeminiService] DIAG: Exception ${e.runtimeType} for model=$model: $e');
      debugPrint('[GeminiService] DIAG: Stack: $stack');
      return null;
    }
  }
}
