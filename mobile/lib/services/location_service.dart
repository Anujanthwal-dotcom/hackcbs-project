import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../config/map_config.dart';
import '../models/farm_model.dart';

enum LocationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
  error,
}

enum LocationQualityLevel {
  high, // <= 5 meters
  acceptable, // <= 25 meters
  poor, // > 25 meters
  unavailable,
}

/// Centralized service for real device GPS tracking and quality evaluation.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static LocationService get instance => _instance;

  StreamSubscription<Position>? _positionSubscription;
  final _positionController = StreamController<GeoCoordinate>.broadcast();

  GeoCoordinate? _lastKnownPosition;
  DateTime? _lastPositionTimestamp;

  /// Stream of real device GPS coordinates with live accuracy.
  Stream<GeoCoordinate> get positionStream => _positionController.stream;

  /// The most recent verified device GPS position.
  GeoCoordinate? get lastKnownPosition => _lastKnownPosition;

  /// Returns the quality classification for a given horizontal accuracy in meters.
  static LocationQualityLevel evaluateQuality(double? accuracyMeters) {
    if (accuracyMeters == null || accuracyMeters <= 0) {
      return LocationQualityLevel.unavailable;
    }
    if (accuracyMeters <= MapConfig.highAccuracyThresholdMeters) {
      return LocationQualityLevel.high;
    }
    if (accuracyMeters <= MapConfig.minAcceptableAccuracyMeters) {
      return LocationQualityLevel.acceptable;
    }
    return LocationQualityLevel.poor;
  }

  /// Checks device location services and requests permissions if necessary.
  Future<({LocationPermissionStatus status, String? message})> checkAndRequestPermission() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (
          status: LocationPermissionStatus.serviceDisabled,
          message: 'Location services are disabled on your device.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return (
            status: LocationPermissionStatus.denied,
            message: 'Location permission was denied. Location is needed to map your farm.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return (
          status: LocationPermissionStatus.permanentlyDenied,
          message: 'Location permission is permanently disabled. Please enable it in Settings.',
        );
      }

      return (status: LocationPermissionStatus.granted, message: null);
    } catch (e) {
      return (
        status: LocationPermissionStatus.error,
        message: 'Error verifying location permissions: $e',
      );
    }
  }

  /// Acquires a fresh high-accuracy position from the device GPS.
  Future<GeoCoordinate?> getCurrentPosition({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final perm = await checkAndRequestPermission();
    if (perm.status != LocationPermissionStatus.granted) {
      return null;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final coord = GeoCoordinate(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      );

      _lastKnownPosition = coord;
      _lastPositionTimestamp = DateTime.now();
      _positionController.add(coord);

      return coord;
    } catch (e) {
      debugPrint('[LocationService] getCurrentPosition warning: $e');
      // Fallback to last known position if within freshness window
      if (_lastKnownPosition != null && _lastPositionTimestamp != null) {
        final age = DateTime.now().difference(_lastPositionTimestamp!).inSeconds;
        if (age <= MapConfig.maxLocationAgeSeconds) {
          return _lastKnownPosition;
        }
      }
      return null;
    }
  }

  /// Maximum accuracy radius accepted from the GPS stream.
  /// Positions with horizontal uncertainty above this value (e.g. indoor spikes
  /// where satellite signal is blocked) are silently discarded. This prevents
  /// the blue dot from jumping wildly while preserving legitimate poor readings.
  static const double _maxAccuracySpikeMeters = 200.0;

  /// Starts continuous live GPS tracking.
  ///
  /// Uses Android Fused Location Provider HIGH_ACCURACY priority via
  /// [LocationAccuracy.high]. The [timeIntervalMs] hint requests fresher fixes
  /// from the provider (default 2 s). [distanceFilterMeters] suppresses
  /// redundant micro-updates when stationary.
  void startTracking({
    int distanceFilterMeters = 2,
    int timeIntervalMs = 2000,
  }) {
    _positionSubscription?.cancel();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        intervalDuration: Duration(milliseconds: timeIntervalMs),
        // forceLocationManager: false uses Fused Location Provider (default)
        forceLocationManager: false,
      ),
    ).listen(
      (Position pos) {
        // Guard: reject GPS spikes with absurdly large accuracy radii.
        // These typically occur indoors when satellite lock is lost momentarily.
        // The displayed accuracy remains the hardware-reported value — we never
        // fabricate a better number; we simply skip the outlier update.
        if (pos.accuracy > _maxAccuracySpikeMeters) {
          debugPrint(
            '[LocationService] Discarding spike: accuracy=${pos.accuracy.toStringAsFixed(0)}m '
            '(threshold=${_maxAccuracySpikeMeters.toStringAsFixed(0)}m)',
          );
          return;
        }

        final coord = GeoCoordinate(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracyMeters: pos.accuracy,
          timestamp: pos.timestamp,
        );
        _lastKnownPosition = coord;
        _lastPositionTimestamp = DateTime.now();
        _positionController.add(coord);
      },
      onError: (err) {
        debugPrint('[LocationService] Stream error: $err');
      },
    );
  }

  /// Stops continuous tracking and cancels subscription.
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void dispose() {
    stopTracking();
    _positionController.close();
  }
}
