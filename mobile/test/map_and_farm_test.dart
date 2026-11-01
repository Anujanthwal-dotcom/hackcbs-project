import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/farm_model.dart';
import 'package:app/models/detection_record.dart';
import 'package:app/models/navigation_models.dart';
import 'package:app/screens/map/widgets/farm_list_sheet.dart';
import 'package:app/screens/map/widgets/farm_marker_sheet.dart';
import 'package:app/services/geometry_service.dart';
import 'package:app/services/location_service.dart';

void main() {
  group('GeometryService & Farm Polygon Tests', () {
    test('Valid non-intersecting quadrilateral polygon passes validation', () {
      // 4 corners of a farm in India (~20.0° N, 75.0° E)
      const points = [
        GeoCoordinate(latitude: 20.0000, longitude: 75.0000),
        GeoCoordinate(latitude: 20.0010, longitude: 75.0000),
        GeoCoordinate(latitude: 20.0010, longitude: 75.0010),
        GeoCoordinate(latitude: 20.0000, longitude: 75.0010),
      ];

      final result = GeometryService.validateFarmPolygon(points);
      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);

      final area = GeometryService.calculateGeodesicPolygonArea(points);
      expect(area, greaterThan(1000.0)); // ~11,000 m² (~1.1 ha)

      final centroid = GeometryService.calculateCentroid(points);
      expect(centroid.latitude, closeTo(20.0005, 0.0001));
      expect(centroid.longitude, closeTo(75.0005, 0.0001));
    });

    test('Self-intersecting bowtie polygon fails validation with descriptive message', () {
      // Bowtie polygon: (0,0) -> (1,1) -> (0,1) -> (1,0)
      const selfIntersecting = [
        GeoCoordinate(latitude: 20.0000, longitude: 75.0000),
        GeoCoordinate(latitude: 20.0010, longitude: 75.0010),
        GeoCoordinate(latitude: 20.0000, longitude: 75.0010),
        GeoCoordinate(latitude: 20.0010, longitude: 75.0000),
      ];

      final result = GeometryService.validateFarmPolygon(selfIntersecting);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('self-intersect'));
    });

    test('Collinear points fail validation', () {
      const collinear = [
        GeoCoordinate(latitude: 20.0000, longitude: 75.0000),
        GeoCoordinate(latitude: 20.0010, longitude: 75.0000),
        GeoCoordinate(latitude: 20.0020, longitude: 75.0000),
      ];

      final result = GeometryService.validateFarmPolygon(collinear);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('straight line'));
    });

    test('Fewer than 3 points fail validation', () {
      const twoPoints = [
        GeoCoordinate(latitude: 20.0000, longitude: 75.0000),
        GeoCoordinate(latitude: 20.0010, longitude: 75.0000),
      ];

      final result = GeometryService.validateFarmPolygon(twoPoints);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('at least 3'));
    });

    test('Point-in-polygon correctly identifies interior and exterior coordinates', () {
      const farm = [
        GeoCoordinate(latitude: 20.0000, longitude: 75.0000),
        GeoCoordinate(latitude: 20.0020, longitude: 75.0000),
        GeoCoordinate(latitude: 20.0020, longitude: 75.0020),
        GeoCoordinate(latitude: 20.0000, longitude: 75.0020),
      ];

      const insidePoint = GeoCoordinate(latitude: 20.0010, longitude: 75.0010);
      const outsidePoint = GeoCoordinate(latitude: 20.0030, longitude: 75.0030);

      expect(GeometryService.isPointInsidePolygon(insidePoint, farm), isTrue);
      expect(GeometryService.isPointInsidePolygon(outsidePoint, farm), isFalse);
    });

    test('Haversine distance and bearing calculation produce accurate geospatial metrics', () {
      const p1 = GeoCoordinate(latitude: 20.0000, longitude: 75.0000);
      const p2 = GeoCoordinate(latitude: 20.0010, longitude: 75.0000);

      final distance = GeometryService.calculateHaversineDistance(p1, p2);
      // 0.001 degree of latitude is approximately 111.1 meters
      expect(distance, closeTo(111.2, 2.0));

      final bearing = GeometryService.calculateBearing(p1, p2);
      // Directly north is 0 degrees (or 360)
      expect(bearing, closeTo(0.0, 1.0));
    });
  });

  group('FarmModel & Geotagged DetectionRecord Serialization', () {
    test('FarmModel serializes to and from Map correctly', () {
      final now = DateTime.now();
      final farm = FarmModel(
        id: 'farm_123',
        userId: 'user_abc',
        name: 'South Field Plot',
        boundary: const [
          GeoCoordinate(latitude: 20.1, longitude: 75.1),
          GeoCoordinate(latitude: 20.2, longitude: 75.1),
          GeoCoordinate(latitude: 20.2, longitude: 75.2),
        ],
        center: const GeoCoordinate(latitude: 20.166, longitude: 75.133),
        areaSquareMeters: 45000.0,
        createdAt: now,
        updatedAt: now,
      );

      final map = farm.toMap();
      expect(map['id'], 'farm_123');
      expect(map['userId'], 'user_abc');
      expect((map['boundary'] as List).length, 3);
      expect(map['areaSquareMeters'], 45000.0);

      final restored = FarmModel.fromMap(map, 'farm_123');
      expect(restored.id, farm.id);
      expect(restored.name, 'South Field Plot');
      expect(restored.boundary.length, 3);
      expect(restored.center.latitude, closeTo(20.166, 0.001));
    });

    test('DetectionRecord serializes with GPS metadata and validates hasLocation', () {
      final now = DateTime.now();
      final record = DetectionRecord(
        id: 'scan_456',
        userId: 'user_abc',
        crop: 'Soybean',
        prediction: 'soybean_whitefly',
        condition: 'Whitefly',
        confidence: 0.962,
        status: 'validTarget',
        latitude: 20.12345,
        longitude: 75.67890,
        accuracyMeters: 3.8,
        farmId: 'farm_123',
        createdAt: now,
      );

      expect(record.hasLocation, isTrue);
      expect(record.confidencePercentage, '96.2%');

      final map = record.toMap();
      expect(map['latitude'], 20.12345);
      expect(map['longitude'], 75.67890);
      expect(map['accuracyMeters'], 3.8);
      expect(map['farmId'], 'farm_123');

      final restored = DetectionRecord.fromMap(map, 'scan_456');
      expect(restored.latitude, 20.12345);
      expect(restored.longitude, 75.67890);
      expect(restored.accuracyMeters, 3.8);
      expect(restored.hasLocation, isTrue);
    });

    test('LocationService accurately evaluates GPS quality levels', () {
      expect(LocationService.evaluateQuality(3.0), LocationQualityLevel.high);
      expect(LocationService.evaluateQuality(15.0), LocationQualityLevel.acceptable);
      expect(LocationService.evaluateQuality(35.0), LocationQualityLevel.poor);
      expect(LocationService.evaluateQuality(null), LocationQualityLevel.unavailable);
    });
  });

  group('NavigationModels & Dynamic Progress Calculations', () {
    test('NavigationProgress formats remaining distance and ETA cleanly', () {
      const origin = GeoCoordinate(latitude: 20.000, longitude: 75.000);
      const dest = GeoCoordinate(latitude: 20.001, longitude: 75.001);

      const nav = NavigationProgress(
        status: NavigationStatus.navigating,
        currentPosition: origin,
        destination: dest,
        routeCoordinates: [origin, dest],
        distanceRemainingMeters: 45.0,
        estimatedSeconds: 38,
        bearingDegrees: 45.0,
        hasArrived: false,
        isFarmLocalRoute: true,
      );

      expect(nav.formattedDistance, '45 m');
      expect(nav.formattedEta, '38 sec');
      expect(nav.hasArrived, isFalse);
    });
  });

  group('Multi-Farm & FarmListSheet Tests', () {
    test('Pin-type farm (single-point boundary) serializes correctly and shows 0.0 ha', () {
      final now = DateTime.now();
      const pinCoord = GeoCoordinate(latitude: 28.6139, longitude: 77.2090, accuracyMeters: 4.2);
      final pinFarm = FarmModel(
        id: 'farm_pin_1',
        userId: 'user_xyz',
        name: 'North Wheat Field',
        boundary: const [pinCoord],
        center: pinCoord,
        areaSquareMeters: 0.0,
        createdAt: now,
        updatedAt: now,
      );

      expect(pinFarm.boundary.length, 1);
      expect(pinFarm.formattedArea, '0.0 ha');
      expect(pinFarm.center.latitude, 28.6139);

      final map = pinFarm.toMap();
      final restored = FarmModel.fromMap(map, 'farm_pin_1');
      expect(restored.id, 'farm_pin_1');
      expect(restored.name, 'North Wheat Field');
      expect(restored.boundary.length, 1);
      expect(restored.center.longitude, 77.2090);
    });

    testWidgets('FarmListSheet renders list of multiple farms and selects tapped farm', (tester) async {
      final now = DateTime.now();
      final farm1 = FarmModel(
        id: 'f1',
        userId: 'u1',
        name: 'Plot A - Soybean',
        boundary: const [
          GeoCoordinate(latitude: 20.0, longitude: 75.0),
          GeoCoordinate(latitude: 20.01, longitude: 75.0),
          GeoCoordinate(latitude: 20.01, longitude: 75.01),
        ],
        center: const GeoCoordinate(latitude: 20.005, longitude: 75.005),
        areaSquareMeters: 20000.0,
        cropType: 'Soybean',
        createdAt: now,
        updatedAt: now,
      );
      final farm2 = FarmModel(
        id: 'f2',
        userId: 'u1',
        name: 'Plot B - Cotton',
        boundary: const [GeoCoordinate(latitude: 20.02, longitude: 75.02)],
        center: const GeoCoordinate(latitude: 20.02, longitude: 75.02),
        areaSquareMeters: 0.0,
        cropType: 'Cotton',
        createdAt: now,
        updatedAt: now,
      );

      FarmModel? selectedFarm;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  FarmListSheet.show(
                    context: context,
                    farms: [farm1, farm2],
                    activeFarm: farm1,
                    onFarmSelected: (f) => selectedFarm = f,
                  );
                },
                child: const Text('Open Farms'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Farms'));
      await tester.pumpAndSettle();

      // Verify header and both farms are listed
      expect(find.text('My Farms (2)'), findsOneWidget);
      expect(find.text('Plot A - Soybean'), findsOneWidget);
      expect(find.text('Plot B - Cotton'), findsOneWidget);
      expect(find.text('2.00 ha (4.94 ac)'), findsOneWidget);
      expect(find.text('Pin location'), findsOneWidget);

      // Tap on Farm 2
      await tester.tap(find.text('Plot B - Cotton'));
      await tester.pumpAndSettle();

      // Verify callback fired
      expect(selectedFarm, isNotNull);
      expect(selectedFarm!.id, 'f2');
      expect(selectedFarm!.name, 'Plot B - Cotton');
    });

    testWidgets('FarmListSheet confirms and triggers farm deletion', (tester) async {
      final now = DateTime.now();
      final farm = FarmModel(
        id: 'del_farm_1',
        userId: 'u1',
        name: 'Plot to Delete',
        boundary: const [GeoCoordinate(latitude: 20.0, longitude: 75.0)],
        center: const GeoCoordinate(latitude: 20.0, longitude: 75.0),
        areaSquareMeters: 0.0,
        createdAt: now,
        updatedAt: now,
      );

      FarmModel? deletedFarm;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  FarmListSheet.show(
                    context: context,
                    farms: [farm],
                    activeFarm: farm,
                    onFarmSelected: (_) {},
                    onFarmDeleted: (f) => deletedFarm = f,
                  );
                },
                child: const Text('Open Farms'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Farms'));
      await tester.pumpAndSettle();

      // Tap the delete icon
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Delete Farm?'), findsOneWidget);

      // Tap confirm Delete
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(deletedFarm, isNotNull);
      expect(deletedFarm!.id, 'del_farm_1');
    });

    testWidgets('FarmMarkerSheet confirms and triggers detection point deletion', (tester) async {
      final now = DateTime.now();
      final scan = DetectionRecord(
        id: 'scan_del_1',
        userId: 'u1',
        crop: 'Soybean',
        prediction: 'soybean_caterpillar',
        condition: 'Caterpillar',
        confidence: 0.94,
        status: 'validTarget',
        latitude: 20.123,
        longitude: 75.456,
        accuracyMeters: 3.5,
        createdAt: now,
      );

      bool deleteTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => FarmMarkerSheet(
                      scan: scan,
                      onNavigate: () {},
                      onAskAssistant: (_) {},
                      onDelete: () => deleteTriggered = true,
                    ),
                  );
                },
                child: const Text('Open Marker Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Marker Sheet'));
      await tester.pumpAndSettle();

      // Tap delete icon in sheet header
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Delete Detection Point?'), findsOneWidget);

      // Tap Delete button
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(deleteTriggered, isTrue);
    });
  });
}

