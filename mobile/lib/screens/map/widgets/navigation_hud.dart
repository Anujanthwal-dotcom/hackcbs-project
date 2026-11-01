import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/navigation_models.dart';

/// Floating live navigation guidance HUD showing remaining distance, ETA, bearing arrow, and arrival alert.
class NavigationHud extends StatelessWidget {
  final NavigationProgress progress;
  final VoidCallback onStop;

  const NavigationHud({
    super.key,
    required this.progress,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasArrived = progress.hasArrived;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: hasArrived ? const Color(0xFF1B5E20) : const Color(0xFF27421D),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Direction Bearing Compass Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: hasArrived
                      ? const Icon(Icons.check_circle, color: Color(0xFF81C784), size: 28)
                      : Transform.rotate(
                          angle: (progress.bearingDegrees * math.pi / 180.0),
                          child: const Icon(Icons.navigation, color: Colors.white, size: 24),
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Distance & ETA or Arrival State
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasArrived
                          ? 'Arrived at Scan Location!'
                          : progress.formattedDistance,
                      style: TextStyle(
                        color: hasArrived ? const Color(0xFFA5D6A7) : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      hasArrived
                          ? 'Inspect crop / Rescan with Camera'
                          : 'ETA ~${progress.formattedEta} • ${progress.statusMessage ?? "Direct farm path"}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Stop / Done Button
              IconButton(
                icon: Icon(
                  hasArrived ? Icons.check : Icons.close,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: hasArrived ? 'Finish' : 'Stop Navigation',
                onPressed: onStop,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
