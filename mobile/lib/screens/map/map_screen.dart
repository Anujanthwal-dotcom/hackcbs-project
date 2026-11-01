import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../../config/map_config.dart';
import '../../models/detection_record.dart';
import '../../models/farm_model.dart';
import '../../models/field_point_context.dart';
import '../../models/navigation_models.dart';
import '../../models/weather_model.dart';
import '../../services/auth_service.dart';
import '../../services/detection_repository.dart';
import '../../services/farm_repository.dart';
import '../../services/field_assessment_repository.dart';
import '../../services/geometry_service.dart';
import '../../services/language_service.dart';
import '../../services/location_service.dart';
import '../../services/routing_service.dart';
import '../../services/weather_service.dart';
import '../assistant/field_assistant_screen.dart';
import 'widgets/farm_list_sheet.dart';
import 'widgets/farm_marker_sheet.dart';
import 'widgets/navigation_hud.dart';
import '../../services/global_context_engine.dart';
import '../../services/semantic_ui_registry.dart';

enum MapInteractionMode {
  normal,
  markingFarm,
  navigating,
}

/// Controls whether the map camera automatically follows the blue GPS dot.
///
/// [followLocation] — camera tracks GPS updates in real time.
/// [selectedFarm]  — camera stays on the farm the user chose; GPS updates
///                   do NOT move the camera.
/// [manual]        — user has panned/zoomed freely; automatic follow is off.
enum _CameraMode { followLocation, selectedFarm, manual }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PolygonAnnotationManager? _polygonManager;
  mapbox.PolylineAnnotationManager? _polylineManager;
  mapbox.CircleAnnotationManager? _circleManager;
  mapbox.PointAnnotationManager? _pointManager;

  MapInteractionMode _interactionMode = MapInteractionMode.normal;

  /// Camera-follow state machine.
  ///
  /// Default: [_CameraMode.followLocation] so the map opens on the blue dot.
  /// Changes to [_CameraMode.selectedFarm] when a farm is chosen.
  /// Changes to [_CameraMode.manual] when the user pans the map.
  _CameraMode _cameraMode = _CameraMode.followLocation;

  LocationQualityLevel _locationQuality = LocationQualityLevel.unavailable;
  GeoCoordinate? _currentLocation;
  bool _isInsideFarm = false;

  // Farm state
  List<FarmModel> _userFarms = [];
  FarmModel? _activeFarm;
  StreamSubscription<List<FarmModel>>? _farmsSubscription;

  // Realtime Detections
  List<DetectionRecord> _detections = [];
  StreamSubscription<List<DetectionRecord>>? _detectionsSubscription;

  // Farm Creation (polygon marking) State
  final List<GeoCoordinate> _markingPoints = [];
  String? _markingValidationError;

  // Active Navigation State
  NavigationProgress? _navProgress;
  StreamSubscription<NavigationProgress>? _navSubscription;
  StreamSubscription<GeoCoordinate>? _locationStreamSubscription;

  bool _isSatellite = true;

  @override
  void initState() {
    super.initState();
    mapbox.MapboxOptions.setAccessToken(MapConfig.mapboxAccessToken);
    _initializeLocationAndStreams();
  }

  @override
  void dispose() {
    _locationStreamSubscription?.cancel();
    _farmsSubscription?.cancel();
    _detectionsSubscription?.cancel();
    _navSubscription?.cancel();
    RoutingService.instance.stopNavigation();
    super.dispose();
  }

  // ── Initialization ──────────────────────────────────────────────────────────

  void _initializeLocationAndStreams() async {
    // 1. Acquire initial GPS fix → center map on blue dot immediately.
    //    This runs before the Firestore farm stream emits, so the first camera
    //    position is always the user's current location (not an old farm).
    final pos = await LocationService.instance.getCurrentPosition();
    if (mounted && pos != null) {
      setState(() {
        _currentLocation = pos;
        _locationQuality = LocationService.evaluateQuality(pos.accuracyMeters);
      });
      // Only move camera if we are still in follow-location mode (default on open)
      if (_cameraMode == _CameraMode.followLocation) {
        _moveCameraTo(pos.latitude, pos.longitude, zoom: MapConfig.defaultZoom);
      }
    }

    // 2. Continuous GPS stream.
    LocationService.instance.startTracking(distanceFilterMeters: 2);
    _locationStreamSubscription =
        LocationService.instance.positionStream.listen((newPos) {
      if (!mounted) return;
      final insideFarm = _activeFarm != null &&
          _activeFarm!.boundary.length >= 3 &&
          GeometryService.isPointInsidePolygon(newPos, _activeFarm!.boundary);
      setState(() {
        _currentLocation = newPos;
        _locationQuality = LocationService.evaluateQuality(newPos.accuracyMeters);
        _isInsideFarm = insideFarm;
      });

      // Follow the blue dot only when camera is in follow-location mode.
      // If the user selected a farm or is panning manually, do NOT override.
      if (_cameraMode == _CameraMode.followLocation && _mapboxMap != null) {
        _moveCameraTo(newPos.latitude, newPos.longitude);
      }

      _renderMapLayers();
    });

    // 3. Firestore farms stream.
    //    IMPORTANT: Do NOT call _fitCameraToFarm here. The camera starts on the
    //    blue dot (_CameraMode.followLocation). Farm data updates UI state only.
    final uid = AuthService.instance.currentUid;
    if (uid != null) {
      _farmsSubscription =
          FarmRepository.instance.streamUserFarms(uid).listen((farms) {
        if (!mounted) return;
        setState(() {
          _userFarms = farms;
          // Keep the previously selected farm if it still exists.
          // If it was deleted, fall through to null (no farm selected).
          if (_activeFarm != null) {
            final stillExists = farms.any((f) => f.id == _activeFarm!.id);
            if (!stillExists) _activeFarm = null;
          }
          // Do NOT auto-select a farm or move the camera. The user controls this.
        });
        _renderMapLayers();
        // NOTE: intentionally removed _fitCameraToFarm() that was previously
        // called unconditionally here — that was the root cause of Problem 1.
      });

      // 4. Disease scan detections stream.
      _detectionsSubscription =
          DetectionRepository.instance.streamUserDetections(uid).listen((scans) {
        if (!mounted) return;
        debugPrint(
            '[MAP] FIRESTORE SNAPSHOT RECEIVED: totalDetections=${scans.length}');
        setState(() {
          _detections = scans.where((s) => s.hasLocation).toList();
        });
        _renderMapLayers();
      }, onError: (e) {
        debugPrint('[MAP] Detections stream error: $e');
      });
    }

    // 5. Navigation progress stream.
    _navSubscription =
        RoutingService.instance.progressStream.listen((progress) {
      if (!mounted) return;
      setState(() {
        _navProgress = progress;
        if (progress.status == NavigationStatus.idle ||
            progress.status == NavigationStatus.failed) {
          _interactionMode = MapInteractionMode.normal;
        } else if (progress.status == NavigationStatus.navigating ||
            progress.status == NavigationStatus.arrived) {
          _interactionMode = MapInteractionMode.navigating;
        }
      });
      _renderMapLayers();
    });
  }

  // ── Map lifecycle ───────────────────────────────────────────────────────────

  void _onMapCreated(mapbox.MapboxMap controller) async {
    _mapboxMap = controller;

    _polygonManager =
        await controller.annotations.createPolygonAnnotationManager();
    _polylineManager =
        await controller.annotations.createPolylineAnnotationManager();
    _circleManager =
        await controller.annotations.createCircleAnnotationManager();
    _pointManager =
        await controller.annotations.createPointAnnotationManager();

    // Enable the blue current-location puck.
    // puckBearingEnabled: false — stops FlutterCompass from continuously
    // polling the magnetometer, which spams logcat on uncalibrated devices.
    await controller.location.updateSettings(
      mapbox.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: const Color(0xFF2196F3).toARGB32(),
        puckBearingEnabled: false,
        locationPuck: mapbox.LocationPuck(
          locationPuck2D: mapbox.DefaultLocationPuck2D(),
        ),
      ),
    );

    _renderMapLayers();

    // If GPS was already acquired before the map widget was ready, center now.
    if (_currentLocation != null && _cameraMode == _CameraMode.followLocation) {
      _moveCameraTo(_currentLocation!.latitude, _currentLocation!.longitude);
    }
  }

  // ── Camera helpers ──────────────────────────────────────────────────────────

  void _moveCameraTo(double lat, double lng, {double zoom = 17.0}) {
    _mapboxMap?.setCamera(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
        zoom: zoom,
      ),
    );
  }

  void _fitCameraToFarm(FarmModel farm) {
    if (_mapboxMap == null) return;

    if (farm.boundary.length <= 1) {
      // Pin-type farm: just centre on the pin coordinate.
      _moveCameraTo(farm.center.latitude, farm.center.longitude,
          zoom: MapConfig.defaultZoom);
      return;
    }

    final bbox = GeometryService.calculateBoundingBox(farm.boundary);
    final centerLat = (bbox.minLat + bbox.maxLat) / 2.0;
    final centerLng = (bbox.minLng + bbox.maxLng) / 2.0;

    _mapboxMap?.setCamera(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(centerLng, centerLat)),
        zoom: 16.5,
      ),
    );
  }

  /// Called when the user manually pans the map. Switches to manual mode so
  /// the camera stops following the GPS dot.
  void _onMapScrolled() {
    if (_cameraMode == _CameraMode.followLocation) {
      setState(() => _cameraMode = _CameraMode.manual);
    }
  }

  /// Recentres the map on the blue GPS dot and restores follow-location mode.
  Future<void> _recenterOnLocation() async {
    GeoCoordinate? pos = _currentLocation;
    pos ??= await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _cameraMode = _CameraMode.followLocation);
      _moveCameraTo(pos.latitude, pos.longitude, zoom: MapConfig.defaultZoom);
    }
  }

  /// Selects a farm, centres the camera on it, and switches to selectedFarm mode.
  void _selectFarm(FarmModel farm) {
    setState(() {
      _activeFarm = farm;
      _cameraMode = _CameraMode.selectedFarm;
    });
    GlobalContextEngine.instance.setSelectedFarm(farm);
    _fitCameraToFarm(farm);
    _renderMapLayers();
  }

  void _showRenameFarmDialog(FarmModel farm) {
    final controller = TextEditingController(text: farm.name);
    final isHindi = LanguageService.instance.isHindi;
    GlobalContextEngine.instance.setModalState('Rename Farm Dialog');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E14),
        title: Text(
          isHindi ? 'खेत का नाम बदलें' : 'Rename Farm',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: isHindi ? 'नया नाम दर्ज करें' : 'Enter new farm name',
            hintStyle: const TextStyle(color: Colors.white54),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF81C784))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4CAF50), width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              GlobalContextEngine.instance.setModalState(null);
            },
            child: Text(isHindi ? 'रद्द करें' : 'Cancel', style: const TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                GlobalContextEngine.instance.setModalState(null);
                final updated = FarmModel(
                  id: farm.id,
                  userId: farm.userId,
                  name: newName,
                  boundary: farm.boundary,
                  center: farm.center,
                  areaSquareMeters: farm.areaSquareMeters,
                  cropType: farm.cropType,
                  createdAt: farm.createdAt,
                  updatedAt: DateTime.now(),
                );
                await FarmRepository.instance.saveFarm(updated);
                _selectFarm(updated);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
            child: Text(isHindi ? 'सहेजें' : 'Save'),
          ),
        ],
      ),
    );
  }

  // ── Tap handling ────────────────────────────────────────────────────────────

  void _handleMapTap(double lat, double lng) {
    if (_interactionMode == MapInteractionMode.markingFarm) {
      final newPoint = GeoCoordinate(latitude: lat, longitude: lng);
      setState(() {
        _markingPoints.add(newPoint);
        final validation = GeometryService.validateFarmPolygon(_markingPoints);
        _markingValidationError =
            _markingPoints.length >= 3 ? validation.errorMessage : null;
      });
      _renderMapLayers();
      return;
    }

    if (_interactionMode == MapInteractionMode.normal) {
      // Any tap while in normal mode counts as manual interaction.
      if (_cameraMode == _CameraMode.followLocation) {
        setState(() => _cameraMode = _CameraMode.manual);
      }

      // Check if tapped near a disease marker.
      final tapCoord = GeoCoordinate(latitude: lat, longitude: lng);
      DetectionRecord? closestScan;
      double minDistance = double.infinity;

      for (final scan in _filteredDetections) {
        if (scan.latitude != null && scan.longitude != null) {
          final scanCoord =
              GeoCoordinate(latitude: scan.latitude!, longitude: scan.longitude!);
          final dist =
              GeometryService.calculateHaversineDistance(tapCoord, scanCoord);
          if (dist < 35.0 && dist < minDistance) {
            minDistance = dist;
            closestScan = scan;
          }
        }
      }

      if (closestScan != null) {
        _showScanDetailsModal(closestScan);
      }
    }
  }

  // ── Map layer rendering ─────────────────────────────────────────────────────

  /// Re-renders all dynamic visual overlays.
  ///
  /// Renders ALL farms in [_userFarms]:
  /// - Active/selected farm: solid green polygon + bright green border.
  /// - Other farms: blue-tinted polygon (15% opacity) + dashed blue border.
  /// - Each farm centre: labelled circle marker for quick identification.
  void _renderMapLayers() async {
    if (_mapboxMap == null) return;

    try {
      await _polygonManager?.deleteAll();
      await _polylineManager?.deleteAll();
      await _circleManager?.deleteAll();
      await _pointManager?.deleteAll();

      // 1. Render all farm boundaries (non-active farms in subtle blue style).
      //    ALWAYS renders existing farms — even while the user is drawing a new
      //    farm boundary — so previously saved farms never disappear from the map.
      for (final farm in _userFarms) {
        final isActive = farm.id == _activeFarm?.id;

        if (farm.boundary.length >= 3) {
          final polygonCoords = farm.boundary
              .map((p) => mapbox.Position(p.longitude, p.latitude))
              .toList();
          polygonCoords.add(mapbox.Position(
              farm.boundary.first.longitude, farm.boundary.first.latitude));

          await _polygonManager?.create(
            mapbox.PolygonAnnotationOptions(
              geometry: mapbox.Polygon(coordinates: [polygonCoords]),
              fillColor: isActive
                  ? Colors.green.withValues(alpha: 0.25).toARGB32()
                  : const Color(0xFF2196F3).withValues(alpha: 0.12).toARGB32(),
              fillOutlineColor: isActive
                  ? const Color(0xFF2E7D32).toARGB32()
                  : const Color(0xFF1565C0).toARGB32(),
            ),
          );

          final lineCoords = farm.boundary
              .map((p) => mapbox.Position(p.longitude, p.latitude))
              .toList();
          lineCoords.add(mapbox.Position(
              farm.boundary.first.longitude, farm.boundary.first.latitude));
          await _polylineManager?.create(
            mapbox.PolylineAnnotationOptions(
              geometry: mapbox.LineString(coordinates: lineCoords),
              lineColor: isActive
                  ? const Color(0xFF4CAF50).toARGB32()
                  : const Color(0xFF42A5F5).toARGB32(),
              lineWidth: isActive ? 3.5 : 2.0,
            ),
          );
        }

        // Farm centre marker (circle + name label) — shown for all farms,
        // including pin-type farms (boundary.length <= 1).
        // Rendered even during markingFarm mode so existing farm pins remain visible.
        await _circleManager?.create(
          mapbox.CircleAnnotationOptions(
            geometry: mapbox.Point(
              coordinates:
                  mapbox.Position(farm.center.longitude, farm.center.latitude),
            ),
            circleColor: isActive
                ? const Color(0xFF4CAF50).toARGB32()
                : const Color(0xFF42A5F5).toARGB32(),
            circleRadius: isActive ? 8.0 : 6.0,
            circleStrokeWidth: 2.0,
            circleStrokeColor: Colors.white.toARGB32(),
          ),
        );

        await _pointManager?.create(
          mapbox.PointAnnotationOptions(
            geometry: mapbox.Point(
              coordinates:
                  mapbox.Position(farm.center.longitude, farm.center.latitude),
            ),
            textField: farm.name,
            textColor: Colors.white.toARGB32(),
            textSize: isActive ? 12.0 : 10.0,
            textOffset: [0.0, 1.6],
            textHaloColor: Colors.black.toARGB32(),
            textHaloWidth: 1.5,
          ),
        );
      }

      // 2. In-progress polygon marking overlay.
      if (_interactionMode == MapInteractionMode.markingFarm &&
          _markingPoints.isNotEmpty) {
        final markLineCoords = _markingPoints
            .map((p) => mapbox.Position(p.longitude, p.latitude))
            .toList();

        if (_markingPoints.length >= 2) {
          await _polylineManager?.create(
            mapbox.PolylineAnnotationOptions(
              geometry: mapbox.LineString(coordinates: markLineCoords),
              lineColor: const Color(0xFFFF9800).toARGB32(),
              lineWidth: 3.0,
            ),
          );
        }

        if (_markingPoints.length >= 3) {
          final markPolygonCoords = List<mapbox.Position>.from(markLineCoords);
          markPolygonCoords.add(mapbox.Position(
              _markingPoints.first.longitude, _markingPoints.first.latitude));
          await _polygonManager?.create(
            mapbox.PolygonAnnotationOptions(
              geometry: mapbox.Polygon(coordinates: [markPolygonCoords]),
              fillColor: Colors.orange.withValues(alpha: 0.2).toARGB32(),
              fillOutlineColor: Colors.orange.toARGB32(),
            ),
          );
        }
      }

      // 3. Navigation route.
      if (_interactionMode == MapInteractionMode.navigating &&
          _navProgress != null &&
          _navProgress!.routeCoordinates.isNotEmpty) {
        final routeCoords = _navProgress!.routeCoordinates
            .map((c) => mapbox.Position(c.longitude, c.latitude))
            .toList();

        await _polylineManager?.create(
          mapbox.PolylineAnnotationOptions(
            geometry: mapbox.LineString(coordinates: routeCoords),
            lineColor: const Color(0xFF2196F3).toARGB32(),
            lineWidth: 5.0,
          ),
        );
      }

      // 4. Disease scan markers.
      if (_interactionMode == MapInteractionMode.normal) {
        final listToRender = _filteredDetections;
        debugPrint('[MAP] Rendering ${listToRender.length} disease markers on map');
        for (final scan in listToRender) {
          if (scan.latitude != null && scan.longitude != null) {
            debugPrint(
                '[MAP] MARKER:\n  creating marker\n  latitude=${scan.latitude}\n  longitude=${scan.longitude}');
            await _circleManager?.create(
              mapbox.CircleAnnotationOptions(
                geometry: mapbox.Point(
                  coordinates:
                      mapbox.Position(scan.longitude!, scan.latitude!),
                ),
                circleColor: scan.statusColor.toARGB32(),
                circleRadius: 10.0,
                circleStrokeWidth: 2.5,
                circleStrokeColor: Colors.white.toARGB32(),
              ),
            );

            await _pointManager?.create(
              mapbox.PointAnnotationOptions(
                geometry: mapbox.Point(
                  coordinates:
                      mapbox.Position(scan.longitude!, scan.latitude!),
                ),
                textField: scan.crop,
                textColor: Colors.white.toARGB32(),
                textSize: 11.0,
                textOffset: [0.0, 1.3],
                textHaloColor: Colors.black.toARGB32(),
                textHaloWidth: 1.0,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[MAP] Render annotations error: $e');
    }
  }

  // ── Filtered detections ─────────────────────────────────────────────────────

  List<DetectionRecord> get _filteredDetections {
    final withLoc = _detections.where((s) => s.hasLocation).toList();
    if (_activeFarm == null) return withLoc;
    return withLoc
        .where((s) =>
            s.farmId == _activeFarm!.id ||
            (_activeFarm!.boundary.length >= 3 &&
                s.latitude != null &&
                s.longitude != null &&
                GeometryService.isPointInsidePolygon(
                  GeoCoordinate(latitude: s.latitude!, longitude: s.longitude!),
                  _activeFarm!.boundary,
                )))
        .toList();
  }

  // ── Farm creation ───────────────────────────────────────────────────────────

  void _startMarkingFarm() {
    setState(() {
      _interactionMode = MapInteractionMode.markingFarm;
      _markingPoints.clear();
      _markingValidationError = null;
    });
    _renderMapLayers();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Tap on the map around your field to drop boundary corner points.'),
        backgroundColor: Color(0xFF27421D),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _undoLastMarkingPoint() {
    if (_markingPoints.isEmpty) return;
    setState(() {
      _markingPoints.removeLast();
      final validation = GeometryService.validateFarmPolygon(_markingPoints);
      _markingValidationError =
          _markingPoints.length >= 3 ? validation.errorMessage : null;
    });
    _renderMapLayers();
  }

  void _cancelMarkingFarm() {
    setState(() {
      _interactionMode = MapInteractionMode.normal;
      _markingPoints.clear();
      _markingValidationError = null;
    });
    _renderMapLayers();
  }

  Future<void> _saveFarmBoundary() async {
    final validation = GeometryService.validateFarmPolygon(_markingPoints);
    if (!validation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation.errorMessage ?? 'Invalid farm boundary.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final uid = AuthService.instance.currentUid;
    if (uid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please log in to save your farm.')));
      return;
    }

    final nameController =
        TextEditingController(text: 'Farm ${_userFarms.length + 1}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Farm Boundary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Area: ${(GeometryService.calculateGeodesicPolygonArea(_markingPoints) / 10000.0).toStringAsFixed(2)} ha '
              '(${_markingPoints.length} corner points)',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF27421D)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Farm / Plot Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF27421D)),
            child: const Text('Save Farm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final area = GeometryService.calculateGeodesicPolygonArea(_markingPoints);
    final centroid = GeometryService.calculateCentroid(_markingPoints);
    final now = DateTime.now();

    final newFarm = FarmModel(
      id: '',
      userId: uid,
      name: nameController.text.trim().isEmpty
          ? 'My Farm'
          : nameController.text.trim(),
      boundary: List.from(_markingPoints),
      center: centroid,
      areaSquareMeters: area,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final savedId = await FarmRepository.instance.saveFarm(newFarm);
      final savedFarm = FarmModel(
        id: savedId,
        userId: uid,
        name: newFarm.name,
        boundary: newFarm.boundary,
        center: newFarm.center,
        areaSquareMeters: newFarm.areaSquareMeters,
        createdAt: now,
        updatedAt: now,
      );
      setState(() {
        _activeFarm = savedFarm;
        _userFarms = [..._userFarms.where((f) => f.id != savedId), savedFarm];
        _cameraMode = _CameraMode.selectedFarm;
        _interactionMode = MapInteractionMode.normal;
        _markingPoints.clear();
      });
      _renderMapLayers();
      _fitCameraToFarm(savedFarm);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Farm "${newFarm.name}" saved successfully!'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save farm: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Quick-add farm: saves the current GPS position as a named pin farm.
  ///
  /// No polygon drawing required — satisfies pitch MVP:
  /// ADD FARM → NAME FARM → SAVE LOCATION → SHOW MARKER
  Future<void> _addFarmAtCurrentLocation() async {
    final pos = _currentLocation ??
        await LocationService.instance.getCurrentPosition();

    if (pos == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS position not yet available. Please wait a moment.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final uid = AuthService.instance.currentUid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to save a farm.')));
      }
      return;
    }

    if (!mounted) return;
    final nameController =
        TextEditingController(text: 'Farm ${_userFarms.length + 1}');
    final isHindi = LanguageService.instance.isHindi;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E14),
        title: Text(
          isHindi ? 'खेत जोड़ें' : 'Add Farm',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gps_fixed, color: Color(0xFF81C784), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'
                    '${pos.accuracyMeters != null ? ' (±${pos.accuracyMeters!.toStringAsFixed(0)}m)' : ''}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: isHindi ? 'खेत का नाम' : 'Farm Name',
                labelStyle: const TextStyle(color: Colors.white54),
                enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF81C784))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isHindi ? 'रद्द करें' : 'Cancel',
                style: const TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
            child:
                Text(isHindi ? 'सेव करें' : 'Save Farm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final now = DateTime.now();
    final newFarm = FarmModel(
      id: '',
      userId: uid,
      name: nameController.text.trim().isEmpty
          ? 'Farm ${_userFarms.length + 1}'
          : nameController.text.trim(),
      boundary: [pos], // Single-point pin farm
      center: pos,
      areaSquareMeters: 0.0,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final savedId = await FarmRepository.instance.saveFarm(newFarm);
      final savedFarm = FarmModel(
        id: savedId,
        userId: uid,
        name: newFarm.name,
        boundary: newFarm.boundary,
        center: newFarm.center,
        areaSquareMeters: 0.0,
        createdAt: now,
        updatedAt: now,
      );
      setState(() {
        _activeFarm = savedFarm;
        _userFarms = [..._userFarms.where((f) => f.id != savedId), savedFarm];
        _cameraMode = _CameraMode.selectedFarm;
      });
      _renderMapLayers();
      _moveCameraTo(pos.latitude, pos.longitude, zoom: MapConfig.defaultZoom);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${savedFarm.name}" saved at your current location!'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save farm: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteFarm(FarmModel farm) async {
    final uid = AuthService.instance.currentUid;
    if (uid == null) return;

    try {
      await FarmRepository.instance.deleteFarm(uid, farm.id);
      setState(() {
        _userFarms = _userFarms.where((f) => f.id != farm.id).toList();
        if (_activeFarm?.id == farm.id) {
          _activeFarm = _userFarms.isNotEmpty ? _userFarms.first : null;
        }
      });
      _renderMapLayers();
      if (_activeFarm != null) {
        _fitCameraToFarm(_activeFarm!);
      } else {
        _recenterOnLocation();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Farm "${farm.name}" deleted.'),
            backgroundColor: const Color(0xFF27421D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete farm: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Scan / navigation helpers ───────────────────────────────────────────────

  void _showScanDetailsModal(DetectionRecord scan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => FarmMarkerSheet(
        scan: scan,
        currentLocation: _currentLocation,
        onNavigate: () {
          Navigator.pop(ctx);
          _startNavigatingToScan(scan);
        },
        onAskAssistant: (attachedImages) async {
          Navigator.pop(ctx);
          await _openFieldAssistant(scan, attachedImages: attachedImages);
        },
        onDelete: () => _deleteDetection(scan),
      ),
    );
  }

  Future<void> _deleteDetection(DetectionRecord scan) async {
    final uid = AuthService.instance.currentUid;
    if (uid == null) return;

    try {
      await DetectionRepository.instance.deleteDetection(uid, scan.id);
      setState(() {
        _detections = _detections.where((d) => d.id != scan.id).toList();
      });
      _renderMapLayers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Detection point "${scan.displayTitle}" deleted.'),
            backgroundColor: const Color(0xFF27421D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete detection point: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openFieldAssistant(DetectionRecord scan,
      {List<File>? attachedImages}) async {
    final uid = AuthService.instance.currentUid;
    if (uid == null) return;

    final previousAssessments = await FieldAssessmentRepository.instance
        .fetchAssessments(uid, scan.id, limit: 5);

    WeatherData? weather;
    try {
      final lat = scan.latitude ?? _activeFarm?.center.latitude;
      final lng = scan.longitude ?? _activeFarm?.center.longitude;
      if (lat != null && lng != null) {
        weather = await WeatherService.instance.getWeather(lat, lng);
      }
    } catch (_) {}

    final context = FieldPointContext.fromRecord(
      record: scan,
      assessments: previousAssessments,
      userId: uid,
      weather: weather,
    );

    if (!mounted) return;
    await Navigator.push(
      this.context,
      MaterialPageRoute(
        builder: (_) => FieldAssistantScreen(
          fieldContext: context,
          initialImages: attachedImages,
        ),
      ),
    );
  }

  void _startNavigatingToScan(DetectionRecord scan) async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acquiring your current GPS position...')));
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Cannot navigate: GPS position unavailable.'),
                backgroundColor: Colors.red),
          );
        }
        return;
      }
      _currentLocation = pos;
    }

    final progress = await RoutingService.instance.startNavigation(
      currentPosition: _currentLocation!,
      destinationScan: scan,
    );

    setState(() {
      _navProgress = progress;
      _interactionMode = MapInteractionMode.navigating;
    });

    _renderMapLayers();

    if (scan.latitude != null && scan.longitude != null) {
      final midLat = (_currentLocation!.latitude + scan.latitude!) / 2.0;
      final midLng = (_currentLocation!.longitude + scan.longitude!) / 2.0;
      _moveCameraTo(midLat, midLng, zoom: 18.0);
    }
  }

  void _stopNavigation() {
    RoutingService.instance.stopNavigation();
    setState(() {
      _interactionMode = MapInteractionMode.normal;
      _navProgress = null;
    });
    _renderMapLayers();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isHindi = LanguageService.instance.isHindi;

    return Scaffold(
      backgroundColor: const Color(0xFF27421D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF27421D),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _interactionMode == MapInteractionMode.markingFarm
              ? (isHindi ? 'खेत की सीमा तय करें' : 'Mark Farm Boundary')
              : (_interactionMode == MapInteractionMode.navigating
                  ? (isHindi ? 'खेत में मार्गदर्शन' : 'Navigating Field')
                  : l10n.mapTitle),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          // Toggle satellite/outdoors style
          IconButton(
            icon: Icon(
              _isSatellite ? Icons.satellite_alt : Icons.map_outlined,
              color: Colors.white,
            ),
            tooltip: _isSatellite
                ? (isHindi ? 'मानचित्र दृश्य' : 'Outdoors Map')
                : (isHindi ? 'सैटेलाइट दृश्य' : 'Satellite View'),
            onPressed: () {
              setState(() => _isSatellite = !_isSatellite);
              _mapboxMap?.loadStyleURI(
                _isSatellite
                    ? MapConfig.satelliteStyleUri
                    : MapConfig.outdoorsStyleUri,
              );
            },
          ),
          // My Location — recenter on blue dot, restore follow mode
          IconButton(
            icon: Icon(
              _cameraMode == _CameraMode.followLocation
                  ? Icons.my_location
                  : Icons.location_searching,
              color: _cameraMode == _CameraMode.followLocation
                  ? const Color(0xFF64B5F6)
                  : Colors.white,
            ),
            tooltip: l10n.currentLocation,
            onPressed: _recenterOnLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── 1. Mapbox Map ─────────────────────────────────────────────────
          mapbox.MapWidget(
            key: const ValueKey('farm_mapbox_widget'),
            styleUri: _isSatellite
                ? MapConfig.satelliteStyleUri
                : MapConfig.outdoorsStyleUri,
            onMapCreated: _onMapCreated,
            // ignore: deprecated_member_use
            onTapListener: (context) {
              _handleMapTap(
                context.point.coordinates.lat.toDouble(),
                context.point.coordinates.lng.toDouble(),
              );
            },
            // Detect manual panning to switch off follow-location mode.
            // ignore: deprecated_member_use
            onScrollListener: (_) => _onMapScrolled(),
          ),

          // ── 2. Navigation HUD ─────────────────────────────────────────────
          if (_interactionMode == MapInteractionMode.navigating &&
              _navProgress != null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: NavigationHud(
                progress: _navProgress!,
                onStop: _stopNavigation,
              ),
            ),

          // ── 3. Farm Marking Header ────────────────────────────────────────
          if (_interactionMode == MapInteractionMode.markingFarm)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _buildFarmMarkingHeader(),
            ),

          // ── 4. GPS + Farm Badge ───────────────────────────────────────────
          if (_interactionMode == MapInteractionMode.normal)
            Positioned(
              top: 12,
              left: 16,
              child: _buildGpsAndFarmBadge(l10n, isHindi),
            ),

          // ── 5. Normal Bottom Bar ──────────────────────────────────────────
          if (_interactionMode == MapInteractionMode.normal)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _buildNormalBottomBar(l10n, isHindi),
            ),

          // ── 6. Farm Marking Bottom Bar ────────────────────────────────────
          if (_interactionMode == MapInteractionMode.markingFarm)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _buildFarmMarkingBottomBar(l10n),
            ),

          // ── 7. Manual mode indicator — show when camera is NOT following ──
          if (_interactionMode == MapInteractionMode.normal &&
              _cameraMode == _CameraMode.manual)
            Positioned(
              bottom: 108,
              right: 20,
              child: FloatingActionButton.small(
                heroTag: 'recenter_fab',
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF27421D),
                tooltip: isHindi ? 'वर्तमान स्थान पर वापस जाएं' : 'Back to my location',
                onPressed: _recenterOnLocation,
                child: const Icon(Icons.my_location, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  // ── UI Widgets ──────────────────────────────────────────────────────────────

  Widget _buildGpsAndFarmBadge(AppLocalizations l10n, bool isHindi) {
    Color badgeColor = Colors.grey;
    String statusText = isHindi ? 'जीपीएस खोजा जा रहा है' : 'Acquiring GPS';

    switch (_locationQuality) {
      case LocationQualityLevel.high:
        badgeColor = const Color(0xFF4CAF50);
        statusText =
            '${l10n.gpsHigh} (±${_currentLocation?.accuracyMeters?.toStringAsFixed(1) ?? "0"}m)';
        break;
      case LocationQualityLevel.acceptable:
        badgeColor = const Color(0xFFFF9800);
        statusText =
            '${l10n.gpsMedium} (±${_currentLocation?.accuracyMeters?.toStringAsFixed(1) ?? "0"}m)';
        break;
      case LocationQualityLevel.poor:
        badgeColor = const Color(0xFFF44336);
        statusText =
            '${l10n.gpsLow} (±${_currentLocation?.accuracyMeters?.toStringAsFixed(0) ?? "0"}m)';
        break;
      case LocationQualityLevel.unavailable:
        badgeColor = Colors.grey;
        statusText = l10n.gpsUnavailable;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // GPS Accuracy Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: badgeColor, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 4, backgroundColor: badgeColor),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Active Farm Badge
        if (_activeFarm != null)
          GestureDetector(
            onTap: () => _showFarmList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF27421D).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.agriculture,
                      color: Color(0xFF81C784), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _activeFarm!.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _isInsideFarm
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.85)
                          : const Color(0xFFFF9800).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isInsideFarm ? l10n.insideFarm : l10n.outsideFarm,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showFarmList() {
    FarmListSheet.show(
      context: context,
      farms: _userFarms,
      activeFarm: _activeFarm,
      onFarmSelected: _selectFarm,
      onFarmDeleted: _deleteFarm,
    );
  }

  Widget _buildNormalBottomBar(AppLocalizations l10n, bool isHindi) {
    final farmCount = _userFarms.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5EA),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Farm Info & Quick Action Icons
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: farmCount > 0 ? _showFarmList : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27421D).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.agriculture, color: Color(0xFF27421D), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _activeFarm != null
                                        ? _activeFarm!.name
                                        : (isHindi ? 'कोई खेत नहीं चुना' : 'No Farm Saved'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF27421D),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (farmCount > 1) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF27421D),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$farmCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '${_filteredDetections.length} ${l10n.geotaggedScans}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_activeFarm != null) ...[
                AgentUiElement(
                  id: 'rename_farm',
                  label: 'Rename Farm',
                  description: 'Opens a dialog to rename the currently selected farm',
                  screen: 'Map',
                  onTrigger: () => _showRenameFarmDialog(_activeFarm!),
                  child: IconButton.filledTonal(
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.edit_note, size: 18),
                    tooltip: isHindi ? 'खेत का नाम बदलें' : 'Rename Farm',
                    onPressed: () => _showRenameFarmDialog(_activeFarm!),
                  ),
                ),
                const SizedBox(width: 4),
                AgentUiElement(
                  id: 'map_fit_farm',
                  label: 'Focus Farm',
                  description: 'Centers and fits the active farm boundary on the map',
                  screen: 'Map',
                  onTrigger: () => _selectFarm(_activeFarm!),
                  child: IconButton.filledTonal(
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.crop_free, size: 18),
                    tooltip: isHindi ? 'खेत पर केंद्रित करें' : 'Fit Farm',
                    onPressed: () => _selectFarm(_activeFarm!),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (farmCount > 0)
                AgentUiElement(
                  id: 'map_my_farms',
                  label: 'My Farms',
                  description: 'Opens the list of all your saved farms to select or manage them',
                  screen: 'Map',
                  onTrigger: _showFarmList,
                  child: IconButton.filledTonal(
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.layers_outlined, size: 18),
                    tooltip: isHindi ? 'मेरे खेत' : 'My Farms',
                    onPressed: _showFarmList,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2: Action Buttons
          Row(
            children: [
              // Add Pin Farm Button
              Expanded(
                child: AgentUiElement(
                  id: 'add_pin_farm',
                  label: 'Add Pin Farm',
                  description: 'Saves a new farm marker at your current GPS location',
                  screen: 'Map',
                  onTrigger: _addFarmAtCurrentLocation,
                  child: OutlinedButton.icon(
                    onPressed: _addFarmAtCurrentLocation,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF27421D),
                      side: const BorderSide(color: Color(0xFF27421D), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                    label: Text(
                      isHindi ? 'यहाँ जोड़ें' : 'Add Pin',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Mark / Edit Boundary Button
              Expanded(
                child: AgentUiElement(
                  id: 'mark_farm_boundary',
                  label: 'Mark Farm Boundary',
                  description: 'Draws or edits the polygon boundary points of your field',
                  screen: 'Map',
                  onTrigger: _startMarkingFarm,
                  child: FilledButton.icon(
                    onPressed: _startMarkingFarm,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF27421D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(
                      _activeFarm == null ? Icons.polyline : Icons.edit_location_alt,
                      size: 16,
                    ),
                    label: Text(
                      _activeFarm == null ? l10n.markMyFarm : l10n.editFarmBoundary,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFarmMarkingHeader() {
    final area = GeometryService.calculateGeodesicPolygonArea(_markingPoints);
    final formattedArea = (area / 10000.0).toStringAsFixed(2);
    final isHindi = LanguageService.instance.isHindi;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app,
                  color: Color(0xFFFFB74D), size: 18),
              const SizedBox(width: 8),
              Text(
                isHindi
                    ? 'बिंदु: ${_markingPoints.length} | क्षेत्रफल: $formattedArea हेक्टेयर'
                    : 'Points: ${_markingPoints.length} | Area: $formattedArea ha',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
          if (_markingValidationError != null) ...[
            const SizedBox(height: 4),
            Text(
              _markingValidationError!,
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFarmMarkingBottomBar(AppLocalizations l10n) {
    final bool canSave =
        _markingPoints.length >= 3 && _markingValidationError == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5EA),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: _cancelMarkingFarm,
            child: Text(l10n.cancel,
                style: const TextStyle(color: Colors.black54)),
          ),
          const Spacer(),
          IconButton.outlined(
            icon: const Icon(Icons.undo, size: 20),
            tooltip: LanguageService.instance.isHindi
                ? 'पिछला बिंदु हटाएं'
                : 'Undo Last Point',
            onPressed:
                _markingPoints.isNotEmpty ? _undoLastMarkingPoint : null,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: canSave ? _saveFarmBoundary : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF27421D),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.check, size: 18),
            label: Text(l10n.saveBoundary),
          ),
        ],
      ),
    );
  }
}
