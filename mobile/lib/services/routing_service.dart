import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/map_config.dart';
import '../models/farm_model.dart';
import '../models/detection_record.dart';
import '../models/navigation_models.dart';
import 'geometry_service.dart';
import 'location_service.dart';

/// Service responsible for dynamic intra-farm walking navigation, Mapbox Directions,
/// and farm-local direct routing fallbacks.
class RoutingService {
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();

  static RoutingService get instance => _instance;

  StreamSubscription<GeoCoordinate>? _liveNavSubscription;
  final _navProgressController = StreamController<NavigationProgress>.broadcast();

  NavigationProgress? _currentProgress;
  DetectionRecord? _activeDestinationScan;

  /// Stream of active navigation progress updates.
  Stream<NavigationProgress> get progressStream => _navProgressController.stream;

  /// Current navigation progress state.
  NavigationProgress? get currentProgress => _currentProgress;

  /// Starts dynamic navigation from current GPS position to a target scan coordinate.
  Future<NavigationProgress> startNavigation({
    required GeoCoordinate currentPosition,
    required DetectionRecord destinationScan,
  }) async {
    _activeDestinationScan = destinationScan;

    if (destinationScan.latitude == null || destinationScan.longitude == null) {
      final failedProgress = NavigationProgress(
        status: NavigationStatus.failed,
        currentPosition: currentPosition,
        destination: GeoCoordinate(
          latitude: currentPosition.latitude,
          longitude: currentPosition.longitude,
        ),
        targetScan: destinationScan,
        routeCoordinates: const [],
        distanceRemainingMeters: 0,
        estimatedSeconds: 0,
        bearingDegrees: 0,
        hasArrived: false,
        statusMessage: 'Destination scan has no GPS coordinates attached.',
      );
      _currentProgress = failedProgress;
      _navProgressController.add(failedProgress);
      return failedProgress;
    }

    final destCoord = GeoCoordinate(
      latitude: destinationScan.latitude!,
      longitude: destinationScan.longitude!,
    );

    // Initial calculation
    final initialProgress = await _computeRoute(
      origin: currentPosition,
      destination: destCoord,
      targetScan: destinationScan,
    );

    _currentProgress = initialProgress;
    _navProgressController.add(initialProgress);

    // Start live tracking subscription to update navigation in real-time as farmer moves
    _liveNavSubscription?.cancel();
    LocationService.instance.startTracking(distanceFilterMeters: 1);

    _liveNavSubscription = LocationService.instance.positionStream.listen((updatedPos) {
      _handleLivePositionUpdate(updatedPos);
    });

    return initialProgress;
  }

  /// Stops and resets active navigation.
  void stopNavigation() {
    _liveNavSubscription?.cancel();
    _liveNavSubscription = null;
    _activeDestinationScan = null;

    if (_currentProgress != null) {
      final stopped = NavigationProgress(
        status: NavigationStatus.idle,
        currentPosition: _currentProgress!.currentPosition,
        destination: _currentProgress!.destination,
        targetScan: null,
        routeCoordinates: const [],
        distanceRemainingMeters: 0,
        estimatedSeconds: 0,
        bearingDegrees: 0,
        hasArrived: false,
      );
      _currentProgress = stopped;
      _navProgressController.add(stopped);
    }
  }

