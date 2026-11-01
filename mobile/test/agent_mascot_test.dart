import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/farm_model.dart';
import 'package:app/services/agent_runtime.dart';
import 'package:app/services/global_context_engine.dart';
import 'package:app/services/semantic_ui_registry.dart';
import 'package:app/services/voice_service.dart';
import 'package:app/widgets/mascot/global_mascot_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Global Context Engine Tests', () {
    final engine = GlobalContextEngine.instance;

    test('Engine tracks screen transitions and snapshots', () {
      engine.setScreen('Map', route: '/map');
      expect(engine.currentScreen, 'Map');
      expect(engine.currentRoute, '/map');

      final snapshot = engine.getSnapshot();
      expect(snapshot['application']['currentScreen'], 'Map');
      expect(snapshot['application']['currentRoute'], '/map');
    });

    test('Engine tracks selected farm in context snapshot', () {
      final farm = FarmModel(
        id: 'farm_test_1',
        userId: 'farmer_1',
        name: 'Wheat Field Alpha',
        boundary: [const GeoCoordinate(latitude: 22.5, longitude: 77.5)],
        center: const GeoCoordinate(latitude: 22.5, longitude: 77.5),
        areaSquareMeters: 8000,
        cropType: 'Wheat',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      engine.setSelectedFarm(farm);
      expect(engine.selectedFarm?.name, 'Wheat Field Alpha');

      final snapshot = engine.getSnapshot();
      expect(snapshot['farm']['id'], 'farm_test_1');
      expect(snapshot['farm']['name'], 'Wheat Field Alpha');
      expect(snapshot['farm']['cropType'], 'Wheat');
    });

    test('Engine navigates by screen name through tab switcher', () {
      int? switchedTab;
      engine.registerTabSwitchCallback((tab) {
        switchedTab = tab;
      });

      expect(engine.navigateToScreenName('Map'), isTrue);
      expect(switchedTab, 1);

      expect(engine.navigateToScreenName('Help Desk'), isTrue);
      expect(switchedTab, 2);

      expect(engine.navigateToScreenName('Profile'), isTrue);
      expect(switchedTab, 3);

      expect(engine.navigateToScreenName('Scan'), isTrue);
      expect(switchedTab, 0);
    });
  });

  group('Semantic UI Registry Tests', () {
    final registry = SemanticUiRegistry.instance;

    test('Registers and finds interactive element', () {
      final key = GlobalKey();
      final element = SemanticElementData(
        id: 'test_rename_btn',
        label: 'Rename Farm',
        description: 'Opens rename dialog',
        screen: 'Map',
        globalKey: key,
      );

      registry.register(element);
      expect(registry.find('test_rename_btn')?.label, 'Rename Farm');

      final currentElements = registry.describeCurrentScreenElements('Map');
      expect(currentElements.any((e) => e['id'] == 'test_rename_btn'), isTrue);

      registry.unregister('test_rename_btn');
      expect(registry.find('test_rename_btn'), isNull);
    });
  });

  group('Agent Runtime & Tool Execution Tests', () {
    final runtime = AgentRuntime.instance;

    test('get_screen_context returns current context', () async {
      final res = await runtime.executeTool('get_screen_context', {});
      expect(res.success, isTrue);
      expect(res.data?['application'], isNotNull);
    });

    test('navigate_to executes approved navigation', () async {
      final res = await runtime.executeTool('navigate_to', {'target_screen': 'Map'});
      expect(res.success, isTrue);
      expect(res.message, contains('Navigated to Map'));
    });

    test('Destructive write action enforces Human-in-the-Loop approval', () async {
      final res = await runtime.executeTool('rename_farm', {'new_name': 'Green Haven'});
      expect(res.requiresConfirmation, isTrue);
      expect(runtime.pendingAction, isNotNull);
      expect(runtime.pendingAction?.title, 'Rename Farm');

      // Farmer cancels action
      runtime.cancelPendingAction();
      expect(runtime.pendingAction, isNull);
    });

    test('rename_farm pending action can be confirmed and updates selected farm', () async {
      final res = await runtime.executeTool('rename_farm', {'new_name': 'Yash Farm'});
      expect(res.requiresConfirmation, isTrue);
      expect(runtime.pendingAction, isNotNull);

      // Farmer confirms action
      final confirmMsg = await runtime.confirmPendingAction();
      expect(confirmMsg, contains('Successfully renamed farm to "Yash Farm"'));
      expect(runtime.pendingAction, isNull);
      expect(GlobalContextEngine.instance.selectedFarm?.name, 'Yash Farm');
    });

    testWidgets('Tapping floating mascot opens conversation sheet with microphone in sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: GlobalContextEngine.instance.navigatorKey,
          home: const Scaffold(body: Center(child: Text('Home Screen'))),
          builder: (context, child) => GlobalMascotOverlay(child: child!),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Only the clean sprout mascot is visible in sight
      expect(find.text('🌱'), findsOneWidget);
      await tester.tap(find.text('🌱'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Krishi Mitra'), findsOneWidget);
      // Inside sheet, mic button is available for farmer voice input
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    });
  });

  group('Wake Word Detection & Processing Tests', () {
    test('English wake words are accurately detected and stripped', () {
      expect(VoiceService.detectWakeWord('Hey, Bandhu rename my farm'), isTrue);
      expect(VoiceService.detectWakeWord('hey bandhu what is the weather?'), isTrue);
      expect(VoiceService.detectWakeWord('Hey Bandu help me scan'), isTrue);
      expect(VoiceService.stripWakeWord('Hey, Bandhu rename my farm to Yash Farm'), 'rename my farm to Yash Farm');
      expect(VoiceService.stripWakeWord('hey bandhu: show wheat diseases'), 'show wheat diseases');
    });

    test('Hindi wake words are accurately detected and stripped', () {
      expect(VoiceService.detectWakeWord('हे बंधु मेरे खेत का नाम बताओ'), isTrue);
      expect(VoiceService.detectWakeWord('नमस्ते बंधु सहायता करो'), isTrue);
      expect(VoiceService.stripWakeWord('हे बंधु मेरे खेत का नाम यश फार्म करो'), 'मेरे खेत का नाम यश फार्म करो');
    });
  });
}

