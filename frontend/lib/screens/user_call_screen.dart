import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghajini_app/core/responsive.dart';
import 'package:ghajini_app/core/user_theme.dart';
import 'package:ghajini_app/models/person.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/screens/calling_screen.dart';

/// Elderly-friendly screen for Phone 2 to call loved ones, doctors, or caregivers.
/// Shows large, clear contact cards with simple one-touch green "Call" buttons.
class UserCallScreen extends ConsumerWidget {
  const UserCallScreen({super.key});

  void _requestOmniDimCall(BuildContext context, WidgetRef ref, Person person) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UserTheme.cardRadius)),
        title: Text("Request AI Call to ${person.name}?", style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          "Ghajini will initiate an automated AI voice check-in to ${person.name} via OmniDimension.",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel", style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: UserTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final api = ref.read(apiServiceProvider);
                await api.initiateOrchestratedCall(
                  reason: "Patient requested automated OmniDim call with ${person.name}",
                  contactId: person.id,
                  source: "user_app",
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: UserTheme.primaryGreen,
                      content: Text(
                        "AI Call requested for ${person.name} via OmniDimension.",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: UserTheme.emergencyRed,
                      content: Text("Could not request AI call: $e"),
                    ),
                  );
                }
              }
            },
            child: const Text("Request Call", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _initiateCall(BuildContext context, {required String name, required String reason, int contactIndex = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallingScreen(
          reason: reason,
          source: "user_call_screen",
          contactIndex: contactIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleAsync = ref.watch(peopleListProvider);

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
          "Call Someone",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: UserTheme.textTitle,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsivePatientContainer(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quick Call Family Primary Card
                Material(
                  color: UserTheme.primaryLight,
                  borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                    onTap: () => _initiateCall(
                      context,
                      name: "Family",
                      reason: "Patient tapped Quick Call Family",
                      contactIndex: 0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                        border: Border.all(color: UserTheme.primaryBorder, width: 2.0),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: UserTheme.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.phone_rounded, color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 18),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Call Family",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: UserTheme.primaryGreenDark,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Instantly ring your primary caregiver",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: UserTheme.textBody,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: UserTheme.primaryGreen, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Section Label
                const Text(
                  "Loved Ones & Doctors",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: UserTheme.textTitle,
                  ),
                ),
                const SizedBox(height: 12),

                // Contacts List
                peopleAsync.when(
                  data: (people) {
                    if (people.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                          border: Border.all(color: UserTheme.cardBorder),
                        ),
                        child: const Text(
                          "Your family contacts will appear here once registered by your caretaker.",
                          style: TextStyle(fontSize: 17, color: UserTheme.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return Column(
                      children: people.asMap().entries.map((entry) {
                        final index = entry.key;
                        final person = entry.value;
                        return _ContactCard(
                          person: person,
                          onCall: () => _initiateCall(
                            context,
                            name: person.name,
                            reason: "Patient asked to call ${person.name}",
                            contactIndex: index,
                          ),
                          onAiCall: () => _requestOmniDimCall(context, ref, person),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(color: UserTheme.primaryGreen),
                    ),
                  ),
                  error: (_, __) => Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(UserTheme.cardRadius),
                    ),
                    child: const Text(
                      "Contacts temporarily unavailable. You can still use the Call Family button above.",
                      style: TextStyle(fontSize: 16, color: UserTheme.textTitle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Person person;
  final VoidCallback onCall;
  final VoidCallback? onAiCall;

  const _ContactCard({
    required this.person,
    required this.onCall,
    this.onAiCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UserTheme.cardWhite,
        borderRadius: BorderRadius.circular(UserTheme.cardRadius),
        border: Border.all(color: UserTheme.cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: UserTheme.primaryLight,
            child: Text(
              person.name.isNotEmpty ? person.name.substring(0, 1).toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: UserTheme.primaryGreenDark,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: UserTheme.textTitle,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  person.relationship,
                  style: const TextStyle(
                    fontSize: 16,
                    color: UserTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (onAiCall != null) ...[
            IconButton(
              icon: const Icon(Icons.smart_toy_outlined, color: UserTheme.primaryGreen, size: 26),
              tooltip: "Request AI Check-in Call via OmniDimension",
              onPressed: onAiCall,
            ),
            const SizedBox(width: 4),
          ],
          ElevatedButton.icon(
            onPressed: onCall,
            icon: const Icon(Icons.phone, size: 20, color: Colors.white),
            label: const Text("Call", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: UserTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              minimumSize: const Size(80, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

