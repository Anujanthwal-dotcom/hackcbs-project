import 'package:flutter/material.dart';

/// Represents a verified agricultural institution or support center
/// retrieved dynamically from real mapping data (OpenStreetMap / Overpass).
class AgriculturalPlace {
  final String id;
  final String name;
  final String category; // 'lab' | 'expert' | 'kvk' | 'research' | 'government' | 'disease_help' | 'other'
  final String categoryLabel;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final String? address;
  final String? phone;
  final String? website;
  final String? email;
  final String? openingHours;
  final String? rating;
  final String? operatorName;

  const AgriculturalPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryLabel,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.address,
    this.phone,
    this.website,
    this.email,
    this.openingHours,
    this.rating,
    this.operatorName,
  });

  /// Human-friendly distance representation (e.g., "450 m" or "2.4 km").
  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    final km = distanceMeters / 1000.0;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;
  bool get hasWebsite => website != null && website!.trim().isNotEmpty;
  bool get hasAddress => address != null && address!.trim().isNotEmpty;
  bool get hasOpeningHours => openingHours != null && openingHours!.trim().isNotEmpty;

  /// Returns an appropriate icon for the place's category.
  IconData get icon {
    switch (category) {
      case 'lab':
        return Icons.biotech;
      case 'disease_help':
        return Icons.healing;
      case 'kvk':
      case 'expert':
        return Icons.school;
      case 'research':
        return Icons.science;
      case 'government':
        return Icons.account_balance;
      default:
        return Icons.agriculture;
    }
  }

  /// Clean telephone URI representation.
  String? get cleanPhoneUri {
    if (!hasPhone) return null;
    // Strip non-digits and non-+ characters
    final cleaned = phone!.replaceAll(RegExp(r'[^\d+]'), '');
    return cleaned.isNotEmpty ? 'tel:$cleaned' : null;
  }

  /// Clean website URL ensuring valid scheme.
  String? get cleanWebUrl {
    if (!hasWebsite) return null;
    var trimmed = website!.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    return trimmed;
  }
}
