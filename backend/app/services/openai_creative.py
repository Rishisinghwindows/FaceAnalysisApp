from __future__ import annotations

import base64
import io
from typing import Optional

from openai import AsyncOpenAI

from app.core.config import get_settings


class OpenAICreativeError(RuntimeError):
    """Raised when OpenAI image generation fails."""


class OpenAICreativeClient:
    def __init__(self, *, api_key: Optional[str] = None, model: str = "gpt-image-1") -> None:
        settings = get_settings()
        key = (api_key or settings.openai_api_key).strip()
        if not key:
            raise OpenAICreativeError("OPENAI_API_KEY is not configured.")
        self._client = AsyncOpenAI(api_key=key, base_url=settings.openai_base_url)
        self._model = model

    async def generate_from_image(self, *, image_bytes: bytes, prompt: str) -> str:
        if not image_bytes:
            raise ValueError("image_bytes must not be empty.")

        buffer = io.BytesIO(image_bytes)
        buffer.name = "source.png"

        try:
            response = await self._client.images.edit(
                model=self._model,
                image=buffer,
                prompt=prompt.strip(),
                size="1024x1024",
            )
        except Exception as exc:
            raise OpenAICreativeError(str(exc)) from exc

        data = response.data or []
        if not data or not data[0].b64_json:
            raise OpenAICreativeError("OpenAI response missing image data.")

        return data[0].b64_json
