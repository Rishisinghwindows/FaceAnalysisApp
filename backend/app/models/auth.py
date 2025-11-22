from enum import Enum

from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    email: EmailStr
    password: str
    remember_me: bool = False


class AuthenticatedUser(BaseModel):
    email: EmailStr
    name: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: AuthenticatedUser


class OTPRequest(BaseModel):
    phone_number: str


class OTPRequestResponse(BaseModel):
    expires_in: int
    message: str
    code_preview: str | None = None


class OTPVerifyRequest(BaseModel):
    phone_number: str
    code: str


class SocialProvider(str, Enum):
    apple = "apple"
    google = "google"
    facebook = "facebook"


class SocialLoginPayload(BaseModel):
    token: str
    email: EmailStr | None = None
    name: str | None = None
