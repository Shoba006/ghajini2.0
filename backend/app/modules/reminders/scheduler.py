import logging
from datetime import datetime, timedelta
from typing import Optional
from apscheduler.schedulers.background import BackgroundScheduler
from dateutil.rrule import rrulestr
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.models import Reminder, ReminderLog
from app.db.session import SessionLocal
from app.modules.alerts.service import notify_caregivers

logger = logging.getLogger(__name__)

scheduler = BackgroundScheduler(timezone="UTC")


def send_push_notification_stub(patient_id: int, title: str, message: str) -> None:
    """Stubbed push notification when FEATURE_PUSH=True."""
    if settings.FEATURE_PUSH:
        logger.info(f"[PUSH NOTIFICATION STUB] To patient {patient_id}: {title} - {message}")


def is_in_quiet_hours(dt: datetime) -> bool:
    """Checks if current time falls within configured quiet hours (22:00 - 06:00)."""
    h = dt.hour
    if settings.QUIET_HOURS_START > settings.QUIET_HOURS_END:
        return h >= settings.QUIET_HOURS_START or h < settings.QUIET_HOURS_END
    else:
        return settings.QUIET_HOURS_START <= h < settings.QUIET_HOURS_END


def compute_next_occurrence(scheduled_time_str: str, rrule_str: Optional[str], from_dt: datetime) -> Optional[datetime]:
    """Computes the next occurrence of a reminder using dateutil.rrule."""
    try:
        hour, minute = [int(p) for p in scheduled_time_str.split(":")[:2]]
    except Exception:
        hour, minute = 9, 0

    if rrule_str:
        try:
            # Anchor rule at scheduled time
            base_dt = from_dt.replace(hour=hour, minute=minute, second=0, microsecond=0)
            rule = rrulestr(rrule_str, dtstart=base_dt)
            return rule.after(from_dt)
        except Exception as e:
            logger.warning(f"Failed to parse rrule '{rrule_str}': {e}")

    # Default daily recurrence
    today_target = from_dt.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if today_target > from_dt:
        return today_target
    return today_target + timedelta(days=1)


def trigger_reminder_call_orchestration(reminder: Reminder, db: Session) -> Optional[str]:
    """
    Integration point: Reminder Escalation -> Call Orchestrator -> OmniDim.
    Provides clean bridge connecting unacknowledged reminders to outbound voice calling.
    """
    try:
        session_id = f"rem_{reminder.id}_{int(datetime.utcnow().timestamp())}"
        logger.info(
            f"[Reminder-to-Call Bridge] Session {session_id} prepared for reminder "
            f"#{reminder.id} ('{reminder.title}')"
        )
        return session_id
    except Exception as e:
        logger.warning(f"Error in reminder call orchestration integration point: {e}")
        return None


