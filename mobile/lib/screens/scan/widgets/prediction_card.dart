import 'package:flutter/material.dart';
import '../../../models/prediction_result.dart';
import '../../../services/language_service.dart';

/// Interactive UI card displaying the V4 ML classification outcome, confidence level,
/// margin, blur score, and full 7-class probability distribution.
class PredictionCard extends StatefulWidget {
  final PredictionResult? result;
  final bool isInferring;
  final VoidCallback? onAdjustThreshold;

  const PredictionCard({
    super.key,
    required this.result,
    this.isInferring = false,
    this.onAdjustThreshold,
  });

  @override
  State<PredictionCard> createState() => _PredictionCardState();
}

class _PredictionCardState extends State<PredictionCard> {
  bool _showAllProbabilities = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final isHindi = LanguageService.instance.isHindi;

    return Card(
      color: const Color(0xFFFAFCF5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E9D4), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title & Latency / Metrics
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5ECCF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.eco_outlined,
                          color: Color(0xFF27421D),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isHindi ? 'एआई फसल निदान (V4)' : 'AI Crop Diagnostics (V4)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF27421D),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (widget.isInferring)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF27421D),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isHindi ? 'जाँच हो रही है...' : 'Analyzing...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5A7250),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                else if (result != null && result.inferenceTimeMs > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E9D4).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${result.inferenceTimeMs} ms',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF27421D),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Main State Display
            if (result == null)
              _buildEmptyState(isHindi)
            else
              _buildResultContent(result, isHindi),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isHindi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1DB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.camera_alt_outlined, color: Color(0xFF38572A), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isHindi
                  ? 'कैमरे को सोयाबीन या कपास की पत्तियों पर रखें, या जाँच के लिए "तस्वीर लें" पर टैप करें।'
                  : 'Point camera at a Soybean or Cotton leaf, or tap "Capture" to scan.',
              style: const TextStyle(
                color: Color(0xFF38572A),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultContent(PredictionResult result, bool isHindi) {
    final statusColor = result.statusColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Primary Classification Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(result.statusIcon, color: statusColor, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.displayTitle,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.displaySubtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: result.isValid
                                ? const Color(0xFF27421D)
                                : statusColor,
                            fontWeight: result.isValid
                                ? FontWeight.w500
                                : FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (result.isValid)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        result.confidencePercentage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),

              // Rejection Details Alert
              if (!result.isValid) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getRejectionExplanation(result, isHindi),
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Metrics Bar: Confidence, Margin & Blur
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1DB).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricChip(
                isHindi ? 'विश्वास स्तर' : 'Confidence',
                result.confidencePercentage,
                result.isConfident ? const Color(0xFF27421D) : Colors.orange,
              ),
              Container(width: 1, height: 24, color: const Color(0xFFD2DEC0)),
              _buildMetricChip(
                isHindi ? 'अंतर' : 'Margin',
                result.marginPercentage,
                !result.isAmbiguous ? const Color(0xFF27421D) : Colors.orange,
              ),
              Container(width: 1, height: 24, color: const Color(0xFFD2DEC0)),
              _buildMetricChip(
                isHindi ? 'स्पष्टता' : 'Image Clarity',
                result.blurScore > 0 ? result.blurScore.toStringAsFixed(0) : 'N/A',
                !result.isBlurry ? const Color(0xFF27421D) : Colors.deepOrange,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 3. Thresholds Indicator & Tuning Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isHindi
                    ? 'सीमाएँ: विश्वास ${(result.confidenceThreshold * 100).toInt()}% • अंतर ${(result.marginThreshold * 100).toInt()}%'
                    : 'Thresholds: Conf ${(result.confidenceThreshold * 100).toInt()}% • Margin ${(result.marginThreshold * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF5A7250),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            if (widget.onAdjustThreshold != null)
              InkWell(
                onTap: widget.onAdjustThreshold,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune, size: 14, color: Color(0xFF27421D)),
                      const SizedBox(width: 4),
                      Text(
                        isHindi ? 'बदलें' : 'Tune',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF27421D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        // 4. Probabilities Breakdown Toggle
        InkWell(
          onTap: () {
            setState(() {
              _showAllProbabilities = !_showAllProbabilities;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showAllProbabilities
                      ? (isHindi ? 'विवरण छिपाएं' : 'Hide 7-Class Breakdown')
                      : (isHindi ? 'सभी 7 श्रेणियों का विवरण देखें' : 'View Full 7-Class Breakdown'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF27421D),
                  ),
                ),
                Icon(
                  _showAllProbabilities
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: const Color(0xFF27421D),
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        // 5. Full 7-Class Probability Table
        if (_showAllProbabilities) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E9D4)),
            ),
            child: Column(
              children: result.allProbabilities.entries.map((entry) {
                final isTop = entry.key == result.predictedClass;
                final probPercent = (entry.value * 100).toStringAsFixed(1);
                final formattedName = _formatClassName(entry.key, isHindi);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isTop ? const Color(0xFFF0F5E6) : Colors.transparent,
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFF0F3E8), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isTop ? const Color(0xFF27421D) : Colors.black26,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          formattedName,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                            color: isTop
                                ? const Color(0xFF27421D)
                                : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        '$probPercent%',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: isTop ? FontWeight.bold : FontWeight.w500,
                          color: isTop
                                ? const Color(0xFF27421D)
                                : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF5A7250)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: color,
          ),
        ),
      ],
    );
  }

  String _getRejectionExplanation(PredictionResult result, bool isHindi) {
    switch (result.state) {
      case InferenceState.imageUnclear:
        return isHindi
            ? 'स्पष्टता स्कोर (${result.blurScore.toStringAsFixed(1)}) आवश्यक सीमा (${result.blurThreshold.toInt()}) से कम है।'
            : 'Clarity score (${result.blurScore.toStringAsFixed(1)}) is below blur threshold (${result.blurThreshold.toInt()}).';
      case InferenceState.uncertainLowConfidence:
        return isHindi
            ? 'विश्वास स्तर (${result.confidencePercentage}) न्यूनतम सीमा (${(result.confidenceThreshold * 100).toInt()}%) से कम है।'
            : 'Confidence (${result.confidencePercentage}) is below threshold (${(result.confidenceThreshold * 100).toInt()}%).';
      case InferenceState.uncertainAmbiguousMargin:
        return isHindi
            ? 'शीर्ष 2 श्रेणियों में अंतर बहुत कम है (अंतर ${result.marginPercentage} < ${(result.marginThreshold * 100).toInt()}%).'
            : 'Top 2 classes are too close (Margin ${result.marginPercentage} < ${(result.marginThreshold * 100).toInt()}%).';
      case InferenceState.negativeUnsupported:
        return isHindi
            ? 'मॉडल ने इस तस्वीर को असमर्थित / गैर-लक्षित श्रेणी में पहचाना है।'
            : 'Model classified image into the negative/unsupported dataset.';
      case InferenceState.validTarget:
        return '';
    }
  }

  String _formatClassName(String raw, bool isHindi) {
    switch (raw) {
      case 'soybean_healthy':
        return isHindi ? 'सोयाबीन • स्वस्थ' : 'Soybean • Healthy';
      case 'soybean_bacterial_blight':
        return isHindi ? 'सोयाबीन • जीवाणु झुलसा रोग' : 'Soybean • Bacterial Blight';
      case 'soybean_whitefly':
        return isHindi ? 'सोयाबीन • सफेद मक्खी' : 'Soybean • Whitefly';
      case 'cotton_healthy':
        return isHindi ? 'कपास • स्वस्थ' : 'Cotton • Healthy';
      case 'cotton_bacterial_blight':
        return isHindi ? 'कपास • जीवाणु झुलसा रोग' : 'Cotton • Bacterial Blight';
      case 'cotton_pink_bollworm':
        return isHindi ? 'कपास • गुलाबी सुंडी' : 'Cotton • Pink Bollworm';
      case 'negative':
        return isHindi ? 'असमर्थित / गैर-लक्षित पौधा' : 'Negative (Unsupported)';
      default:
        return raw;
    }
  }
}
