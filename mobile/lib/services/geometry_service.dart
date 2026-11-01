import 'dart:math' as math;
import '../models/farm_model.dart';

/// Geometry validation and GIS geospatial mathematics engine for farm boundaries and intra-farm navigation.
class GeometryService {
  static const double earthRadiusMeters = 6378137.0; // WGS-84 equatorial radius

  /// Validates whether a list of points forms a valid, non-self-intersecting farm boundary.
  /// Returns a record with `isValid` and a user-friendly error message if invalid.
  static ({bool isValid, String? errorMessage}) validateFarmPolygon(List<GeoCoordinate> points) {
    if (points.length < 3) {
      return (
        isValid: false,
        errorMessage: 'A farm boundary requires at least 3 distinct corner points.',
      );
    }

    // Check for valid lat/long ranges
    for (final p in points) {
      if (p.latitude < -90.0 || p.latitude > 90.0 || p.longitude < -180.0 || p.longitude > 180.0) {
        return (
          isValid: false,
          errorMessage: 'One or more coordinates are geographically invalid.',
        );
      }
    }

    // Check for duplicate consecutive points
    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      if (calculateHaversineDistance(p1, p2) < 0.5) {
        return (
          isValid: false,
          errorMessage: 'Points ${i + 1} and ${((i + 1) % points.length) + 1} are too close together.',
        );
      }
    }

    // Check for collinearity (points lying on a single straight line)
    if (_areAllCollinear(points)) {
      return (
        isValid: false,
        errorMessage: 'The selected boundary points lie on a straight line and do not form an enclosed area.',
      );
    }

    // Check for self-intersections
    if (_hasSelfIntersection(points)) {
      return (
        isValid: false,
        errorMessage: 'The farm boundary crosses over itself. Boundary lines must not self-intersect.',
      );
    }

    // Check for meaningful area (> 5 m² to avoid accidental micro-taps)
    final area = calculateGeodesicPolygonArea(points);
    if (area < 5.0) {
      return (
        isValid: false,
        errorMessage: 'The marked area is too small (< 5 m²). Please outline your actual farm plot.',
      );
    }

