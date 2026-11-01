import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central service managing application locale selection and persistence.
///
/// Supported Locales:
/// - English: Locale('en')
/// - Hindi: Locale('hi')
class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  static LanguageService get instance => _instance;

  static const String _prefKeyLanguage = 'kisaan_app_language';

  final ValueNotifier<Locale> localeNotifier = ValueNotifier<Locale>(const Locale('en'));

  Locale get currentLocale => localeNotifier.value;
  String get languageCode => localeNotifier.value.languageCode;
  bool get isHindi => localeNotifier.value.languageCode == 'hi';

  /// Initializes the service and loads the persisted language preference.
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKeyLanguage);
      if (savedCode != null && (savedCode == 'hi' || savedCode == 'en')) {
        localeNotifier.value = Locale(savedCode);
        debugPrint('[LanguageService] Loaded persisted locale: $savedCode');
      } else {
        localeNotifier.value = const Locale('en');
        debugPrint('[LanguageService] Defaulted to English locale.');
      }
    } catch (e) {
      debugPrint('[LanguageService] Initialization warning: $e');
    }
  }

  /// Sets and persists a new application locale ('en' or 'hi').
  Future<void> setLocale(Locale newLocale) async {
    if (newLocale.languageCode != 'en' && newLocale.languageCode != 'hi') return;
    if (localeNotifier.value == newLocale) return;

    localeNotifier.value = newLocale;
    debugPrint('[LanguageService] Locale changed to: ${newLocale.languageCode}');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyLanguage, newLocale.languageCode);
    } catch (e) {
      debugPrint('[LanguageService] Failed to persist locale: $e');
    }
  }

  /// Detects whether a string contains Hindi/Devanagari characters.
  static bool isTextHindi(String text) {
    return RegExp(r'[\u0900-\u097F]').hasMatch(text);
  }

  /// Detects effective conversational language ('hi' or 'en') from user input.
  /// If user input contains Devanagari script, returns 'hi'.
  /// If strictly Latin/English, returns 'en' unless default is Hindi and query has no letters.
  String detectQueryLanguage(String text) {
    if (isTextHindi(text)) {
      return 'hi';
    }
    // If the text has English letters
    if (RegExp(r'[a-zA-Z]').hasMatch(text)) {
      return 'en';
    }
    return languageCode;
  }
}
