import 'package:flutter/material.dart';
import '../../services/agent_runtime.dart';
import '../../services/ai_mode_manager.dart';
import '../../services/global_context_engine.dart';
import '../../services/guided_demo_service.dart';
import '../../services/voice_service.dart';
import 'agent_highlight_overlay.dart';
import 'guided_demo_overlay.dart';
import 'mascot_conversation_sheet.dart';

/// Global Persistent AI Mascot Overlay.
///
/// Lives throughout the application life-cycle, sitting above all routes.
/// Persists across navigation and route transitions.
///
/// States:
/// 1. Collapsed: Floating at bottom-right with subtle breathing animation & status badge
/// 2. Expanded: Slides up the full context-aware conversational interface
/// 3. Working: Visual indicator when agent is retrieving context or executing tools
/// 4. Offline: Clearly indicates offline state with graceful local RAG fallback
class GlobalMascotOverlay extends StatefulWidget {
  final Widget child;

  const GlobalMascotOverlay({super.key, required this.child});

  @override
  State<GlobalMascotOverlay> createState() => _GlobalMascotOverlayState();
}

class _GlobalMascotOverlayState extends State<GlobalMascotOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  final GlobalContextEngine _contextEngine = GlobalContextEngine.instance;
  final AiModeManager _modeManager = AiModeManager.instance;
  final AgentRuntime _runtime = AgentRuntime.instance;
  final VoiceService _voiceService = VoiceService.instance;

  bool _isSheetOpen = false;

  @override
  void initState() {
    super.initState();
    // Subtle breathing floating animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: 0, end: -7).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _contextEngine.addListener(_onStateChanged);
    _modeManager.modeNotifier.addListener(_onStateChanged);
    _runtime.addListener(_onStateChanged);
    GuidedDemoService.instance.addListener(_onStateChanged);

    // Initialize voice service and start passive wake-word detection
    _startWakeWordListening();
  }

  void _startWakeWordListening() {
    if (_isSheetOpen || GuidedDemoService.instance.isRunningOrLaunching) return;
    _voiceService.startWakeWordListening(
      preferredLanguageCode: 'hi',
      onWakeWordDetected: (trigger) {
        if (mounted && !_isSheetOpen && !GuidedDemoService.instance.isRunningOrLaunching) {
          debugPrint('[GlobalMascotOverlay] Wake word detected: "$trigger" -> Opening mascot');
          final isDemo = GuidedDemoService.isDemoTrigger(trigger);
          _openConversationSheet(
            initialQuery: isDemo ? 'Start demo' : null,
            initialVoiceMode: !isDemo,
          );
        }
      },
    );
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _voiceService.stopWakeWordListening();
    _contextEngine.removeListener(_onStateChanged);
    _modeManager.modeNotifier.removeListener(_onStateChanged);
    _runtime.removeListener(_onStateChanged);
    GuidedDemoService.instance.removeListener(_onStateChanged);
    _floatController.dispose();
    super.dispose();
  }

  void _openConversationSheet({
    BuildContext? context,
    String? initialQuery,
    bool initialVoiceMode = false,
  }) {
    if (_isSheetOpen) return;

    _voiceService.stopWakeWordListening();

    final targetContext = GlobalContextEngine.instance.navigatorKey.currentContext ?? context;
    if (targetContext == null) {
      debugPrint('[GlobalMascotOverlay] Cannot open conversation sheet: No valid Navigator context found');
      return;
    }

    _isSheetOpen = true;

    showModalBottomSheet<void>(
      context: targetContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      useRootNavigator: true,
      builder: (sheetContext) {
        return MascotConversationSheet(
          initialQuery: initialQuery,
          initialVoiceMode: initialVoiceMode,
          onMinimize: () {
            Navigator.of(sheetContext, rootNavigator: true).pop();
          },
        );
      },
    ).whenComplete(() {
      _isSheetOpen = false;
      if (mounted) {
        setState(() {});
        _startWakeWordListening();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDemoRunning = GuidedDemoService.instance.isRunning;
    // Mascot is visible at all times across all screens, unless the automated demo is active
    final isVisible = _contextEngine.isMascotVisible && !_isSheetOpen && !isDemoRunning;
    final isOffline = _modeManager.isOfflineMode;
    final hasPendingAction = _runtime.pendingAction != null;

    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    // Position above standard bottom navigation bar (68px + bottom safe area)
    final mascotBottomPosition = 82.0 + bottomPadding;

    return Stack(
      children: [
        // Main App Hierarchy
        widget.child,

        // Global Semantic UI Spotlight Overlay
        const AgentHighlightOverlay(),

        // Automated Controlled Environment Demo Overlay
        const GuidedDemoOverlay(),

        // Floating AI Mascot (Collapsed State)
        if (isVisible)
          Positioned(
            right: 16,
            bottom: mascotBottomPosition,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatAnimation.value),
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: () => _openConversationSheet(context: context),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF27421D),
                        Color(0xFF3B642B),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: hasPendingAction
                          ? Colors.amber
                          : (isOffline ? const Color(0xFFD48B28) : const Color(0xFF8BAE68)),
                      width: hasPendingAction ? 2.8 : 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (hasPendingAction
                                ? Colors.amber
                                : (isOffline ? const Color(0xFFD48B28) : const Color(0xFF27421D)))
                            .withValues(alpha: 0.4),
                        blurRadius: 14,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Mascot Leaf Icon / Face
                      const Center(
                        child: Text(
                          '🌱',
                          style: TextStyle(fontSize: 28),
                        ),
                      ),

                      // Status Indicator Badge (Top Right)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasPendingAction
                                ? Colors.amber
                                : (isOffline ? const Color(0xFFE65100) : const Color(0xFF4CAF50)),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),

                      // Pending Approval Alert Indicator (Bottom Left)
                      if (hasPendingAction)
                        Positioned(
                          left: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.priority_high, size: 10, color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
