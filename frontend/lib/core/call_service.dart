import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:ghajini_app/core/theme.dart';
import 'package:ghajini_app/screens/calling_screen.dart';
import 'package:url_launcher/url_launcher.dart';

enum CallOutcome { placed, openedDialer, copiedNumber, cancelled }

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  static CallService get instance => _instance;
  CallService._internal();

  /// Initiates emergency or family calling flow
  Future<void> initiateCallFlow({
    required BuildContext context,
    int patientId = 1,
    required String reason,
    String source = 'call',
    String? lang,
  }) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallingScreen(
          reason: reason,
          source: source,
          patientId: patientId,
        ),
      ),
    );
  }

  /// Cleans phone number string (removes spaces, dashes, brackets)
  static String cleanPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  /// Places a direct phone call from the patient's device SIM.
  ///
  /// - Android: Uses flutter_phone_direct_caller to dial directly using SIM.
  /// - iOS: Opens phone system prompt via url_launcher tel:
  /// - Web / Desktop / Permission Denied / Error: Displays a calm fallback card
  ///   with large phone display, Copy button, and Open Dialer button. Never crashes.
  Future<CallOutcome> placeCall({
    required BuildContext context,
    required String phone,
    required String contactName,
  }) async {
    final cleaned = cleanPhoneNumber(phone);

    // 1. Web or Desktop: Always show calm dialer card
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      return await showFallbackDialerDialog(context, phone: cleaned, contactName: contactName);
    }

    // 2. Mobile Execution
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android: Direct call using SIM
        final bool? success = await FlutterPhoneDirectCaller.callNumber(cleaned);
        if (success == true) {
          return CallOutcome.placed;
        }
      }

      // iOS or Android fallback: url_launcher tel:
      final Uri telUri = Uri.parse('tel:$cleaned');
      if (await canLaunchUrl(telUri)) {
        final launched = await launchUrl(telUri);
        if (launched) {
          return CallOutcome.openedDialer;
        }
      }

      // If cannot launch or permission denied, show friendly card
      if (context.mounted) {
        return await showFallbackDialerDialog(context, phone: cleaned, contactName: contactName);
      }
    } catch (e) {
      debugPrint('[CallService] Mobile direct call exception: $e');
      if (context.mounted) {
        return await showFallbackDialerDialog(context, phone: cleaned, contactName: contactName);
      }
    }

    return CallOutcome.cancelled;
  }

  /// Displays a friendly card with the phone number, a Copy button,
  /// and an Open Dialer button. Ensures patients & caregivers can always reach someone.
  static Future<CallOutcome> showFallbackDialerDialog(
    BuildContext context, {
    required String phone,
    required String contactName,
  }) async {
    CallOutcome outcome = CallOutcome.cancelled;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: GhajiniTheme.cardWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GhajiniTheme.cardRadius),
            side: const BorderSide(color: GhajiniTheme.primaryOrange, width: 2),
          ),
          title: Row(
            children: [
              const Icon(Icons.phone_in_talk, color: GhajiniTheme.primaryOrange, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Call $contactName',
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: GhajiniTheme.darkBrown,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Direct SIM calling is unavailable on this device browser. You can copy the number or open your phone dialer below:',
                style: TextStyle(
                  fontSize: 16,
                  color: GhajiniTheme.darkBrown.withOpacity(0.85),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              // Big readable phone badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: GhajiniTheme.softCream,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: GhajiniTheme.borderOrange, width: 1.5),
                ),
                child: SelectableText(
                  phone,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: GhajiniTheme.darkBrown,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GhajiniTheme.darkBrown,
                        side: const BorderSide(color: GhajiniTheme.borderOrange, width: 1.5),
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.copy, size: 20),
                      label: const Text('Copy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: phone));
                        outcome = CallOutcome.copiedNumber;
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied $phone to clipboard'),
                            backgroundColor: GhajiniTheme.darkBrown,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GhajiniTheme.successGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.dialer_sip, size: 20),
                      label: const Text('Dialer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        outcome = CallOutcome.openedDialer;
                        Navigator.of(ctx).pop();
                        final uri = Uri.parse('tel:$phone');
                        try {
                          await launchUrl(uri);
                        } catch (_) {}
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close', style: TextStyle(fontSize: 16, color: GhajiniTheme.darkBrown)),
            ),
          ],
        );
      },
    );

    return outcome;
  }
}
