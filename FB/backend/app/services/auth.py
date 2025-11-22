from __future__ import annotations

import hashlib
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta
from threading import Lock
from typing import Dict

from app.core.config import get_settings


class InvalidCredentialsError(Exception):
    """Raised when login credentials are invalid."""


@dataclass(frozen=True)
class UserRecord:
    email: str
    password_hash: str
    name: str


@dataclass(frozen=True)
class AuthSession:
    token: str
    expires_at: datetime
    user: UserRecord
    ttl_seconds: int


class AuthService:
    def __init__(self) -> None:
        settings = get_settings()
        self._lock = Lock()
        self._token_store: Dict[str, datetime] = {}
        self._default_user = UserRecord(
            email=str(settings.demo_user_email),
            name=settings.demo_user_name,
            password_hash=self._hash_password(settings.demo_user_password),
        )
        self._ttl_default = settings.auth_token_ttl_seconds
        self._ttl_remember = settings.auth_token_ttl_remember_seconds

    @staticmethod
    def _hash_password(password: str) -> str:
        return hashlib.sha256(password.encode("utf-8")).hexdigest()

    def authenticate(self, email: str, password: str, remember_me: bool = False) -> AuthSession:
        if email.lower() != self._default_user.email.lower():
            raise InvalidCredentialsError

        provided_hash = self._hash_password(password)
        if provided_hash != self._default_user.password_hash:
            raise InvalidCredentialsError

        token = secrets.token_urlsafe(32)
        ttl = self._ttl_remember if remember_me else self._ttl_default
        expires_at = datetime.utcnow() + timedelta(seconds=ttl)

        with self._lock:
            self._token_store[token] = expires_at

        return AuthSession(token=token, expires_at=expires_at, user=self._default_user, ttl_seconds=ttl)

    def validate(self, token: str) -> bool:
        with self._lock:
            expires_at = self._token_store.get(token)
            if not expires_at:
                return False
            if datetime.utcnow() >= expires_at:
                self._token_store.pop(token, None)
                return False
            return True

    def revoke(self, token: str) -> None:
        with self._lock:
            self._token_store.pop(token, None)

auth_service = AuthService()
