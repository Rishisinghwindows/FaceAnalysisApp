from functools import lru_cache

from pydantic import AnyHttpUrl, EmailStr
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "FaceMap Beauty API"
    description: str = "Offline-first face analysis service"
    version: str = "1.0.0"
    demo_user_email: EmailStr = "demo@facemapbeauty.ai"
    demo_user_name: str = "Demo User"
    demo_user_password: str = "Beauty123!"
    demo_user_phone: str = "+15555551234"
    auth_token_ttl_seconds: int = 3600
    auth_token_ttl_remember_seconds: int = 604800
    otp_code_ttl_seconds: int = 300
    apple_sign_in_demo_token: str = "apple-demo-token"
    google_oauth_demo_token: str = "google-demo-token"
    facebook_oauth_demo_token: str = "facebook-demo-token"
    google_sign_in_client_id: str = "950124297924-u7tdjrj119g5dbs3a8q1kkkf6236icg2.apps.googleusercontent.com"
    fal_api_key: str = ""
    openai_api_key: str = ""
    openai_base_url: str = "https://api.openai.com/v1"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
