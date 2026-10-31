import 'package:flutter/material.dart';
import 'package:ghajini_app/core/theme.dart';
import 'package:ghajini_app/widgets/status_chip.dart';

class ReminderCard extends StatelessWidget {
  final String title;
  final String? message;
  final String scheduledTime;
  final String? frequency;
  final bool isCritical;
  final String status;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onSnooze;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ReminderCard({
    super.key,
    required this.title,
    this.message,
    required this.scheduledTime,
    this.frequency,
    this.isCritical = false,
    this.status = "pending",
    this.onAcknowledge,
    this.onSnooze,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = status == "acknowledged";

    return Semantics(
      label: "Reminder: $title at $scheduledTime, status $status",
      child: Card(
        color: isDone ? const Color(0xFFF0FDF4) : GhajiniTheme.cardWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GhajiniTheme.cardRadius),
          side: BorderSide(
            color: isCritical
                ? GhajiniTheme.emergencyRed
                : (isDone ? GhajiniTheme.successGreen : GhajiniTheme.borderLight),
            width: isCritical ? 2.5 : 1.5,
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Time & Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_filled, color: GhajiniTheme.primaryOrange, size: 26),
                      const SizedBox(width: 8),
                      Text(
                        scheduledTime,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: GhajiniTheme.darkBrown,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (isCritical)
                        const StatusChip(
                          label: "CRITICAL",
                          icon: Icons.warning_amber_rounded,
                          color: GhajiniTheme.emergencyRed,
                          backgroundColor: GhajiniTheme.emergencyBg,
                        ),
                      const SizedBox(width: 6),
                      StatusChip(
                        label: isDone ? "COMPLETED" : status.toUpperCase(),
                        icon: isDone ? Icons.check_circle : Icons.schedule,
                        color: isDone ? GhajiniTheme.successGreen : GhajiniTheme.primaryOrange,
                        backgroundColor: isDone ? GhajiniTheme.successBg : GhajiniTheme.softCream,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: GhajiniTheme.darkBrown,
                ),
              ),

              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  message!,
                  style: const TextStyle(
                    fontSize: 18,
                    color: GhajiniTheme.mutedBrown,
                    height: 1.4,
                  ),
                ),
              ],

              if (onEdit != null || onDelete != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (frequency != null)
                      Text(
                        'Freq: $frequency',
                        style: const TextStyle(fontSize: 14, color: GhajiniTheme.mutedBrown, fontStyle: FontStyle.italic),
                      ),
                    const Spacer(),
                    if (onEdit != null)
                      IconButton(
                        icon: const Icon(Icons.edit, color: GhajiniTheme.primaryOrange),
                        onPressed: onEdit,
                        tooltip: 'Edit reminder',
                      ),
                    if (onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: GhajiniTheme.emergencyRed),
                        onPressed: onDelete,
                        tooltip: 'Delete reminder',
                      ),
                  ],
                ),
              ],

              // Action Buttons if active
              if (!isDone && (onAcknowledge != null || onSnooze != null)) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (onAcknowledge != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onAcknowledge,
                          icon: const Icon(Icons.check, size: 24),
                          label: const Text("Done"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GhajiniTheme.successGreen,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 54),
                          ),
                        ),
                      ),
                    if (onAcknowledge != null && onSnooze != null)
                      const SizedBox(width: 12),
                    if (onSnooze != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onSnooze,
                          icon: const Icon(Icons.snooze, size: 24),
                          label: const Text("Later (5m)"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GhajiniTheme.darkBrown,
                            minimumSize: const Size(double.infinity, 54),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
