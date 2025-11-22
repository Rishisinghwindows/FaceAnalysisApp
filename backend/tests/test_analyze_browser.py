from __future__ import annotations

import base64
from pathlib import Path
import sys

import pytest
from fastapi.testclient import TestClient

PROJECT_ROOT = Path(__file__).resolve().parents[2] / "backend"
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app.main import app


client = TestClient(app)


@pytest.fixture(scope="module")
def sample_image_base64() -> str:
    image_path = Path(__file__).parent / "fixtures" / "sample_face.png"
    with image_path.open("rb") as image_file:
        return base64.b64encode(image_file.read()).decode("utf-8")


def test_impact_analyze_browser_missing_body() -> None:
    response = client.post("/impact_analyze_browser", json={})
    assert response.status_code == 422


def test_impact_analyze_browser_invalid_base64() -> None:
    payload = {
        "image_base64": "@@invalid@@",
    }
    response = client.post("/impact_analyze_browser", json=payload)
    assert response.status_code == 400
    assert response.json()["detail"] == "Invalid base64 image payload."


def test_impact_analyze_browser_success(sample_image_base64: str, monkeypatch: pytest.MonkeyPatch) -> None:
    fake_result = {
        "face_shape": "oval",
        "skin_tone": "medium",
        "undertone": "warm",
        "skin_sample_rgb": [220, 180, 160],
        "dimensions": {
            "forehead_width": 130.0,
            "cheekbone_width": 150.0,
            "jaw_width": 120.0,
            "face_length": 200.0,
            "jaw_angle": 1.5,
        },
        "overlay": {
            "bounding_box": [0.1, 0.1, 0.9, 0.9],
            "zones": {
                "contour": [[0.2, 0.3], [0.4, 0.5], [0.3, 0.6]],
            },
        },
        "recommendations": {
            "blush": {
                "details": "Apply along cheekbones.",
                "suggested_shades": ["Peach"],
                "suggested_finishes": None,
            }
        },
    }

    def fake_analyze_image(_: bytes) -> dict:
        return fake_result

    monkeypatch.setattr("app.api.routes.analyze_image", fake_analyze_image)

    payload = {
        "image_base64": sample_image_base64,
        "store_history": True,
        "notes": "browser test",
    }

    response = client.post("/impact_analyze_browser", json=payload)
    assert response.status_code == 200

    json_body = response.json()
    assert json_body["result"]["face_shape"] == "oval"
    assert json_body["history_id"] is not None
    assert json_body["created_at"] is not None


def test_status_endpoint() -> None:
    response = client.get("/api/status")
    assert response.status_code == 200
    body = response.json()
    assert "uptime_seconds" in body
    assert "history_entries" in body
