import asyncio
import copy
import json
import logging
import os
import threading
import time
from typing import Any, Dict, List, Optional
from urllib.parse import urlparse

from app.core.config import settings

logger = logging.getLogger(__name__)

# Try importing Motor
try:
    from motor.motor_asyncio import AsyncIOMotorClient
    HAS_MOTOR = True
except ImportError:
    AsyncIOMotorClient = None
    HAS_MOTOR = False


class AsyncCursor:
    """Async cursor conforming to Motor cursor interface."""
    def __init__(self, docs: List[Dict[str, Any]]):
        self._docs = docs
        self._index = 0

    def sort(self, key_or_list: Any, direction: int = 1) -> "AsyncCursor":
        if isinstance(key_or_list, str):
            reverse = direction == -1
            self._docs.sort(key=lambda d: d.get(key_or_list, 0), reverse=reverse)
        elif isinstance(key_or_list, list) and key_or_list:
            k, d = key_or_list[0]
            self._docs.sort(key=lambda doc: doc.get(k, 0), reverse=(d == -1))
        return self

    def limit(self, count: int) -> "AsyncCursor":
        self._docs = self._docs[:count]
        return self

    async def to_list(self, length: Optional[int] = None) -> List[Dict[str, Any]]:
        if length is None:
            return copy.deepcopy(self._docs)
        return copy.deepcopy(self._docs[:length])

    def __aiter__(self):
        self._index = 0
        return self

    async def __anext__(self):
        if self._index < len(self._docs):
            doc = copy.deepcopy(self._docs[self._index])
            self._index += 1
            return doc
        raise StopAsyncIteration


class InsertOneResult:
    def __init__(self, inserted_id: Any):
        self.inserted_id = inserted_id


class UpdateResult:
    def __init__(self, matched_count: int, modified_count: int):
        self.matched_count = matched_count
        self.modified_count = modified_count


class AsyncDocumentCollection:
    """
    In-memory / JSON-backed Async MongoDB Collection implementation.
    Implements standard Motor collection methods:
    find, find_one, insert_one, update_one, delete_many, count_documents.
    """
    def __init__(self, name: str, storage_dir: Optional[str] = None):
        self.name = name
        self._storage_path = os.path.join(storage_dir or settings.DATA_DIR, f"mongo_{name}.json")
        self._docs: List[Dict[str, Any]] = []
        self._lock = threading.Lock()
        self._load()

    def _load(self) -> None:
        if os.path.exists(self._storage_path):
            try:
                with open(self._storage_path, "r", encoding="utf-8") as f:
                    self._docs = json.load(f)
            except Exception as e:
                logger.warning(f"Failed to load mongo fallback collection '{self.name}': {e}")
                self._docs = []
        else:
            self._docs = []

    def _save(self) -> None:
        try:
            os.makedirs(os.path.dirname(self._storage_path), exist_ok=True)
            with open(self._storage_path, "w", encoding="utf-8") as f:
                json.dump(self._docs, f, indent=2, default=str)
        except Exception as e:
            logger.warning(f"Failed to persist mongo fallback collection '{self.name}': {e}")

    def _matches(self, doc: Dict[str, Any], query: Dict[str, Any]) -> bool:
        for k, v in query.items():
            if k == "$or" and isinstance(v, list):
                if not any(self._matches(doc, subq) for subq in v):
                    return False
            elif isinstance(v, dict):
                # Simple operator support: $gte, $lte, $gt, $lt, $in
                doc_val = doc.get(k)
                for op, target in v.items():
                    if op == "$gte" and not (doc_val is not None and doc_val >= target):
                        return False
                    elif op == "$lte" and not (doc_val is not None and doc_val <= target):
                        return False
                    elif op == "$gt" and not (doc_val is not None and doc_val > target):
                        return False
                    elif op == "$lt" and not (doc_val is not None and doc_val < target):
                        return False
                    elif op == "$in" and doc_val not in target:
                        return False
            else:
                if doc.get(k) != v:
                    return False
        return True

    async def insert_one(self, document: Dict[str, Any]) -> InsertOneResult:
        with self._lock:
            doc = copy.deepcopy(document)
            if "_id" not in doc:
                doc["_id"] = f"{self.name}_{int(time.time() * 1000)}_{len(self._docs) + 1}"
            self._docs.append(doc)
            self._save()
            return InsertOneResult(doc["_id"])

    async def find_one(self, filter: Optional[Dict[str, Any]] = None) -> Optional[Dict[str, Any]]:
        with self._lock:
            filter = filter or {}
            for doc in self._docs:
                if self._matches(doc, filter):
                    return copy.deepcopy(doc)
            return None

    def find(self, filter: Optional[Dict[str, Any]] = None) -> AsyncCursor:
        filter = filter or {}
        matched = [d for d in self._docs if self._matches(d, filter)]
        return AsyncCursor(matched)

    async def update_one(self, filter: Dict[str, Any], update: Dict[str, Any]) -> UpdateResult:
        with self._lock:
            matched = 0
            modified = 0
            for doc in self._docs:
                if self._matches(doc, filter):
                    matched += 1
                    if "$set" in update:
                        for sk, sv in update["$set"].items():
                            doc[sk] = sv
                        modified += 1
                    else:
                        for k, v in update.items():
                            doc[k] = v
                        modified += 1
                    break
            if modified > 0:
                self._save()
            return UpdateResult(matched, modified)

    async def delete_many(self, filter: Dict[str, Any]) -> int:
        with self._lock:
            before_len = len(self._docs)
            self._docs = [d for d in self._docs if not self._matches(d, filter)]
            deleted = before_len - len(self._docs)
            if deleted > 0:
                self._save()
            return deleted

    async def count_documents(self, filter: Optional[Dict[str, Any]] = None) -> int:
        with self._lock:
            filter = filter or {}
            return sum(1 for d in self._docs if self._matches(d, filter))


class MongoManager:
    """Manages Motor or fallback Mongo collections."""
    def __init__(self):
        self._motor_client = None
        self._fallback_collections: Dict[str, AsyncDocumentCollection] = {}
        self._connected = False

    async def init(self) -> None:
        if os.environ.get("TESTING") or os.environ.get("PYTEST_CURRENT_TEST"):
            self._connected = False
            return

        if HAS_MOTOR and AsyncIOMotorClient is not None:
            try:
                kwargs = {"serverSelectionTimeoutMS": 2500}
                try:
                    import certifi
                    if "mongodb+srv://" in settings.MONGODB_URL:
                        kwargs["tlsCAFile"] = certifi.where()
                except ImportError:
                    pass
                client = AsyncIOMotorClient(settings.MONGODB_URL, **kwargs)
                await asyncio.wait_for(client.admin.command("ping"), timeout=3.0)
                self._motor_client = client
                self._connected = True
                logger.info("Connected to MongoDB via Motor")
            except Exception as e:
                self._connected = False
                logger.info(f"MongoDB server not reachable ({e}); using AsyncDocumentCollection engine.")
        else:
            self._connected = False

    def get_collection(self, name: str) -> Any:
        if not os.environ.get("PYTEST_CURRENT_TEST") and not os.environ.get("TESTING"):
            if self._connected and self._motor_client is not None:
                try:
                    db = self._motor_client.get_default_database("ghajini")
                except Exception:
                    db = self._motor_client["ghajini"]
                return db[name]
        if name not in self._fallback_collections:
            self._fallback_collections[name] = AsyncDocumentCollection(name)
        return self._fallback_collections[name]


mongo_manager = MongoManager()
