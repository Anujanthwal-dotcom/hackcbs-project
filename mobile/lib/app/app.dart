import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app/l10n/app_localizations.dart';
import '../screens/auth/auth_gate.dart';
import '../services/global_context_engine.dart';
import '../services/language_service.dart';
import '../widgets/mascot/global_mascot_overlay.dart';
import 'theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LanguageService.instance.localeNotifier,
      builder: (context, currentLocale, _) {
        return MaterialApp(
          title: 'KisaanBandhu',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: currentLocale,
          navigatorKey: GlobalContextEngine.instance.navigatorKey,
          navigatorObservers: [
            AgentNavigationObserver(),
          ],
          builder: (context, child) {
            return GlobalMascotOverlay(
              child: child ?? const SizedBox.shrink(),
            );
          },
          supportedLocales: const [
            Locale('en'),
            Locale('hi'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthGate(),
        );
      },
    );
  }
}
