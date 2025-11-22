from functools import lru_cache

from pydantic import EmailStr
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "FaceMap Beauty API"
    description: str = "Offline-first face analysis service"
    version: str = "1.0.0"
    demo_user_email: EmailStr = "demo@facemapbeauty.ai"
    demo_user_name: str = "Demo User"
    demo_user_password: str = "Beauty123!"
    auth_token_ttl_seconds: int = 3600
    auth_token_ttl_remember_seconds: int = 604800


@lru_cache()
def get_settings() -> Settings:
    return Settings()
