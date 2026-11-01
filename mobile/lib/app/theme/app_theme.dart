import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color darkGreen = Color(0xFF27421D);
  static const Color paleCream = Color(0xFFF3F5EA);
  static const Color lightGreenHighlight = Color(0xFFDCE9C7);
  static const Color cardBg = Color(0xFFFAFCF5);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paleCream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkGreen,
        primary: darkGreen,
        onPrimary: Colors.white,
        secondary: lightGreenHighlight,
        onSecondary: darkGreen,
        surface: paleCream,
        onSurface: darkGreen,
        surfaceContainerHighest: Color(0xFFE5ECCF),
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: darkGreen,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: darkGreen),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0.5,
        shadowColor: Colors.black12,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E9D4), width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkGreen,
          side: const BorderSide(color: darkGreen, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paleCream,
        elevation: 0,
        indicatorColor: lightGreenHighlight,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: darkGreen,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return const TextStyle(
            color: Color(0xFF5A7250),
            fontWeight: FontWeight.normal,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: darkGreen, size: 24);
          }
          return const IconThemeData(color: Color(0xFF5A7250), size: 24);
        }),
      ),
    );
  }
}
