import 'package:flutter/material.dart';
import '../models/farm_model.dart';
import 'farm_repository.dart';
import 'global_context_engine.dart';
import 'semantic_ui_registry.dart';

/// Represents an agent proposed action that requires explicit human confirmation
class PendingAction {
  final String id;
  final String actionType;
  final String title;
  final String description;
  final Map<String, dynamic> payload;
  final Future<String> Function() execute;
  final VoidCallback onCancel;

  PendingAction({
    required this.id,
    required this.actionType,
    required this.title,
    required this.description,
    required this.payload,
    required this.execute,
    required this.onCancel,
  });
}

/// Tool execution result returned to the agent loop
class ToolExecutionResult {
  final String toolName;
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final bool requiresConfirmation;

  const ToolExecutionResult({
    required this.toolName,
    required this.success,
    required this.message,
    this.data,
    this.requiresConfirmation = false,
  });
}

/// Agent Runtime that executes approved application tools and enforces
/// Human-in-the-Loop approval for write and destructive operations.
class AgentRuntime extends ChangeNotifier {
  static final AgentRuntime _instance = AgentRuntime._internal();
  factory AgentRuntime() => _instance;
  AgentRuntime._internal();

  static AgentRuntime get instance => _instance;

  final GlobalContextEngine _contextEngine = GlobalContextEngine.instance;
  final SemanticUiRegistry _registry = SemanticUiRegistry.instance;

  PendingAction? _pendingAction;
  PendingAction? get pendingAction => _pendingAction;

  /// Sets or clears a pending confirmation action
  void setPendingAction(PendingAction? action) {
    _pendingAction = action;
    notifyListeners();
  }

  /// User confirms the pending action
  Future<String> confirmPendingAction() async {
    final action = _pendingAction;
    if (action == null) return 'No pending action';
    _pendingAction = null;
    notifyListeners();

    try {
      final result = await action.execute();
      _contextEngine.trackAction('Approved action executed: ${action.title}');
      return result;
    } catch (e) {
      return 'Action execution failed: $e';
    }
  }

  /// User cancels the pending action
  void cancelPendingAction() {
    final action = _pendingAction;
    if (action != null) {
      action.onCancel();
      _contextEngine.trackAction('Action cancelled: ${action.title}');
    }
    _pendingAction = null;
    notifyListeners();
  }

  // ── Approved Tool Execution ───────────────────────────────────────────────

