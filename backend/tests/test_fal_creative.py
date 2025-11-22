from __future__ import annotations

from pathlib import Path
import sys
from typing import Any, Dict

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app.services.fal_creative import FalCreativeClient, FalCreativeError


class StubHandler:
    def __init__(self, payload: Dict[str, Any]) -> None:
        self._payload = payload

    async def get(self) -> Dict[str, Any]:
        return self._payload


class StubAsyncClient:
    def __init__(self, key: str | None = None) -> None:
        self.key = key
        self.last_upload = None
        self.last_submit = None

    async def upload(self, data: bytes, *, content_type: str, file_name: str | None = None) -> str:
        self.last_upload = {"content_type": content_type, "file_name": file_name, "size": len(data)}
        return "https://example.com/uploaded.png"

    async def submit(self, model_id: str, arguments: Dict[str, Any]) -> StubHandler:
        self.last_submit = {"model_id": model_id, "arguments": arguments}
        payload = {"images": [{"base64": "abc123"}], "metadata": {"prompt": arguments["prompt"]}}
        return StubHandler(payload)


@pytest.mark.asyncio
async def test_edit_image(monkeypatch: pytest.MonkeyPatch) -> None:
    stub_client = StubAsyncClient("key")
    monkeypatch.setattr("app.services.fal_creative.fal_client.AsyncClient", lambda key: stub_client)

    client = FalCreativeClient(api_key="secret")
    result = await client.edit_image(image_urls=["https://example.com"], prompt="dreamy neon")

    assert result["image_base64"] == "abc123"
    assert stub_client.last_submit["arguments"]["image_urls"] == ["https://example.com"]


@pytest.mark.asyncio
async def test_remix_bytes(monkeypatch: pytest.MonkeyPatch) -> None:
    stub_client = StubAsyncClient("key")
    monkeypatch.setattr("app.services.fal_creative.fal_client.AsyncClient", lambda key: stub_client)

    client = FalCreativeClient(api_key="secret")
    result = await client.remix_bytes(image_bytes=b"\x89PNGfake", prompt="cool tones")

    assert result["image_base64"] == "abc123"
    assert stub_client.last_upload["file_name"] == "input.png"
    assert stub_client.last_submit["arguments"]["image_urls"] == ["https://example.com/uploaded.png"]


def test_missing_api_key_raises() -> None:
    with pytest.raises(FalCreativeError):
        FalCreativeClient(api_key="")
