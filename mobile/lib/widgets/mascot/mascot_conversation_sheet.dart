import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../services/agent_runtime.dart';
import '../../services/ai_mode_manager.dart';
import '../../services/global_context_engine.dart';
import '../../services/guided_demo_service.dart';
import '../../services/language_service.dart';
import '../../services/voice_service.dart';

/// Message model for the Ambient Mascot conversation
class MascotMessage {
  final String id;
  final String text;
  final bool isUser;
  final bool isOffline;
  final List<String> toolsExecuted;
  final DateTime timestamp;

  MascotMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.isOffline = false,
    this.toolsExecuted = const [],
    required this.timestamp,
  });
}

/// Expanded Conversational Interface for the Global AI Mascot
class MascotConversationSheet extends StatefulWidget {
  final VoidCallback onMinimize;
  final String? initialQuery;
  final bool initialVoiceMode;

  const MascotConversationSheet({
    super.key,
    required this.onMinimize,
    this.initialQuery,
    this.initialVoiceMode = false,
  });

  @override
  State<MascotConversationSheet> createState() => _MascotConversationSheetState();
}

class _MascotConversationSheetState extends State<MascotConversationSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final VoiceService _voiceService = VoiceService.instance;
  final AiModeManager _modeManager = AiModeManager.instance;
  final AgentRuntime _runtime = AgentRuntime.instance;

  static final List<MascotMessage> _chatHistory = [];
  bool _isThinking = false;
  String _statusMessage = 'Krishi Mitra is listening...';
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _autoVoiceOutput = false;
  String _voiceLanguage = 'hi'; // Default voice recognition language: Hindi (Devanagari)
  bool _isAwaitingDemoConfirmation = false;

  @override
  void initState() {
    super.initState();
    _voiceService.initialize();
    _voiceService.isListeningNotifier.addListener(_onVoiceListeningChanged);
    _voiceService.isSpeakingNotifier.addListener(_onVoiceSpeakingChanged);
    _runtime.addListener(_onRuntimeChanged);

    if (_chatHistory.isEmpty) {
      _chatHistory.add(
        MascotMessage(
          id: 'welcome',
          text: 'नमस्ते किसान भाई! मैं आपका कृषि मित्र (Bandhu) हूँ। 🌱\n\nआप माइक दबाकर बोल सकते हैं या "Hey, Bandhu" कहकर मुझसे अपने खेत, फसल रोग या ऐप के किसी भी फीचर के बारे में पूछ सकते हैं।',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    }

    if (widget.initialVoiceMode) {
      _autoVoiceOutput = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
        _textController.text = widget.initialQuery!.trim();
        _handleSendMessage();
      } else if (widget.initialVoiceMode) {
        _toggleVoiceInput();
      }
    });
  }

  void _onVoiceListeningChanged() {
    if (mounted) {
      setState(() {
        _isListening = _voiceService.isListening;
      });
    }
  }

  void _onVoiceSpeakingChanged() {
    if (mounted) {
      setState(() {
        _isSpeaking = _voiceService.isSpeaking;
      });
    }
  }

  void _onRuntimeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _voiceService.isListeningNotifier.removeListener(_onVoiceListeningChanged);
    _voiceService.isSpeakingNotifier.removeListener(_onVoiceSpeakingChanged);
    // Do not stop speaking if guided demo is actively starting/running
    if (!GuidedDemoService.instance.isRunning) {
      _voiceService.stopSpeaking();
    }
    _runtime.removeListener(_onRuntimeChanged);
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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Detects wake words like "Hey, Bandhu", "Hey Bandhu", "हे बंधु", "नमस्ते बंधु"
  bool _detectWakeWord(String text) {
    return VoiceService.detectWakeWord(text);
  }

  /// Strips the wake word prefix so the AI receives the clean question
  String _stripWakeWord(String text) {
    return VoiceService.stripWakeWord(text);
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _voiceService.stopListening();
      return;
    }

    if (_isSpeaking) {
      await _voiceService.stopSpeaking();
    }

    final success = await _voiceService.startListening(
      preferredLanguageCode: _voiceLanguage,
      onResult: (words, confidence) {
        if (mounted && words.isNotEmpty) {
          setState(() {
            _textController.text = words;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );
            // If farmer uses voice or wake word, automatically enable voice output
            _autoVoiceOutput = true;
          });

          // Check if farmer said wake word in speech
          if (VoiceService.detectWakeWord(words)) {
            _autoVoiceOutput = true;
          }
        }
      },
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_voiceLanguage == 'hi'
              ? 'माइक्रोफ़ोन शुरू नहीं हो सका। कृपया अनुमति जाँचें।'
              : 'Microphone unavailable. Check permissions.'),
        ),
      );
    }
  }

  void _triggerDemoConfirmation(String userPrompt) {
    final isHi = _voiceLanguage == 'hi' || LanguageService.instance.isHindi;

    final userMsg = MascotMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: userPrompt,
      isUser: true,
      timestamp: DateTime.now(),
    );

    final promptText = isHi
        ? 'क्या आप किसान बंधु के संपूर्ण लाइव ऑटो-डेमो के लिए तैयार हैं? 🚀\n\nमैं आपको सभी मुख्य पृष्ठों (फसल रोग स्कैनर, खेत नक्शा, हेल्प डेस्क, प्रोफाइल) पर ले जाकर हर एक फीचर को लाइव वॉयस और स्क्रीन हाइलाइट के साथ विस्तार से समझाऊँगा। जजों के सामने आप बीच में कभी भी रोक (Pause) सकते हैं!'
        : 'Ready for the experience? 🚀\n\nI will take you on a complete hands-free guided tour across all screens of KisaanBandhu, highlighting every key feature with live voice narration and animated screen focus. You can pause anytime to explain things to the judges!';

    final agentMsg = MascotMessage(
      id: 'demo_confirmation_request',
      text: promptText,
      isUser: false,
      timestamp: DateTime.now(),
    );

    setState(() {
      _chatHistory.add(userMsg);
      _chatHistory.add(agentMsg);
      _isAwaitingDemoConfirmation = true;
      _isThinking = false;
    });

    _textController.clear();
    _scrollToBottom();

    if (_autoVoiceOutput) {
      final voicePrompt = isHi
          ? 'क्या आप किसान बंधु के लाइव ऑटो-डेमो के लिए तैयार हैं? नीचे हाँ पर टैप करें।'
          : 'Ready for the live guided demo experience? Tap Start Demo below.';
      _voiceService.speak(voicePrompt, languageCode: isHi ? 'hi' : 'en');
    }
  }

  void _confirmAndLaunchDemo() {
    _voiceService.stopSpeaking();
    _isAwaitingDemoConfirmation = false;
    final lang = _voiceLanguage;

    // Reserve the demo slot SYNCHRONOUSLY before the sheet pop begins.
    // This ensures GlobalMascotOverlay's whenComplete → _startWakeWordListening
    // sees isRunningOrLaunching = true and does NOT restart the mic listener,
    // which would pick up TTS audio and re-open this sheet.
    GuidedDemoService.instance.reserveLaunch();

    widget.onMinimize(); // Drop the mascot chat sheet immediately

    // Delay slightly (300ms) until sheet pop transition settles,
    // ensuring Step 1 audio begins cleanly and is not cut off by sheet disposal
    Future.delayed(const Duration(milliseconds: 300), () {
      GuidedDemoService.instance.startDemo(languageCode: lang);
    });
  }

  void _cancelDemo() {
    final isHi = _voiceLanguage == 'hi' || LanguageService.instance.isHindi;
    setState(() {
      _isAwaitingDemoConfirmation = false;
      _chatHistory.add(
        MascotMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: isHi
              ? 'डेमो रद्द किया गया। आप कोई अन्य प्रश्न पूछ सकते हैं।'
              : 'Demo cancelled. You can ask me anything else!',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _handleSendMessage() async {
    final rawText = _textController.text.trim();
    if (rawText.isEmpty || _isThinking) return;

    if (_isListening) {
      await _voiceService.stopListening();
    }

    // Check for Wake Up Word: "Hey, Bandhu"
    final hadWakeWord = _detectWakeWord(rawText);
    if (hadWakeWord) {
      _autoVoiceOutput = true;
    }

    final cleanQuery = hadWakeWord ? _stripWakeWord(rawText) : rawText;
    final queryToSend = cleanQuery.isNotEmpty ? cleanQuery : rawText;
    final lower = queryToSend.toLowerCase().trim();

    // 1. If currently awaiting demo confirmation:
    if (_isAwaitingDemoConfirmation) {
      if (lower.contains('yes') ||
          lower.contains('start') ||
          lower.contains('हाँ') ||
          lower.contains('शुरू') ||
          lower.contains('chalu') ||
          lower.contains('ready') ||
          lower.contains('ok') ||
          lower.contains('sure')) {
        _textController.clear();
        _confirmAndLaunchDemo();
        return;
      } else if (lower.contains('no') ||
          lower.contains('cancel') ||
          lower.contains('नहीं') ||
          lower.contains('रद्द')) {
        _textController.clear();
        _cancelDemo();
        return;
      }
    }

    // 2. Check if this is the "Start Demo" action word (voice or text)!
    if (GuidedDemoService.isDemoTrigger(queryToSend)) {
      _triggerDemoConfirmation(rawText);
      return;
    }

    final userMsg = MascotMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: rawText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _chatHistory.add(userMsg);
      _isThinking = true;
      _statusMessage = _modeManager.isOfflineMode
          ? 'Searching local agricultural knowledge...'
          : 'Analyzing farm context & consulting Gemini...';
    });
    _textController.clear();
    _scrollToBottom();

    // Build history items
    final historyPayload = _chatHistory
        .take(_chatHistory.length - 1)
        .map((m) => {
              'role': m.isUser ? 'user' : 'model',
              'text': m.text,
            })
        .toList();

    final response = await _modeManager.processMessage(
      query: queryToSend,
      conversationHistory: historyPayload,
    );

    if (!mounted) return;

    final agentMsg = MascotMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      text: response.text,
      isUser: false,
      isOffline: response.isOffline,
      toolsExecuted: response.toolsExecuted,
      timestamp: response.timestamp,
    );

    setState(() {
      _chatHistory.add(agentMsg);
      _isThinking = false;
    });

    _scrollToBottom();

    // Automatically speak response aloud if wake word was used or voice output is active
    if (_autoVoiceOutput && response.text.isNotEmpty) {
      _voiceService.speak(response.text, messageId: agentMsg.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = LanguageService.instance.isHindi;
    final isOffline = _modeManager.isOfflineMode;
    final currentScreen = GlobalContextEngine.instance.currentScreen;
    final selectedFarm = GlobalContextEngine.instance.selectedFarm;
    final pendingAction = _runtime.pendingAction;

    return Container(
      height: MediaQuery.of(context).size.height * 0.84,
      decoration: const BoxDecoration(
        color: Color(0xFFF3F5EA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Drag Handle & Header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFE5ECCF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8BAE68).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Mascot Leaf Avatar
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF27421D),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF8BAE68), width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          '🌱',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isHindi ? 'कृषि मित्र (Bandhu)' : 'Krishi Mitra',
                                style: const TextStyle(
                                  color: Color(0xFF27421D),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Online/Offline pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOffline ? Colors.orange.shade800 : const Color(0xFF2E7D32),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isOffline ? 'OFFLINE' : 'ONLINE',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selectedFarm != null
                                ? 'Context: $currentScreen • ${selectedFarm.name}'
                                : 'Screen Context: $currentScreen',
                            style: const TextStyle(
                              color: Color(0xFF5A7250),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Voice Output (TTS) Toggle
                    IconButton(
                      icon: Icon(
                        _autoVoiceOutput ? Icons.volume_up : Icons.volume_off_outlined,
                        color: _autoVoiceOutput ? const Color(0xFF27421D) : Colors.grey,
                        size: 22,
                      ),
                      tooltip: _autoVoiceOutput ? 'Voice Output ON' : 'Voice Output OFF (Wake word: "Hey, Bandhu")',
                      onPressed: () {
                        setState(() {
                          _autoVoiceOutput = !_autoVoiceOutput;
                        });
                        if (!_autoVoiceOutput && _isSpeaking) {
                          _voiceService.stopSpeaking();
                        }
                      },
                    ),

                    // Minimize button
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF27421D), size: 26),
                      onPressed: widget.onMinimize,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Speaking Audio Indicator Bar ──────────────────────────────────
          if (_isSpeaking)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFFE8F5E9),
              child: Row(
                children: [
                  const Icon(Icons.record_voice_over, size: 16, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Bandhu is speaking...',
                      style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _voiceService.stopSpeaking(),
                    icon: const Icon(Icons.stop_circle_outlined, size: 16, color: Colors.red),
                    label: const Text('Stop', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
            ),

          // ── Offline Warning / Mode Switcher Bar ────────────────────────────
          if (isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFFFFF3E0),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isHindi
                          ? 'ऑफलाइन मोड: ऑन-डिवाइस जेमा व आरएजी ज्ञान आधार सक्रिय है।'
                          : 'Offline mode active: Using on-device Gemma & local RAG.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _modeManager.checkOnlineAvailability(),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    child: const Text('Retry Online', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // ── Conversation Messages ──────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final msg = _chatHistory[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // ── Human-In-The-Loop Confirmation Card (e.g. Rename Farm) ────────
          if (pendingAction != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3516),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF8BAE68), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security, color: Color(0xFFC7E898), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Approval Required: ${pendingAction.title}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pendingAction.description,
                    style: const TextStyle(color: Color(0xFFE2E9D4), fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _runtime.cancelPendingAction(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white30),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () async {
                          final res = await _runtime.confirmPendingAction();
                          setState(() {
                            _chatHistory.add(MascotMessage(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              text: '✓ $res',
                              isUser: false,
                              timestamp: DateTime.now(),
                            ));
                          });
                          if (_autoVoiceOutput) {
                            _voiceService.speak(res);
                          }
                          _scrollToBottom();
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Confirm & Save'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF76BA1B),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ── Thinking Status Bar ────────────────────────────────────────────
          if (_isThinking)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF27421D)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF27421D),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Quick Suggestion Chips (Includes Start Live Demo) ─────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.rocket_launch_rounded, size: 14, color: Colors.white),
                  label: Text(
                    isHindi ? '🚀 लाइव डेमो शुरू करें' : '🚀 Start Live Demo',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFF27421D),
                  side: const BorderSide(color: Color(0xFF76BA1B), width: 1.2),
                  onPressed: () => _triggerDemoConfirmation('Start demo'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.qr_code_scanner, size: 14, color: Color(0xFF27421D)),
                  label: Text(
                    isHindi ? 'फसल रोग जांच' : 'Scan Disease',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF27421D)),
                  ),
                  backgroundColor: const Color(0xFFE5ECCF),
                  side: const BorderSide(color: Color(0xFFC5D9A5)),
                  onPressed: () {
                    _textController.text = isHindi ? 'मेरी फसल में रोग की जांच कैसे करें?' : 'How to scan crop disease?';
                    _handleSendMessage();
                  },
                ),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.map_outlined, size: 14, color: Color(0xFF27421D)),
                  label: Text(
                    isHindi ? 'खेत नक्शा' : 'Farm Map',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF27421D)),
                  ),
                  backgroundColor: const Color(0xFFE5ECCF),
                  side: const BorderSide(color: Color(0xFFC5D9A5)),
                  onPressed: () {
                    _textController.text = isHindi ? 'खेत का नक्शा दिखाओ' : 'Show farm map';
                    _handleSendMessage();
                  },
                ),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.support_agent, size: 14, color: Color(0xFF27421D)),
                  label: Text(
                    isHindi ? 'हेल्प डेस्क' : 'Help Desk',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF27421D)),
                  ),
                  backgroundColor: const Color(0xFFE5ECCF),
                  side: const BorderSide(color: Color(0xFFC5D9A5)),
                  onPressed: () {
                    _textController.text = isHindi ? 'हेल्प डेस्क खोलो' : 'Open help desk';
                    _handleSendMessage();
                  },
                ),
              ],
            ),
          ),

          // ── Voice Language Selector Pill Bar ──────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F5EA),
              border: Border(top: BorderSide(color: Color(0xFFE2E9D4), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        _isListening ? Icons.graphic_eq : Icons.record_voice_over_outlined,
                        size: 14,
                        color: _isListening ? const Color(0xFFC62828) : const Color(0xFF5A7250),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _voiceLanguage == 'hi' ? 'आवाज़ पहचान: हिन्दी' : 'Voice Input: English',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isListening ? const Color(0xFFC62828) : const Color(0xFF27421D),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCE9C7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_voiceLanguage != 'hi') {
                            setState(() => _voiceLanguage = 'hi');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _voiceLanguage == 'hi' ? const Color(0xFF27421D) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '🇮🇳 हिन्दी',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _voiceLanguage == 'hi' ? Colors.white : const Color(0xFF27421D),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (_voiceLanguage != 'en') {
                            setState(() => _voiceLanguage = 'en');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _voiceLanguage == 'en' ? const Color(0xFF27421D) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '🇬🇧 Eng',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _voiceLanguage == 'en' ? Colors.white : const Color(0xFF27421D),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Input Bar with Mic & Send ──────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).viewInsets.bottom + 8
                  : 18,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFE5ECCF),
              border: Border(top: BorderSide(color: Color(0xFFD2DEC0), width: 1)),
            ),
            child: Row(
              children: [
                // Speech to text button
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.red : const Color(0xFF27421D),
                  ),
                  tooltip: _voiceLanguage == 'hi'
                      ? 'माइक दबाकर बोलें (या कहें "Hey, Bandhu")'
                      : 'Tap to speak (or say "Hey, Bandhu")',
                  onPressed: _toggleVoiceInput,
                ),
                // Text input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFC5D9A5)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSendMessage(),
                      decoration: InputDecoration(
                        hintText: _voiceLanguage == 'hi'
                            ? 'हिन्दी में बोलें या प्रश्न लिखें...'
                            : 'Say "Hey, Bandhu" or type question...',
                        hintStyle: const TextStyle(color: Color(0xFF8B9E7E), fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF27421D),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                    onPressed: _handleSendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MascotMessage msg) {
    if (msg.id == 'demo_confirmation_request') {
      final isHi = _voiceLanguage == 'hi' || LanguageService.instance.isHindi;
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3516),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF76BA1B), width: 1.8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF76BA1B).withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF76BA1B).withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF9EEB49), size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isHi ? 'लाइव ऑटो-डेमो अनुभव (Live Demo)' : 'Live Automated Demo Experience',
                    style: const TextStyle(
                      color: Color(0xFF9EEB49),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              msg.text,
              style: const TextStyle(color: Color(0xFFE2E9D4), fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _cancelDemo,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isHi ? 'रद्द करें' : 'Cancel'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _confirmAndLaunchDemo,
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                    label: Text(
                      isHi ? 'हाँ, डेमो शुरू करें' : 'Yes, Start Demo',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF76BA1B),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: const Color(0xFF27421D),
            borderRadius: BorderRadius.circular(18).copyWith(bottomRight: const Radius.circular(2)),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18).copyWith(bottomLeft: const Radius.circular(2)),
          border: Border.all(color: const Color(0xFFD2DEC0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tool execution chips if any
            if (msg.toolsExecuted.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: msg.toolsExecuted.map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF81C784)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, size: 12, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 4),
                        Text(
                          t,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            // Markdown text
            MarkdownBody(
              data: msg.text,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: Color(0xFF1E2F16), fontSize: 13.5, height: 1.4),
                strong: const TextStyle(color: Color(0xFF27421D), fontWeight: FontWeight.bold),
              ),
            ),
            // Interactive in-app guidance button if tools spotlighted or navigated to an element
            if (msg.toolsExecuted.any((t) =>
                t.toLowerCase().contains('highlight') ||
                t.toLowerCase().contains('navigat') ||
                t.toLowerCase().contains('हाइलाइट') ||
                t.toLowerCase().contains('स्क्रीन') ||
                t.toLowerCase().contains('rename_farm'))) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.onMinimize,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF27421D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                  label: const Text(
                    '📍 स्क्रीन पर बटन देखें (View on Screen)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            // Read aloud button for this specific response
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.volume_up_outlined, size: 18, color: Color(0xFF5A7250)),
                tooltip: 'Listen to answer',
                onPressed: () => _voiceService.speak(msg.text, messageId: msg.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
