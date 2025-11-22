from __future__ import annotations

import base64
import hashlib
import json
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta
from threading import Lock
from typing import Dict

from app.core.config import get_settings
from app.models.auth import SocialProvider


class InvalidCredentialsError(Exception):
    """Raised when login credentials are invalid."""


@dataclass(frozen=True)
class UserRecord:
    email: str
    password_hash: str
    name: str
    phone_number: str


@dataclass(frozen=True)
class AuthSession:
    token: str
    expires_at: datetime
    user: UserRecord
    ttl_seconds: int


@dataclass(frozen=True)
class OTPChallenge:
    phone_number: str
    code: str
    expires_at: datetime


class AuthService:
    def __init__(self) -> None:
        settings = get_settings()
        self._lock = Lock()
        self._token_store: Dict[str, datetime] = {}
        self._otp_store: Dict[str, OTPChallenge] = {}
        self._default_user = UserRecord(
            email=str(settings.demo_user_email),
            name=settings.demo_user_name,
            password_hash=self._hash_password(settings.demo_user_password),
            phone_number=self._normalize_phone(settings.demo_user_phone),
        )
        self._ttl_default = settings.auth_token_ttl_seconds
        self._ttl_remember = settings.auth_token_ttl_remember_seconds
        self._otp_ttl = settings.otp_code_ttl_seconds
        self._google_client_id = settings.google_sign_in_client_id.strip()
        self._social_tokens = {
            SocialProvider.apple: settings.apple_sign_in_demo_token.strip(),
            SocialProvider.google: settings.google_oauth_demo_token.strip(),
            SocialProvider.facebook: settings.facebook_oauth_demo_token.strip(),
        }

    @staticmethod
    def _hash_password(password: str) -> str:
        return hashlib.sha256(password.encode("utf-8")).hexdigest()

    @staticmethod
    def _normalize_phone(phone_number: str) -> str:
        digits = "".join(ch for ch in phone_number if ch.isdigit())
        if phone_number.startswith("+"):
            return phone_number
        if digits.startswith("00"):
            digits = digits[2:]
        if digits.startswith("1") and len(digits) == 11:
            return digits
        return digits

    def _create_session(self, remember_me: bool = False, user: UserRecord | None = None) -> AuthSession:
        token = secrets.token_urlsafe(32)
        ttl = self._ttl_remember if remember_me else self._ttl_default
        expires_at = datetime.utcnow() + timedelta(seconds=ttl)

        with self._lock:
            self._token_store[token] = expires_at

        session_user = user if user is not None else self._default_user
        return AuthSession(token=token, expires_at=expires_at, user=session_user, ttl_seconds=ttl)

    def authenticate(self, email: str, password: str, remember_me: bool = False) -> AuthSession:
        if email.lower() != self._default_user.email.lower():
            raise InvalidCredentialsError

        provided_hash = self._hash_password(password)
        if provided_hash != self._default_user.password_hash:
            raise InvalidCredentialsError

        return self._create_session(remember_me=remember_me)

    def authenticate_social(
        self,
        provider: SocialProvider,
        token: str,
        email: str | None = None,
        name: str | None = None,
    ) -> AuthSession:
        sanitized_token = token.strip() if token else ""

        if provider == SocialProvider.google:
            if not self._is_google_token_valid(sanitized_token):
                raise InvalidCredentialsError
        else:
            expected_token = self._social_tokens.get(provider)
            if not expected_token or sanitized_token != expected_token:
                raise InvalidCredentialsError

        social_user = UserRecord(
            email=email or self._default_user.email,
            password_hash=self._default_user.password_hash,
            name=name or f"{provider.value.title()} User",
            phone_number=self._default_user.phone_number,
        )

        return self._create_session(remember_me=True, user=social_user)

    def _is_google_token_valid(self, token: str) -> bool:
        if not token:
            return False

        parts = token.split(".")
        if len(parts) < 2:
            return False

        payload_segment = parts[1]
        padding = "=" * (-len(payload_segment) % 4)

        try:
            decoded = base64.urlsafe_b64decode(payload_segment + padding)
            payload = json.loads(decoded)
        except (ValueError, json.JSONDecodeError):
            return False

        aud = payload.get("aud")
        if self._google_client_id and aud != self._google_client_id:
            return False

        exp = payload.get("exp")
        if exp is not None:
            try:
                expires_at = datetime.utcfromtimestamp(int(exp))
            except (TypeError, ValueError, OSError):
                return False
            if expires_at <= datetime.utcnow():
                return False

        return True

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

    def request_otp(self, phone_number: str) -> OTPChallenge:
        normalized = self._normalize_phone(phone_number)
        if normalized != self._default_user.phone_number:
            raise InvalidCredentialsError

        code = f"{secrets.randbelow(1_000_000):06d}"
        expires_at = datetime.utcnow() + timedelta(seconds=self._otp_ttl)
        challenge = OTPChallenge(phone_number=normalized, code=code, expires_at=expires_at)

        with self._lock:
            self._otp_store[normalized] = challenge

        return challenge

    def verify_otp(self, phone_number: str, code: str) -> AuthSession:
        normalized = self._normalize_phone(phone_number)

        with self._lock:
            challenge = self._otp_store.get(normalized)
            if not challenge or challenge.code != code or datetime.utcnow() > challenge.expires_at:
                raise InvalidCredentialsError
            self._otp_store.pop(normalized, None)

        return self._create_session(remember_me=False)

auth_service = AuthService()
