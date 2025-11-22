from __future__ import annotations

from pydantic import BaseModel, Field


class GPTCreativeRequest(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=500)
    image_base64: str = Field(..., description="Base64-encoded PNG/JPEG source image.")


class GPTCreativeResponse(BaseModel):
    image_base64: str
