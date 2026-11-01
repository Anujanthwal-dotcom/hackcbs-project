import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/map_config.dart';

/// Reverse-geocodes GPS coordinates to a human-readable place name
/// using the Mapbox Geocoding v6 API.
///
/// Architecture:
/// - Called on-demand only (not on a timer or background loop)
/// - 10-minute in-memory cache keyed by rounded lat/lon (~111m resolution)
/// - Returns a rich location string e.g. "Suddhowala, Dehradun, Uttarakhand, India"
/// - Falls back gracefully when offline or Mapbox token is absent
class LocationGeocodingService {
  static final LocationGeocodingService _instance =
      LocationGeocodingService._internal();
  factory LocationGeocodingService() => _instance;
  LocationGeocodingService._internal();

  static LocationGeocodingService get instance => _instance;

  // Cache: key = "lat,lon" rounded to 3dp (~111m resolution), value = entry
  final Map<String, _GeocodeCacheEntry> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 10);

  // Mapbox Geocoding v6 reverse endpoint
  static const String _baseUrl =
      'https://api.mapbox.com/search/geocode/v6/reverse';

  /// Returns a human-readable location string for [lat]/[lon].
  ///
  /// Example output: "Suddhowala, Dehradun, Uttarakhand, India"
  ///
  /// Returns null if the token is missing, network fails, or API returns nothing usable.
  Future<String?> reverseGeocode(double lat, double lon) async {
    final token = MapConfig.mapboxAccessToken;
    if (token.isEmpty) {
      debugPrint('[Geocoding] Mapbox token not configured — skipping reverse geocode.');
      return null;
    }

    // Cache key: round to 3 decimal places (~111 m resolution)
    final cacheKey =
        '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';

    // Return cached result if still fresh
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      debugPrint('[Geocoding] Cache hit for ($lat, $lon): ${cached.displayName}');
      return cached.displayName;
    }

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'longitude': lon.toStringAsFixed(6),
        'latitude': lat.toStringAsFixed(6),
        'access_token': token,
        'language': 'en',
        'limit': '1',
      });

      debugPrint('[Geocoding] Fetching reverse geocode for ($lat, $lon)...');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = _extractDisplayName(json);

        if (displayName != null) {
          _cache[cacheKey] = _GeocodeCacheEntry(
            displayName: displayName,
            fetchedAt: DateTime.now(),
          );
          debugPrint('[Geocoding] Resolved: $displayName');
          return displayName;
        } else {
          debugPrint('[Geocoding] No usable place data in response.');
        }
      } else {
        debugPrint('[Geocoding] API HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[Geocoding] Request failed: $e');
    }

    return null;
  }

  /// Parses Mapbox Geocoding v6 context into a readable address hierarchy.
  ///
  /// Order: neighborhood → locality → place → district → region → country
  String? _extractDisplayName(Map<String, dynamic> json) {
    try {
      final features = json['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return null;

      final feature = features.first as Map<String, dynamic>;
      final properties =
          feature['properties'] as Map<String, dynamic>? ?? {};
      final context =
          properties['context'] as Map<String, dynamic>? ?? {};

      final parts = <String>[];
      _addContextPart(parts, context, 'neighborhood');
      _addContextPart(parts, context, 'locality');
      _addContextPart(parts, context, 'place');
      _addContextPart(parts, context, 'district');
      _addContextPart(parts, context, 'region');
      _addContextPart(parts, context, 'country');

      if (parts.isNotEmpty) return parts.join(', ');

      // Fallback: top-level name
      final name = properties['name'] as String?;
      if (name != null && name.isNotEmpty) return name;
      return null;
    } catch (e) {
      debugPrint('[Geocoding] Parse error: $e');
      return null;
    }
  }

  void _addContextPart(
      List<String> parts, Map<String, dynamic> context, String key) {
    final entry = context[key] as Map<String, dynamic>?;
    if (entry == null) return;
    final name = entry['name'] as String?;
    if (name != null && name.isNotEmpty && !parts.contains(name)) {
      parts.add(name);
    }
  }

  /// Clears the in-memory cache.
  void clearCache() => _cache.clear();
}

class _GeocodeCacheEntry {
  final String displayName;
  final DateTime fetchedAt;
  const _GeocodeCacheEntry({
    required this.displayName,
    required this.fetchedAt,
  });
}
