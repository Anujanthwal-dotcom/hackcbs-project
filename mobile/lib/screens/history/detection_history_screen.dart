import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/detection_record.dart';
import '../../services/auth_service.dart';
import '../../services/detection_repository.dart';
import '../../widgets/nature_background.dart';

/// User-specific detection history screen displaying diagnosed plant pests and diseases.
class DetectionHistoryScreen extends StatefulWidget {
  const DetectionHistoryScreen({super.key});

  @override
  State<DetectionHistoryScreen> createState() => _DetectionHistoryScreenState();
}

class _DetectionHistoryScreenState extends State<DetectionHistoryScreen> {
  final _detectionRepository = DetectionRepository.instance;
  final _authService = AuthService.instance;

  String _filterCrop = 'All'; // 'All', 'Soybean', 'Cotton'

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUid;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Detection History',
          style: TextStyle(
            color: Color(0xFF27421D),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: NatureBackground(
        child: uid == null
            ? _buildUnauthenticatedState()
            : Column(
                children: [
                  // Filter Chips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        _buildFilterChip('All'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Soybean'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Cotton'),
                      ],
                    ),
                  ),

                  // Detection Records List
                  Expanded(
                    child: StreamBuilder<List<DetectionRecord>>(
                      stream: _detectionRepository.streamUserDetections(uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF27421D),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cloud_off, size: 48, color: Colors.orange.shade700),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Unable to load history',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF27421D),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${snapshot.error}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF5A7250)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final allRecords = snapshot.data ?? [];
                        final filteredRecords = _filterCrop == 'All'
                            ? allRecords
                            : allRecords.where((r) => r.crop.toLowerCase().contains(_filterCrop.toLowerCase())).toList();

                        if (filteredRecords.isEmpty) {
                          return _buildEmptyState();
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: filteredRecords.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final record = filteredRecords[index];
                            return _buildDetectionCard(record, uid);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filterCrop == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF27421D),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF27421D),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      backgroundColor: const Color(0xFFEAF1DB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD2DEC0)),
      ),
      onSelected: (_) {
        setState(() {
          _filterCrop = label;
        });
      },
    );
  }

  Widget _buildDetectionCard(DetectionRecord record, String uid) {
    final statusColor = record.statusColor;
    final formattedDate = DateFormat('MMM d, y • h:mm a').format(record.createdAt);

    return Card(
      color: const Color(0xFFFAFCF5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E9D4), width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showRecordDetailsSheet(record, uid),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Crop / Condition Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Icon(
                    record.condition == 'Healthy' ? Icons.eco : Icons.bug_report,
                    color: statusColor,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title & Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.displayTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formattedDate,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF5A7250)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Confidence: ${record.confidencePercentage}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (record.margin > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            'Margin: ${(record.margin * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF5A7250)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right, color: Color(0xFF7A936A)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF1DB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_outlined, size: 40, color: Color(0xFF27421D)),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Detections Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27421D),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Diagnose crop diseases or pests using the Camera Scan tab. Your private diagnosis history will be saved here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF5A7250)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnauthenticatedState() {
    return const Center(
      child: Text(
        'Please sign in to view your diagnosis history.',
        style: TextStyle(fontSize: 14, color: Color(0xFF5A7250)),
      ),
    );
  }

  void _showRecordDetailsSheet(DetectionRecord record, String uid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAFCF5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    record.displayTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: record.statusColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _detectionRepository.deleteDetection(uid, record.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Detection record deleted.')),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Crop', record.crop),
              _buildDetailRow('Diagnosis', record.condition),
              _buildDetailRow('Raw Class', record.prediction),
              _buildDetailRow('Confidence', record.confidencePercentage),
              _buildDetailRow('Margin', '${(record.margin * 100).toStringAsFixed(1)}%'),
              _buildDetailRow('Clarity Score', record.blurScore > 0 ? record.blurScore.toStringAsFixed(1) : 'N/A'),
              _buildDetailRow('Date', DateFormat('MMMM d, y • h:mm:ss a').format(record.createdAt)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF27421D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF5A7250))),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF27421D),
            ),
          ),
        ],
      ),
    );
  }
}
