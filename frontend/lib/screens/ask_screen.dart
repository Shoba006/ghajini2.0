import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ghajini_app/core/localization.dart';
import 'package:ghajini_app/core/responsive.dart';
import 'package:ghajini_app/core/theme.dart';
import 'package:ghajini_app/core/user_theme.dart';
import 'package:ghajini_app/models/memory.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/widgets/big_button.dart';
import 'package:ghajini_app/widgets/friendly_error.dart';
import 'package:ghajini_app/widgets/section_card.dart';
import 'package:ghajini_app/widgets/sos_button.dart';
import 'package:ghajini_app/widgets/status_chip.dart';
import 'package:ghajini_app/widgets/voice_orb.dart';

/// Elderly-friendly, responsive screen for Memory Q&A with VoiceOrb.
/// Zero dart:io imports, fully cross-platform (Web, Android, iOS, Tablet, Desktop).
class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key});

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final TextEditingController _questionController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isRecording = false;
  bool _isLoading = false;
  bool _isTranscribing = false;

  String? _transcribedText;
  bool _needsConfirmation = false;

  AskResponseModel? _response;
  String? _errorMessage;

  static const List<Map<String, String>> languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'hi', 'name': 'हिंदी (Hindi)'},
    {'code': 'pa', 'name': 'ਪੰਜਾਬੀ (Punjabi)'},
  ];

  @override
  void dispose() {
    _questionController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        setState(() {
          _isRecording = true;
          _errorMessage = null;
          _needsConfirmation = false;
        });

        // 16 kHz mono wav as per specification
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: kIsWeb ? '' : 'ghajini_voice_temp.wav',
        );
      } else {
        setState(() {
          _errorMessage = "Microphone access is needed to listen. You can also type your question.";
        });
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _errorMessage = "Could not start microphone on this device. Please type your question.";
      });
    }
  }

  Future<void> _stopRecordingAndTranscribe() async {
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
        final detectedLang = result['language'] as String? ?? 'en';

        // Auto-switch language if detected
        if (languages.any((l) => l['code'] == detectedLang)) {
          ref.read(currentLanguageProvider.notifier).state = detectedLang;
        }

        setState(() {
          _isTranscribing = false;
          _transcribedText = text;
          _questionController.text = text;
          _needsConfirmation = needsConf;
        });

        if (text.isNotEmpty && !needsConf) {
          // High confidence: automatically ask question
          await _askQuestion(text);
        }
      } else {
        setState(() => _isTranscribing = false);
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isTranscribing = false;
        _errorMessage = "I had trouble hearing your voice. Please try again or type below.";
      });
    }
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecordingAndTranscribe();
    } else {
      _startRecording();
    }
  }

  Future<void> _askQuestion(String query) async {
    final text = query.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _response = null;
      _needsConfirmation = false;
    });

    final currentLang = ref.read(currentLanguageProvider);
    final api = ref.read(apiServiceProvider);
    final tts = ref.read(ttsServiceProvider);

    try {
      final res = await api.askQuestion(text: text, lang: currentLang).timeout(
        const Duration(seconds: 15),
        onTimeout: () => AskResponseModel(
          answer: AppStrings.get(currentLang, 'notSure'),
          grounded: false,
          sources: [],
        ),
      );

      if (mounted) {
        setState(() {
          _response = res;
          _isLoading = false;
        });

        // Speak answer with mapped locale (en-IN, hi-IN, pa-IN) at rate 0.8
        await tts.speak(res.answer, lang: currentLang);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = AppStrings.get(currentLang, 'notSure');
        });
      }
    }
  }

  Future<void> _callFamily() async {
    final Uri telUri = Uri(scheme: 'tel', path: '+919876543210');
    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else {
        _showCopyPhoneDialog();
      }
    } catch (_) {
      _showCopyPhoneDialog();
    }
  }

  void _showCopyPhoneDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GhajiniTheme.softCream,
        title: const Text('Call Family', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Caregiver phone number:', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            SelectableText(
              '+91 98765 43210',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: GhajiniTheme.primaryOrange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(currentLanguageProvider);
    final tts = ref.watch(ttsServiceProvider);
    final isWide = Responsive.isWide(context);

    return Scaffold(
      backgroundColor: UserTheme.backgroundWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: UserTheme.primaryGreen, size: 26),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppStrings.get(currentLang, 'askGhajini'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: UserTheme.textTitle,
          ),
        ),
        backgroundColor: UserTheme.backgroundWhite,
        foregroundColor: UserTheme.textTitle,
        elevation: 0,
        actions: [
          // Language selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: UserTheme.primaryLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: UserTheme.primaryBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: currentLang,
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.language, color: UserTheme.primaryGreen),
                  style: const TextStyle(
                    fontSize: 16,
                    color: UserTheme.primaryGreenDark,
                    fontWeight: FontWeight.bold,
                  ),
                  items: languages.map((lang) {
                    return DropdownMenuItem<String>(
                      value: lang['code'],
                      child: Text(lang['name']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(currentLanguageProvider.notifier).state = val;
                    }
                  },
                ),
              ),
            ),
          ),
          if (isWide)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CompactSosButton(
                onPressed: () => ref.read(apiServiceProvider).triggerSOSHelp(
                  note: 'SOS triggered from Ask Memory screen',
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: Responsive.screenPadding(context),
          child: ResponsivePatientContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Prompt Header
                Text(
                  'How can I help you today?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: UserTheme.textTitle,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap the big microphone to talk, or write below.',
                  style: TextStyle(
                    fontSize: 17,
                    color: UserTheme.textBody,
                  ),
                ),
                const SizedBox(height: 28),

                // Pulsing Mic Orb
                Center(
                  child: VoiceOrb(
                    isListening: _isRecording,
                    onTap: _toggleRecording,
                    size: 110,
                    baseColor: UserTheme.primaryGreen,
                    activeColor: UserTheme.emergencyRed,
                    label: _isRecording ? 'Listening... Tap to stop' : 'Tap to speak',
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _isRecording
                        ? 'Listening... Tap again when finished'
                        : _isTranscribing
                            ? 'Transcribing your voice...'
                            : 'Tap microphone to speak',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isRecording ? UserTheme.emergencyRed : UserTheme.primaryGreenDark,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Confirmation card for low confidence transcription
                if (_needsConfirmation && _transcribedText != null && _transcribedText!.isNotEmpty)
                  SectionCard(
                    borderColor: GhajiniTheme.amberAccent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.hearing, color: GhajiniTheme.amberAccent, size: 32),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Did I hear you correctly?',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: GhajiniTheme.darkBrown,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '"$_transcribedText"',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: GhajiniTheme.darkBrown,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: BigButton(
                                text: 'Yes, ask this',
                                icon: Icons.check,
                                backgroundColor: GhajiniTheme.successGreen,
                                textColor: Colors.white,
                                onPressed: () => _askQuestion(_transcribedText!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: BigButton(
                                text: 'No, retry',
                                icon: Icons.close,
                                backgroundColor: Colors.white,
                                textColor: GhajiniTheme.darkBrown,
                                borderColor: GhajiniTheme.borderLight,
                                onPressed: () {
                                  setState(() {
                                    _needsConfirmation = false;
                                    _transcribedText = null;
                                    _questionController.clear();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Fallback Text Field
                SectionCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _questionController,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: GhajiniTheme.darkBrown,
                        ),
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g., Where does Priya live?',
                          hintStyle: const TextStyle(color: Colors.black38),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send_rounded, color: UserTheme.primaryGreen, size: 32),
                            onPressed: _isLoading ? null : () => _askQuestion(_questionController.text),
                          ),
                        ),
                        onSubmitted: (val) => _askQuestion(val),
                      ),
                      const SizedBox(height: 14),
                      BigButton(
                        text: 'Ask Ghajini',
                        icon: Icons.search_rounded,
                        backgroundColor: UserTheme.primaryGreen,
                        textColor: Colors.white,
                        onPressed: _isLoading ? null : () => _askQuestion(_questionController.text),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Loading
                if (_isLoading)
                  SectionCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(UserTheme.primaryGreen),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Remembering...',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: UserTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Friendly Error
                if (_errorMessage != null && !_isLoading) ...[
                  FriendlyError(
                    message: _errorMessage!,
                    onRetry: () => _askQuestion(_questionController.text),
                  ),
                  const SizedBox(height: 20),
                ],

                // Answer Display
                if (_response != null && !_isLoading)
                  _buildAnswerCard(context, _response!, tts, currentLang),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              color: GhajiniTheme.softCream,
              child: FullWidthSosButton(
                onPressed: () => ref.read(apiServiceProvider).triggerSOSHelp(
                  note: 'SOS triggered from Ask Memory screen',
                ),
              ),
            ),
    );
  }

  Widget _buildAnswerCard(BuildContext context, AskResponseModel res, dynamic tts, String lang) {
    final isGrounded = res.grounded;
    final cardBg = isGrounded ? GhajiniTheme.successBg : const Color(0xFFFFFBEB);
    final borderCol = isGrounded ? GhajiniTheme.successGreen : GhajiniTheme.amberAccent;

    return Card(
      color: cardBg,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderCol, width: 2.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                StatusChip(
                  label: isGrounded ? 'Grounded Memory' : 'Helpful Guidance',
                  type: isGrounded ? StatusType.success : StatusType.warning,
                  fontSize: 18,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Replay audio',
                  icon: const Icon(Icons.volume_up, size: 32, color: GhajiniTheme.darkBrown),
                  onPressed: () => tts.speak(res.answer, lang: lang),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Answer text
            Text(
              res.answer,
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: GhajiniTheme.darkBrown,
                height: 1.4,
              ),
            ),

            if (res.sources.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Remembered from:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: GhajiniTheme.mutedBrown,
                ),
              ),
              const SizedBox(height: 8),
              ...res.sources.map(
                (src) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 20, color: GhajiniTheme.successGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          src,
                          style: const TextStyle(fontSize: 18, color: GhajiniTheme.darkBrown),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action: Replay Button
            BigButton(
              text: 'Replay Answer',
              icon: Icons.replay_rounded,
              backgroundColor: UserTheme.primaryGreen,
              textColor: Colors.white,
              onPressed: () => tts.speak(res.answer, lang: lang),
            ),

            if (!isGrounded) ...[
              const SizedBox(height: 14),
              BigButton(
                text: 'Call Family For Help',
                icon: Icons.phone_rounded,
                backgroundColor: GhajiniTheme.emergencyRed,
                textColor: Colors.white,
                onPressed: _callFamily,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
