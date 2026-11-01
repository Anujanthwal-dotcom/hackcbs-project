import '../l10n/agricultural_translations.dart';
import '../services/language_service.dart';

/// Weather data fetched from Open-Meteo API.
class WeatherData {
  final double temperatureC;
  final double humidity;       // %
  final double precipitation;  // mm current hour
  final double windSpeedKmh;
  final int weatherCode;       // WMO weather interpretation code
  final String description;    // human-readable
  final double? latitude;
  final double? longitude;
  final DateTime fetchedAt;

  const WeatherData({
    required this.temperatureC,
    required this.humidity,
    required this.precipitation,
    required this.windSpeedKmh,
    required this.weatherCode,
    required this.description,
    this.latitude,
    this.longitude,
    required this.fetchedAt,
  });

  /// True if this data is still within the cache TTL.
  bool isStale(Duration ttl) {
    return DateTime.now().difference(fetchedAt) > ttl;
  }

  /// Agricultural disease risk level based on current conditions.
  /// Returns 'low', 'medium', or 'high'.
  String get diseaseRiskLevel {
    // High humidity + warm temperature → elevated fungal/bacterial disease risk
    if (humidity >= 80 && temperatureC >= 20 && temperatureC <= 35) return 'high';
    if (humidity >= 65 && temperatureC >= 18) return 'medium';
    return 'low';
  }

  /// True if conditions may warrant a weather-based alert.
  bool get shouldAlert {
    final isHeavyRain = precipitation >= 10;
    final isExtremeHeat = temperatureC >= 40;
    final isHighDiseaseRisk = diseaseRiskLevel == 'high';
    return isHeavyRain || isExtremeHeat || isHighDiseaseRisk;
  }

  /// Alert type key for deduplication.
  String get alertTypeKey {
    if (temperatureC >= 40) return 'extreme_heat';
    if (precipitation >= 10) return 'heavy_rain';
    if (diseaseRiskLevel == 'high') return 'disease_risk';
    return 'general';
  }

  /// Human-readable summary for LLM context, including data freshness.
  String toContextString({bool showStaleness = true}) {
    final age = DateTime.now().difference(fetchedAt);
    final stale = age.inMinutes > 10;
    final timeLabel = _formatTime(fetchedAt);
    final cacheNote = (showStaleness && stale) ? ' (cached, ${age.inMinutes} min old)' : '';
    return 'Temperature: ${temperatureC.toStringAsFixed(1)}°C, '
        'Humidity: ${humidity.toStringAsFixed(0)}%, '
        'Precipitation: ${precipitation.toStringAsFixed(1)} mm, '
        'Wind: ${windSpeedKmh.toStringAsFixed(1)} km/h, '
        'Conditions: $description, '
        'Updated: $timeLabel$cacheNote';
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  factory WeatherData.fromOpenMeteo(Map<String, dynamic> json, double lat, double lon) {
    final current = json['current'] as Map<String, dynamic>;
    final code = (current['weather_code'] as num?)?.toInt() ?? 0;
    return WeatherData(
      temperatureC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      humidity: (current['relative_humidity_2m'] as num?)?.toDouble() ?? 0,
      precipitation: (current['precipitation'] as num?)?.toDouble() ?? 0,
      windSpeedKmh: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      weatherCode: code,
      description: _wmoDescription(code),
      latitude: lat,
      longitude: lon,
      fetchedAt: DateTime.now(),
    );
  }

  /// Localized disease risk label.
  String get localizedDiseaseRisk => AgriculturalTranslations.getDiseaseRiskLabel(diseaseRiskLevel);

  /// Localized weather description.
  String get localizedDescription {
    if (LanguageService.instance.isHindi) {
      return _wmoDescriptionHindi(weatherCode);
    }
    return description;
  }

  static String _wmoDescriptionHindi(int code) {
    if (code == 0) return 'साफ आसमान';
    if (code <= 3) return 'आंशिक बादल';
    if (code <= 19) return 'धुंध या कोहरा';
    if (code <= 29) return 'हल्की बूंदाबांदी';
    if (code <= 39) return 'धूल भरी हवा';
    if (code <= 49) return 'कोहरा';
    if (code <= 59) return 'बूंदाबांदी';
    if (code <= 69) return 'वर्षा';
    if (code <= 79) return 'बर्फबारी';
    if (code <= 84) return 'तेज बौछारें';
    if (code <= 94) return 'गरज के साथ बारिश';
    return 'भारी आंधी-तूफान';
  }

  static String _wmoDescription(int code) {
    if (code == 0) return 'Clear sky';
    if (code <= 3) return 'Partly cloudy';
    if (code <= 19) return 'Fog or haze';
    if (code <= 29) return 'Drizzle or light rain';
    if (code <= 39) return 'Dust or sand';
    if (code <= 49) return 'Fog';
    if (code <= 59) return 'Drizzle';
    if (code <= 69) return 'Rain';
    if (code <= 79) return 'Snow or sleet';
    if (code <= 84) return 'Rain showers';
    if (code <= 94) return 'Thunderstorm';
    return 'Severe thunderstorm';
  }
}