  /// Handles incoming live GPS position updates during navigation.
  void _handleLivePositionUpdate(GeoCoordinate newPos) {
    if (_activeDestinationScan == null || _currentProgress == null) return;
    if (_currentProgress!.status == NavigationStatus.idle) return;

    final dest = _currentProgress!.destination;
    final double remainingDistance = GeometryService.calculateHaversineDistance(newPos, dest);
    final double bearing = GeometryService.calculateBearing(newPos, dest);
    final int estimatedSeconds = (remainingDistance / MapConfig.averageWalkingSpeedMps).round();

    // Check dynamic arrival
    final bool hasArrived = remainingDistance <= MapConfig.arrivalRadiusMeters;
    final NavigationStatus newStatus = hasArrived ? NavigationStatus.arrived : NavigationStatus.navigating;

    // Update route line: start from new position to destination
    List<GeoCoordinate> updatedRoute = List.from(_currentProgress!.routeCoordinates);
    if (updatedRoute.isNotEmpty) {
      updatedRoute[0] = newPos;
    } else {
      updatedRoute = [newPos, dest];
    }

    final progress = NavigationProgress(
      status: newStatus,
      currentPosition: newPos,
      destination: dest,
      targetScan: _activeDestinationScan,
      routeCoordinates: updatedRoute,
      distanceRemainingMeters: remainingDistance,
      estimatedSeconds: estimatedSeconds,
      bearingDegrees: bearing,
      hasArrived: hasArrived,
      isFarmLocalRoute: _currentProgress!.isFarmLocalRoute,
      statusMessage: hasArrived ? 'Arrived at scan location' : _currentProgress!.statusMessage,
    );

    _currentProgress = progress;
    _navProgressController.add(progress);
  }

  /// Computes walking route using Mapbox Directions with seamless fallback to farm-local routing.
  Future<NavigationProgress> _computeRoute({
    required GeoCoordinate origin,
    required GeoCoordinate destination,
    required DetectionRecord targetScan,
  }) async {
    final double directDistance = GeometryService.calculateHaversineDistance(origin, destination);
    final double bearing = GeometryService.calculateBearing(origin, destination);
    final int estimatedSeconds = (directDistance / MapConfig.averageWalkingSpeedMps).round();

    // Try Mapbox Directions API (walking profile)
    try {
      final token = MapConfig.mapboxAccessToken;
      if (token.isNotEmpty) {
        final url = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/walking/'
          '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}'
          '?geometries=geojson&overview=full&access_token=$token',
        );

        final response = await http.get(url).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final routes = data['routes'] as List<dynamic>?;
          if (routes != null && routes.isNotEmpty) {
            final route = routes.first;
            final double distance = (route['distance'] as num).toDouble();
            final double duration = (route['duration'] as num).toDouble();
            final geometry = route['geometry']['coordinates'] as List<dynamic>;

            final coords = geometry.map((pt) {
              final lon = (pt[0] as num).toDouble();
              final lat = (pt[1] as num).toDouble();
              return GeoCoordinate(latitude: lat, longitude: lon);
            }).toList();

            debugPrint('[RoutingService] Mapbox walking route acquired: ${coords.length} points, $distance meters');

            return NavigationProgress(
              status: NavigationStatus.navigating,
              currentPosition: origin,
              destination: destination,
              targetScan: targetScan,
              routeCoordinates: coords,
              distanceRemainingMeters: distance,
              estimatedSeconds: duration.round(),
              bearingDegrees: bearing,
              hasArrived: distance <= MapConfig.arrivalRadiusMeters,
              isFarmLocalRoute: false,
              statusMessage: 'Navigating via walking path',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[RoutingService] Mapbox routing exception (using farm-local direct fallback): $e');
    }

    // Fallback: Farm-Local Direct Geodesic Route across field
    debugPrint('[RoutingService] Private farm field path — using farm-local direct navigation line');
    return NavigationProgress(
      status: NavigationStatus.navigating,
      currentPosition: origin,
      destination: destination,
      targetScan: targetScan,
      routeCoordinates: [origin, destination],
      distanceRemainingMeters: directDistance,
      estimatedSeconds: estimatedSeconds,
      bearingDegrees: bearing,
      hasArrived: directDistance <= MapConfig.arrivalRadiusMeters,
      isFarmLocalRoute: true,
      statusMessage: 'Farm-local direct field navigation',
    );
  }

  void dispose() {
    _liveNavSubscription?.cancel();
    _navProgressController.close();
  }
}
