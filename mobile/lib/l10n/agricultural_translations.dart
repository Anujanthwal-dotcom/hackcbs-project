import '../services/language_service.dart';

/// Central agricultural translation and terminology mapper for KisaanBandhu.
///
/// Ensures pure, farmer-friendly Hindi (no Hinglish) and standard English.
/// Keeps internal model IDs, database keys, and RAG chunk tags language-independent.
class AgriculturalTranslations {
  AgriculturalTranslations._();

  // ── Crop Names ─────────────────────────────────────────────────────────────
  static String getCropName(String rawCrop, [String? langCode]) {
    final lang = langCode ?? LanguageService.instance.languageCode;
    final lower = rawCrop.toLowerCase();

    if (lower.contains('soybean')) {
      return lang == 'hi' ? 'सोयाबीन' : 'Soybean';
    }
    if (lower.contains('cotton')) {
      return lang == 'hi' ? 'कपास' : 'Cotton';
    }
    if (lower.contains('unclear')) {
      return lang == 'hi' ? 'अस्पष्ट' : 'Unclear';
    }
    return lang == 'hi' ? 'अज्ञात फसल' : 'Unknown Crop';
  }

  // ── Condition / Disease / Pest Names ─────────────────────────────────────────
  static String getConditionName(String rawCondition, [String? langCode]) {
    final lang = langCode ?? LanguageService.instance.languageCode;
    final lower = rawCondition.toLowerCase();

    if (lower.contains('healthy')) {
      return lang == 'hi' ? 'स्वस्थ' : 'Healthy';
    }
    if (lower.contains('bacterial') || lower.contains('blight')) {
      return lang == 'hi' ? 'जीवाणु झुलसा रोग' : 'Bacterial Blight';
    }
    if (lower.contains('caterpillar') || lower.contains('larva')) {
      return lang == 'hi' ? 'इल्ली / सुंडी' : 'Caterpillar';
    }
    if (lower.contains('whitefly')) {
      return lang == 'hi' ? 'सफेद मक्खी' : 'Whitefly';
    }
    if (lower.contains('bollworm') || lower.contains('pink')) {
      return lang == 'hi' ? 'गुलाबी सुंडी' : 'Pink Bollworm';
    }
    if (lower.contains('unclear')) {
      return lang == 'hi' ? 'तस्वीर स्पष्ट नहीं है' : 'Image Unclear';
    }
    if (lower.contains('uncertain') || lower.contains('unknown')) {
      return lang == 'hi' ? 'अनिश्चित परिणाम' : 'Uncertain Detection';
    }
    if (lower.contains('negative') || lower.contains('unsupported')) {
      return lang == 'hi' ? 'असमर्थित / गैर-लक्षित पौधा' : 'Unsupported / Negative';
    }
    return rawCondition;
  }

  // ── Formatted Class Title (e.g. "Cotton • Pink Bollworm" / "कपास • गुलाबी सुंडी")
  static String getDisplayTitle({
    required String crop,
    required String condition,
    required bool isValid,
    required bool isBlurry,
    required bool isNegative,
    required bool isAmbiguous,
    required bool isUncertain,
    String? langCode,
  }) {
    final lang = langCode ?? LanguageService.instance.languageCode;

    if (isBlurry) {
      return lang == 'hi' ? 'तस्वीर स्पष्ट नहीं है' : 'Image Unclear';
    }
    if (isNegative) {
      return lang == 'hi' ? 'असमर्थित / गैर-लक्षित पौधा' : 'Unsupported / Negative';
    }
    if (isAmbiguous || isUncertain) {
      return lang == 'hi' ? 'अनिश्चित परिणाम' : 'Uncertain Detection';
    }
    if (isValid) {
      final translatedCrop = getCropName(crop, lang);
      final translatedCond = getConditionName(condition, lang);
      return '$translatedCrop • $translatedCond';
    }
    return getConditionName(condition, lang);
  }

