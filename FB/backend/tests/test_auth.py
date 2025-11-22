from __future__ import annotations

from pathlib import Path
import sys

from fastapi.testclient import TestClient

PROJECT_ROOT = Path(__file__).resolve().parents[2] / "backend"
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app.core.config import get_settings
from app.core.messages import LOGIN_INVALID_CREDENTIALS
from app.main import app


client = TestClient(app)

def test_login_success() -> None:
    settings = get_settings()
    payload = {
        "email": str(settings.demo_user_email),
        "password": settings.demo_user_password,
    }

    response = client.post("/api/login", json=payload)
    assert response.status_code == 200

    body = response.json()
    assert "access_token" in body
    assert body["token_type"] == "bearer"
    assert body["user"]["email"].lower() == str(settings.demo_user_email).lower()
    assert body["expires_in"] == settings.auth_token_ttl_seconds


def test_login_invalid_credentials() -> None:
    payload = {
        "email": "demo@facemapbeauty.ai",
        "password": "wrong-password",
    }

    response = client.post("/api/login", json=payload)
    assert response.status_code == 401
    assert response.json()["detail"] == LOGIN_INVALID_CREDENTIALS


def test_login_remember_me_extends_expiry() -> None:
    settings = get_settings()
    payload = {
        "email": str(settings.demo_user_email),
        "password": settings.demo_user_password,
        "remember_me": True,
    }

    response = client.post("/api/login", json=payload)
    assert response.status_code == 200

    body = response.json()
    assert body["expires_in"] == settings.auth_token_ttl_remember_seconds
