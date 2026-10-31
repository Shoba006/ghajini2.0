import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghajini_app/core/call_service.dart';
import 'package:ghajini_app/core/responsive.dart';
import 'package:ghajini_app/core/theme.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/widgets/big_button.dart';

enum CallingStep {
  requesting,
  calling,
  inCall,
  outcomePrompt,
  escalatePrompt,
  completed,
  blocked,
}

class CallingScreen extends ConsumerStatefulWidget {
  final String reason;
  final String source;
  final int patientId;
  final int contactIndex;

  const CallingScreen({
    super.key,
    required this.reason,
    required this.source,
    this.patientId = 1,
    this.contactIndex = 0,
  });

  @override
  ConsumerState<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends ConsumerState<CallingScreen> with SingleTickerProviderStateMixin {
  CallingStep _step = CallingStep.requesting;
  String? _callId;
  Map<String, dynamic>? _contact;
  Map<String, dynamic>? _nextContact;
  bool _hasNextContact = false;
  String _patientMessage = "I am calling your family. Please stay right here.";
  String _blockReason = "";
  int _countdownSeconds = 5;
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _initiateCallRequest());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initiateCallRequest() async {
    try {
      final api = ref.read(apiServiceProvider);
      final lang = ref.read(languageProvider);

      final res = await api.requestCall(
        reason: widget.reason,
        source: widget.source,
        patientId: widget.patientId,
        lang: lang,
        contactIndex: widget.contactIndex,
      );

      final allowed = res['allowed'] as bool? ?? false;
      if (!allowed) {
        if (mounted) {
          setState(() {
            _step = CallingStep.blocked;
            _blockReason = res['block_reason'] as String? ?? "Call limit or safety policy reached.";
          });
        }
        return;
      }

      final callId = res['id'] as String?;
      final contactData = res['contact'] as Map<String, dynamic>?;
      final nextContactData = res['next_contact'] as Map<String, dynamic>?;
      final hasNext = res['has_next_contact'] as bool? ?? false;
      final patientMsg = res['patient_message'] as String? ?? "I am calling family for you. Please stay here.";

      if (mounted) {
        setState(() {
          _callId = callId;
          _contact = contactData;
          _nextContact = nextContactData;
          _hasNextContact = hasNext;
          _patientMessage = patientMsg;
          _step = CallingStep.calling;
        });

        // 1. Speak reassuring message to patient
        final tts = ref.read(ttsServiceProvider);
        tts.speak(_patientMessage);

        // 2. Start countdown (5s cancel window unless emergency)
        final isEmergency = widget.source.toLowerCase().contains("sos") ||
            widget.source.toLowerCase().contains("emergency");
        _countdownSeconds = isEmergency ? 2 : 5;

        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) return;
          if (_countdownSeconds <= 1) {
            timer.cancel();
            _dialContact();
          } else {
            setState(() {
              _countdownSeconds--;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = CallingStep.blocked;
          _blockReason = "Could not reach call coordinator. Please try again.";
        });
      }
    }
  }

  Future<void> _dialContact() async {
    _countdownTimer?.cancel();
    if (_contact == null) return;

    final phone = _contact!['phone'] as String? ?? "+919876543210";
    final name = _contact!['name'] as String? ?? "Caregiver";

    if (mounted) {
      setState(() {
        _step = CallingStep.inCall;
      });
    }

    // Place SIM call via CallService
    await CallService().placeCall(
      context: context,
      phone: phone,
      contactName: name,
    );

    // After user returns from call/dialer, ask "Did they answer?"
    if (mounted) {
      setState(() {
        _step = CallingStep.outcomePrompt;
      });
      final tts = ref.read(ttsServiceProvider);
      tts.speak("Did $name answer your call?");
    }
  }

