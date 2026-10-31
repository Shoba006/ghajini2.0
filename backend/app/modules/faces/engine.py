import json
import logging
from typing import Dict, List, Optional, Tuple
import numpy as np

from app.core.config import settings

logger = logging.getLogger(__name__)

# Try importing insightface and faiss
try:
    import faiss
except ImportError:
    faiss = None
    logger.warning("faiss not installed; face recognition index will use fallback")

try:
    import cv2
except ImportError:
    cv2 = None
    logger.warning("cv2 not installed; image processing will be limited")

try:
    import insightface
    from insightface.app import FaceAnalysis
except ImportError:
    insightface = None
    FaceAnalysis = None
    logger.warning("insightface not installed; face recognition will use fallback")


class FaceEngine:
    def __init__(self) -> None:
        self.embedding_dim: int = 512
        self.app: Optional[FaceAnalysis] = None
        self.face_id_to_person_id: Dict[int, int] = {}
        self.index = None
        self._init_faiss_index()
        self._init_insightface()

    def _init_faiss_index(self) -> None:
        if faiss is not None:
            # Inner Product on L2 normalized vectors gives cosine similarity
            base_index = faiss.IndexFlatIP(self.embedding_dim)
            self.index = faiss.IndexIDMap2(base_index)
        else:
            # Fallback memory store for when FAISS is unavailable
            self.index = None
            self._fallback_vectors: Dict[int, np.ndarray] = {}

    def _init_insightface(self) -> None:
        import os
        if FaceAnalysis is None:
            logger.warning("InsightFace is not available.")
            return

        if os.environ.get("PYTEST_CURRENT_TEST") or os.environ.get("TESTING"):
            logger.info("Test mode: skipping InsightFace remote download, fallback enabled.")
            self.app = None
            return

        try:
            # buffalo_l is required; check workspace models first then default
            from app.core.config import settings
            workspace_models = os.path.join(settings.DATA_DIR, "models")
            if os.path.exists(os.path.join(workspace_models, "buffalo_l")):
                self.app = FaceAnalysis(name="buffalo_l", root=workspace_models, providers=["CPUExecutionProvider"])
            else:
                self.app = FaceAnalysis(name="buffalo_l", providers=["CPUExecutionProvider"])
            self.app.prepare(ctx_id=0, det_size=(640, 640))
            logger.info("InsightFace buffalo_l loaded successfully.")
        except Exception as e:
            logger.warning(f"Could not load buffalo_l InsightFace model: {e}. Fallback enabled.")
            self.app = None

    def _normalize(self, vector: np.ndarray) -> np.ndarray:
        norm = np.linalg.norm(vector)
        if norm == 0:
            return vector
        return (vector / norm).astype(np.float32)

    def extract_face_embedding(self, image_bytes: bytes) -> Tuple[Optional[np.ndarray], float]:
        """
        Extracts 512-d L2-normalized embedding and quality score from raw image bytes.
        Returns: (embedding_or_none, quality_score)
        """
        if not image_bytes:
            return None, 0.0

        img = None
        if cv2 is not None:
            nparr = np.frombuffer(image_bytes, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
            try:
                import io
                from PIL import Image
                pil_img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
                img = np.array(pil_img)[:, :, ::-1]  # Convert RGB to BGR
            except Exception:
                img = None

        if img is None:
            return None, 0.0

        if self.app is not None:
            try:
                faces = self.app.get(img)
                if faces:
                    best_face = max(faces, key=lambda f: getattr(f, "det_score", 0.0))
                    raw_emb = getattr(best_face, "normed_embedding", None)
                    if raw_emb is None:
                        raw_emb = getattr(best_face, "embedding", None)
                    if raw_emb is not None:
                        norm_emb = self._normalize(np.array(raw_emb, dtype=np.float32))
                        quality = float(getattr(best_face, "det_score", 0.8))
                        return norm_emb, quality
                # No face detected by InsightFace
                return None, 0.0
            except Exception as e:
                logger.error(f"Error during InsightFace extraction: {e}")
                return None, 0.0

        # Fallback pseudo-embedding only if InsightFace model is not loaded at all
        # Deterministically hash image data to 512 dimensions for consistency
        if cv2 is not None:
            resized = cv2.resize(img, (32, 16)).flatten()
        else:
            try:
                import io
                from PIL import Image
                pil_img = Image.open(io.BytesIO(image_bytes)).convert("L")
                resized = np.array(pil_img.resize((32, 16))).flatten()
            except Exception:
                resized = img.flatten()[: self.embedding_dim]
        vector = np.zeros(self.embedding_dim, dtype=np.float32)
        vector[: len(resized)] = resized[: self.embedding_dim]
        return self._normalize(vector), 0.75

    def add_face(self, face_id: int, person_id: int, embedding: np.ndarray) -> None:
        norm_emb = self._normalize(embedding)
        if self.index is not None:
            vec_2d = np.array([norm_emb], dtype=np.float32)
            id_arr = np.array([face_id], dtype=np.int64)
            self.index.add_with_ids(vec_2d, id_arr)
        elif hasattr(self, "_fallback_vectors"):
            self._fallback_vectors[face_id] = norm_emb
        self.face_id_to_person_id[face_id] = person_id

    add_face_embedding = add_face

    def remove_person(self, person_id: int, face_ids: List[int]) -> None:
        for face_id in face_ids:
            if self.index is not None:
                try:
                    id_arr = np.array([face_id], dtype=np.int64)
                    self.index.remove_ids(id_arr)
                except Exception as e:
                    logger.warning(f"Error removing face {face_id} from FAISS index: {e}")
            elif hasattr(self, "_fallback_vectors") and face_id in self._fallback_vectors:
                del self._fallback_vectors[face_id]
            self.face_id_to_person_id.pop(face_id, None)

    def recognize(self, image_bytes: bytes) -> Dict[str, object]:
        """
        Recognize face from image bytes.
        Returns:
            status: "match" | "uncertain" | "unknown" | "no_face"
            person_id: Optional[int]
            similarity: float
            message: str
        """
        embedding, quality = self.extract_face_embedding(image_bytes)
        if embedding is None:
            return {
                "status": "no_face",
                "person_id": None,
                "similarity": 0.0,
                "message": "No face detected in the image.",
            }

        total_faces = self.index.ntotal if self.index is not None else len(getattr(self, "_fallback_vectors", {}))
        if total_faces == 0:
            return {
                "status": "unknown",
                "person_id": None,
                "similarity": 0.0,
                "message": "I don't recognize this person yet. You can add them.",
            }

        norm_emb = self._normalize(embedding)
        best_face_id: Optional[int] = None
        best_score: float = -1.0

        if self.index is not None:
            query = np.array([norm_emb], dtype=np.float32)
            distances, ids = self.index.search(query, k=1)
            best_score = float(distances[0][0])
            best_face_id = int(ids[0][0])
        elif hasattr(self, "_fallback_vectors"):
            for fid, vec in self._fallback_vectors.items():
                sim = float(np.dot(norm_emb, vec))
                if sim > best_score:
                    best_score = sim
                    best_face_id = fid

        if best_face_id is None or best_face_id == -1 or best_face_id not in self.face_id_to_person_id:
            return {
                "status": "unknown",
                "person_id": None,
                "similarity": 0.0,
                "message": "This person is not in your memory companion.",
            }

        # Threshold evaluation
        if best_score >= settings.FACE_T_HIGH:
            status = "match"
            person_id = self.face_id_to_person_id.get(best_face_id)
            message = "Face recognized successfully."
        elif best_score >= settings.FACE_T_LOW:
            status = "uncertain"
            person_id = self.face_id_to_person_id.get(best_face_id)
            message = "Person looks familiar, but confidence is moderate."
        else:
            # Never guess below the low threshold
            status = "unknown"
            person_id = None
            message = "This person is not in your memory companion."

        return {
            "status": status,
            "person_id": person_id,
            "similarity": round(best_score, 4),
            "message": message,
        }

    def load_from_db(self, db_faces: List[Tuple[int, int, str]]) -> None:
        """
        Re-indexes face embeddings from database on startup: list of (face_id, person_id, embedding_json)
        """
        for face_id, person_id, emb_json in db_faces:
            if not emb_json:
                continue
            try:
                emb_list = json.loads(emb_json)
                vec = np.array(emb_list, dtype=np.float32)
                self.add_face(face_id, person_id, vec)
            except Exception as e:
                logger.warning(f"Failed to load face {face_id} from JSON: {e}")

    def clear(self) -> None:
        self.face_id_to_person_id.clear()
        self._init_faiss_index()


# Global face engine instance
face_engine = FaceEngine()
