import 'dart:async';
import 'package:flutter/material.dart';

/// Type of UI element registered in the Semantic UI Registry
enum AgentElementType {
  button,
  card,
  input,
  tab,
  iconButton,
  dialog,
  sheet,
  menuItem,
}

/// Metadata and hook for an element registered in [SemanticUiRegistry]
class SemanticElementData {
  final String id;
  final String label;
  final String description;
  final String screen;
  final AgentElementType elementType;
  final GlobalKey globalKey;
  final VoidCallback? onTrigger;
  final bool isDestructive;

  const SemanticElementData({
    required this.id,
    required this.label,
    required this.description,
    required this.screen,
    required this.globalKey,
    this.elementType = AgentElementType.button,
    this.onTrigger,
    this.isDestructive = false,
  });

  /// Computes the element's current bounding rect in global window coordinates
  Rect? getBoundingRect() {
    final context = globalKey.currentContext;
    if (context == null) return null;
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.hasSize) return null;
    final position = renderBox.localToGlobal(Offset.zero);
    return position & renderBox.size;
  }
}

/// Active highlight data passed to the highlight overlay
class ActiveHighlight {
  final String elementId;
  final String label;
  final String? explanation;
  final Rect boundingRect;
  final DateTime expiresAt;

  const ActiveHighlight({
    required this.elementId,
    required this.label,
    this.explanation,
    required this.boundingRect,
    required this.expiresAt,
  });
}

/// Global Semantic UI Registry allowing the AI Agent to locate,
/// explain, scroll to, highlight, and trigger interactive UI components.
class SemanticUiRegistry extends ChangeNotifier {
  static final SemanticUiRegistry _instance = SemanticUiRegistry._internal();
  factory SemanticUiRegistry() => _instance;
  SemanticUiRegistry._internal();

  static SemanticUiRegistry get instance => _instance;

  final Map<String, SemanticElementData> _registry = {};
  ActiveHighlight? _activeHighlight;
  Timer? _highlightTimer;

  ActiveHighlight? get activeHighlight => _activeHighlight;

  /// Registers an interactive UI element
  void register(SemanticElementData data) {
    _registry[data.id] = data;
    notifyListeners();
  }

  /// Unregisters an element when unmounted
  void unregister(String id) {
    _registry.remove(id);
    if (_activeHighlight?.elementId == id) {
      clearHighlight();
    }
    notifyListeners();
  }

  /// Finds an element by ID
  SemanticElementData? find(String id) => _registry[id];

  /// Returns all registered elements, optionally filtered by screen
  List<SemanticElementData> getElements({String? screen}) {
    if (screen == null) return _registry.values.toList();
    return _registry.values.where((e) => e.screen.toLowerCase() == screen.toLowerCase()).toList();
  }

  /// Highlights an element on screen with a visible animated spotlight and tooltip
  bool highlightElement(String id, {String? explanation, Duration duration = const Duration(seconds: 4)}) {
    final elem = _registry[id];
    if (elem == null) return false;

    final rect = elem.getBoundingRect();
    if (rect == null) return false;

    _highlightTimer?.cancel();
    _activeHighlight = ActiveHighlight(
      elementId: id,
      label: elem.label,
      explanation: explanation ?? elem.description,
      boundingRect: rect,
      expiresAt: DateTime.now().add(duration),
    );
    notifyListeners();

    _highlightTimer = Timer(duration, () {
      clearHighlight();
    });
    return true;
  }

  /// Scrolls an element into view if inside a Scrollable
  Future<bool> scrollToElement(String id) async {
    final elem = _registry[id];
    if (elem == null) return false;
    final context = elem.globalKey.currentContext;
    if (context == null) return false;
    try {
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Programmatically triggers an element's action (if safe and approved)
  bool triggerElement(String id) {
    final elem = _registry[id];
    if (elem == null || elem.onTrigger == null) return false;
    elem.onTrigger!();
    return true;
  }

  /// Dismisses the active highlight
  void clearHighlight() {
    _highlightTimer?.cancel();
    _highlightTimer = null;
    if (_activeHighlight != null) {
      _activeHighlight = null;
      notifyListeners();
    }
  }

  /// Export list of visible elements on the current screen for AI context
  List<Map<String, dynamic>> describeCurrentScreenElements(String currentScreen) {
    return _registry.values
        .where((e) => e.screen.toLowerCase() == currentScreen.toLowerCase())
        .map((e) => {
              'id': e.id,
              'label': e.label,
              'description': e.description,
              'type': e.elementType.name,
              'isDestructive': e.isDestructive,
            })
        .toList();
  }
}

/// Reusable Agent-Aware Wrapper Widget.
///
/// Wraps any widget, assigns a stable ID, registers with [SemanticUiRegistry],
/// and unregisters automatically on dispose.
class AgentUiElement extends StatefulWidget {
  final String id;
  final String label;
  final String description;
  final String screen;
  final AgentElementType elementType;
  final VoidCallback? onTrigger;
  final bool isDestructive;
  final Widget child;

  const AgentUiElement({
    super.key,
    required this.id,
    required this.label,
    required this.description,
    required this.screen,
    this.elementType = AgentElementType.button,
    this.onTrigger,
    this.isDestructive = false,
    required this.child,
  });

  @override
  State<AgentUiElement> createState() => _AgentUiElementState();
}

class _AgentUiElementState extends State<AgentUiElement> {
  final GlobalKey _elementKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(covariant AgentUiElement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.label != widget.label) {
      SemanticUiRegistry.instance.unregister(oldWidget.id);
      _register();
    }
  }

  void _register() {
    SemanticUiRegistry.instance.register(
      SemanticElementData(
        id: widget.id,
        label: widget.label,
        description: widget.description,
        screen: widget.screen,
        globalKey: _elementKey,
        elementType: widget.elementType,
        onTrigger: widget.onTrigger,
        isDestructive: widget.isDestructive,
      ),
    );
  }

  @override
  void dispose() {
    SemanticUiRegistry.instance.unregister(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _elementKey,
      child: widget.child,
    );
  }
}

