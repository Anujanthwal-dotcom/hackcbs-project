import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/map_config.dart';
import '../models/agricultural_place.dart';
import '../models/farm_model.dart';
import 'geometry_service.dart';

/// Help Desk service using Google Places API (New) — Text Search endpoint.
///
/// Architecture:
/// - 6 concurrent targeted Text Search queries via Future.wait()
/// - Deduplication by Google's stable place.id
/// - Distance calculated locally via existing GeometryService.calculateHaversineDistance()
/// - Results filtered to requested radius, sorted nearest-first
/// - 10-minute in-memory cache keyed by rounded lat/lon + radius
/// - API key is read from --dart-define=GOOGLE_PLACES_API_KEY (never hardcoded)
class HelpDeskService {
  static final HelpDeskService _instance = HelpDeskService._internal();
  factory HelpDeskService() => _instance;
  HelpDeskService._internal();

  static HelpDeskService get instance => _instance;

  // Google Places Text Search (New) endpoint
  static const String _placesEndpoint =
      'https://places.googleapis.com/v1/places:searchText';

  // Explicit FieldMask keeps responses small and cost-efficient.
  static const String _fieldMask =
      'places.id,'
      'places.displayName,'
      'places.formattedAddress,'
      'places.location,'
      'places.rating,'
      'places.userRatingCount,'
      'places.nationalPhoneNumber,'
      'places.websiteUri,'
      'places.googleMapsUri,'
      'places.regularOpeningHours,'
      'places.businessStatus';

  // Google Places circular locationBias supports a maximum of 50,000 meters.
  static const int _googleMaxRadiusMeters = 50000;

  // How many results to request per query
  static const int _maxResultsPerQuery = 10;