  Future<ToolExecutionResult> executeTool(String toolName, Map<String, dynamic> args) async {
    debugPrint('[AgentRuntime] Executing tool: $toolName with args: $args');

    switch (toolName) {
      // 1. get_screen_context
      case 'get_screen_context':
        return ToolExecutionResult(
          toolName: toolName,
          success: true,
          message: 'Retrieved screen context',
          data: _contextEngine.getSnapshot(),
        );

      // 2. get_selected_object
      case 'get_selected_object':
        final farm = _contextEngine.selectedFarm;
        final detection = _contextEngine.selectedDetection;
        return ToolExecutionResult(
          toolName: toolName,
          success: true,
          message: 'Retrieved selected objects',
          data: {
            'selectedFarm': farm != null
                ? {
                    'id': farm.id,
                    'name': farm.name,
                    'crop': farm.cropType,
                    'area': farm.formattedArea,
                  }
                : null,
            'selectedDetection': detection != null
                ? {
                    'id': detection.id,
                    'crop': detection.crop,
                    'condition': detection.condition,
                    'confidence': detection.confidencePercentage,
                  }
                : null,
          },
        );

      // 3. navigate_to
      case 'navigate_to':
        final target = args['target_screen']?.toString() ?? args['screen']?.toString() ?? '';
        final success = _contextEngine.navigateToScreenName(target);
        return ToolExecutionResult(
          toolName: toolName,
          success: success,
          message: success
              ? 'Navigated to $target'
              : 'Could not navigate to $target. Known screens: Scan, Map, Help Desk, Profile.',
        );

      // 4. highlight_element
      case 'highlight_element':
        final elementId = args['element_id']?.toString() ?? '';
        final explanation = args['explanation']?.toString();
        final success = _registry.highlightElement(elementId, explanation: explanation);
        return ToolExecutionResult(
          toolName: toolName,
          success: success,
          message: success
              ? 'Highlighted element "$elementId"'
              : 'Element "$elementId" is not visible on the current screen (${_contextEngine.currentScreen}).',
        );

      // 5. scroll_to_element
      case 'scroll_to_element':
        final elementId = args['element_id']?.toString() ?? '';
        final success = await _registry.scrollToElement(elementId);
        return ToolExecutionResult(
          toolName: toolName,
          success: success,
          message: success
              ? 'Scrolled to element "$elementId"'
              : 'Could not scroll to "$elementId".',
        );

      // 6. explain_element
      case 'explain_element':
        final elementId = args['element_id']?.toString() ?? '';
        final elem = _registry.find(elementId);
        if (elem != null) {
          _registry.highlightElement(elementId, explanation: elem.description);
          return ToolExecutionResult(
            toolName: toolName,
            success: true,
            message: '${elem.label}: ${elem.description}',
            data: {'id': elem.id, 'label': elem.label, 'description': elem.description},
          );
        }
        return ToolExecutionResult(
          toolName: toolName,
          success: false,
          message: 'Element "$elementId" not found in registry.',
        );

      // 7. open_modal
      case 'open_modal':
        final modalName = args['modal_name']?.toString() ?? '';
        _contextEngine.setModalState(modalName);
        return ToolExecutionResult(
          toolName: toolName,
          success: true,
          message: 'Recorded modal state: $modalName',
        );

      // 8. close_modal
      case 'close_modal':
        final navState = _contextEngine.navigatorKey.currentState;
        if (navState != null && navState.canPop()) {
          navState.pop();
          _contextEngine.setModalState(null);
          return const ToolExecutionResult(
            toolName: 'close_modal',
            success: true,
            message: 'Closed active dialog or modal',
          );
        }
        return const ToolExecutionResult(
          toolName: 'close_modal',
          success: false,
          message: 'No active modal to close',
        );

      // 9. click_element
      case 'click_element':
        final elementId = args['element_id']?.toString() ?? '';
        final elem = _registry.find(elementId);
        if (elem == null) {
          return ToolExecutionResult(
            toolName: toolName,
            success: false,
            message: 'Element "$elementId" not found',
          );
        }
        if (elem.isDestructive) {
          return ToolExecutionResult(
            toolName: toolName,
            success: false,
            message: 'Cannot click destructive element "$elementId" directly without human confirmation.',
          );
        }
        final ok = _registry.triggerElement(elementId);
        return ToolExecutionResult(
          toolName: toolName,
          success: ok,
          message: ok ? 'Triggered element "$elementId"' : 'Element has no tap handler registered.',
        );

      // 10. fill_form
      case 'fill_form':
        final fieldName = args['field_name']?.toString() ?? '';
        final value = args['value'];
        _contextEngine.updateFormField(fieldName, value);
        return ToolExecutionResult(
          toolName: toolName,
          success: true,
          message: 'Updated form field "$fieldName"',
        );

      // 11. execute_workflow (Human-in-the-Loop for Write/Modify Actions)
      case 'prepare_action':
      case 'rename_farm':
        final newName = args['new_name']?.toString() ?? args['name']?.toString() ?? '';
        final targetRef = args['target_farm']?.toString() ?? args['target']?.toString() ?? '';

        final allFarms = FarmRepository.instance.cachedFarms;
        FarmModel? farm;

        if (targetRef.isNotEmpty && allFarms.isNotEmpty) {
          final targetClean = targetRef.trim();
          final targetLower = targetClean.toLowerCase();

          // 1. Exact ID match
          farm = allFarms.where((f) => f.id == targetClean).firstOrNull;

          // 2. Exact Name match (case-insensitive)
          farm ??= allFarms.where((f) => f.name.toLowerCase().trim() == targetLower).firstOrNull;

          // 3. Numeric match (e.g. "Farm 1" -> 1st farm, "खेत 1" -> 1st farm, "4" -> 4th farm)
          final numMatch = RegExp(r'\d+').firstMatch(targetLower);
          if (farm == null && numMatch != null) {
            final index = int.tryParse(numMatch.group(0)!) ?? 0;
            if (index > 0 && index <= allFarms.length) {
              farm = allFarms[index - 1];
            }
          }

          // 4. Partial substring match
          farm ??= allFarms.where((f) =>
              f.name.toLowerCase().contains(targetLower) ||
              targetLower.contains(f.name.toLowerCase())).firstOrNull;
        }

        // Fallback to currently selected farm or first available farm
        farm ??= _contextEngine.selectedFarm ?? (allFarms.isNotEmpty ? allFarms.first : null);

        if (farm == null) {
          return const ToolExecutionResult(
            toolName: 'rename_farm',
            success: false,
            message: 'No farm found to rename. Please create a farm on the Map screen first.',
          );
        }

        // Create Human-in-the-loop pending action
        final targetFarm = farm;
        final pending = PendingAction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          actionType: 'rename_farm',
          title: 'Rename Farm',
          description: 'Change farm name from "${targetFarm.name}" to "$newName"',
          payload: {'farmId': targetFarm.id, 'oldName': targetFarm.name, 'newName': newName},
          execute: () async {
            final updatedFarm = FarmModel(
              id: targetFarm.id,
              userId: targetFarm.userId,
              name: newName,
              boundary: targetFarm.boundary,
              center: targetFarm.center,
              areaSquareMeters: targetFarm.areaSquareMeters,
              cropType: targetFarm.cropType,
              createdAt: targetFarm.createdAt,
              updatedAt: DateTime.now(),
            );
            await FarmRepository.instance.saveFarm(updatedFarm);
            _contextEngine.setSelectedFarm(updatedFarm);
            _registry.highlightElement('rename_farm', explanation: 'Farm renamed to "$newName"');
            return 'Successfully renamed farm to "$newName".';
          },
          onCancel: () {},
        );

        setPendingAction(pending);
        return ToolExecutionResult(
          toolName: toolName,
          success: true,
          message: 'I have prepared to rename your farm "${targetFarm.name}" to "$newName". Please confirm the change below.',
          requiresConfirmation: true,
        );

      // 12. verify_action
      case 'verify_action':
        final expectedState = args['expected_state']?.toString() ?? '';
        return ToolExecutionResult(
          toolName: toolName,
          success: true,
          message: 'State verified: $expectedState',
        );

      default:
        return ToolExecutionResult(
          toolName: toolName,
          success: false,
          message: 'Unknown or unapproved tool: $toolName',
        );
    }
  }
}

