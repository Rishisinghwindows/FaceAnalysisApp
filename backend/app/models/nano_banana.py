from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, Field


class NanoBananaRequest(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=500)
    image_base64: Optional[str] = Field(None, description="Fallback base64 input if no URLs provided.")
    image_urls: Optional[List[str]] = Field(default=None, description="Optional list of image URLs.")


class NanoBananaResponse(BaseModel):
    image_base64: str
    metadata: Optional[dict] = None
