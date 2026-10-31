import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghajini_app/core/theme.dart';
import 'package:ghajini_app/models/call_attempt.dart';
import 'package:ghajini_app/providers/app_providers.dart';
import 'package:ghajini_app/widgets/section_card.dart';
import 'package:ghajini_app/widgets/status_chip.dart';
import 'package:intl/intl.dart';

/// Caretaker Call Session Card with interactive 3-attempt timeline inspection.
class CallSessionCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> callData;

  const CallSessionCard({
    super.key,
    required this.callData,
  });

  @override
  ConsumerState<CallSessionCard> createState() => _CallSessionCardState();
}

class _CallSessionCardState extends ConsumerState<CallSessionCard> {
  bool _isExpanded = false;

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('d MMM y • h:mm a').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  String _formatTimeOnly(DateTime? dt) {
    if (dt == null) return '--:--';
    return DateFormat('h:mm:ss a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.callData;
    final String? sessionId = call['call_session_id'] as String?;
    final int attemptNumber = (call['attempt_number'] as num?)?.toInt() ?? 1;
    final String rawStatus = (call['status'] as String? ?? 'initiated').toLowerCase();
    final bool isTechnicalFailure = (call['is_technical_failure'] as bool?) ?? false;

    // Resolve recipient details
    final recipientMap = (call['recipient'] as Map<String, dynamic>?) ??
        (call['contact'] as Map<String, dynamic>?);
    final String recipientName = recipientMap?['name'] as String? ?? 'Family Contact';
    final String recipientPhone = recipientMap?['phone'] as String? ?? '';
    final String reason = call['reason'] as String? ?? 'Scheduled Reminder Call';
    final String dateStr = _formatDateTime(call['created_at'] as String?);

    // Determine overall status
    final bool isCompleted = rawStatus == 'completed' || rawStatus == 'answered';
    final bool isEscalated = rawStatus == 'escalated' || (rawStatus == 'no_answer' && attemptNumber >= 3);
    final bool isNoAnswer = rawStatus == 'no_answer' && !isEscalated;

    Color borderColor = GhajiniTheme.borderLight;
    if (isEscalated) {
      borderColor = GhajiniTheme.emergencyRed;
    } else if (isCompleted) {
      borderColor = GhajiniTheme.successGreen;
    } else if (isNoAnswer) {
      borderColor = GhajiniTheme.primaryOrange;
    }

    return SectionCard(
      borderColor: borderColor,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row: Recipient & Overall Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEscalated
                      ? const Color(0xFFFEE2E2)
                      : (isCompleted ? GhajiniTheme.successBg : GhajiniTheme.softCream),
                ),
                child: Icon(
                  isEscalated
                      ? Icons.warning_amber_rounded
                      : (isCompleted ? Icons.phone_callback : Icons.phone_forwarded),
                  color: isEscalated
                      ? GhajiniTheme.emergencyRed
                      : (isCompleted ? GhajiniTheme.successGreen : GhajiniTheme.primaryOrange),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipientName,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: GhajiniTheme.darkBrown,
                      ),
                    ),
                    if (recipientPhone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        recipientPhone,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: GhajiniTheme.mutedBrown,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildOverallStatusChip(
                rawStatus: rawStatus,
                isCompleted: isCompleted,
                isEscalated: isEscalated,
                isNoAnswer: isNoAnswer,
                isTechnicalFailure: isTechnicalFailure,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reason & Date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: GhajiniTheme.softCream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 20, color: GhajiniTheme.primaryOrange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: GhajiniTheme.darkBrown,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Metadata row: Time & Attempt count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 15,
                  color: GhajiniTheme.mutedBrown,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: GhajiniTheme.cardWhite,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GhajiniTheme.borderLight),
                ),
                child: Text(
                  isEscalated
                      ? '3 of 3 Attempts (Escalated)'
                      : 'Attempt $attemptNumber of 3',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isEscalated ? GhajiniTheme.emergencyRed : GhajiniTheme.darkBrown,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: GhajiniTheme.borderLight),
          const SizedBox(height: 10),

          // Toggle Timeline Button
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: GhajiniTheme.primaryOrange,
                    size: 24,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isExpanded ? 'Hide Attempt Timeline' : 'View Attempt Timeline (1 → 2 → 3)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: GhajiniTheme.primaryOrange,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Timeline Section
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            if (sessionId != null && sessionId.isNotEmpty)
              _buildAttemptsTimeline(sessionId)
            else
              _buildSingleAttemptFallback(call),
          ],
        ],
      ),
    );
  }

  Widget _buildOverallStatusChip({
    required String rawStatus,
    required bool isCompleted,
    required bool isEscalated,
    required bool isNoAnswer,
    required bool isTechnicalFailure,
  }) {
    if (isEscalated) {
      return const StatusChip(
        label: 'ESCALATED',
        icon: Icons.error_rounded,
        type: StatusType.error,
      );
    }
    if (isCompleted) {
      return const StatusChip(
        label: 'COMPLETED',
        icon: Icons.check_circle,
        type: StatusType.success,
      );
    }
    if (isTechnicalFailure) {
      return const StatusChip(
        label: 'TECH ISSUE',
        icon: Icons.warning_amber_rounded,
        type: StatusType.warning,
      );
    }
    if (isNoAnswer) {
      return const StatusChip(
        label: 'NO ANSWER',
        icon: Icons.phone_missed,
        color: GhajiniTheme.primaryOrange,
      );
    }
    return const StatusChip(
      label: 'INITIATED',
      icon: Icons.ring_volume,
      type: StatusType.info,
    );
  }

  Widget _buildAttemptsTimeline(String sessionId) {
    final attemptsAsync = ref.watch(callSessionAttemptsProvider(sessionId));

    return attemptsAsync.when(
      data: (attempts) {
        if (attempts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No separate attempt logs recorded for this session.',
              style: TextStyle(fontSize: 15, color: GhajiniTheme.mutedBrown),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: GhajiniTheme.softCream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GhajiniTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.timeline, size: 20, color: GhajiniTheme.primaryOrange),
                  const SizedBox(width: 8),
                  Text(
                    'Call Attempt Sequence (${attempts.length} of 3)',
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: GhajiniTheme.darkBrown,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < attempts.length; i++) ...[
                _buildTimelineStep(
                  attempt: attempts[i],
                  isLast: i == attempts.length - 1,
                  totalAttempts: attempts.length,
                ),
                if (i < attempts.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 17, top: 2, bottom: 2),
                    child: Container(
                      width: 2.5,
                      height: 18,
                      color: GhajiniTheme.borderLight,
                    ),
                  ),
              ],
              if (attempts.length >= 3 && attempts.any((a) => a.isNoAnswer)) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GhajiniTheme.emergencyRed.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.notification_important, color: GhajiniTheme.emergencyRed, size: 22),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Calling halted after 3 unanswered attempts. Caretaker escalation alert generated.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: GhajiniTheme.emergencyRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text('Could not load attempts: $e', style: const TextStyle(fontSize: 14, color: GhajiniTheme.emergencyRed)),
      ),
    );
  }

  Widget _buildTimelineStep({
    required CallAttempt attempt,
    required bool isLast,
    required int totalAttempts,
  }) {
    final bool isCompleted = attempt.isCompleted;
    final bool isNoAnswer = attempt.isNoAnswer;
    final bool isEscalated = isNoAnswer && attempt.attemptNumber >= 3;
    final bool isTechFail = attempt.isTechnicalFailure;

    Color badgeColor = GhajiniTheme.primaryOrange;
    IconData badgeIcon = Icons.phone_forwarded;
    String statusText = 'Initiated';

    if (isEscalated) {
      badgeColor = GhajiniTheme.emergencyRed;
      badgeIcon = Icons.warning_rounded;
      statusText = 'Escalated (No Answer)';
    } else if (isCompleted) {
      badgeColor = GhajiniTheme.successGreen;
      badgeIcon = Icons.check_circle;
      statusText = 'Completed';
    } else if (isTechFail) {
      badgeColor = GhajiniTheme.amberAccent;
      badgeIcon = Icons.error_outline;
      statusText = 'Technical Failure';
    } else if (isNoAnswer) {
      badgeColor = GhajiniTheme.primaryOrange;
      badgeIcon = Icons.phone_missed;
      statusText = 'No Answer';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number badge
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: badgeColor, width: 2),
          ),
          child: Center(
            child: Text(
              '${attempt.attemptNumber}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: badgeColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Attempt ${attempt.attemptNumber}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: GhajiniTheme.darkBrown,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(badgeIcon, size: 16, color: badgeColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Time: ${_formatTimeOnly(attempt.createdAt)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: GhajiniTheme.mutedBrown,
                ),
              ),
              if (isTechFail && attempt.failureReason != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Reason: ${attempt.failureReason}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: GhajiniTheme.emergencyRed,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleAttemptFallback(Map<String, dynamic> call) {
    final status = (call['status'] as String? ?? 'initiated').toUpperCase();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GhajiniTheme.softCream,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone, size: 20, color: GhajiniTheme.primaryOrange),
          const SizedBox(width: 8),
          Text(
            'Attempt 1: $status',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: GhajiniTheme.darkBrown),
          ),
        ],
      ),
    );
  }
}

