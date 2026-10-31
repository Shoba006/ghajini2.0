import json
import os
import time
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse
from pydantic import BaseModel, ConfigDict
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.models import AuditLog, Consent, Person, PersonFace
from app.db.session import get_db
from app.modules.faces.engine import face_engine

router = APIRouter()


class PersonCreate(BaseModel):
    name: str
    relationship: str
    phone: Optional[str] = None
    is_emergency_contact: Optional[bool] = False
    priority: Optional[int] = 1
    notes: Optional[str] = None
    consent: bool
    patient_id: Optional[int] = None


class PersonResponse(BaseModel):
    id: int
    patient_id: int
    name: str
    relationship: str
    phone: Optional[str] = None
    is_emergency_contact: bool = False
    priority: int = 1
    notes: Optional[str] = None
    created_at: datetime
    faces_count: int = 0

    model_config = ConfigDict(from_attributes=True)


class EmergencyContactUpdate(BaseModel):
    phone: Optional[str] = None
    is_emergency_contact: bool
    priority: Optional[int] = 1


class RecognizeResponse(BaseModel):
    status: str
    person: Optional[dict] = None
    similarity: float
    message: str


@router.post("", response_model=PersonResponse, status_code=status.HTTP_201_CREATED)
def create_person(payload: PersonCreate, db: Session = Depends(get_db)):
    if not payload.consent:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Consent is required to register a person and their personal data.",
        )

    pid = payload.patient_id or settings.DEFAULT_PATIENT_ID
    person = Person(
        patient_id=pid,
        name=payload.name.strip(),
        relationship=payload.relationship.strip(),
        phone=payload.phone.strip() if payload.phone else None,
        is_emergency_contact=payload.is_emergency_contact or False,
        priority=payload.priority or 1,
        notes=payload.notes.strip() if payload.notes else None,
    )
    db.add(person)
    db.commit()
    db.refresh(person)

    # Record explicit consent
    consent_record = Consent(
        patient_id=pid,
        person_id=person.id,
        consent_given=True,
        consent_type="face_recognition_and_data_storage",
    )
    db.add(consent_record)

    # Record audit log
    audit_record = AuditLog(
        patient_id=pid,
        action="create_person",
        details=f"Created person '{person.name}' ({person.relationship}), id={person.id}",
    )
    db.add(audit_record)
    db.commit()

    return PersonResponse(
        id=person.id,
        patient_id=person.patient_id,
        name=person.name,
        relationship=person.relationship,
        phone=person.phone,
        is_emergency_contact=person.is_emergency_contact or False,
        priority=person.priority or 1,
        notes=person.notes,
        created_at=person.created_at,
        faces_count=0,
    )


@router.get("", response_model=List[PersonResponse])
def list_people(
    patient_id: int = Query(default=1),
    db: Session = Depends(get_db),
):
    people = (
        db.query(Person)
        .filter(Person.patient_id == patient_id)
        .order_by(Person.name.asc())
        .all()
    )
    results = []
    for p in people:
        results.append(
            PersonResponse(
                id=p.id,
                patient_id=p.patient_id,
                name=p.name,
                relationship=p.relationship,
                phone=p.phone,
                is_emergency_contact=p.is_emergency_contact or False,
                priority=p.priority or 1,
                notes=p.notes,
                created_at=p.created_at,
                faces_count=len(p.faces),
            )
        )
    return results


@router.get("/{person_id}/photo")
def get_person_photo(person_id: int, db: Session = Depends(get_db)):
    face = (
        db.query(PersonFace)
        .filter(PersonFace.person_id == person_id)
        .order_by(PersonFace.id.desc())
        .first()
    )
    if not face:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Face photo not found")

    file_path = face.file_path
    if not os.path.exists(file_path):
        basename = os.path.basename(file_path)
        file_path = os.path.join(settings.UPLOAD_DIR, basename)

    if os.path.exists(file_path):
        return FileResponse(file_path, media_type="image/jpeg")

    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Face photo file not found on disk")


@router.put("/{person_id}/emergency", response_model=PersonResponse)
def update_emergency_contact(
    person_id: int,
    payload: EmergencyContactUpdate,
    db: Session = Depends(get_db),
):
    person = db.query(Person).filter(Person.id == person_id).first()
    if not person:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Person not found")
    if payload.phone is not None:
        person.phone = payload.phone.strip()
    person.is_emergency_contact = payload.is_emergency_contact
    if payload.priority is not None:
        person.priority = payload.priority
    db.commit()
    db.refresh(person)
    return PersonResponse(
        id=person.id,
        patient_id=person.patient_id,
        name=person.name,
        relationship=person.relationship,
        phone=person.phone,
        is_emergency_contact=person.is_emergency_contact or False,
        priority=person.priority or 1,
        notes=person.notes,
        created_at=person.created_at,
        faces_count=len(person.faces),
    )


