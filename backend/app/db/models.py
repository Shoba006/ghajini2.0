from datetime import datetime
from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship as orm_relationship

from app.db.session import Base


class Patient(Base):
    __tablename__ = "patients"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String(100), default="Default Patient", nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    people = orm_relationship("Person", back_populates="patient", cascade="all, delete-orphan")
    memories = orm_relationship("Memory", back_populates="patient", cascade="all, delete-orphan")
    reminders = orm_relationship("Reminder", back_populates="patient", cascade="all, delete-orphan")
    consents = orm_relationship("Consent", back_populates="patient", cascade="all, delete-orphan")
    alerts = orm_relationship("Alert", back_populates="patient", cascade="all, delete-orphan")
    audit_logs = orm_relationship("AuditLog", back_populates="patient", cascade="all, delete-orphan")
    places = orm_relationship("Place", back_populates="patient", cascade="all, delete-orphan")
    vitals = orm_relationship("VitalsReading", back_populates="patient", cascade="all, delete-orphan")
    call_attempts = orm_relationship("CallAttempt", back_populates="patient", cascade="all, delete-orphan")


class Person(Base):
    __tablename__ = "people"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, default=1, index=True)
    name = Column(String(120), nullable=False)
    relationship = Column(String(80), nullable=False)
    phone = Column(String(50), nullable=True)
    is_emergency_contact = Column(Boolean, default=False, nullable=False)
    priority = Column(Integer, default=1, nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    patient = orm_relationship("Patient", back_populates="people")
    faces = orm_relationship("PersonFace", back_populates="person", cascade="all, delete-orphan")


class PersonFace(Base):
    __tablename__ = "person_faces"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, default=1, index=True)
    person_id = Column(Integer, ForeignKey("people.id", ondelete="CASCADE"), nullable=False, index=True)
    file_path = Column(String(255), nullable=False)
    embedding_json = Column(Text, nullable=True)
    quality_score = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    person = orm_relationship("Person", back_populates="faces")


class Memory(Base):
    __tablename__ = "memories"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, default=1, index=True)
    text = Column(Text, nullable=False)
    category = Column(String(50), nullable=True, default="general")
    embedding_json = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    patient = orm_relationship("Patient", back_populates="memories")


class Reminder(Base):
    __tablename__ = "reminders"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, default=1, index=True)
    title = Column(String(200), nullable=False)
    message = Column(Text, nullable=True)
    scheduled_time = Column(String(20), nullable=False)  # e.g., "09:00"
    frequency = Column(String(50), default="daily", nullable=False)
    rrule = Column(String(200), nullable=True)  # iCal RRULE e.g. "FREQ=DAILY" or "FREQ=WEEKLY;BYDAY=MO,WE,FR"
    is_critical = Column(Boolean, default=False, nullable=False)
    escalate_after_min = Column(Integer, default=10, nullable=False)
    status = Column(String(50), default="pending", nullable=False)  # pending, triggered, acknowledged, snoozed, distressed, escalated
    retry_count = Column(Integer, default=0, nullable=False)
    last_triggered_at = Column(DateTime, nullable=True)
    next_run_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    patient = orm_relationship("Patient", back_populates="reminders")
    logs = orm_relationship("ReminderLog", back_populates="reminder", cascade="all, delete-orphan")


class ReminderLog(Base):
    __tablename__ = "reminder_logs"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, default=1, index=True)
    reminder_id = Column(Integer, ForeignKey("reminders.id", ondelete="CASCADE"), nullable=False, index=True)
    action = Column(String(50), nullable=False)  # triggered, repeated, acknowledged, snoozed, distressed, escalated
    outcome = Column(String(50), default="ignored", nullable=False)  # ignored, repeated, acknowledged, snoozed, distressed, escalated
    details = Column(Text, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False)

    reminder = orm_relationship("Reminder", back_populates="logs")


class Consent(Base):
    __tablename__ = "consents"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, default=1, index=True)
    person_id = Column(Integer, ForeignKey("people.id", ondelete="CASCADE"), nullable=True)
    consent_given = Column(Boolean, nullable=False, default=True)
    consent_type = Column(String(100), default="face_recognition_and_data_storage", nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    patient = orm_relationship("Patient", back_populates="consents")


class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, default=1, index=True)
    reminder_id = Column(Integer, ForeignKey("reminders.id", ondelete="SET NULL"), nullable=True, index=True)
    alert_type = Column(String(50), nullable=False)  # "sos_button", "emergency_phrase", "reminder_escalated", "distress_response"
    message = Column(Text, nullable=False)
    status = Column(String(50), default="sent", nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    patient = orm_relationship("Patient", back_populates="alerts")


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, default=1, index=True)
    action = Column(String(50), nullable=False)  # "create_person", "delete_person", "export_data", "wipe_all_data", "alert_created", "recognition"
    details = Column(Text, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False)

    patient = orm_relationship("Patient", back_populates="audit_logs")


class Place(Base):
    __tablename__ = "places"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, default=1, index=True)
    name = Column(String(120), nullable=False)
    address = Column(String(255), nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    patient = orm_relationship("Patient", back_populates="places")


class VitalsReading(Base):
    __tablename__ = "vitals_readings"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, default=1, index=True)
    heart_rate_bpm = Column(Integer, nullable=False, default=72)
    blood_pressure_systolic = Column(Integer, nullable=True, default=120)
    blood_pressure_diastolic = Column(Integer, nullable=True, default=80)
    oxygen_saturation = Column(Integer, nullable=True, default=98)
    hrv_ms = Column(Integer, nullable=True, default=45)
    status = Column(String(50), default="normal", nullable=False)  # normal, elevated, low, critical_high, critical_low, arrhythmia
    notes = Column(Text, nullable=True)
    recorded_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    patient = orm_relationship("Patient", back_populates="vitals")


class CallAttempt(Base):
    __tablename__ = "call_attempts"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    call_session_id = Column(String(100), index=True, nullable=False)
    patient_id = Column(Integer, ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, default=1, index=True)
    person_id = Column(Integer, ForeignKey("people.id", ondelete="CASCADE"), nullable=True, index=True)
    reminder_id = Column(Integer, ForeignKey("reminders.id", ondelete="SET NULL"), nullable=True, index=True)
    attempt_number = Column(Integer, default=1, nullable=False)
    provider = Column(String(50), default="omnidim", nullable=False)
    provider_call_id = Column(String(120), unique=True, nullable=True, index=True)
    recipient_phone = Column(String(50), nullable=False)
    recipient_name = Column(String(120), nullable=True)
    status = Column(String(50), default="initiated", nullable=False)  # initiated, ringing, answered, no_answer, failed, busy, voicemail, cancelled
    is_technical_failure = Column(Boolean, default=False, nullable=False)
    failure_reason = Column(Text, nullable=True)
    duration_seconds = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    patient = orm_relationship("Patient", back_populates="call_attempts")
    person = orm_relationship("Person", backref="call_attempts")
    reminder = orm_relationship("Reminder", backref="call_attempts")