def process_reminders() -> None:
    """
    Periodic job:
    1. Fires due reminders (suppresses non-critical during quiet hours).
    2. Repeats unacknowledged reminders once after 5 minutes.
    3. Escalates after escalate_after_min (default 10 min) and notifies caregivers.
    """
    db = SessionLocal()
    now = datetime.utcnow()
    try:
        in_quiet = is_in_quiet_hours(now)

        # 1. Check unacknowledged reminders for repetition or escalation
        active_reminders = (
            db.query(Reminder)
            .filter(Reminder.status.in_(["triggered", "repeated"]))
            .all()
        )

        for rem in active_reminders:
            if not rem.last_triggered_at:
                continue

            elapsed = now - rem.last_triggered_at
            esc_limit = timedelta(minutes=rem.escalate_after_min or settings.ESCALATE_AFTER_MIN)

            # Check for escalation first (after escalate_after_min)
            if elapsed >= esc_limit and rem.retry_count >= 1:
                rem.status = "escalated"
                log_esc = ReminderLog(
                    patient_id=rem.patient_id,
                    reminder_id=rem.id,
                    action="escalated",
                    outcome="escalated",
                    details=f"Reminder unacknowledged after {rem.escalate_after_min} min; marked escalated.",
                    timestamp=now,
                )
                db.add(log_esc)

                notify_caregivers(
                    patient_id=rem.patient_id,
                    alert_type="reminder_escalated",
                    message=f"Reminder escalated (unacknowledged): {rem.title}",
                    reminder_id=rem.id,
                    db=db,
                )
                trigger_reminder_call_orchestration(rem, db)
                logger.warning(f"Reminder {rem.id} ('{rem.title}') escalated to caregivers.")

            # Repeat once after 5 minutes if not yet repeated
            elif elapsed >= timedelta(minutes=5) and rem.retry_count == 0:
                rem.retry_count = 1
                rem.status = "repeated"
                rem.last_triggered_at = now
                log_rep = ReminderLog(
                    patient_id=rem.patient_id,
                    reminder_id=rem.id,
                    action="repeated",
                    outcome="ignored",
                    details="Reminder unacknowledged after 5 min; repeated once.",
                    timestamp=now,
                )
                db.add(log_rep)
                send_push_notification_stub(
                    rem.patient_id,
                    f"Reminder (Repeat): {rem.title}",
                    rem.message or rem.title,
                )
                logger.info(f"Reminder {rem.id} ('{rem.title}') repeated.")

        # 2. Check pending reminders that are due
        current_hm = now.strftime("%H:%M")
        pending = db.query(Reminder).filter(Reminder.status == "pending").all()

        for rem in pending:
            # Check if scheduled time matches or next_run_at <= now
            is_due = (rem.scheduled_time == current_hm) or (rem.next_run_at and rem.next_run_at <= now)

            if is_due:
                # Quiet hours check: suppress non-critical
                if in_quiet and not rem.is_critical:
                    logger.info(f"Reminder {rem.id} ('{rem.title}') suppressed by quiet hours.")
                    continue

                rem.status = "triggered"
                rem.last_triggered_at = now
                rem.retry_count = 0

                # Schedule next occurrence via RRULE/frequency
                rem.next_run_at = compute_next_occurrence(rem.scheduled_time, rem.rrule, now)

                # Create reminder_log with outcome "ignored" by default
                log_trig = ReminderLog(
                    patient_id=rem.patient_id,
                    reminder_id=rem.id,
                    action="triggered",
                    outcome="ignored",
                    details=f"Reminder fired: {rem.title}",
                    timestamp=now,
                )
                db.add(log_trig)

                send_push_notification_stub(
                    rem.patient_id,
                    f"Reminder: {rem.title}",
                    rem.message or rem.title,
                )
                logger.info(f"Reminder {rem.id} ('{rem.title}') triggered.")

        db.commit()
    except Exception as e:
        logger.error(f"Error in process_reminders: {e}")
        db.rollback()
    finally:
        db.close()


def schedule_startup_jobs() -> None:
    """Ensures reminders still fire after server restart by pre-calculating next occurrences."""
    db = SessionLocal()
    now = datetime.utcnow()
    try:
        reminders = db.query(Reminder).all()
        for rem in reminders:
            if not rem.next_run_at:
                rem.next_run_at = compute_next_occurrence(rem.scheduled_time, rem.rrule, now)
        db.commit()
        logger.info(f"Verified next_run_at for {len(reminders)} reminders on startup.")
    except Exception as e:
        logger.error(f"Error scheduling startup reminders: {e}")
    finally:
        db.close()


def start_scheduler() -> None:
    if not scheduler.running:
        schedule_startup_jobs()
        scheduler.add_job(
            process_reminders,
            "interval",
            seconds=15,
            id="process_reminders_job",
            replace_existing=True,
        )
        scheduler.start()
        logger.info("APScheduler reminder job running every 15s.")


def stop_scheduler() -> None:
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("APScheduler stopped.")
