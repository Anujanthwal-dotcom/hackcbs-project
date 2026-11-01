import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/agricultural_place.dart';
import 'package:app/screens/help_desk/widgets/help_desk_card.dart';
import 'package:app/app/theme/app_theme.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AgriculturalPlace Model Tests', () {
    test('Formats distance correctly for meters and kilometers', () {
      const place1 = AgriculturalPlace(
        id: 'node_1',
        name: 'District Soil Testing Lab',
        category: 'lab',
        categoryLabel: 'Agricultural Laboratory',
        latitude: 28.6139,
        longitude: 77.2090,
        distanceMeters: 450.4,
      );
      expect(place1.formattedDistance, equals('450 m'));

      const place2 = AgriculturalPlace(
        id: 'node_2',
        name: 'Krishi Vigyan Kendra',
        category: 'kvk',
        categoryLabel: 'Krishi Vigyan Kendra / Expert Center',
        latitude: 28.6200,
        longitude: 77.2100,
        distanceMeters: 2420.0,
      );
      expect(place2.formattedDistance, equals('2.4 km'));

      const place3 = AgriculturalPlace(
        id: 'node_3',
        name: 'ICAR Research Complex',
        category: 'research',
        categoryLabel: 'Agricultural Research Center',
        latitude: 28.7000,
        longitude: 77.3000,
        distanceMeters: 18450.0,
      );
      expect(place3.formattedDistance, equals('18 km'));
    });

    test('Contact availability getters and URI sanitization', () {
      const placeWithContacts = AgriculturalPlace(
        id: 'node_1',
        name: 'ICAR Regional Station',
        category: 'research',
        categoryLabel: 'Agricultural Research Center',
        latitude: 28.6139,
        longitude: 77.2090,
        distanceMeters: 1200,
        phone: '+91 11 2584 1234',
        website: 'icar.org.in',
        address: 'Pusa Road, New Delhi',
      );

      expect(placeWithContacts.hasPhone, isTrue);
      expect(placeWithContacts.cleanPhoneUri, equals('tel:+911125841234'));
      expect(placeWithContacts.hasWebsite, isTrue);
      expect(placeWithContacts.cleanWebUrl, equals('https://icar.org.in'));
      expect(placeWithContacts.hasAddress, isTrue);

      const placeWithoutContacts = AgriculturalPlace(
        id: 'node_2',
        name: 'Block Agriculture Office',
        category: 'government',
        categoryLabel: 'Government Agriculture Office',
        latitude: 28.6139,
        longitude: 77.2090,
        distanceMeters: 3500,
      );

      expect(placeWithoutContacts.hasPhone, isFalse);
      expect(placeWithoutContacts.cleanPhoneUri, isNull);
      expect(placeWithoutContacts.hasWebsite, isFalse);
      expect(placeWithoutContacts.cleanWebUrl, isNull);
      expect(placeWithoutContacts.hasAddress, isFalse);
    });

    test('Category icon resolution', () {
      const lab = AgriculturalPlace(
        id: '1',
        name: 'Lab',
        category: 'lab',
        categoryLabel: 'Lab',
        latitude: 0,
        longitude: 0,
        distanceMeters: 0,
      );
      expect(lab.icon, equals(Icons.biotech));

      const kvk = AgriculturalPlace(
        id: '2',
        name: 'KVK',
        category: 'kvk',
        categoryLabel: 'KVK',
        latitude: 0,
        longitude: 0,
        distanceMeters: 0,
      );
      expect(kvk.icon, equals(Icons.school));

      const research = AgriculturalPlace(
        id: '3',
        name: 'Research',
        category: 'research',
        categoryLabel: 'Research',
        latitude: 0,
        longitude: 0,
        distanceMeters: 0,
      );
      expect(research.icon, equals(Icons.science));

      const gov = AgriculturalPlace(
        id: '4',
        name: 'Gov',
        category: 'government',
        categoryLabel: 'Government',
        latitude: 0,
        longitude: 0,
        distanceMeters: 0,
      );
      expect(gov.icon, equals(Icons.account_balance));

      const disease = AgriculturalPlace(
        id: '5',
        name: 'Plant Doctor',
        category: 'disease_help',
        categoryLabel: 'Disease Help',
        latitude: 0,
        longitude: 0,
        distanceMeters: 0,
      );
      expect(disease.icon, equals(Icons.healing));
    });
  });

  group('HelpDeskCard Widget Tests', () {
    testWidgets('Renders all available details including Call, Directions, and Website when present',
        (WidgetTester tester) async {
      const fullPlace = AgriculturalPlace(
        id: 'node_100',
        name: 'Central Soil and Water Conservation Research Institute',
        category: 'research',
        categoryLabel: 'Agricultural Research Center',
        latitude: 30.3344,
        longitude: 78.0435,
        distanceMeters: 1500,
        address: 'Kaulagarh Road, Dehradun, Uttarakhand',
        phone: '+91 135 2758564',
        website: 'cswcrtiweb.org',
        operatorName: 'Indian Council of Agricultural Research',
        openingHours: 'Mo-Fr 09:30-17:30',
      );

      await tester.pumpWidget(_wrap(const HelpDeskCard(place: fullPlace)));

      expect(find.text('Central Soil and Water Conservation Research Institute'), findsOneWidget);
      expect(find.text('Agricultural Research Center'), findsOneWidget);
      expect(find.text('1.5 km'), findsOneWidget);
      expect(find.text('Indian Council of Agricultural Research'), findsOneWidget);
      expect(find.text('Kaulagarh Road, Dehradun, Uttarakhand'), findsOneWidget);
      expect(find.text('Mo-Fr 09:30-17:30'), findsOneWidget);

      // Buttons check
      expect(find.widgetWithText(OutlinedButton, 'Call'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Directions'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Website'), findsOneWidget);
    });

    testWidgets('Hides Call and Website buttons when contact information is absent',
        (WidgetTester tester) async {
      const minimalPlace = AgriculturalPlace(
        id: 'node_101',
        name: 'Local Agriculture Extension Office',
        category: 'government',
        categoryLabel: 'Government Agriculture Office',
        latitude: 30.3200,
        longitude: 78.0300,
        distanceMeters: 620,
      );

      await tester.pumpWidget(_wrap(const HelpDeskCard(place: minimalPlace)));

      expect(find.text('Local Agriculture Extension Office'), findsOneWidget);
      expect(find.text('Government Agriculture Office'), findsOneWidget);
      expect(find.text('620 m'), findsOneWidget);

      // Directions is always available
      expect(find.widgetWithText(FilledButton, 'Directions'), findsOneWidget);

      // Call and Website must NOT be shown
      expect(find.widgetWithText(OutlinedButton, 'Call'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Website'), findsNothing);
    });
  });
}
