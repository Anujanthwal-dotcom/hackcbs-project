/// Configuration for Mapbox Maps, Intra-Farm Navigation, and Google Places.
class MapConfig {
  /// Mapbox public access token configured securely via:
  /// `--dart-define=MAPBOX_ACCESS_TOKEN=your_token_here`
  static String get mapboxAccessToken {
    return const String.fromEnvironment('MAPBOX_ACCESS_TOKEN', defaultValue: '');
  }

  /// Google Places API key (New Places API) configured securely via:
  /// `--dart-define=GOOGLE_PLACES_API_KEY=your_key_here`
  static String get googlePlacesApiKey {
    return const String.fromEnvironment('GOOGLE_PLACES_API_KEY', defaultValue: '');
  }

  /// Mapbox satellite style URI for high-detail agricultural crop view.
  static const String satelliteStyleUri = 'mapbox://styles/mapbox/satellite-streets-v12';

  /// Standard outdoors style URI for clear farm trail visualization.
  static const String outdoorsStyleUri = 'mapbox://styles/mapbox/outdoors-v12';

  /// Default starting zoom level when focusing on farm or location.
  static const double defaultZoom = 17.0;

  /// Minimum acceptable GPS accuracy in meters to geotag a crop scan.
  /// Readings with horizontal uncertainty > 25.0 meters will warn the farmer.
  static const double minAcceptableAccuracyMeters = 25.0;

  /// High-accuracy GPS threshold (green badge) in meters.
  static const double highAccuracyThresholdMeters = 5.0;

  /// Distance threshold in meters to trigger arrival at a disease scan point.
  /// Accounts for commercial smartphone GPS horizontal variance (~5-8m).
  static const double arrivalRadiusMeters = 8.0;

  /// Maximum allowed age in seconds for a cached GPS position before re-querying.
  static const int maxLocationAgeSeconds = 30;

  /// Average walking speed in meters/second used for ETA estimation (~4.3 km/h).
  static const double averageWalkingSpeedMps = 1.2;
}
