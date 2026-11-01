import 'dart:async';
import 'package:flutter/foundation.dart';
import 'agent_runtime.dart';
import 'assistant_service.dart';
import 'backend_api_service.dart';
import 'global_context_engine.dart';

enum AiAgentMode {
  onlineAgentActive,
  offlineAssistantActive,
  checkingConnectivity,
  onlineServiceUnavailable,
  switchingToOffline,
}

/// Unified response from either the online Ambient Agent or offline RAG assistant
class UnifiedAgentResponse {
  final String text;
  final bool isOffline;
  final List<String> toolsExecuted;
  final bool hasPendingConfirmation;
  final List<String> ragSources;
  final DateTime timestamp;

  const UnifiedAgentResponse({
    required this.text,
    required this.isOffline,
    this.toolsExecuted = const [],
    this.hasPendingConfirmation = false,
    this.ragSources = const [],
    required this.timestamp,
  });
}

/// Intelligent AI Mode Manager.
///
/// Orchestrates dual operating modes:
/// 1. ONLINE INTELLIGENT AGENT:
///    - Gemini reasoning via authenticated NestJS backend
///    - Meko persistent conversational memory
///    - Global context awareness & application tool calling
/// 2. OFFLINE AI ASSISTANT:
///    - Existing local Gemma 3 1B LLM
///    - On-device 109-chunk RAG vector retrieval
///    - Zero network dependencies
class AiModeManager {
  static final AiModeManager _instance = AiModeManager._internal();
  factory AiModeManager() => _instance;
  AiModeManager._internal();

  static AiModeManager get instance => _instance;

  final ValueNotifier<AiAgentMode> modeNotifier =
      ValueNotifier<AiAgentMode>(AiAgentMode.onlineAgentActive);

  bool _userForcedOffline = false;
  bool get isOfflineMode =>
      _userForcedOffline ||
      modeNotifier.value == AiAgentMode.offlineAssistantActive ||
      modeNotifier.value == AiAgentMode.onlineServiceUnavailable;

  void setForcedOffline(bool forceOffline) {
    _userForcedOffline = forceOffline;
    if (forceOffline) {
      modeNotifier.value = AiAgentMode.offlineAssistantActive;
    } else {
      checkOnlineAvailability();
    }
  }

  /// Checks if backend online agent services are available
  Future<bool> checkOnlineAvailability() async {
    if (_userForcedOffline) return false;
    modeNotifier.value = AiAgentMode.checkingConnectivity;
    try {
      final isOnline = await BackendApiService.instance.checkAgentHealth();
      modeNotifier.value = isOnline
          ? AiAgentMode.onlineAgentActive
          : AiAgentMode.offlineAssistantActive;
      return isOnline;
    } catch (_) {
      modeNotifier.value = AiAgentMode.offlineAssistantActive;
      return false;
    }
  }

  /// Dispatches farmer query to either the online agent or offline assistant
  Future<UnifiedAgentResponse> processMessage({
    required String query,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    // Only bypass online agent if user explicitly forced offline mode
    if (_userForcedOffline) {
      return _runOfflineFallback(query, reason: 'Offline mode forced by user');
    }

    // Try online agent first whenever not manually forced offline
    try {
      final contextSnapshot = GlobalContextEngine.instance.getSnapshot();
      final backendResponse = await BackendApiService.instance.queryOnlineAgent(
        message: query,
        context: contextSnapshot,
        history: conversationHistory,
      );

      if (backendResponse != null && backendResponse['success'] == true) {
        modeNotifier.value = AiAgentMode.onlineAgentActive;

        final replyText = backendResponse['reply']?.toString() ?? '';
        final toolCalls = backendResponse['toolCalls'] as List<dynamic>? ?? [];
        final executedTools = <String>[];
        bool requiresConfirmation = false;

        // Execute approved tool calls locally on device
        for (final tc in toolCalls) {
          final toolName = tc['tool']?.toString() ?? '';
          final args = tc['parameters'] as Map<String, dynamic>? ?? {};
          final toolResult = await AgentRuntime.instance.executeTool(toolName, args);
          executedTools.add(toolResult.message);
          if (toolResult.requiresConfirmation) {
            requiresConfirmation = true;
          }
        }

        return UnifiedAgentResponse(
          text: replyText,
          isOffline: false,
          toolsExecuted: executedTools,
          hasPendingConfirmation: requiresConfirmation,
          timestamp: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('[AiModeManager] Online agent error: $e — falling back to offline assistant.');
    }

    // Graceful single-query fallback to offline RAG assistant without permanently trapping user
    final fallbackResponse = await _runOfflineFallback(
      query,
      reason: 'Online service temporarily unavailable. Switched to offline knowledge base.',
    );
    // Don't permanently lock into offline mode; keep online ready for next message
    return fallbackResponse;
  }

  /// Runs the preserved existing offline AI assistant (RAG + on-device Gemma)
  Future<UnifiedAgentResponse> _runOfflineFallback(String query, {required String reason}) async {
    try {
      final assistantResp = await AssistantService.instance.respond(query: query);
      return UnifiedAgentResponse(
        text: assistantResp.text,
        isOffline: true,
        ragSources: assistantResp.ragSources,
        toolsExecuted: [reason],
        timestamp: assistantResp.timestamp,
      );
    } catch (e) {
      return UnifiedAgentResponse(
        text: 'The offline agricultural assistant is ready. Please try asking your farming question.\n\n($reason)',
        isOffline: true,
        toolsExecuted: [reason],
        timestamp: DateTime.now(),
      );
    }
  }
}
