from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, Field


class BrowserAnalyzeRequest(BaseModel):
    image_base64: str = Field(..., description="Base64-encoded image (JPEG/PNG).")
    filename: Optional[str] = Field(default=None, description="Optional original filename.")
    store_history: bool = Field(default=True, description="Persist the analysis in history.")
    notes: Optional[str] = Field(default=None, description="Optional annotation stored with the entry.")


class BrowserAnalyzeResponse(BaseModel):
    result: dict
    history_id: Optional[str] = None
    created_at: Optional[str] = None