  // ── Subtitle Guidance ───────────────────────────────────────────────────────
  static String getDisplaySubtitle({
    required bool isValid,
    required bool isBlurry,
    required bool isNegative,
    required bool isAmbiguous,
    required bool isUncertain,
    required String confidencePercentage,
    required String marginPercentage,
    double confidenceThreshold = 0.55,
    double marginThreshold = 0.05,
    String? langCode,
  }) {
    final lang = langCode ?? LanguageService.instance.languageCode;

    if (isBlurry) {
      return lang == 'hi'
          ? 'तस्वीर धुंधली है — कृपया कैमरे को पत्तियों पर स्थिर रखें।'
          : 'Image unclear — please focus the camera.';
    }
    if (isNegative) {
      return lang == 'hi'
          ? 'यह असमर्थित फसल या गैर-लक्षित पौधा है।'
          : 'Unsupported crop / plant — Non-target subject.';
    }
    if (isUncertain) {
      return lang == 'hi'
          ? 'कम विश्वास स्तर ($confidencePercentage)। कैमरे को पौधे के करीब रखें।'
          : 'Low confidence ($confidencePercentage < ${(confidenceThreshold * 100).toInt()}%). Hold camera steady.';
    }
    if (isAmbiguous) {
      return lang == 'hi'
          ? 'संदिग्ध परिणाम (अंतर $marginPercentage)। स्पष्ट रोशनी में पुनः प्रयास करें।'
          : 'Ambiguous prediction (margin $marginPercentage < ${(marginThreshold * 100).toInt()}%).';
    }
    if (isValid) {
      return lang == 'hi'
          ? 'विश्वास स्तर: $confidencePercentage (अंतर: $marginPercentage)'
          : 'Confidence: $confidencePercentage (Margin: $marginPercentage)';
    }
    return '';
  }

  // ── Severity Labels ─────────────────────────────────────────────────────────
  static String getSeverityLabel(String severityName, [String? langCode]) {
    final lang = langCode ?? LanguageService.instance.languageCode;
    switch (severityName.toLowerCase()) {
      case 'early':
        return lang == 'hi' ? 'प्रारंभिक अवस्था' : 'Early Stage';
      case 'moderate':
        return lang == 'hi' ? 'मध्यम प्रकोप' : 'Moderate';
      case 'worsening':
        return lang == 'hi' ? 'फैलता हुआ' : 'Worsening';
      case 'severe':
        return lang == 'hi' ? 'अति गंभीर' : 'Severe';
      default:
        return lang == 'hi' ? 'सामान्य' : 'Standard';
    }
  }

  // ── Progression Labels ──────────────────────────────────────────────────────
  static String getProgressionLabel(String progressionName, [String? langCode]) {
    final lang = langCode ?? LanguageService.instance.languageCode;
    switch (progressionName.toLowerCase()) {
      case 'initial':
        return lang == 'hi' ? 'प्रारंभिक पहचान' : 'Initial Detection';
      case 'stable':
        return lang == 'hi' ? 'स्थिति स्थिर है' : 'Stable';
      case 'improved':
        return lang == 'hi' ? 'सुधार हुआ है' : 'Improved';
      case 'worsening':
        return lang == 'hi' ? 'प्रकोप बढ़ा है' : 'Worsening';
      default:
        return progressionName;
    }
  }

  // ── Weather Disease Risk Labels ─────────────────────────────────────────────
  static String getDiseaseRiskLabel(String riskLevel, [String? langCode]) {
    final lang = langCode ?? LanguageService.instance.languageCode;
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return lang == 'hi' ? 'कम जोखिम' : 'Low Disease Risk';
      case 'medium':
        return lang == 'hi' ? 'मध्यम जोखिम' : 'Medium Disease Risk';
      case 'high':
        return lang == 'hi' ? 'उच्च जोखिम' : 'High Disease Risk';
      default:
        return riskLevel;
    }
  }

  // ── GPS Quality Label ───────────────────────────────────────────────────────
  static String getGpsQualityLabel(String quality, [String? langCode]) {
    final lang = langCode ?? LanguageService.instance.languageCode;
    switch (quality.toLowerCase()) {
      case 'high':
        return lang == 'hi' ? 'जीपीएस: सटीक' : 'GPS: High';
      case 'medium':
        return lang == 'hi' ? 'जीपीएस: सामान्य' : 'GPS: Medium';
      case 'low':
        return lang == 'hi' ? 'जीपीएस: कमजोर' : 'GPS: Low';
      default:
        return lang == 'hi' ? 'जीपीएस: अनुपलब्ध' : 'GPS: Unavailable';
    }
  }
}
