import 'dart:io';
import 'package:flutter/material.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../models/detection_record.dart';
import '../../../models/farm_model.dart';
import '../../../services/geometry_service.dart';
import '../../../services/language_service.dart';

/// Modal bottom sheet displaying detailed dynamic metrics for a tapped disease detection marker.
class FarmMarkerSheet extends StatefulWidget {
  final DetectionRecord scan;
  final GeoCoordinate? currentLocation;
  final VoidCallback onNavigate;
  final Function(List<File> attachedImages) onAskAssistant;
  final VoidCallback? onDelete;

  const FarmMarkerSheet({
    super.key,
    required this.scan,
    this.currentLocation,
    required this.onNavigate,
    required this.onAskAssistant,
    this.onDelete,
  });

  @override
  State<FarmMarkerSheet> createState() => _FarmMarkerSheetState();
}

class _FarmMarkerSheetState extends State<FarmMarkerSheet> {
  final List<File> _attachedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isPickingImage = false;

  Future<void> _confirmDelete(BuildContext context) async {
    final isHindi = LanguageService.instance.isHindi;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E14),
        title: Text(
          isHindi ? 'यह बिंदु हटाएं?' : 'Delete Detection Point?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isHindi
              ? 'क्या आप "${widget.scan.displayTitle}" बिंदु को मानचित्र से हटाना चाहते हैं?'
              : 'Are you sure you want to delete "${widget.scan.displayTitle}" from the map?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isHindi ? 'रद्द करें' : 'Cancel', style: const TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text(isHindi ? 'हटाएं' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      widget.onDelete?.call();
    }
  }

  Future<void> _takePhoto() async {
    try {
      setState(() => _isPickingImage = true);
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
      );
      if (picked != null) {
        setState(() {
          _attachedImages.add(File(picked.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _uploadImage() async {
    try {
      setState(() => _isPickingImage = true);
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked != null) {
        setState(() {
          _attachedImages.add(File(picked.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gallery error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _attachedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final currentLocation = widget.currentLocation;
    final l10n = AppLocalizations.of(context)!;
    final isHindi = LanguageService.instance.isHindi;

    final double? distanceMeters = (currentLocation != null && scan.latitude != null && scan.longitude != null)
        ? GeometryService.calculateHaversineDistance(
            currentLocation,
            GeoCoordinate(latitude: scan.latitude!, longitude: scan.longitude!),
          )
        : null;

    final formattedDate = DateFormat('MMM dd, yyyy • hh:mm a', LanguageService.instance.languageCode).format(scan.createdAt);
    final statusLabel = scan.reviewCount > 0
        ? (isHindi ? 'निगरानी में' : 'Under Observation')
        : (isHindi ? 'पहचान हुई' : 'Detected');

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFCF5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFC4D1B5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header: Detection Point Title & Confidence badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF27421D).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isHindi ? 'निरीक्षण बिंदु' : 'Detection Point',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF27421D),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange, width: 1),
                            ),
                            child: Text(
                              statusLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        scan.displayTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF27421D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${isHindi ? "दिनांक" : "Detected on"} $formattedDate',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: scan.statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scan.statusColor, width: 1.2),
                      ),
                      child: Text(
                        scan.confidencePercentage,
                        style: TextStyle(
                          color: scan.statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (widget.onDelete != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                        tooltip: isHindi ? 'बिंदु हटाएं' : 'Delete Point',
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        onPressed: () => _confirmDelete(context),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Details Grid (GPS Coordinates, Accuracy, Distance)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5EA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isHindi ? 'स्थान निर्देशांक:' : 'Coordinates:', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      Text(
                        '${scan.latitude?.toStringAsFixed(5) ?? "N/A"}, ${scan.longitude?.toStringAsFixed(5) ?? "N/A"}',
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isHindi ? 'जीपीएस सटीकता:' : 'GPS Accuracy:', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      Text(
                        '±${scan.accuracyMeters?.toStringAsFixed(1) ?? "N/A"} m',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  if (distanceMeters != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isHindi ? 'आपसे दूरी:' : 'Distance From You:', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        Text(
                          distanceMeters < 1000
                              ? '${distanceMeters.toStringAsFixed(0)} ${isHindi ? "मी" : "m"}'
                              : '${(distanceMeters / 1000).toStringAsFixed(2)} ${isHindi ? "किमी" : "km"}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Original scan image preview if available
            if (scan.imageUrl != null && File(scan.imageUrl!).existsSync())
              Container(
                height: 90,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: FileImage(File(scan.imageUrl!)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // Previous assessment count chip
            if (scan.reviewCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.history, size: 14, color: Color(0xFF27421D)),
                      label: Text(
                        isHindi ? '${scan.reviewCount} पूर्व निरीक्षण' : '${scan.reviewCount} previous assessments',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF27421D), fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: const Color(0xFFE8F5E9),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    if (scan.latestSeverity != null)
                      Chip(
                        label: Text(
                          '${isHindi ? "अंतिम:" : "Last:"} ${scan.latestSeverity!}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: const Color(0xFFFFF3E0),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),

            // Attached Images for Assistant Section (Thumbnails)
            if (_attachedImages.isNotEmpty) ...[
              Text(
                isHindi
                    ? 'सहायक के लिए संलग्न तस्वीरें (${_attachedImages.length}):'
                    : 'Attached Evidence for Assistant (${_attachedImages.length}):',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF27421D)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachedImages.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (ctx, index) {
                    final img = _attachedImages[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(img, width: 70, height: 70, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkWell(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons Row 1: Navigate, Take Photo, Upload Image
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onNavigate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF27421D),
                      side: const BorderSide(color: Color(0xFF27421D), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.navigation, size: 15),
                    label: Text(l10n.navigate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isPickingImage ? null : _takePhoto,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF27421D),
                      side: const BorderSide(color: Color(0xFF27421D), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.camera_alt, size: 15),
                    label: Text(l10n.takePhoto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isPickingImage ? null : _uploadImage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF27421D),
                      side: const BorderSide(color: Color(0xFF27421D), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.photo_library, size: 15),
                    label: Text(l10n.uploadPhoto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Action Button Row 2: Ask Assistant
            FilledButton.icon(
              onPressed: () => widget.onAskAssistant(_attachedImages),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF27421D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.psychology, size: 18),
              label: Text(
                _attachedImages.isEmpty
                    ? (isHindi ? 'इस बिंदु के बारे में सहायक से पूछें' : 'Ask Assistant about this Point')
                    : (isHindi
                        ? '${_attachedImages.length} तस्वीरों के साथ सहायक से पूछें'
                        : 'Ask Assistant with ${_attachedImages.length} ${_attachedImages.length == 1 ? "Image" : "Images"}'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
