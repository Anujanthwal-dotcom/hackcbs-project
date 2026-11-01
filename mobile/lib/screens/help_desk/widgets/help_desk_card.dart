import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app/l10n/app_localizations.dart';
import '../../../../models/agricultural_place.dart';
import '../../../../app/theme/app_theme.dart';

/// Card widget to display a single agricultural support place with real action buttons.
class HelpDeskCard extends StatelessWidget {
  final AgriculturalPlace place;

  const HelpDeskCard({
    super.key,
    required this.place,
  });

  Future<void> _handleCall(BuildContext context) async {
    final uriString = place.cleanPhoneUri;
    if (uriString == null) return;

    try {
      final uri = Uri.parse(uriString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open phone dialer for ${place.phone}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching dialer: $e')),
        );
      }
    }
  }

  Future<void> _handleDirections(BuildContext context) async {
    try {
      // Direct universal Google Maps / Apple Maps directions URL
      final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${place.latitude},${place.longitude}',
      );
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        final geoUrl = Uri.parse('geo:${place.latitude},${place.longitude}?q=${place.latitude},${place.longitude}');
        if (await canLaunchUrl(geoUrl)) {
          await launchUrl(geoUrl);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening maps navigation: $e')),
        );
      }
    }
  }

  Future<void> _handleWebsite(BuildContext context) async {
    final webUrl = place.cleanWebUrl;
    if (webUrl == null) return;

    try {
      final uri = Uri.parse(webUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open website: $webUrl')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening website: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      elevation: 0,
      color: AppTheme.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E9D4), width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Category Badge & Distance
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreenHighlight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(place.icon, size: 14, color: AppTheme.darkGreen),
                      const SizedBox(width: 5),
                      Text(
                        place.categoryLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EFE0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me, size: 12, color: Color(0xFF4A6B35)),
                      const SizedBox(width: 4),
                      Text(
                        place.formattedDistance,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A6B35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Place Name
            Text(
              place.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGreen,
                height: 1.25,
              ),
            ),

            // Operator or organization if present
            if (place.operatorName != null && place.operatorName!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                place.operatorName!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B8060),
                ),
              ),
            ],

            // Address if present
            if (place.hasAddress) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF7A8F6E)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      place.address!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF55694A),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Opening Hours if present
            if (place.hasOpeningHours) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.access_time, size: 14, color: Color(0xFF7A8F6E)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      place.openingHours!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6E8062),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // Action Buttons Row: Call, Directions, Website
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // Call Button (only if valid phone exists)
                if (place.hasPhone)
                  OutlinedButton.icon(
                    onPressed: () => _handleCall(context),
                    icon: const Icon(Icons.call, size: 16),
                    label: Text(l10n?.actionCall ?? 'Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.darkGreen,
                      side: const BorderSide(color: AppTheme.darkGreen, width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),

                // Directions Button (always available since coordinates exist)
                FilledButton.icon(
                  onPressed: () => _handleDirections(context),
                  icon: const Icon(Icons.directions, size: 16),
                  label: Text(l10n?.actionDirections ?? 'Directions'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.darkGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),

                // Website Button (only if website exists)
                if (place.hasWebsite)
                  OutlinedButton.icon(
                    onPressed: () => _handleWebsite(context),
                    icon: const Icon(Icons.language, size: 16),
                    label: Text(l10n?.actionWebsite ?? 'Website'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38572A),
                      side: const BorderSide(color: Color(0xFF9FB68C), width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
