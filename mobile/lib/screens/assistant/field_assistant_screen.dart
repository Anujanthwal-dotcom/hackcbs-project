import 'dart:io';
import 'package:flutter/material.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:image/image.dart' as img_lib;
import 'package:image_picker/image_picker.dart';
import '../../models/field_assessment.dart';
import '../../models/field_point_context.dart';
import '../../models/prediction_result.dart';
import '../../services/assistant_service.dart';
import '../../services/detection_repository.dart';
import '../../services/field_assessment_repository.dart';
import '../../services/language_service.dart';
import '../../services/ml_inference_service.dart';
import '../../services/voice_service.dart';
import '../help_desk/help_desk_screen.dart';
import 'models/chat_message.dart';

/// Point-aware persistent assistant screen anchored to a specific physical GPS coordinate.
///
/// Supports:
/// - Full conversation persistence across app restarts (users/{uid}/detections/{detectionId}/messages)
/// - Progressive reassessment when follow-up images and notes are submitted
/// - Voice input (STT) & Voice output (TTS) with dual Hindi/English support
/// - Seamless expert escalation to Help Desk
class FieldAssistantScreen extends StatefulWidget {
  final FieldPointContext fieldContext;
  final List<File>? initialImages;

  const FieldAssistantScreen({
    super.key,
    required this.fieldContext,
    this.initialImages,
  });

  @override
  State<FieldAssistantScreen> createState() => _FieldAssistantScreenState();
}