    return (isValid: true, errorMessage: null);
  }

  /// Calculates the geodesic area of a polygon in square meters on the WGS-84 sphere.
  static double calculateGeodesicPolygonArea(List<GeoCoordinate> points) {
    if (points.length < 3) return 0.0;

    double total = 0.0;
    final int n = points.length;

    for (int i = 0; i < n; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % n];

      final double lat1Rad = p1.latitude * math.pi / 180.0;
      final double lat2Rad = p2.latitude * math.pi / 180.0;
      final double lon1Rad = p1.longitude * math.pi / 180.0;
      final double lon2Rad = p2.longitude * math.pi / 180.0;

      total += (lon2Rad - lon1Rad) * (2.0 + math.sin(lat1Rad) + math.sin(lat2Rad));
    }

    final double area = (total.abs() * earthRadiusMeters * earthRadiusMeters) / 2.0;
    return area;
  }

  /// Calculates the geographic centroid (center of mass) of the polygon vertices.
  static GeoCoordinate calculateCentroid(List<GeoCoordinate> points) {
    if (points.isEmpty) {
      return const GeoCoordinate(latitude: 0, longitude: 0);
    }
    if (points.length == 1) return points.first;

    double sumLat = 0.0;
    double sumLng = 0.0;

    for (final p in points) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }

    return GeoCoordinate(
      latitude: sumLat / points.length,
      longitude: sumLng / points.length,
    );
  }

  /// Computes the bounding box for a set of coordinates (minLat, maxLat, minLng, maxLng).
  static ({double minLat, double maxLat, double minLng, double maxLng}) calculateBoundingBox(
    List<GeoCoordinate> points,
  ) {
    if (points.isEmpty) {
      return (minLat: 0.0, maxLat: 0.0, minLng: 0.0, maxLng: 0.0);
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return (minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng);
  }

  /// Great-circle Haversine distance in meters between two GPS coordinates.
  static double calculateHaversineDistance(GeoCoordinate c1, GeoCoordinate c2) {
    final double lat1Rad = c1.latitude * math.pi / 180.0;
    final double lon1Rad = c1.longitude * math.pi / 180.0;
    final double lat2Rad = c2.latitude * math.pi / 180.0;
    final double lon2Rad = c2.longitude * math.pi / 180.0;

    final double dLat = lat2Rad - lat1Rad;
    final double dLon = lon2Rad - lon1Rad;

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Initial bearing (forward azimuth) in degrees from c1 to c2 (0° - 360°).
  static double calculateBearing(GeoCoordinate c1, GeoCoordinate c2) {
    final double lat1Rad = c1.latitude * math.pi / 180.0;
    final double lon1Rad = c1.longitude * math.pi / 180.0;
    final double lat2Rad = c2.latitude * math.pi / 180.0;
    final double lon2Rad = c2.longitude * math.pi / 180.0;

    final double dLon = lon2Rad - lon1Rad;

    final double y = math.sin(dLon) * math.cos(lat2Rad);
    final double x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

    final double bearingRad = math.atan2(y, x);
    final double bearingDeg = (bearingRad * 180.0 / math.pi + 360.0) % 360.0;

    return bearingDeg;
  }

  /// Ray-casting algorithm to test if a point is geometrically inside a polygon.
  static bool isPointInsidePolygon(GeoCoordinate point, List<GeoCoordinate> polygon) {
    if (polygon.length < 3) return false;

    bool isInside = false;
    final int n = polygon.length;
    final double x = point.longitude;
    final double y = point.latitude;

    for (int i = 0, j = n - 1; i < n; j = i++) {
      final double xi = polygon[i].longitude;
      final double yi = polygon[i].latitude;
      final double xj = polygon[j].longitude;
      final double yj = polygon[j].latitude;

      final bool intersect = ((yi > y) != (yj > y)) &&
          (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (intersect) {
        isInside = !isInside;
      }
    }

    return isInside;
  }

  // --- Internal Geometric Helpers ---

  static bool _areAllCollinear(List<GeoCoordinate> points) {
    if (points.length < 3) return true;
    final p0 = points[0];
    final p1 = points[1];

    for (int i = 2; i < points.length; i++) {
      final pi = points[i];
      // Cross product in 2D space
      final cross = (p1.longitude - p0.longitude) * (pi.latitude - p0.latitude) -
          (p1.latitude - p0.latitude) * (pi.longitude - p0.longitude);
      if (cross.abs() > 1e-10) {
        return false;
      }
    }
    return true;
  }

  static bool _hasSelfIntersection(List<GeoCoordinate> points) {
    final int n = points.length;
    if (n < 4) return false; // Triangles cannot self-intersect unless degraded

    for (int i = 0; i < n; i++) {
      final a1 = points[i];
      final a2 = points[(i + 1) % n];

      // Check against all non-adjacent edges
      for (int j = i + 2; j < n; j++) {
        // Skip comparing first and last edges since they share an endpoint
        if (i == 0 && j == n - 1) continue;

        final b1 = points[j];
        final b2 = points[(j + 1) % n];

        if (_doLineSegmentsIntersect(a1, a2, b1, b2)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _doLineSegmentsIntersect(
    GeoCoordinate p1,
    GeoCoordinate p2,
    GeoCoordinate p3,
    GeoCoordinate p4,
  ) {
    double ccw(GeoCoordinate a, GeoCoordinate b, GeoCoordinate c) {
      return (c.latitude - a.latitude) * (b.longitude - a.longitude) -
          (b.latitude - a.latitude) * (c.longitude - a.longitude);
    }

    final double d1 = ccw(p3, p4, p1);
    final double d2 = ccw(p3, p4, p2);
    final double d3 = ccw(p1, p2, p3);
    final double d4 = ccw(p1, p2, p4);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }

    return false;
  }
}
