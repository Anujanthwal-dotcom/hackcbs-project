/// Structured response from the AssistantService pipeline.
class AssistantResponse {
  /// The final farmer-friendly text to display.
  final String text;

  /// Section names of RAG chunks used (for citations).
  final List<String> ragSources;

  /// Brief ML result summary that was included in context.
  final String? mlSummary;

  /// Whether live weather was included in the context.
  final bool weatherUsed;

  /// Whether RAG knowledge was successfully retrieved.
  final bool ragUsed;

  /// Whether the local LLM generated the response (vs. RAG-only fallback).
  final bool llmUsed;

  /// Whether the LLM server was reachable.
  final bool llmAvailable;

  final DateTime timestamp;

  const AssistantResponse({
    required this.text,
    this.ragSources = const [],
    this.mlSummary,
    this.weatherUsed = false,
    this.ragUsed = false,
    this.llmUsed = false,
    this.llmAvailable = false,
    required this.timestamp,
  });

  /// Factory for a simple error/unavailable response.
  factory AssistantResponse.unavailable(String reason) {
    return AssistantResponse(
      text: reason,
      timestamp: DateTime.now(),
      llmAvailable: false,
    );
  }

  /// Factory for a RAG-only response (no LLM).
  factory AssistantResponse.ragOnly(String text, List<String> sources) {
    return AssistantResponse(
      text: text,
      ragSources: sources,
      ragUsed: true,
      llmUsed: false,
      llmAvailable: false,
      timestamp: DateTime.now(),
    );
  }
}