class _FieldAssistantScreenState extends State<FieldAssistantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _imagePicker = ImagePicker();
  final _mlService = MLInferenceService();
  final _voiceService = VoiceService.instance;

  final List<ChatMessage> _messages = [];
  bool _isResponding = false;
  bool _isLoadingHistory = true;
  File? _attachedImage;
  PredictionResult? _pendingMlResult;
  bool _isRunningMl = false;
  String _statusText = 'Evaluating field point…';
  bool _isListening = false;

  late FieldPointContext _currentContext;

  @override
  void initState() {
    super.initState();
    _currentContext = widget.fieldContext;
    _voiceService.initialize();
    _voiceService.isListeningNotifier.addListener(_onListeningChanged);
    _loadPersistentHistory();
  }

  void _onListeningChanged() {
    if (mounted) {
      setState(() {
        _isListening = _voiceService.isListening;
      });
    }
  }

  @override
  void dispose() {
    _voiceService.isListeningNotifier.removeListener(_onListeningChanged);
    _voiceService.stopSpeaking();
    _voiceService.stopListening();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Restores persistent chat history for this specific field point from Firestore.
  Future<void> _loadPersistentHistory() async {
    try {
      final savedMessages = await FieldAssessmentRepository.instance.fetchChatMessages(
        _currentContext.userId,
        _currentContext.detectionId,
      );

      if (mounted) {
        setState(() {
          if (savedMessages.isNotEmpty) {
            _messages.addAll(savedMessages);
          } else {
            _initSessionGreeting();
          }
          _isLoadingHistory = false;
        });
        _scrollToBottom();
      }

      if (widget.initialImages != null && widget.initialImages!.isNotEmpty) {
        _handleInitialImage(widget.initialImages!.first);
      }
    } catch (e) {
      debugPrint('[FieldAssistantScreen] History load warning: $e');
      if (mounted) {
        setState(() {
          if (_messages.isEmpty) _initSessionGreeting();
          _isLoadingHistory = false;
        });
      }
    }
  }

  void _initSessionGreeting() {
    final ctx = _currentContext;
    final isFirst = ctx.isFirstVisit;
    final isHindi = LanguageService.instance.isHindi;

    String greeting;
    if (isFirst) {
      greeting = isHindi
          ? '📍 **खेत निरीक्षण बिंदु**\n\n'
              '• **स्थान**: `${ctx.coordsLabel}` (±${ctx.gpsAccuracyMeters?.toStringAsFixed(1) ?? "N/A"}m)\n'
              '• **फसल व लक्षण**: ${ctx.crop} • ${ctx.previousCondition} (${(ctx.previousConfidence * 100).toStringAsFixed(1)}% सटीकता)\n\n'
              'इस खेत बिंदु का मूल्यांकन शुरू करने के लिए नई तस्वीर लें या सवाल पूछें।'
          : '📍 **Inspecting Field Point**\n\n'
              '• **Location**: `${ctx.coordsLabel}` (±${ctx.gpsAccuracyMeters?.toStringAsFixed(1) ?? "N/A"}m)\n'
              '• **Target**: ${ctx.crop} • ${ctx.previousCondition} (${(ctx.previousConfidence * 100).toStringAsFixed(1)}% confidence)\n\n'
              'Take a fresh photo or ask a question to begin this field point assessment.';
    } else {
      final last = ctx.previousAssessments.first;
      greeting = isHindi
          ? '📍 **खेत बिंदु की पुनः समीक्षा**\n\n'
              '• **स्थान**: `${ctx.coordsLabel}`\n'
              '• **फसल**: ${ctx.crop} • ${ctx.previousCondition}\n'
              '• **कुल समीक्षाएं**: ${ctx.reviewCount}\n'
              '• **पिछली स्थिति**: ${last.severityLabel} (${last.progressionLabel})\n\n'
              'रोग की प्रगति जांचने के लिए अनुवर्ती (follow-up) तस्वीर अपलोड करें या अपडेटेड सलाह पूछें।'
          : '📍 **Re-inspecting Field Point**\n\n'
              '• **Location**: `${ctx.coordsLabel}`\n'
              '• **Target**: ${ctx.crop} • ${ctx.previousCondition}\n'
              '• **Previous Visits**: ${ctx.reviewCount}\n'
              '• **Last Severity**: ${last.severityLabel} (${last.progressionLabel})\n\n'
              'Take a follow-up photo to evaluate disease progression or ask for updated guidance.';
    }

    final greetingMsg = ChatMessage(
      id: 'greeting_${DateTime.now().millisecondsSinceEpoch}',
      text: greeting,
      sender: MessageSender.assistant,
      timestamp: DateTime.now(),
    );

    _messages.add(greetingMsg);
    FieldAssessmentRepository.instance.saveChatMessage(
      _currentContext.userId,
      _currentContext.detectionId,
      greetingMsg,
    );
  }

  Future<void> _handleInitialImage(File file) async {
    setState(() {
      _attachedImage = file;
      _isRunningMl = true;
      _pendingMlResult = null;
    });

    try {
      final bytes = await file.readAsBytes();
      final decoded = img_lib.decodeImage(bytes);
      debugPrint('[FP_TRACE] IMAGE_SELECTED\n  path=${file.path}\n  bytes=${bytes.length}\n  width=${decoded?.width ?? 0}\n  height=${decoded?.height ?? 0}');

      final result = await _mlService.classifyImageFile(file);

      if (mounted) {
        setState(() {
          _pendingMlResult = result;
          _isRunningMl = false;
        });
      }
    } catch (e) {
      debugPrint('[FP_TRACE] ML error: $e');
      if (mounted) {
        setState(() => _isRunningMl = false);
      }
    }
  }

  // ── Voice Input (STT) ──────────────────────────────────────────────────────

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _voiceService.stopListening();
      return;
    }

    final isHindi = LanguageService.instance.isHindi;
    final success = await _voiceService.startListening(
      preferredLanguageCode: isHindi ? 'hi' : 'en',
      onResult: (words, confidence) {
        if (mounted && words.isNotEmpty) {
          setState(() {
            _textController.text = words;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );
          });
        }
      },
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isHindi
              ? 'माइक्रोफ़ोन चालू नहीं हो सका। कृपया अनुमतियां जांचें।'
              : 'Voice recognition unavailable. Check microphone permissions.'),
          backgroundColor: const Color(0xFF27421D),
        ),
      );
    }
  }

  // ── Image Attachment ───────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isRunningMl = true);
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (picked == null) {
        setState(() => _isRunningMl = false);
        return;
      }

      final file = File(picked.path);
      setState(() {
        _attachedImage = file;
        _pendingMlResult = null;
      });

      final result = await _mlService.classifyImageFile(file);

      if (mounted) {
        setState(() {
          _pendingMlResult = result;
          _isRunningMl = false;
        });
      }
    } catch (e) {
      debugPrint('[FP_TRACE] ML error: $e');
      if (mounted) {
        setState(() => _isRunningMl = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image processing error: $e')),
        );
      }
    }
  }

  // ── Message Submission & Progression Reassessment ─────────────────────────

  Future<void> _sendMessage() async {
    if (_isListening) {
      await _voiceService.stopListening();
    }

    final text = _textController.text.trim();
    if (text.isEmpty && _attachedImage == null) return;

    final image = _attachedImage;
    final mlResult = _pendingMlResult;

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.isNotEmpty ? text : 'Field inspection follow-up scan',
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      imagePath: image?.path,
      mlResult: mlResult,
    );

    setState(() {
      _messages.add(userMessage);
      _textController.clear();
      _attachedImage = null;
      _pendingMlResult = null;
      _isResponding = true;
      _statusText = 'Evaluating progression with Gemma…';
    });

    _scrollToBottom();

    // Persist user message to Firestore
    FieldAssessmentRepository.instance.saveChatMessage(
      _currentContext.userId,
      _currentContext.detectionId,
      userMessage,
    );

    try {
      final response = await AssistantService.instance.respondToFieldPoint(
        fieldContext: _currentContext,
        query: text,
        imageFile: image,
        mlResult: mlResult,
      );

      final assistantMessage = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: response.text,
        sender: MessageSender.assistant,
        timestamp: DateTime.now(),
        ragSources: response.ragSources,
        llmUsed: response.llmUsed,
      );

      if (mounted) {
        setState(() {
          _messages.add(assistantMessage);
          _isResponding = false;
        });
        _scrollToBottom();
      }

      // Persist assistant message to Firestore
      FieldAssessmentRepository.instance.saveChatMessage(
        _currentContext.userId,
        _currentContext.detectionId,
        assistantMessage,
      );

      // Record structured FieldAssessment
      try {
        final severity = _deduceSeverity(mlResult, response.text);
        final progression = _deduceProgression(_currentContext, mlResult, text);
        final actionLevel = _deduceActionLevel(severity);

        final assessment = FieldAssessment(
          id: '',
          detectionId: _currentContext.detectionId,
          userId: _currentContext.userId,
          createdAt: DateTime.now(),
          crop: mlResult?.crop ?? _currentContext.crop,
          condition: mlResult?.condition ?? _currentContext.previousCondition,
          mlPrediction: mlResult?.predictedClass ?? _currentContext.previousPrediction,
          mlConfidence: mlResult?.confidence ?? _currentContext.previousConfidence,
          severity: severity,
          progressionStatus: progression,
          recommendationSummary: response.text.length > 200
              ? '${response.text.substring(0, 200)}...'
              : response.text,
          actionLevel: actionLevel,
          followUpDays: severity == AssessmentSeverity.worsening || severity == AssessmentSeverity.severe ? 3 : 7,
          farmerQuestion: text,
          imagePath: image?.path,
        );

        final savedId = await FieldAssessmentRepository.instance.saveAssessment(assessment);
        debugPrint('[FieldAssistantScreen] Assessment saved: $savedId');

        final newReviewCount = _currentContext.reviewCount + 1;
        await DetectionRepository.instance.updateDetectionMeta(
          _currentContext.userId,
          _currentContext.detectionId,
          latestSeverity: severity.name,
          latestRecommendation: assessment.recommendationSummary,
          reviewCount: newReviewCount,
          lastReviewedAt: DateTime.now(),
        );

        final updatedAssessments = [assessment, ..._currentContext.previousAssessments];
        _currentContext = FieldPointContext(
          detectionId: _currentContext.detectionId,
          farmId: _currentContext.farmId,
          userId: _currentContext.userId,
          coordinates: _currentContext.coordinates,
          gpsAccuracyMeters: _currentContext.gpsAccuracyMeters,
          crop: assessment.crop,
          previousCondition: assessment.condition,
          previousPrediction: assessment.mlPrediction,
          previousConfidence: assessment.mlConfidence,
          previousAssessments: updatedAssessments,
          lastSeverity: severity.name,
          lastRecommendation: assessment.recommendationSummary,
          reviewCount: newReviewCount,
          lastReviewedAt: DateTime.now(),
          currentWeather: _currentContext.currentWeather,
        );
      } catch (e) {
        debugPrint('[FieldAssistantScreen] Assessment save warning: $e');
      }
    } catch (e, stack) {
      debugPrint('[FP_GEMMA] ERROR: $e\n$stack');
      if (mounted) {
        final errMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: 'Unable to complete field assessment: $e',
          sender: MessageSender.assistant,
          timestamp: DateTime.now(),
        );
        setState(() {
          _messages.add(errMessage);
          _isResponding = false;
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResponding = false;
        });
      }
    }
  }

  AssessmentSeverity _deduceSeverity(PredictionResult? ml, String text) {
    final lower = text.toLowerCase();
    if (lower.contains('severe') || lower.contains('urgent') || lower.contains('critical') || lower.contains('गंभीर')) {
      return AssessmentSeverity.severe;
    }
    if (lower.contains('worsen') || lower.contains('spread') || lower.contains('escalat') || lower.contains('फैल')) {
      return AssessmentSeverity.worsening;
    }
    if (lower.contains('moderate') || lower.contains('मध्यम')) {
      return AssessmentSeverity.moderate;
    }
    if (ml != null && ml.condition == 'Healthy') {
      return AssessmentSeverity.early;
    }
    return AssessmentSeverity.moderate;
  }

  ProgressionStatus _deduceProgression(FieldPointContext ctx, PredictionResult? ml, String farmerQuery) {
    final lowerQuery = farmerQuery.toLowerCase();
    if (lowerQuery.contains('worse') || lowerQuery.contains('spread') || lowerQuery.contains('फैल') || lowerQuery.contains('काम नहीं')) {
      return ProgressionStatus.worsening;
    }
    if (lowerQuery.contains('better') || lowerQuery.contains('improved') || lowerQuery.contains('ठीक')) {
      return ProgressionStatus.improved;
    }
    if (ctx.isFirstVisit) return ProgressionStatus.initial;
    if (ml != null && ml.condition == 'Healthy') return ProgressionStatus.improved;
    if (ctx.lastSeverity == 'early' && ml != null && ml.isValid && ml.condition != 'Healthy') {
      return ProgressionStatus.worsening;
    }
    return ProgressionStatus.stable;
  }

  ActionLevel _deduceActionLevel(AssessmentSeverity severity) {
    switch (severity) {
      case AssessmentSeverity.early:
        return ActionLevel.monitor;
      case AssessmentSeverity.moderate:
        return ActionLevel.integrated;
      case AssessmentSeverity.worsening:
        return ActionLevel.chemical;
      case AssessmentSeverity.severe:
        return ActionLevel.expert;
      case AssessmentSeverity.unknown:
        return ActionLevel.monitor;
    }
  }

  void _showHistorySheet() {
    final l10n = AppLocalizations.of(context)!;
    final isHindi = LanguageService.instance.isHindi;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAFCF5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final assessments = _currentContext.previousAssessments;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.pointAssessmentHistory,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF27421D)),
                  ),
                  Chip(
                    label: Text(isHindi ? '${assessments.length} दौरे' : '${assessments.length} visits'),
                    backgroundColor: const Color(0xFFE8F5E9),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (assessments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      isHindi ? 'इस खेत बिंदु पर कोई पिछला मूल्यांकन नहीं।' : 'No previous assessments at this field point.',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: assessments.length,
                    separatorBuilder: (_, _) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final a = assessments[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isHindi
                                    ? 'दौरा #${assessments.length - index} • ${a.createdAt.toIso8601String().split("T").first}'
                                    : 'Visit #${assessments.length - index} • ${a.createdAt.toIso8601String().split("T").first}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF27421D).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  a.severityLabel,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF27421D)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isHindi
                                ? 'निदान: ${a.crop} • ${a.condition}'
                                : 'Diagnosis: ${a.crop} • ${a.condition}',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                          if (a.recommendationSummary.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${isHindi ? "सलाह" : "Advice"}: ${a.recommendationSummary}',
                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openHelpDesk() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpDeskScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = _currentContext;
    final l10n = AppLocalizations.of(context)!;
    final isHindi = LanguageService.instance.isHindi;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF27421D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.orangeAccent),
                const SizedBox(width: 4),
                Text(
                  isHindi
                      ? 'बिंदु: ${ctx.crop} • ${ctx.previousCondition}'
                      : 'Point: ${ctx.crop} • ${ctx.previousCondition}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Text(
              isHindi
                  ? '${ctx.coordsLabel} • ${ctx.reviewCount} पिछली समीक्षाएँ'
                  : '${ctx.coordsLabel} • ${ctx.reviewCount} previous reviews',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: isHindi ? 'इतिहास देखें' : 'View Point History',
            onPressed: _showHistorySheet,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isListening) _buildListeningBanner(),

          // Messages list
          Expanded(
            child: _isLoadingHistory
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF27421D)),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),

          // Thinking / ML loading bar
          if (_isResponding || _isRunningMl)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFE8F5E9),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF27421D)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isRunningMl
                        ? (isHindi ? 'V4 ML वर्गीकरण चल रहा है…' : 'Running V4 ML classifier…')
                        : _statusText,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF27421D), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          // Quick Action Bar
          if (!_isResponding && !_isRunningMl && _messages.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.support_agent, size: 14, color: Color(0xFF27421D)),
                      label: Text(
                        isHindi ? 'कृषि सहायता केंद्र (Help Desk)' : 'Nearby Agricultural Support',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF27421D)),
                      ),
                      backgroundColor: const Color(0xFFFFF9C4),
                      onPressed: _openHelpDesk,
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFF27421D)),
                      label: Text(l10n.askFollowUp, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF27421D))),
                      backgroundColor: const Color(0xFFE8F5E9),
                      onPressed: () => _focusNode.requestFocus(),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.camera_alt_outlined, size: 14, color: Color(0xFF27421D)),
                      label: Text(l10n.takeAnotherPhoto, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF27421D))),
                      backgroundColor: const Color(0xFFE8F5E9),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.photo_library_outlined, size: 14, color: Color(0xFF27421D)),
                      label: Text(l10n.uploadImage, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF27421D))),
                      backgroundColor: const Color(0xFFE8F5E9),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.map_outlined, size: 14, color: Color(0xFF27421D)),
                      label: Text(l10n.backToMap, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF27421D))),
                      backgroundColor: const Color(0xFFE8F5E9),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),

          // Pending attached image preview
          if (_attachedImage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF1F8E9),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_attachedImage!, width: 48, height: 48, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isHindi ? 'अनुवर्ती तस्वीर संलग्न' : 'Follow-up Photo Attached',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        if (_pendingMlResult != null)
                          Text(
                            'ML: ${_pendingMlResult!.displayTitle} (${_pendingMlResult!.confidencePercentage})',
                            style: TextStyle(fontSize: 11, color: _pendingMlResult!.statusColor, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() {
                      _attachedImage = null;
                      _pendingMlResult = null;
                    }),
                  ),
                ],
              ),
            ),

          // Input field row
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildListeningBanner() {
    final isHindi = LanguageService.instance.isHindi;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFE8F5E9),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isHindi ? '🎙️ बोलिए... KisaanBandhu सुन रहा है' : '🎙️ Listening... Speak your observation',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _voiceService.stopListening(),
            child: const Icon(Icons.stop_circle_outlined, size: 20, color: Color(0xFF2E7D32)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.sender == MessageSender.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF27421D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2)),
          ],
          border: isUser ? null : Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(msg.imagePath!), fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
            ],
            if (isUser)
              Text(
                msg.text,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              )
            else
              MarkdownBody(
                data: msg.text,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
                  strong: const TextStyle(color: Color(0xFF27421D), fontWeight: FontWeight.bold),
                  code: const TextStyle(backgroundColor: Color(0xFFF5F5F5), fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            if (msg.mlResult != null) ...[
              const SizedBox(height: 6),
              Text(
                'ML: ${msg.mlResult!.displayTitle} (${msg.mlResult!.confidencePercentage})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
              ),
            ],
            if (!isUser) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: _voiceService.spokenMessageIdNotifier,
                    builder: (context, spokenId, _) {
                      final isCurrentlySpeaking =
                          _voiceService.isSpeaking && spokenId == msg.id;
                      return IconButton(
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          isCurrentlySpeaking
                              ? Icons.stop_circle_outlined
                              : Icons.volume_up_outlined,
                          color: isCurrentlySpeaking
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF757575),
                        ),
                        tooltip: isCurrentlySpeaking ? 'Stop speaking' : 'Listen',
                        onPressed: () {
                          if (isCurrentlySpeaking) {
                            _voiceService.stopSpeaking();
                          } else {
                            _voiceService.speak(msg.text, messageId: msg.id);
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final l10n = AppLocalizations.of(context)!;
    final isHindi = LanguageService.instance.isHindi;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Color(0xFF27421D), size: 22),
              tooltip: l10n.takePhoto,
              onPressed: () => _pickImage(ImageSource.camera),
            ),
            IconButton(
              icon: const Icon(Icons.photo_library, color: Color(0xFF27421D), size: 22),
              tooltip: l10n.uploadImage,
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.red : const Color(0xFF27421D),
                size: 22,
              ),
              tooltip: isHindi ? 'बोलकर पूछें' : 'Voice Input',
              onPressed: _toggleVoiceInput,
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _attachedImage != null
                      ? (isHindi ? 'इस अनुवर्ती पर नोट्स जोड़ें…' : 'Add notes on this follow-up…')
                      : (isHindi ? 'इस खेत बिंदु के बारे में पूछें…' : 'Ask about this field point…'),
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.black45),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              icon: const Icon(Icons.send, size: 18),
              style: IconButton.styleFrom(backgroundColor: const Color(0xFF27421D)),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
