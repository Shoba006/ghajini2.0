import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import 'package:ghajini_app/core/user_theme.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/screens/calling_screen.dart';
import 'package:ghajini_app/services/tts_service.dart';

class CompanionScreen extends ConsumerStatefulWidget {
  const CompanionScreen({super.key});

  @override
  ConsumerState<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends ConsumerState<CompanionScreen> {
  final TextEditingController _textController = TextEditingController();
  final TtsService _ttsService = TtsService();
  final AudioRecorder _audioRecorder = AudioRecorder();

  String _lastMessage = "Hello! I am Ghajini, your memory companion. How can I help you today?";
  bool _isLoading = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _loadingStatus;
  Timer? _timeoutTimer;
  Timer? _proactiveTimer;
  Map<String, dynamic>? _lastPersonCard;
  List<String> _lastActions = [];
  bool _isSpeaking = false;

  // Confidence confirmation dialog state
  bool _showConfirmation = false;
  String _candidateText = "";

  @override
  void initState() {
    super.initState();
    _initTts();
    _startProactivePolling();
  }

  Future<void> _initTts() async {
    await _ttsService.init();
    _speak(_lastMessage);
  }

  void _startProactivePolling() {
    // Poll proactive companion every 30 seconds
    _proactiveTimer?.cancel();
    _proactiveTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final api = ref.read(apiServiceProvider);
        final res = await api.getCompanionProactive();
        if (res['has_message'] == true && res['message'] != null) {
          final msg = res['message'] as Map<String, dynamic>;
          final text = msg['message'] as String? ?? "";
          if (text.isNotEmpty && mounted) {
            setState(() {
              _lastMessage = text;
            });
            _speak(text);
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _speak(String text) async {
    final lang = ref.read(currentLanguageProvider);
    setState(() => _isSpeaking = true);
    await _ttsService.speak(text, lang: lang);
    if (mounted) {
      setState(() => _isSpeaking = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        setState(() {
          _isRecording = true;
          _showConfirmation = false;
        });
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: kIsWeb ? '' : 'companion_voice_temp.wav',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Microphone permission needed. You can also type below.")),
          );
        }
      }
    } catch (_) {
      setState(() => _isRecording = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not start microphone. You can type below.")),
        );
      }
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });

      if (path != null && path.isNotEmpty) {
        final xfile = XFile(path);
        final bytes = await xfile.readAsBytes();
        final api = ref.read(apiServiceProvider);
        final result = await api.transcribeVoiceBytes(bytes, filename: 'voice.wav');

        final text = (result['text'] as String?)?.trim() ?? '';
        final needsConf = result['needs_confirmation'] as bool? ?? false;
        final detectedLang = result['language'] as String? ?? '';

        if (['en', 'hi', 'pa'].contains(detectedLang)) {
          ref.read(currentLanguageProvider.notifier).state = detectedLang;
        }

        if (mounted) {
          setState(() {
            _isTranscribing = false;
          });

          if (text.isNotEmpty) {
            if (needsConf) {
              setState(() {
                _showConfirmation = true;
                _candidateText = text;
              });
            } else {
              _sendMessage(text, source: 'voice');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("I couldn't hear clearly. Please try speaking again.")),
            );
          }
        }
      } else {
        if (mounted) setState(() => _isTranscribing = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isTranscribing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("I had trouble hearing your voice. Please try again or type.")),
        );
      }
    }
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecordingAndSend();
    } else {
      _startRecording();
    }
  }

  Future<void> _sendMessage(String text, {String source = 'text'}) async {
    if (text.trim().isEmpty) return;
    _textController.clear();

    final currentLang = ref.read(currentLanguageProvider);

    setState(() {
      _isLoading = true;
      _loadingStatus = "Let me think...";
      _lastPersonCard = null;
      _lastActions = [];
    });

    // 15-second timeout safety guardrail
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (_isLoading && mounted) {
        final lang = ref.read(currentLanguageProvider);
        setState(() {
          _isLoading = false;
          _lastMessage = lang == 'hi'
              ? "मुझे पक्का नहीं पता। क्या मैं आपके परिवार को फोन करूं?"
              : (lang == 'pa'
                  ? "ਮੈਨੂੰ ਪੱਕਾ नहीं ਪਤਾ। ਕੀ ਮੈਂ ਤੁਹਾਡੇ ਪਰਿਵਾਰ ਨੂੰ ਫ਼ੋਨ ਕਰਾਂ?"
                  : "I am not sure. Shall I call your family?");
        });
        _speak(_lastMessage);
      }
    });

    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.sendCompanionMessage(
        text: text,
        lang: currentLang,
        source: source,
      );

      _timeoutTimer?.cancel();

      if (mounted) {
        final reply = res['reply'] as String? ?? "";
        final person = res['person'] as Map<String, dynamic>?;
        final actions = (res['actions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

        setState(() {
          _isLoading = false;
          _lastMessage = reply;
          _lastPersonCard = person;
          _lastActions = actions;
        });

        // Speak aloud in selected language
        _speak(reply);

        // If action is call_family or show_sos
        if (actions.contains('call_family') || actions.contains('show_sos')) {
          _showEmergencyAlertBanner();
        }
      }
    } catch (_) {
      _timeoutTimer?.cancel();
      if (mounted) {
        final lang = ref.read(currentLanguageProvider);
        setState(() {
          _isLoading = false;
          _lastMessage = lang == 'hi'
              ? "मुझे पक्का नहीं पता। क्या मैं आपके परिवार को फोन करूं?"
              : (lang == 'pa'
                  ? "ਮੈਨੂੰ ਪੱਕਾ नहीं ਪਤਾ। ਕੀ ਮੈਂ ਤੁਹਾਡੇ ਪਰਿਵਾਰ ਨੂੰ ਫ਼ੋਨ ਕਰਾਂ?"
                  : "I am not sure. Shall I call your family?");
        });
        _speak(_lastMessage);
      }
    }
  }

  void _callFamily() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CallingScreen(
          reason: "Patient asked companion to call family",
          source: "companion",
        ),
      ),
    );
  }

  void _triggerSos() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CallingScreen(
          reason: "SOS Button pressed on Companion Screen",
          source: "sos",
        ),
      ),
    );
  }

  void _showEmergencyAlertBanner() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: UserTheme.emergencyRed,
        content: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Caregiver Alert Dispatched. Your family has been notified.",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _proactiveTimer?.cancel();
    _textController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(currentLanguageProvider);

    return Scaffold(
      backgroundColor: UserTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: UserTheme.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: UserTheme.primaryGreen, size: 26),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: const Text(
          "Companion",
          style: TextStyle(
            color: UserTheme.textTitle,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        actions: [
          // Voice Assistant (VoiceOrb) shortcut button
          IconButton(
            tooltip: "Voice Assistant",
            icon: const Icon(Icons.mic_none_rounded, color: UserTheme.primaryGreen, size: 28),
            onPressed: () => context.push('/ask'),
          ),
          // Language selector
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: UserTheme.primaryLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UserTheme.primaryBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentLang,
                dropdownColor: Colors.white,
                style: const TextStyle(color: UserTheme.primaryGreenDark, fontWeight: FontWeight.bold, fontSize: 15),
                items: const [
                  DropdownMenuItem(value: 'hi', child: Text("हिंदी (HI)")),
                  DropdownMenuItem(value: 'en', child: Text("English (EN)")),
                  DropdownMenuItem(value: 'pa', child: Text("ਪੰਜਾਬੀ (PA)")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    ref.read(currentLanguageProvider.notifier).state = val;
                  }
                },
              ),
            ),
          ),
          // SOS Button Always Visible
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _triggerSos,
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              label: const Text("SOS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: UserTheme.emergencyRed,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section: Avatar & Message Display
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Large Friendly Avatar Circle
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: UserTheme.primaryLight,
                        border: Border.all(color: UserTheme.primaryBorder, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: UserTheme.primaryGreen.withOpacity(0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text("🤖", style: TextStyle(fontSize: 44)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirmation banner if speech confidence was low
                    if (_showConfirmation) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Did you ask: '$_candidateText'?",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() => _showConfirmation = false);
                                    _sendMessage(_candidateText, source: 'voice');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: UserTheme.primaryGreen,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text("Yes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 16),
                                OutlinedButton(
                                  onPressed: () => setState(() => _showConfirmation = false),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF92400E)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text("No", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Big Friendly Message Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: UserTheme.cardWhite,
                        borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                        border: Border.all(color: UserTheme.primaryBorder, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isLoading) ...[
                            Row(
                              children: [
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: UserTheme.primaryGreen),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  _loadingStatus ?? "Let me think...",
                                  style: const TextStyle(fontSize: 19, color: UserTheme.textMuted, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              _lastMessage,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: UserTheme.textTitle,
                                height: 1.45,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isSpeaking ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                                  color: UserTheme.primaryGreen,
                                  size: 32,
                                ),
                                onPressed: () => _speak(_lastMessage),
                                tooltip: "Replay speech",
                              ),
                              ElevatedButton.icon(
                                onPressed: _callFamily,
                                icon: const Icon(Icons.phone, size: 18, color: Colors.white),
                                label: const Text("Call Family", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: UserTheme.primaryGreenDark,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // CardioLife quick action card if vitals intent was detected
                    if (_lastActions.contains('show_cardiolife')) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/cardiolife'),
                        icon: const Icon(Icons.favorite, color: Colors.white, size: 22),
                        label: const Text(
                          'Open CardioLife Care / हृदय स्वास्थ्य',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UserTheme.accentOrange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ],

                    // Photo card if person or place was mentioned
                    if (_lastPersonCard != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: UserTheme.primaryLight,
                          borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                          border: Border.all(color: UserTheme.primaryBorder),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: UserTheme.primaryGreen,
                              child: Text(
                                (_lastPersonCard!['name'] as String? ?? "P").substring(0, 1),
                                style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${_lastPersonCard!['name']} (${_lastPersonCard!['relationship']})",
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: UserTheme.primaryGreenDark),
                                  ),
                                  if (_lastPersonCard!['notes'] != null)
                                    Text(
                                      _lastPersonCard!['notes'],
                                      style: const TextStyle(fontSize: 14, color: UserTheme.textBody),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Section: Three Quick Buttons + Push-to-Talk Mic + Text Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Three Quick Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionButton(
                          label: "Who is this?",
                          icon: Icons.person_search,
                          onPressed: () => _sendMessage("Who is this?"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickActionButton(
                          label: "What's next?",
                          icon: Icons.event_note,
                          onPressed: () => _sendMessage("What is next today?"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickActionButton(
                          label: "Call family",
                          icon: Icons.phone_forwarded,
                          onPressed: _callFamily,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Push-to-Talk Large Mic Button (76dp+)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _isTranscribing ? null : _toggleRecording,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRecording
                                  ? UserTheme.emergencyRed
                                  : (_isTranscribing ? UserTheme.accentOrange : UserTheme.primaryGreen),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isRecording ? UserTheme.emergencyRed : UserTheme.primaryGreen).withOpacity(0.35),
                                  blurRadius: _isRecording ? 24 : 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isTranscribing
                                  ? const SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    )
                                  : Icon(
                                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isRecording
                              ? "Listening... Tap to finish"
                              : (_isTranscribing ? "Hearing your voice..." : "Tap to speak"),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _isRecording ? UserTheme.emergencyRed : UserTheme.primaryGreenDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Text input field with send button
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: "Type or ask Ghajini a question...",
                            hintStyle: const TextStyle(color: UserTheme.textMuted),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: UserTheme.cardBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: UserTheme.primaryGreen, width: 2),
                            ),
                          ),
                          onSubmitted: (val) => _sendMessage(val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () => _sendMessage(_textController.text),
                        icon: const Icon(Icons.send_rounded, color: UserTheme.primaryGreen, size: 30),
                        tooltip: "Send message",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: UserTheme.primaryLight,
        foregroundColor: UserTheme.textTitle,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: UserTheme.primaryBorder),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: UserTheme.primaryGreen),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
