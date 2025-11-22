from __future__ import annotations

import io
from typing import Any, Dict, List, Optional

import fal_client
from PIL import Image

from app.core.config import get_settings


class FalCreativeError(RuntimeError):
    """Raised when Fal returns an error or malformed payload."""


class FalCreativeClient:
    def __init__(self, *, api_key: Optional[str] = None) -> None:
        settings = get_settings()
        self._api_key = (api_key or settings.fal_api_key).strip()
        if not self._api_key:
            raise FalCreativeError("FAL_API_KEY is not configured.")
        self._client = fal_client.AsyncClient(key=self._api_key)

    async def edit_image(
        self,
        *,
        image_urls: List[str],
        prompt: str,
        model_id: str = "fal-ai/nano-banana/edit",
    ) -> Dict[str, Any]:
        if not image_urls:
            raise ValueError("image_urls must contain at least one URL.")

        handler = await self._client.submit(
            model_id,
            arguments={"prompt": prompt.strip(), "image_urls": image_urls},
        )
        result = await handler.get()
        print("Fal edit_image result:", result)

        outputs = result.get("images") or []
        if not outputs:
            raise FalCreativeError("Fal response missing 'images'.")

        first_image = outputs[0]
        content = first_image.get("base64")
        if not content:
            raise FalCreativeError("Generated image missing base64 content.")

        return {"image_base64": content, "metadata": result.get("metadata")}

    async def remix_bytes(self, *, image_bytes: bytes, prompt: str) -> Dict[str, Any]:
        try:
            pil_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        except Exception as exc:
            raise FalCreativeError("Invalid image payload.") from exc

        with io.BytesIO() as buffer:
            pil_image.save(buffer, format="PNG")
            buffer.seek(0)
            upload_url = await self._client.upload(
                buffer.getvalue(),
                content_type="image/png",
                file_name="input.png",
            )

        print("Fal upload URL:", upload_url)
        return await self.edit_image(image_urls=[upload_url], prompt=prompt)