@router.post("/{person_id}/faces")
async def upload_person_face(
    person_id: int,
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    person = db.query(Person).filter(Person.id == person_id).first()
    if not person:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Person not found")

    # Enrolling a face requires a consent record. Reject uploads without it.
    consent = (
        db.query(Consent)
        .filter(Consent.person_id == person_id, Consent.consent_given == True)
        .first()
    )
    if not consent:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Enrolling a face requires an explicit consent record.",
        )

    content = await image.read()
    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Empty image uploaded")

    embedding, quality = face_engine.extract_face_embedding(content)
    if embedding is None:
        return {
            "accepted": False,
            "quality": 0.0,
            "message": "No clear face detected in the image.",
        }

    # Ensure upload directory exists
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    filename = f"face_p{person_id}_{int(time.time())}_{image.filename or 'face.jpg'}"
    file_path = os.path.join(settings.UPLOAD_DIR, filename)
    with open(file_path, "wb") as f:
        f.write(content)

    face_record = PersonFace(
        patient_id=person.patient_id,
        person_id=person.id,
        file_path=file_path,
        embedding_json=json.dumps(embedding.tolist()),
        quality_score=round(quality, 4),
    )
    db.add(face_record)
    db.commit()
    db.refresh(face_record)

    # Add to FAISS index
    face_engine.add_face(face_record.id, person.id, embedding)

    return {
        "accepted": True,
        "quality": round(quality, 4),
        "face_id": face_record.id,
        "file_path": file_path,
        "message": "Face processed and registered successfully.",
    }


@router.delete("/{person_id}")
def delete_person(person_id: int, db: Session = Depends(get_db)):
    person = db.query(Person).filter(Person.id == person_id).first()
    if not person:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Person not found")

    face_ids = [face.id for face in person.faces]
    for face in person.faces:
        if face.file_path and os.path.exists(face.file_path):
            try:
                os.remove(face.file_path)
            except Exception:
                pass

    # Remove vectors from FAISS
    face_engine.remove_person(person_id, face_ids)

    # Record audit log
    audit_record = AuditLog(
        patient_id=person.patient_id,
        action="delete_person",
        details=f"Deleted person id={person_id}, name='{person.name}' and all associated faces",
    )
    db.add(audit_record)

    # Delete person from DB (cascades to faces and consents)
    db.delete(person)
    db.commit()

    return {"deleted": True, "person_id": person_id}


@router.post("/recognize", response_model=RecognizeResponse)
async def recognize_face(
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    content = await image.read()
    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Empty image uploaded")

    # Do not store raw recognition photos unless STORE_PHOTOS=true
    if settings.STORE_PHOTOS:
        try:
            os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
            filename = f"rec_{int(time.time())}_{image.filename or 'rec.jpg'}"
            rec_path = os.path.join(settings.UPLOAD_DIR, filename)
            with open(rec_path, "wb") as f:
                f.write(content)
        except Exception:
            pass

    result = face_engine.recognize(content)

    # Audit log recognition: score and status only, never the image
    audit = AuditLog(
        patient_id=settings.DEFAULT_PATIENT_ID,
        action="recognition",
        details=f"status={result['status']}, similarity={result['similarity']}, person_id={result['person_id']}",
    )
    db.add(audit)
    db.commit()
    person_obj = None

    if result["person_id"]:
        person = db.query(Person).filter(Person.id == result["person_id"]).first()
        if person:
            person_obj = {
                "id": person.id,
                "name": person.name,
                "relationship": person.relationship,
                "notes": person.notes,
            }
            if result["status"] == "match":
                message = f"This is {person.name}, your {person.relationship}."
                if person.notes:
                    message += f" ({person.notes})"
            elif result["status"] == "uncertain":
                message = f"This looks like {person.name}, your {person.relationship}, but I'm not completely certain."
            else:
                message = result["message"]
        else:
            message = result["message"]
    else:
        message = result["message"]

    return RecognizeResponse(
        status=result["status"],
        person=person_obj,
        similarity=result["similarity"],
        message=message,
    )
