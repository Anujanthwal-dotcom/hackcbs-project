import 'dart:io';
import 'package:flutter/material.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/assistant_service.dart';
import '../../services/language_service.dart';
import '../../services/llm_service.dart';
import '../../services/llm_provisioning_service.dart';
import '../../services/ml_inference_service.dart';
import '../../services/voice_service.dart';
import '../../models/prediction_result.dart';
import 'models/chat_message.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _imagePicker = ImagePicker();
  final _voiceService = VoiceService.instance;

  final List<ChatMessage> _messages = [];
  bool _isResponding = false;
  File? _attachedImage;
  PredictionResult? _pendingMlResult;
  bool _isRunningMl = false;
  String _statusText = 'Assistant is thinking…';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    LlmProvisioningService.instance.checkModelStatus();
    _voiceService.initialize();
    _voiceService.isListeningNotifier.addListener(_onListeningChanged);
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
    LlmService.instance.releaseMemory();
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
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;

      final file = File(picked.path);
      setState(() {
        _attachedImage = file;
        _pendingMlResult = null;
        _isRunningMl = true;
      });

      // Run ML immediately so result is ready when user sends
      try {
        final result = await MLInferenceService().classifyImageFile(file);
        if (mounted) {
          setState(() {
            _pendingMlResult = result;
            _isRunningMl = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isRunningMl = false);
      }
    } catch (e) {
      debugPrint('[AssistantScreen] Image pick error: $e');
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5EA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD2DEC0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Attach Image',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27421D),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDCE9C7),
                child: Icon(Icons.camera_alt_outlined, color: Color(0xFF27421D)),
              ),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDCE9C7),
                child: Icon(Icons.photo_library_outlined, color: Color(0xFF27421D)),
              ),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _clearAttachment() {
    setState(() {
      _attachedImage = null;
      _pendingMlResult = null;
      _isRunningMl = false;
    });
  }

  /// Finds the most recent ML result in the chat history if no new image is attached.
  PredictionResult? _getMostRecentMlResult() {
    if (_pendingMlResult != null) return _pendingMlResult;
    for (final msg in _messages.reversed) {
      if (msg.mlResult != null) {
        return msg.mlResult;
      }
    }
    return null;
  }

  // ── Send Message ───────────────────────────────────────────────────────────

  Future<void> _handleSubmitted() async {
    if (_isListening) {
      await _voiceService.stopListening();
    }

    final text = _textController.text.trim();
    final image = _attachedImage;
    final mlResult = _pendingMlResult ?? _getMostRecentMlResult();

    if ((text.isEmpty && image == null) || _isResponding) return;

    final displayText = text.isNotEmpty ? text : '(image attached)';

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: displayText,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      imagePath: image?.path,
      mlResult: _pendingMlResult,
    );

    setState(() {
      _messages.add(userMessage);
      _isResponding = true;
      _statusText = 'Retrieving agricultural knowledge…';
      _attachedImage = null;
      _pendingMlResult = null;
      _isRunningMl = false;
    });
    _textController.clear();
    _scrollToBottom();

    final query = text.isNotEmpty
        ? text
        : (mlResult != null && mlResult.isValid
            ? 'What should I do about ${mlResult.crop} ${mlResult.condition}?'
            : 'Explain this image diagnosis and what I should do.');

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _statusText = 'Generating answer with Gemma…');

      final response = await AssistantService.instance.respond(
        query: query,
        imageFile: image,
        mlResult: mlResult,
      );

      if (!mounted) return;

      final assistantMessage = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: response.text,
        sender: MessageSender.assistant,
        timestamp: response.timestamp,
        ragSources: response.ragSources,
        llmUsed: response.llmUsed,
      );

      setState(() {
        _messages.add(assistantMessage);
        _isResponding = false;
      });
    } catch (e) {
      if (!mounted) return;
      final errorMessage = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: 'Something went wrong. Please try again.\n\nError: $e',
        sender: MessageSender.assistant,
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(errorMessage);
        _isResponding = false;
      });
    }

    _scrollToBottom();
  }

  void _clearChat() {
    if (_messages.isEmpty) return;
    _voiceService.stopSpeaking();
    setState(() {
      _messages.clear();
      _isResponding = false;
      _attachedImage = null;
      _pendingMlResult = null;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          l10n.assistantHeader,
          style: const TextStyle(
            color: Color(0xFF27421D),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFF27421D)),
                tooltip: LanguageService.instance.isHindi ? 'बातचीत हटाएं' : 'Clear conversation',
                onPressed: _clearChat,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusBanner(),
            if (_isListening) _buildListeningBanner(),
            Expanded(
              child: _messages.isEmpty ? _buildEmptyState() : _buildMessageList(),
            ),
            if (_isResponding) _buildTypingIndicator(),
            if (_attachedImage != null) _buildImagePreview(),
            _buildInputBar(),
          ],
        ),
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
              isHindi ? '🎙️ बोलिए... KisaanBandhu सुन रहा है' : '🎙️ Listening... Speak your question',
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

  Widget _buildStatusBanner() {
    final prov = LlmProvisioningService.instance;
    return StreamBuilder<ModelDownloadState>(
      stream: prov.stateStream,
      initialData: prov.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? ModelDownloadState.notDownloaded;

        if (state == ModelDownloadState.downloading) {
          return StreamBuilder<double>(
            stream: prov.progressStream,
            initialData: prov.progress,
            builder: (context, progSnap) {
              final progress = progSnap.data ?? 0.0;
              final downloadedMb = (prov.downloadedBytes / 1024 / 1024).toStringAsFixed(1);
              final totalMb = (prov.totalBytes / 1024 / 1024).toStringAsFixed(1);
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFEAF1DB),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF27421D)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Preparing on-device AI: ${(progress * 100).toStringAsFixed(0)}% ($downloadedMb MB / $totalMb MB)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF27421D)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      backgroundColor: const Color(0xFFD2DEC0),
                      color: const Color(0xFF27421D),
                    ),
                  ],
                ),
              );
            },
          );
        }

        if (state == ModelDownloadState.error) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFFDE8E8),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 18, color: Color(0xFFC81E1E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prov.errorMessage ?? 'Download failed. Tap to enter HuggingFace token and retry.',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9B1C1C), height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    debugPrint('[GEMMA-DOWNLOAD] button pressed: Retry Download');
                    _showDownloadDialog();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9B1C1C))),
                ),
              ],
            ),
          );
        }

        if (state == ModelDownloadState.notDownloaded) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF3F5EA),
            child: Row(
              children: [
                const Icon(Icons.download_for_offline_outlined, size: 18, color: Color(0xFF27421D)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'On-device Gemma AI: Local RAG active (Tap to enable on-device LLM generation)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF5A7250)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    debugPrint('[GEMMA-DOWNLOAD] button pressed: Download Gemma 3 1B');
                    _showDownloadDialog();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Download', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF27421D))),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  void _showDownloadDialog() async {
    debugPrint('[GEMMA-DOWNLOAD] dialog opened');
    final savedToken = await LlmProvisioningService.instance.getSavedHfToken();
    final tokenController = TextEditingController(text: savedToken ?? '');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: Color(0xFF27421D)),
            SizedBox(width: 8),
            Text('On-Device Gemma AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF27421D))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gemma 3 1B INT4 (~555 MB) runs 100% offline on your device.\n\n'
              '⚠️ Gated Model: You must accept terms at huggingface.co/litert-community/Gemma3-1B-IT and enter your free HuggingFace User Token (Read role) below.',
              style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF43483E)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: 'HuggingFace Token',
                hintText: 'hf_...',
                border: OutlineInputBorder(),
                isDense: true,
                helperText: 'Created at huggingface.co/settings/tokens',
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF5A7250))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final token = tokenController.text.trim();
              debugPrint('[GEMMA-DOWNLOAD] button pressed: Start Download (token provided: ${token.isNotEmpty ? 'YES' : 'NO'})');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Starting on-device Gemma 3 1B download...'),
                  duration: Duration(seconds: 3),
                ),
              );
              LlmProvisioningService.instance.startDownload(
                hfToken: token.isNotEmpty ? token : null,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27421D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Download'),
          ),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFDCE9C7),
              ),
              child: const Center(
                child: Icon(Icons.smart_toy_outlined, size: 48, color: Color(0xFF27421D)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.assistantTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27421D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.assistantWelcome,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF5A7250)),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _suggestionChip(Icons.help_outline, l10n.quickPrompt1),
                _suggestionChip(Icons.eco_outlined, l10n.quickPrompt2),
                _suggestionChip(Icons.camera_alt_outlined, l10n.quickPrompt3),
                _suggestionChip(Icons.cloud_outlined, l10n.quickPrompt4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: () {
        _textController.text = label;
        _handleSubmitted();
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFFFAFCF5),
        foregroundColor: const Color(0xFF27421D),
        side: const BorderSide(color: Color(0xFFD2DEC0), width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      icon: Icon(icon, size: 15, color: const Color(0xFF27421D)),
      label: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i]),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.sender == MessageSender.user;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFDCE9C7),
                  child: Icon(Icons.smart_toy_outlined, size: 18, color: Color(0xFF27421D)),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (message.imagePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(message.imagePath!),
                          width: 180,
                          height: 130,
                          fit: BoxFit.cover,
                        ),
                      ),
                    if (message.imagePath != null) const SizedBox(height: 6),

                    if (message.mlResult != null) _buildMlBadge(message.mlResult!),
                    if (message.mlResult != null) const SizedBox(height: 6),

                    if (message.text.isNotEmpty && message.text != '(image attached)')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isUser ? const Color(0xFF27421D) : const Color(0xFFEAF1DB),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isUser ? 20 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 20),
                          ),
                        ),
                        child: isUser
                            ? Text(
                                message.text,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: Colors.white,
                                ),
                              )
                            : MarkdownBody(
                                data: message.text,
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: Color(0xFF27421D),
                                  ),
                                  h1: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF27421D),
                                  ),
                                  h2: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF27421D),
                                  ),
                                  h3: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF27421D),
                                  ),
                                  strong: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF27421D),
                                  ),
                                  em: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF27421D),
                                  ),
                                  listBullet: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF27421D),
                                  ),
                                  blockSpacing: 6,
                                  listIndent: 16,
                                ),
                                softLineBreak: true,
                              ),
                      ),
                  ],
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFDCE9C7),
                  child: Icon(Icons.person, size: 18, color: Color(0xFF27421D)),
                ),
              ],
            ],
          ),

          // Assistant speech & RAG sources footer
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 4),
              child: Row(
                children: [
                  // TTS Narration Button
                  ValueListenableBuilder<String>(
                    valueListenable: _voiceService.spokenMessageIdNotifier,
                    builder: (context, spokenId, _) {
                      final isCurrentlySpeaking =
                          _voiceService.isSpeaking && spokenId == message.id;
                      return IconButton(
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          isCurrentlySpeaking
                              ? Icons.stop_circle_outlined
                              : Icons.volume_up_outlined,
                          color: isCurrentlySpeaking
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF5A7250),
                        ),
                        tooltip: isCurrentlySpeaking ? 'Stop speaking' : 'Listen to response',
                        onPressed: () {
                          if (isCurrentlySpeaking) {
                            _voiceService.stopSpeaking();
                          } else {
                            _voiceService.speak(message.text, messageId: message.id);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  if (message.ragSources.isNotEmpty)
                    Expanded(
                      child: _buildRagSourcesRow(message.ragSources, message.llmUsed),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMlBadge(PredictionResult result) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: result.statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: result.statusColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(result.statusIcon, size: 14, color: result.statusColor),
          const SizedBox(width: 4),
          Text(
            result.displayTitle,
            style: TextStyle(
              fontSize: 12,
              color: result.statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (result.isValid) ...[
            const SizedBox(width: 4),
            Text(
              result.confidencePercentage,
              style: TextStyle(fontSize: 11, color: result.statusColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRagSourcesRow(List<String> sources, bool llmUsed) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        if (llmUsed)
          _sourceChip('⚡ Gemma', const Color(0xFF4A90D9)),
        ...sources.take(3).map(
          (s) => _sourceChip(s.length > 30 ? '${s.substring(0, 27)}…' : s, const Color(0xFF5A7250)),
        ),
      ],
    );
  }

  Widget _sourceChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }

  // ── Typing indicator ───────────────────────────────────────────────────────

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFFDCE9C7),
            child: Icon(Icons.smart_toy_outlined, size: 14, color: Color(0xFF27421D)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF1DB),
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF27421D)),
                ),
                const SizedBox(width: 8),
                Text(
                  _statusText,
                  style: const TextStyle(
                    color: Color(0xFF38572A),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Image preview ─────────────────────────────────────────────────────────

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(_attachedImage!, width: 60, height: 60, fit: BoxFit.cover),
              ),
              if (_isRunningMl)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isRunningMl)
                  const Text('Running ML analysis…', style: TextStyle(fontSize: 12, color: Color(0xFF5A7250)))
                else if (_pendingMlResult != null)
                  Text(
                    _pendingMlResult!.displayTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _pendingMlResult!.statusColor,
                    ),
                  )
                else
                  const Text('Image ready', style: TextStyle(fontSize: 12, color: Color(0xFF5A7250))),
                const Text('Image attached', style: TextStyle(fontSize: 11, color: Color(0xFF9DB086))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Color(0xFF5A7250)),
            onPressed: _clearAttachment,
            tooltip: 'Remove image',
          ),
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    final l10n = AppLocalizations.of(context)!;
    final isHindi = LanguageService.instance.isHindi;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.transparent,
      child: Row(
        children: [
          // Attachment button
          _buildAttachButton(),
          const SizedBox(width: 6),

          // Voice input (Microphone) button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening ? Colors.red.shade600 : const Color(0xFFEAF1DB),
              border: Border.all(
                color: _isListening ? Colors.red.shade700 : const Color(0xFFD2DEC0),
                width: 1.5,
              ),
            ),
            child: IconButton(
              onPressed: _isResponding ? null : _toggleVoiceInput,
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.white : const Color(0xFF27421D),
                size: 20,
              ),
              tooltip: isHindi ? 'बोलकर पूछें' : 'Voice Input (Speak)',
            ),
          ),
          const SizedBox(width: 6),

          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFCF5),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFD2DEC0), width: 1.5),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(color: Color(0xFF27421D), fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: l10n.askQuestionHint,
                  hintStyle: const TextStyle(color: Color(0xFF7C946D), fontSize: 13.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _handleSubmitted(),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Send button
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF27421D),
            ),
            child: IconButton(
              onPressed: _isResponding ? null : _handleSubmitted,
              icon: Transform.rotate(
                angle: -0.2,
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 19),
              ),
              tooltip: 'Send',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachButton() {
    final hasImage = _attachedImage != null;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasImage ? const Color(0xFF27421D) : const Color(0xFFEAF1DB),
        border: Border.all(
          color: hasImage ? const Color(0xFF27421D) : const Color(0xFFD2DEC0),
          width: 1.5,
        ),
      ),
      child: IconButton(
        onPressed: _isResponding ? null : _showImageSourceDialog,
        icon: Icon(
          hasImage ? Icons.image : Icons.attach_file_rounded,
          color: hasImage ? Colors.white : const Color(0xFF27421D),
          size: 20,
        ),
        tooltip: 'Attach image',
      ),
    );
  }
}