  // In-memory session cache: key = "lat_2dp,lon_2dp,radiusMeters"
  final Map<String, _HelpDeskCacheEntry> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 10);

  /// Fetches nearby real agricultural support places using Google Places Text Search.
  ///
  /// [radiusMeters] is the user-facing search radius. Values > 50,000 m are clamped
  /// to 50,000 m for the Google API call; distance filtering is applied locally.
  Future<List<AgriculturalPlace>> fetchNearbyAgriculturalPlaces({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  }) async {
    final cacheKey =
        '${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)},$radiusMeters';
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      debugPrint(
        '[HelpDesk] Cache hit — returning ${cached.places.length} results '
        'for ($latitude, $longitude) radius=${radiusMeters}m',
      );
      return cached.places;
    }

    final apiKey = MapConfig.googlePlacesApiKey;
    if (apiKey.isEmpty) {
      debugPrint(
        '[HelpDesk] GOOGLE_PLACES_API_KEY is not set. '
        'Pass it via --dart-define=GOOGLE_PLACES_API_KEY=AIza... '
        'Help Desk will return no results.',
      );
      return [];
    }

    debugPrint(
      '[HelpDesk] Location: $latitude, $longitude  '
      'UserRadius: ${radiusMeters}m  '
      'GoogleRadius: ${radiusMeters.clamp(1, _googleMaxRadiusMeters)}m',
    );

    // Clamp radius for Google API — max 50 km
    final googleRadius = radiusMeters.clamp(1, _googleMaxRadiusMeters);

    // Run 6 targeted searches concurrently
    final searchQueries = _buildSearchQueries();
    debugPrint('[HelpDesk] Firing ${searchQueries.length} concurrent searches...');

    final futures = searchQueries.map(
      (q) => _runTextSearch(
        query: q.query,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: googleRadius,
        apiKey: apiKey,
        defaultCategory: q.defaultCategory,
        defaultCategoryLabel: q.defaultCategoryLabel,
      ),
    );

    final rawBatches = await Future.wait(futures);

    // Merge all results, deduplicate by Google's stable place ID
    final seen = <String>{};
    final merged = <AgriculturalPlace>[];

    for (final batch in rawBatches) {
      for (final place in batch) {
        if (seen.contains(place.id)) continue;
        seen.add(place.id);
        merged.add(place);
      }
    }

    debugPrint(
      '[HelpDesk] Raw results: ${rawBatches.fold(0, (s, b) => s + b.length)}  '
      'Unique: ${merged.length}',
    );

    // Calculate distance from user and filter to requested radius
    final userCoord = GeoCoordinate(latitude: latitude, longitude: longitude);
    final filtered = merged.where((p) {
      final placeCoord = GeoCoordinate(latitude: p.latitude, longitude: p.longitude);
      final dist = GeometryService.calculateHaversineDistance(userCoord, placeCoord);
      return dist <= radiusMeters;
    }).map((p) {
      final placeCoord = GeoCoordinate(latitude: p.latitude, longitude: p.longitude);
      final dist = GeometryService.calculateHaversineDistance(userCoord, placeCoord);
      return _withDistance(p, dist);
    }).toList();

    // Sort nearest first
    filtered.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    debugPrint(
      '[HelpDesk] Within radius ${radiusMeters}m: ${filtered.length} places',
    );

    // Cache result
    _cache[cacheKey] = _HelpDeskCacheEntry(
      places: filtered,
      fetchedAt: DateTime.now(),
    );

    return filtered;
  }

  // ---------------------------------------------------------------------------
  // Search query definitions
  // ---------------------------------------------------------------------------

  List<_SearchQuery> _buildSearchQueries() {
    return const [
      _SearchQuery(
        query: 'Agricultural laboratory',
        defaultCategory: 'lab',
        defaultCategoryLabel: 'Agricultural Laboratory',
      ),
      _SearchQuery(
        query: 'Soil testing laboratory',
        defaultCategory: 'lab',
        defaultCategoryLabel: 'Soil Testing Laboratory',
      ),
      _SearchQuery(
        query: 'Krishi Vigyan Kendra',
        defaultCategory: 'kvk',
        defaultCategoryLabel: 'Krishi Vigyan Kendra',
      ),
      _SearchQuery(
        query: 'Agricultural research centre',
        defaultCategory: 'research',
        defaultCategoryLabel: 'Agricultural Research Centre',
      ),
      _SearchQuery(
        query: 'Agriculture department office',
        defaultCategory: 'government',
        defaultCategoryLabel: 'Government Agriculture Office',
      ),
      _SearchQuery(
        query: 'Plant disease diagnostic laboratory',
        defaultCategory: 'disease_help',
        defaultCategoryLabel: 'Plant Disease Diagnostic Centre',
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Google Places Text Search (New) — single request
  // ---------------------------------------------------------------------------

  Future<List<AgriculturalPlace>> _runTextSearch({
    required String query,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required String apiKey,
    required String defaultCategory,
    required String defaultCategoryLabel,
  }) async {
    try {
      debugPrint('[HelpDesk] Query: "$query"');

      final requestBody = jsonEncode({
        'textQuery': query,
        'locationBias': {
          'circle': {
            'center': {
              'latitude': latitude,
              'longitude': longitude,
            },
            'radius': radiusMeters.toDouble(),
          },
        },
        'maxResultCount': _maxResultsPerQuery,
        'languageCode': 'en',
      });

      final response = await http
          .post(
            Uri.parse(_placesEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': _fieldMask,
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final places = _parsePlacesResponse(
          data,
          defaultCategory: defaultCategory,
          defaultCategoryLabel: defaultCategoryLabel,
        );
        debugPrint('[HelpDesk] "$query" → ${places.length} results');
        return places;
      } else {
        final body = response.body.length > 200
            ? response.body.substring(0, 200)
            : response.body;
        debugPrint(
          '[HelpDesk] "$query" HTTP ${response.statusCode}: $body',
        );
        return [];
      }
    } on TimeoutException {
      debugPrint('[HelpDesk] "$query" timed out (12s)');
      return [];
    } catch (e) {
      debugPrint('[HelpDesk] "$query" error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Response parsing
  // ---------------------------------------------------------------------------

  List<AgriculturalPlace> _parsePlacesResponse(
    Map<String, dynamic> json, {
    required String defaultCategory,
    required String defaultCategoryLabel,
  }) {
    final places = json['places'] as List<dynamic>? ?? [];
    final result = <AgriculturalPlace>[];

    for (final raw in places) {
      if (raw is! Map<String, dynamic>) continue;

      final id = raw['id'] as String?;
      if (id == null || id.isEmpty) continue;

      final displayNameObj = raw['displayName'] as Map<String, dynamic>?;
      final name = displayNameObj?['text'] as String?;
      if (name == null || name.trim().isEmpty) continue;

      final locationObj = raw['location'] as Map<String, dynamic>?;
      final lat = (locationObj?['latitude'] as num?)?.toDouble();
      final lon = (locationObj?['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final address = raw['formattedAddress'] as String?;
      final phone = raw['nationalPhoneNumber'] as String?;
      final website = raw['websiteUri'] as String?;
      final googleMapsUri = raw['googleMapsUri'] as String?;

      final ratingNum = (raw['rating'] as num?)?.toDouble();
      final ratingStr = ratingNum != null
          ? '${ratingNum.toStringAsFixed(1)} ★'
          : null;

      String? openingHours;
      final hoursObj = raw['regularOpeningHours'] as Map<String, dynamic>?;
      if (hoursObj != null) {
        final isOpen = hoursObj['openNow'] as bool?;
        final weekdayDesc =
            (hoursObj['weekdayDescriptions'] as List<dynamic>?)?.cast<String>();
        if (weekdayDesc != null && weekdayDesc.isNotEmpty) {
          openingHours = weekdayDesc.first;
        } else if (isOpen != null) {
          openingHours = isOpen ? 'Currently open' : 'Currently closed';
        }
      }

      final businessStatus = raw['businessStatus'] as String?;
      if (businessStatus == 'PERMANENTLY_CLOSED') continue;

      final categoryInfo = _categorizePlace(
        name,
        defaultCategory: defaultCategory,
        defaultCategoryLabel: defaultCategoryLabel,
      );

      result.add(
        AgriculturalPlace(
          id: id,
          name: name.trim(),
          category: categoryInfo.category,
          categoryLabel: categoryInfo.label,
          latitude: lat,
          longitude: lon,
          distanceMeters: 0,
          address: address,
          phone: phone?.isNotEmpty == true ? phone : null,
          website: website?.isNotEmpty == true
              ? website
              : (googleMapsUri?.isNotEmpty == true ? null : null),
          openingHours: openingHours,
          rating: ratingStr,
        ),
      );
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Category classification
  // ---------------------------------------------------------------------------

  ({String category, String label}) _categorizePlace(
    String name, {
    required String defaultCategory,
    required String defaultCategoryLabel,
  }) {
    final lower = name.toLowerCase();

    if (lower.contains('disease') ||
        lower.contains('pathology') ||
        lower.contains('protection') ||
        lower.contains('pest diagnosis') ||
        lower.contains('crop health') ||
        lower.contains('phytopathology')) {
      return (
        category: 'disease_help',
        label: 'Plant Disease Diagnostic Centre',
      );
    }

    if (lower.contains('lab') ||
        lower.contains('soil test') ||
        lower.contains('testing') ||
        lower.contains('seed test') ||
        lower.contains('fertilizer test') ||
        lower.contains('pesticide test')) {
      return (category: 'lab', label: 'Agricultural Laboratory');
    }

    if (lower.contains('kvk') ||
        lower.contains('krishi vigyan') ||
        lower.contains('kendra') ||
        lower.contains('extension') ||
        lower.contains('advisory') ||
        lower.contains('farmer training') ||
        lower.contains('kisan')) {
      return (
        category: 'kvk',
        label: 'Krishi Vigyan Kendra / Expert Centre',
      );
    }

    if (lower.contains('research') ||
        lower.contains('icar') ||
        lower.contains('iari') ||
        lower.contains('university') ||
        lower.contains('institute') ||
        lower.contains('college') ||
        lower.contains('crop science') ||
        lower.contains('agronomy')) {
      return (category: 'research', label: 'Agricultural Research Centre');
    }

    if (lower.contains('government') ||
        lower.contains('department') ||
        lower.contains('krishi bhavan') ||
        lower.contains('mandi') ||
        lower.contains('apmc') ||
        lower.contains('samiti') ||
        lower.contains('agriculture office') ||
        lower.contains('ministry')) {
      return (
        category: 'government',
        label: 'Government Agriculture Office',
      );
    }

    return (category: defaultCategory, label: defaultCategoryLabel);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  AgriculturalPlace _withDistance(AgriculturalPlace place, double distanceMeters) {
    return AgriculturalPlace(
      id: place.id,
      name: place.name,
      category: place.category,
      categoryLabel: place.categoryLabel,
      latitude: place.latitude,
      longitude: place.longitude,
      distanceMeters: distanceMeters,
      address: place.address,
      phone: place.phone,
      website: place.website,
      email: place.email,
      openingHours: place.openingHours,
      rating: place.rating,
      operatorName: place.operatorName,
    );
  }

  void clearCache() => _cache.clear();
}

// ---------------------------------------------------------------------------
// Internal types
// ---------------------------------------------------------------------------

class _HelpDeskCacheEntry {
  final List<AgriculturalPlace> places;
  final DateTime fetchedAt;
  const _HelpDeskCacheEntry({
    required this.places,
    required this.fetchedAt,
  });
}

class _SearchQuery {
  final String query;
  final String defaultCategory;
  final String defaultCategoryLabel;

  const _SearchQuery({
    required this.query,
    required this.defaultCategory,
    required this.defaultCategoryLabel,
  });
}
