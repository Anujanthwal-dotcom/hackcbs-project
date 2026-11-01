import 'farm_model.dart';
import 'detection_record.dart';

enum NavigationStatus {
  idle,
  calculating,
  navigating,
  arrived,
  failed,
}

/// Represents live navigation progress from current GPS position to a target scan coordinate.
class NavigationProgress {
  final NavigationStatus status;
  final GeoCoordinate currentPosition;
  final GeoCoordinate destination;
  final DetectionRecord? targetScan;
  final List<GeoCoordinate> routeCoordinates;
  final double distanceRemainingMeters;
  final int estimatedSeconds;
  final double bearingDegrees;
  final bool hasArrived;
  final String? statusMessage;
  final bool isFarmLocalRoute;

  const NavigationProgress({
    required this.status,
    required this.currentPosition,
    required this.destination,
    this.targetScan,
    required this.routeCoordinates,
    required this.distanceRemainingMeters,
    required this.estimatedSeconds,
    required this.bearingDegrees,
    required this.hasArrived,
    this.statusMessage,
    this.isFarmLocalRoute = false,
  });

  /// Formatted remaining distance string (e.g., "42 m" or "1.2 km").
  String get formattedDistance {
    if (distanceRemainingMeters < 1000) {
      return '${distanceRemainingMeters.toStringAsFixed(0)} m';
    }
    return '${(distanceRemainingMeters / 1000).toStringAsFixed(2)} km';
  }

  /// Formatted walking ETA string (e.g., "1 min" or "35 sec").
  String get formattedEta {
    if (estimatedSeconds < 60) {
      return '$estimatedSeconds sec';
    }
    final minutes = (estimatedSeconds / 60).ceil();
    return '$minutes min';
  }
}
