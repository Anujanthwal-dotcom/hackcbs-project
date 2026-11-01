import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/weather_model.dart';

/// Fetches real-time weather from Open-Meteo (free, no API key required).
///
/// Implements a 30-minute in-memory cache to avoid redundant API calls.
class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  static WeatherService get instance => _instance;

  WeatherData? _cached;

  /// Returns current weather for [lat],[lon].
  /// Uses cache if within TTL; fetches fresh data otherwise.
  Future<WeatherData?> getWeather(double lat, double lon) async {
    // Return cached data if still fresh
    if (_cached != null && !_cached!.isStale(AppConfig.weatherCacheTtl)) {
      debugPrint('[WeatherService] Returning cached weather (${_cached!.description})');
      return _cached;
    }

    try {
      final uri = Uri.parse(AppConfig.weatherBaseUrl).replace(
        queryParameters: {
          'latitude': lat.toStringAsFixed(6),
          'longitude': lon.toStringAsFixed(6),
          'current': [
            'temperature_2m',
            'relative_humidity_2m',
            'precipitation',
            'wind_speed_10m',
            'weather_code',
          ].join(','),
          'wind_speed_unit': 'kmh',
          'forecast_days': '1',
        },
      );

      debugPrint('[WeatherService] Fetching: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _cached = WeatherData.fromOpenMeteo(json, lat, lon);
        debugPrint('[WeatherService] Fetched: ${_cached!.toContextString()}');
        return _cached;
      } else {
        debugPrint('[WeatherService] HTTP ${response.statusCode}: ${response.body}');
        return _cached; // Return stale cache on error
      }
    } catch (e) {
      debugPrint('[WeatherService] Fetch error: $e');
      return _cached; // Return stale cache or null
    }
  }

  /// Force-clear cache (e.g., after location change).
  void invalidateCache() => _cached = null;

  /// Cached weather (may be null or stale).
  WeatherData? get cachedWeather => _cached;
}
