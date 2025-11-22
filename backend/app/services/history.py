from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from threading import Lock
from typing import List

from app.models.history import AnalysisResultCreateModel, AnalysisResultModel


class HistoryStorage:
    def __init__(self, storage_path: Path | None = None) -> None:
        self._lock = Lock()
        self._path = storage_path or Path(__file__).resolve().parent.parent / "history_store.json"
        self._path.parent.mkdir(parents=True, exist_ok=True)

    def _load(self) -> List[AnalysisResultModel]:
        if not self._path.exists():
            return []

        with self._path.open("r", encoding="utf-8") as file:
            payload = json.load(file)

        return [AnalysisResultModel.parse_obj(item) for item in payload]

    def _save(self, items: List[AnalysisResultModel]) -> None:
        data = [json.loads(item.json()) for item in items]
        temp_path = self._path.with_suffix(".tmp")
        with temp_path.open("w", encoding="utf-8") as file:
            json.dump(data, file, ensure_ascii=False, indent=2)
        temp_path.replace(self._path)

    def list(self) -> List[AnalysisResultModel]:
        with self._lock:
            return self._load()

    def create(self, payload: AnalysisResultCreateModel) -> AnalysisResultModel:
        with self._lock:
            current = self._load()
            result = payload.to_result()
            current.insert(0, result)
            self._save(current)
            return result

    def get(self, record_id: str) -> AnalysisResultModel | None:
        with self._lock:
            for item in self._load():
                if str(item.id) == record_id:
                    return item
        return None

    def delete(self, record_id: str) -> bool:
        with self._lock:
            current = self._load()
            updated = [item for item in current if str(item.id) != record_id]
            if len(updated) == len(current):
                return False
            self._save(updated)
            return True

    def clear(self) -> int:
        with self._lock:
            count = len(self._load())
            self._save([])
            return count


history_storage = HistoryStorage()


class Metrics:
    def __init__(self) -> None:
        self._start_time = datetime.utcnow()

    @property
    def uptime_seconds(self) -> float:
        delta = datetime.utcnow() - self._start_time
        return delta.total_seconds()


metrics = Metrics()
