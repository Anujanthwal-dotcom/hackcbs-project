import 'package:flutter/material.dart';
import '../../services/guided_demo_service.dart';
import '../../services/semantic_ui_registry.dart';

/// Global overlay widget that listens to [SemanticUiRegistry] and displays
/// an animated spotlight, pulsing ring, and instructional tooltip over highlighted elements.
class AgentHighlightOverlay extends StatefulWidget {
  const AgentHighlightOverlay({super.key});

  @override
  State<AgentHighlightOverlay> createState() => _AgentHighlightOverlayState();
}

class _AgentHighlightOverlayState extends State<AgentHighlightOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    SemanticUiRegistry.instance.addListener(_onRegistryChanged);
    GuidedDemoService.instance.addListener(_onRegistryChanged);
  }

  void _onRegistryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SemanticUiRegistry.instance.removeListener(_onRegistryChanged);
    GuidedDemoService.instance.removeListener(_onRegistryChanged);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hide standard highlight overlay completely when guided demo is active
    if (GuidedDemoService.instance.isRunning) {
      return const SizedBox.shrink();
    }

    final highlight = SemanticUiRegistry.instance.activeHighlight;
    if (highlight == null) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final rect = highlight.boundingRect;
    final paddedRect = Rect.fromCenter(
      center: rect.center,
      width: rect.width + 16,
      height: rect.height + 16,
    );

    // Decide if tooltip goes above or below
    final showTooltipBelow = rect.bottom < (screenHeight - 160);

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => SemanticUiRegistry.instance.clearHighlight(),
        child: Stack(
          children: [
            // Darkened backdrop with cutout hole around element
            CustomPaint(
              size: Size.infinite,
              painter: _SpotlightHolePainter(cutoutRect: paddedRect),
            ),

            // Pulsing spotlight border
            Positioned(
              left: paddedRect.left,
              top: paddedRect.top,
              width: paddedRect.width,
              height: paddedRect.height,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF76BA1B),
                          width: 3.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF76BA1B).withValues(alpha: 0.5),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Instructional Tooltip Card
            Positioned(
              left: 20,
              right: 20,
              top: showTooltipBelow ? paddedRect.bottom + 14 : null,
              bottom: !showTooltipBelow ? (screenHeight - paddedRect.top) + 14 : null,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3516),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF8BAE68), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.touch_app, color: Color(0xFFC7E898), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              highlight.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => SemanticUiRegistry.instance.clearHighlight(),
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close, color: Colors.white70, size: 18),
                            ),
                          ),
                        ],
                      ),
                      if (highlight.explanation != null && highlight.explanation!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          highlight.explanation!,
                          style: const TextStyle(
                            color: Color(0xFFE2E9D4),
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => SemanticUiRegistry.instance.clearHighlight(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF76BA1B).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF8BAE68),
                                width: 1.0,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, size: 16, color: Color(0xFFC7E898)),
                                SizedBox(width: 4),
                                Text(
                                  'Got it',
                                  style: TextStyle(
                                    color: Color(0xFFC7E898),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightHolePainter extends CustomPainter {
  final Rect cutoutRect;

  _SpotlightHolePainter({required this.cutoutRect});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(cutoutRect, const Radius.circular(16)));

    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, holePath);
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.58)
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, paint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightHolePainter oldDelegate) {
    return oldDelegate.cutoutRect != cutoutRect;
  }
}

