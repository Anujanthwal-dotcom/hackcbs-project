import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/screens/main_navigation_screen.dart';
import 'package:app/screens/auth/login_screen.dart';
import 'package:app/screens/auth/register_screen.dart';
import 'package:app/app/theme/app_theme.dart';

Widget _wrapWithLocalization(Widget child) {
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
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MainNavigationScreen renders with 4-item bottom navigation and interacts with Map, Help Desk and Profile',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithLocalization(const MainNavigationScreen()));

    // 1. Initial screen should show reorganized 4-item bottom navigation (Scan, Map, Help Desk, Profile)
    // Assistant tab is removed from bottom nav and lives globally as the AI mascot.
    expect(find.text('Scan'), findsWidgets);
    expect(find.text('Map'), findsWidgets);
    expect(find.text('Help Desk'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Assistant'), findsNothing);

    // 2. Navigate to Map screen
    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pump();

    expect(find.text('Farm Map'), findsOneWidget);
    expect(find.text('Mark My Farm'), findsOneWidget);

    // 3. Navigate to Help Desk screen
    await tester.tap(find.byIcon(Icons.support_agent_outlined));
    await tester.pump();

    expect(find.text('Help Desk'), findsWidgets);
    expect(find.text('Find agricultural support near you'), findsOneWidget);

    // 4. Navigate to Profile screen
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump();

    expect(find.text('Farmer Profile'), findsOneWidget);
    expect(find.text('Account Information'), findsOneWidget);
  });

  testWidgets('LoginScreen renders email and password fields with validations',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithLocalization(const LoginScreen()));

    expect(find.text('Welcome to KisaanBandhu'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);

    // Tap Sign In with empty fields
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pump();

    expect(find.text('Please enter your email address.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
  });

  testWidgets('RegisterScreen validates name, email, and password matching',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithLocalization(const RegisterScreen()));

    expect(find.text('Create Account'), findsWidgets);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);

    // Tap Create Account with empty fields
    await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
    await tester.pump();

    expect(find.text('Full Name is required.'), findsOneWidget);
    expect(find.text('Please enter your email address.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
  });
}