  void _cancelCall() async {
    _countdownTimer?.cancel();
    if (_callId != null) {
      try {
        final api = ref.read(apiServiceProvider);
        await api.reportCallResult(callId: _callId!, status: "cancelled", note: "User cancelled in 5s window");
      } catch (_) {}
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _recordAnswered() async {
    if (_callId != null) {
      try {
        final api = ref.read(apiServiceProvider);
        await api.reportCallResult(callId: _callId!, status: "answered");
      } catch (_) {}
    }

    final name = _contact?['name'] ?? "your family";
    final tts = ref.read(ttsServiceProvider);
    tts.speak("I am glad you connected with $name. Take care.");

    if (mounted) {
      setState(() {
        _step = CallingStep.completed;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  Future<void> _recordNotAnswered() async {
    if (_callId != null) {
      try {
        final api = ref.read(apiServiceProvider);
        final res = await api.reportCallResult(callId: _callId!, status: "not_answered");
        if (res['has_next_contact'] == true && res['next_contact'] != null) {
          _nextContact = res['next_contact'] as Map<String, dynamic>?;
          _hasNextContact = true;
        }
      } catch (_) {}
    }

    if (mounted) {
      if (_hasNextContact && _nextContact != null) {
        setState(() {
          _step = CallingStep.escalatePrompt;
        });
        final nextName = _nextContact!['name'] ?? "next family contact";
        final tts = ref.read(ttsServiceProvider);
        tts.speak("Would you like me to call $nextName now?");
      } else {
        setState(() {
          _step = CallingStep.completed;
        });
        final tts = ref.read(ttsServiceProvider);
        tts.speak("Help is on the way. Your alert has been sent to your family.");
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    }
  }

  void _callNextContact() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallingScreen(
          reason: widget.reason,
          source: widget.source,
          patientId: widget.patientId,
          contactIndex: widget.contactIndex + 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactName = _contact?['name'] ?? "Caregiver";
    final relationship = _contact?['relationship'] ?? "Family";
    final phone = _contact?['phone'] ?? "";

    return Scaffold(
      backgroundColor: GhajiniTheme.softCream,
      body: SafeArea(
        child: Responsive(
          compact: _buildContent(contactName, relationship, phone, isWide: false),
          medium: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: _buildContent(contactName, relationship, phone, isWide: true),
            ),
          ),
          expanded: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: _buildContent(contactName, relationship, phone, isWide: true),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(String name, String rel, String phone, {required bool isWide}) {
    switch (_step) {
      case CallingStep.requesting:
        return _buildLoadingView("Connecting to family...");

      case CallingStep.blocked:
        return _buildBlockedView();

      case CallingStep.calling:
      case CallingStep.inCall:
        return _buildCallingView(name, rel, phone);

      case CallingStep.outcomePrompt:
        return _buildOutcomePromptView(name);

      case CallingStep.escalatePrompt:
        return _buildEscalatePromptView();

      case CallingStep.completed:
        return _buildCompletedView(name);
    }
  }

  Widget _buildLoadingView(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: GhajiniTheme.primaryOrange, strokeWidth: 4),
          const SizedBox(height: 24),
          Text(
            text,
            style: const TextStyle(fontFamily: 'serif', fontSize: 24, fontWeight: FontWeight.bold, color: GhajiniTheme.darkBrown),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedView() {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 72, color: GhajiniTheme.primaryOrange),
          const SizedBox(height: 20),
          const Text(
            "Call Paused",
            style: TextStyle(fontFamily: 'serif', fontSize: 28, fontWeight: FontWeight.bold, color: GhajiniTheme.darkBrown),
          ),
          const SizedBox(height: 16),
          Text(
            _blockReason,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, color: GhajiniTheme.darkBrown, height: 1.4),
          ),
          const SizedBox(height: 36),
          BigButton(
            label: "Back to Home",
            icon: Icons.home,
            color: GhajiniTheme.primaryOrange,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCallingView(String name, String rel, String phone) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.close, size: 30, color: GhajiniTheme.darkBrown),
                onPressed: _cancelCall,
              ),
            ],
          ),

          // Central Avatar & Call Info
          Column(
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GhajiniTheme.primaryOrange.withOpacity(0.15),
                    border: Border.all(color: GhajiniTheme.primaryOrange, width: 4),
                  ),
                  child: const Center(
                    child: Icon(Icons.phone_in_talk, size: 70, color: GhajiniTheme.primaryOrange),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Calling $name...",
                style: const TextStyle(fontFamily: 'serif', fontSize: 32, fontWeight: FontWeight.bold, color: GhajiniTheme.darkBrown),
              ),
              const SizedBox(height: 8),
              Text(
                rel.toUpperCase(),
                style: const TextStyle(fontSize: 18, letterSpacing: 1.5, fontWeight: FontWeight.bold, color: GhajiniTheme.successGreen),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: GhajiniTheme.borderOrange, width: 1.5),
                ),
                child: Text(
                  _patientMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, color: GhajiniTheme.darkBrown, height: 1.4),
                ),
              ),
            ],
          ),

          // Bottom Controls
          Column(
            children: [
              if (_step == CallingStep.calling)
                Text(
                  "Dialing in $_countdownSeconds seconds...",
                  style: TextStyle(fontSize: 18, color: GhajiniTheme.darkBrown.withOpacity(0.7)),
                ),
              const SizedBox(height: 14),
              BigButton(
                label: "Call Now",
                icon: Icons.call,
                color: GhajiniTheme.successGreen,
                onPressed: _dialContact,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  side: const BorderSide(color: GhajiniTheme.emergencyRed, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _cancelCall,
                child: const Text("Cancel Call", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: GhajiniTheme.emergencyRed)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomePromptView(String name) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.help_outline, size: 70, color: GhajiniTheme.primaryOrange),
          const SizedBox(height: 24),
          Text(
            "Did $name answer?",
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'serif', fontSize: 32, fontWeight: FontWeight.bold, color: GhajiniTheme.darkBrown),
          ),
          const SizedBox(height: 12),
          Text(
            "Let me know if you spoke with $name or if you need to reach someone else.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: GhajiniTheme.darkBrown.withOpacity(0.85), height: 1.4),
          ),
          const SizedBox(height: 40),
          BigButton(
            label: "YES, THEY ANSWERED",
            icon: Icons.check_circle_outline,
            color: GhajiniTheme.successGreen,
            onPressed: _recordAnswered,
          ),
          const SizedBox(height: 16),
          BigButton(
            label: "NO, DID NOT ANSWER",
            icon: Icons.cancel_outlined,
            color: GhajiniTheme.emergencyRed,
            onPressed: _recordNotAnswered,
          ),
        ],
      ),
    );
  }

  Widget _buildEscalatePromptView() {
    final nextName = _nextContact?['name'] ?? "Next contact";
    final nextRel = _nextContact?['relationship'] ?? "Family";

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.contact_phone, size: 70, color: GhajiniTheme.primaryOrange),
          const SizedBox(height: 24),
          Text(
            "Call $nextName next?",
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'serif', fontSize: 30, fontWeight: FontWeight.bold, color: GhajiniTheme.darkBrown),
          ),
          const SizedBox(height: 12),
          Text(
            "Since the first contact did not answer, we can immediately call $nextName ($nextRel).",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: GhajiniTheme.darkBrown, height: 1.4),
          ),
          const SizedBox(height: 36),
          BigButton(
            label: "Call $nextName",
            icon: Icons.phone_forwarded,
            color: GhajiniTheme.successGreen,
            onPressed: _callNextContact,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 58),
              side: const BorderSide(color: GhajiniTheme.borderOrange, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("I'm Okay Now", style: TextStyle(fontSize: 20, color: GhajiniTheme.darkBrown, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedView(String name) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified, size: 80, color: GhajiniTheme.successGreen),
            const SizedBox(height: 24),
            const Text(
              "Call Complete",
              style: TextStyle(fontFamily: 'serif', fontSize: 32, fontWeight: FontWeight.bold, color: GhajiniTheme.darkBrown),
            ),
            const SizedBox(height: 12),
            Text(
              "Your companion is here for you throughout the day.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: GhajiniTheme.darkBrown.withOpacity(0.85)),
            ),
          ],
        ),
      ),
    );
  }
}
