import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/guided_demo_service.dart';
import '../../services/semantic_ui_registry.dart';

/// Full automated controlled environment overlay for the KisaanBandhu Guided Demo.
///
/// Redesigned with a minimalist Dynamic Island capsule positioned cleanly
/// just above the bottom navigation bar.
///
/// Features:
/// - Audio narration plays in the background via TTS without large blocking text boxes.
/// - Unobstructed screen view with glowing light-tint spotlight focus on active elements.
/// - Sleek Dynamic Island pill with ONLY Start/Pause, step indicator, and exit button.
/// - Zero overflow, zero missing-material errors.
class GuidedDemoOverlay extends StatefulWidget {
  const GuidedDemoOverlay({super.key});

  @override
  State<GuidedDemoOverlay> createState() => _GuidedDemoOverlayState();
}

class _GuidedDemoOverlayState extends State<GuidedDemoOverlay>
    with SingleTickerProviderStateMixin {
  final GuidedDemoService _demoService = GuidedDemoService.instance;
  final SemanticUiRegistry _registry = SemanticUiRegistry.instance;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _demoService.addListener(_onServiceChanged);
    _registry.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _demoService.removeListener(_onServiceChanged);
    _registry.removeListener(_onServiceChanged);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_demoService.isRunning) return const SizedBox.shrink();

    final step = _demoService.currentStep;
    if (step == null) return const SizedBox.shrink();

    final isHindi = _demoService.languageCode == 'hi';
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    // Determine target bounding rect
    Rect? highlightRect;
    final activeHighlight = _registry.activeHighlight;
    if (activeHighlight != null) {
      highlightRect = activeHighlight.boundingRect;
    } else if (step.elementId != null) {
      final elem = _registry.find(step.elementId!);
      highlightRect = elem?.getBoundingRect();
    }

    // Default fallback rect if element is not rendered
    highlightRect ??= Rect.fromCenter(
      center: Offset(screenWidth / 2, screenHeight * 0.42),
      width: screenWidth * 0.88,
      height: 140,
    );

    final paddedRect = Rect.fromCenter(
      center: highlightRect.center,
      width: highlightRect.width + 16,
      height: highlightRect.height + 16,
    );

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Absorbs all user touch input across the entire screen while demo is running.
          // App controls are completely locked until user ends the demo.
        },
        child: Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle(
            style: const TextStyle(
              decoration: TextDecoration.none,
            ),
            child: Stack(
              children: [
                // ── Soft Semi-transparent Dimmed Backdrop with Cutout ─────────────
                CustomPaint(
                  size: Size.infinite,
                  painter: _SpotlightPainter(cutoutRect: paddedRect),
                ),

                // ── Glowing Light-Tint Animated Spotlight Frame ────────────────────
                Positioned(
                  left: paddedRect.left,
                  top: paddedRect.top,
                  width: paddedRect.width,
                  height: paddedRect.height,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _demoService.isPaused ? 1.0 : _pulseAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: const Color(0xFF76BA1B).withValues(alpha: 0.12),
                            border: Border.all(
                              color: _demoService.isPaused ? Colors.amber : const Color(0xFF76BA1B),
                              width: 3.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_demoService.isPaused
                                        ? Colors.amber
                                        : const Color(0xFF76BA1B))
                                    .withValues(alpha: 0.40),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── DYNAMIC ISLAND CONTROLLER (The ONLY interactive element) ─────
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 76.0 + bottomPadding,
                  child: _buildDynamicIslandPill(context, step, isHindi),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Compact Dynamic Island style controller pill
  Widget _buildDynamicIslandPill(BuildContext context, DemoStep step, bool isHindi) {
    final isPaused = _demoService.isPaused;
    final stepIndex = _demoService.currentStepIndex + 1;
    final totalSteps = _demoService.totalSteps;

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xF212230E), // Obsidian dynamic island styling
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isPaused
                    ? Colors.amber.withValues(alpha: 0.85)
                    : const Color(0xFF76BA1B).withValues(alpha: 0.65),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Pulsing Status Dot
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPaused ? Colors.amber : const Color(0xFF76BA1B),
                        boxShadow: [
                          BoxShadow(
                            color: (isPaused ? Colors.amber : const Color(0xFF76BA1B))
                                .withValues(alpha: isPaused ? 0.3 : 0.7),
                            blurRadius: isPaused ? 3 : 8,
                            spreadRadius: isPaused ? 0 : 2,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Step Counter & Icon
                Text(
                  '${step.icon} $stepIndex/$totalSteps',
                  style: const TextStyle(
                    color: Color(0xFFC7DCB5),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 12),

                // Subtle vertical separator
                Container(
                  width: 1,
                  height: 18,
                  color: Colors.white.withValues(alpha: 0.20),
                ),
                const SizedBox(width: 12),

                // ── Tactile Start / Pause Button ──────────────────────────────
                GestureDetector(
                  onTap: () => _demoService.togglePause(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPaused
                          ? const Color(0xFF76BA1B)
                          : Colors.amber.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isPaused ? const Color(0xFF9EEB49) : Colors.amber,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          color: isPaused ? Colors.black87 : Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isPaused
                              ? (isHindi ? 'जारी रखें' : 'RESUME')
                              : (isHindi ? 'रोकें (Pause)' : 'PAUSE'),
                          style: TextStyle(
                            color: isPaused ? Colors.black87 : Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Subtle vertical separator
                Container(
                  width: 1,
                  height: 18,
                  color: Colors.white.withValues(alpha: 0.20),
                ),
                const SizedBox(width: 8),

                // Exit Button (✕)
                GestureDetector(
                  onTap: () => _demoService.stopDemo(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter that dims the surrounding screen with a cutout around the highlighted element
class _SpotlightPainter extends CustomPainter {
  final Rect cutoutRect;

  _SpotlightPainter({required this.cutoutRect});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = const Color(0x550A1408) // Soft semi-transparent backdrop
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cutoutRect, const Radius.circular(18)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.cutoutRect != cutoutRect;
  }
}
