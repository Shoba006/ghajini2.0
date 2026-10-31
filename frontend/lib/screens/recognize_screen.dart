import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ghajini_app/core/responsive.dart';
import 'package:ghajini_app/core/user_theme.dart';
import 'package:ghajini_app/models/recognition_result.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/widgets/big_button.dart';
import 'package:ghajini_app/widgets/friendly_error.dart';
import 'package:ghajini_app/widgets/status_chip.dart';

/// Elderly-friendly, responsive screen for face recognition in the User App.
/// Pure web and native compatible (zero dart:io dependencies).
/// Uses white + green theme with large buttons and spoken readouts.
class RecognizeScreen extends ConsumerStatefulWidget {
  const RecognizeScreen({super.key});

  @override
  ConsumerState<RecognizeScreen> createState() => _RecognizeScreenState();
}

class _RecognizeScreenState extends ConsumerState<RecognizeScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  RecognitionResult? _result;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();

      setState(() {
        _imageBytes = bytes;
        _result = null;
        _isLoading = true;
        _errorMessage = null;
      });

      final api = ref.read(apiServiceProvider);
      final tts = ref.read(ttsServiceProvider);

      final res = await api.recognizeFaceBytes(bytes, filename: file.name);

      if (mounted) {
        setState(() {
          _result = res;
          _isLoading = false;
        });

        // Automatically speak result out loud for elderly clarity
        final lang = ref.read(currentLanguageProvider);
        await tts.speak(res.message, lang: lang);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "I could not process the photo right now. Please try again or ask family.";
        });
        final lang = ref.read(currentLanguageProvider);
        ref.read(ttsServiceProvider).speak(_errorMessage!, lang: lang);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tts = ref.watch(ttsServiceProvider);
    final currentLang = ref.watch(currentLanguageProvider);

    return Scaffold(
      backgroundColor: UserTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: UserTheme.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: UserTheme.primaryGreen, size: 28),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Who Is This?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: UserTheme.textTitle,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: Responsive.screenPadding(context),
          child: ResponsivePatientContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Instruction banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: UserTheme.primaryLight,
                    borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                    border: Border.all(color: UserTheme.primaryBorder, width: 1.5),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.face_retouching_natural,
                        size: 36,
                        color: UserTheme.primaryGreen,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Show a photo or take a picture to recognize your loved ones.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: UserTheme.primaryGreenDark,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Capture and Gallery Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: BigButton(
                        text: 'Take Photo',
                        icon: Icons.camera_alt,
                        backgroundColor: UserTheme.primaryGreen,
                        textColor: Colors.white,
                        onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: BigButton(
                        text: 'Pick Photo',
                        icon: Icons.photo_library,
                        backgroundColor: Colors.white,
                        textColor: UserTheme.textTitle,
                        borderColor: UserTheme.primaryGreen,
                        onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Loading State
                if (_isLoading)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                    decoration: BoxDecoration(
                      color: UserTheme.cardWhite,
                      borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                      border: Border.all(color: UserTheme.cardBorder),
                    ),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(UserTheme.primaryGreen),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Looking into our family memories...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: UserTheme.primaryGreenDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Error Banner
                if (_errorMessage != null && !_isLoading) ...[
                  FriendlyError(
                    message: _errorMessage!,
                    onRetry: () => _pickImage(ImageSource.gallery),
                  ),
                  const SizedBox(height: 20),
                ],

                // Selected Photo Preview
                if (_imageBytes != null && !_isLoading) ...[
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: UserTheme.primaryBorder, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(
                        _imageBytes!,
                        height: 280,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Recognition Result Card
                if (_result != null && !_isLoading)
                  _buildResultCard(context, _result!, tts, currentLang),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, RecognitionResult res, dynamic tts, String lang) {
    Color cardBg;
    Color borderCol;
    StatusType statusType;
    String statusTitle;

    if (res.isMatch) {
      cardBg = const Color(0xFFF0FDF4);
      borderCol = UserTheme.primaryGreen;
      statusType = StatusType.success;
      statusTitle = 'Recognized';
    } else if (res.isUncertain) {
      cardBg = const Color(0xFFFFFBEB);
      borderCol = const Color(0xFFF59E0B);
      statusType = StatusType.warning;
      statusTitle = 'Looks Familiar';
    } else {
      cardBg = const Color(0xFFEFF6FF);
      borderCol = const Color(0xFF2563EB);
      statusType = StatusType.info;
      statusTitle = 'New or Unknown';
    }

    return Card(
      color: cardBg,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UserTheme.cardRadius),
        side: BorderSide(color: borderCol, width: 2.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                StatusChip(
                  label: statusTitle,
                  type: statusType,
                  fontSize: 18,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Read out loud',
                  icon: const Icon(Icons.volume_up, size: 30, color: UserTheme.primaryGreen),
                  onPressed: () => tts.speak(res.message, lang: lang),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Message text
            Text(
              res.message,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: UserTheme.textTitle,
                height: 1.35,
              ),
            ),

            if (res.person?.notes != null && res.person!.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: UserTheme.cardBorder),
                ),
                child: Text(
                  'Note: ${res.person!.notes}',
                  style: const TextStyle(
                    fontSize: 17,
                    color: UserTheme.textBody,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Read aloud button
            BigButton(
              text: 'Speak Again',
              icon: Icons.volume_up,
              backgroundColor: UserTheme.primaryGreen,
              textColor: Colors.white,
              onPressed: () => tts.speak(res.message, lang: lang),
            ),

            // Uncertain Confirmation: "Is this Priya?" with Yes / No
            if (res.isUncertain && res.person != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      'Is this ${res.person!.name}?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: UserTheme.textTitle,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: BigButton(
                            text: 'Yes',
                            icon: Icons.check,
                            backgroundColor: UserTheme.primaryGreen,
                            textColor: Colors.white,
                            onPressed: () {
                              tts.speak('Great, I have noted this is ${res.person!.name}.', lang: lang);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Confirmed ${res.person!.name}',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  backgroundColor: UserTheme.primaryGreen,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: BigButton(
                            text: 'No',
                            icon: Icons.close,
                            backgroundColor: UserTheme.textMuted,
                            textColor: Colors.white,
                            onPressed: () {
                              tts.speak('Understood. I will ask your family.', lang: lang);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Noted. We will ask your family.',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Unknown Person Options
            if (res.isUnknown) ...[
              const SizedBox(height: 16),
              BigButton(
                text: 'Tell Family About Visitor',
                icon: Icons.notifications_active,
                backgroundColor: UserTheme.emergencyRed,
                textColor: Colors.white,
                onPressed: () async {
                  await ref.read(apiServiceProvider).triggerSOSHelp(
                    note: 'Unknown visitor at the door/camera.',
                  );
                  tts.speak('Your family has been told about this visitor.', lang: lang);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your family has been notified.', style: TextStyle(fontSize: 18)),
                      backgroundColor: UserTheme.primaryGreen,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
