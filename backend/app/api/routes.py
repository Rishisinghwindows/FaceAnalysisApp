import base64
import binascii
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, File, HTTPException, UploadFile, status
from fastapi.responses import JSONResponse

from app.core.messages import (
    LOGIN_GENERIC_ERROR,
    LOGIN_INVALID_CREDENTIALS,
    OTP_INVALID_CODE,
    OTP_INVALID_PHONE,
    OTP_REQUEST_SUCCESS,
    SOCIAL_LOGIN_INVALID_TOKEN,
)
from app.models.auth import (
    AuthenticatedUser,
    LoginRequest,
    LoginResponse,
    OTPRequest,
    OTPRequestResponse,
    OTPVerifyRequest,
    SocialLoginPayload,
    SocialProvider,
)
from app.models.history import (
    AnalysisResultCreateModel,
    AnalysisResultModel,
    HistoryResponseModel,
    StatusResponseModel,
)
from app.models.browser import BrowserAnalyzeRequest, BrowserAnalyzeResponse
from app.models.nano_banana import NanoBananaRequest, NanoBananaResponse
from app.models.openai_creative import GPTCreativeRequest, GPTCreativeResponse
from app.services.analysis import analyze_image
from app.services.auth import InvalidCredentialsError, auth_service
from app.services.history import history_storage, metrics
from app.services.fal_creative import FalCreativeError, FalCreativeClient
from app.services.openai_creative import OpenAICreativeClient, OpenAICreativeError


router = APIRouter()


@router.post("/login", response_model=LoginResponse)
async def login(payload: LoginRequest) -> LoginResponse:
    try:
        session = auth_service.authenticate(
            email=str(payload.email),
            password=payload.password,
            remember_me=payload.remember_me,
        )
    except InvalidCredentialsError as exc:  # pragma: no cover - defensive wrapping
        raise HTTPException(status_code=401, detail=LOGIN_INVALID_CREDENTIALS) from exc
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail=LOGIN_GENERIC_ERROR) from exc

    return LoginResponse(
        access_token=session.token,
        token_type="bearer",
        expires_in=session.ttl_seconds,
        user=AuthenticatedUser(email=session.user.email, name=session.user.name),
    )


@router.post("/otp/request", response_model=OTPRequestResponse)
async def request_otp(payload: OTPRequest) -> OTPRequestResponse:
    try:
        challenge = auth_service.request_otp(payload.phone_number)
    except InvalidCredentialsError as exc:
        raise HTTPException(status_code=404, detail=OTP_INVALID_PHONE) from exc

    expires_in = int((challenge.expires_at - datetime.utcnow()).total_seconds())
    return OTPRequestResponse(
        expires_in=max(expires_in, 0),
        message=OTP_REQUEST_SUCCESS,
        code_preview=challenge.code,
    )


@router.post("/otp/verify", response_model=LoginResponse)
async def verify_otp(payload: OTPVerifyRequest) -> LoginResponse:
    try:
        session = auth_service.verify_otp(payload.phone_number, payload.code)
    except InvalidCredentialsError as exc:
        raise HTTPException(status_code=400, detail=OTP_INVALID_CODE) from exc

    return LoginResponse(
        access_token=session.token,
        token_type="bearer",
        expires_in=session.ttl_seconds,
        user=AuthenticatedUser(email=session.user.email, name=session.user.name),
    )


@router.post("/login/social/{provider}", response_model=LoginResponse)
async def social_login(provider: SocialProvider, payload: SocialLoginPayload) -> LoginResponse:
    try:
        session = auth_service.authenticate_social(
            provider=provider,
            token=payload.token,
            email=str(payload.email) if payload.email else None,
            name=payload.name,
        )
    except InvalidCredentialsError as exc:
        raise HTTPException(status_code=401, detail=SOCIAL_LOGIN_INVALID_TOKEN) from exc

    return LoginResponse(
        access_token=session.token,
        token_type="bearer",
        expires_in=session.ttl_seconds,
        user=AuthenticatedUser(email=session.user.email, name=session.user.name),
    )


@router.post("/analyze")
async def analyze(file: UploadFile = File(...)) -> JSONResponse:
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Invalid file type. Please upload an image.")

    image_bytes = await file.read()
    try:
        result = analyze_image(image_bytes)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail="Analysis failed.") from exc

    return JSONResponse(content=result)


@router.get("/status", response_model=StatusResponseModel)
async def status_endpoint() -> StatusResponseModel:
    history_items = history_storage.list()
    return StatusResponseModel(
        name="FaceMap Beauty API",
        version="1.0.0",
        uptime_seconds=metrics.uptime_seconds,
        history_entries=len(history_items),
    )


@router.get("/history", response_model=HistoryResponseModel)
async def list_history(limit: Optional[int] = None) -> HistoryResponseModel:
    items = history_storage.list()
    total = len(items)
    if limit is not None and limit >= 0:
        items = items[:limit]
    return HistoryResponseModel(items=items, total=total)


@router.post("/history", response_model=AnalysisResultModel, status_code=status.HTTP_201_CREATED)
async def create_history_entry(payload: AnalysisResultCreateModel) -> AnalysisResultModel:
    entry = history_storage.create(payload)
    return entry


@router.delete("/history/{record_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_history_entry(record_id: str) -> None:
    deleted = history_storage.delete(record_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="History record not found")


@router.delete("/history", status_code=status.HTTP_204_NO_CONTENT)
async def clear_history() -> None:
    history_storage.clear()


@router.post("/impact_analyze_browser", response_model=BrowserAnalyzeResponse)
async def impact_analyze_browser(payload: BrowserAnalyzeRequest) -> BrowserAnalyzeResponse:
    try:
        image_bytes = base64.b64decode(payload.image_base64)
    except (binascii.Error, ValueError) as exc:  # pragma: no cover - defensive
        raise HTTPException(status_code=400, detail="Invalid base64 image payload.") from exc

    try:
        result = analyze_image(image_bytes)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail="Analysis failed.") from exc

    history_id: Optional[str] = None
    created_at: Optional[str] = None

    if payload.store_history:
        create_model = AnalysisResultCreateModel.parse_obj(
            {
                "face_shape": result["face_shape"],
                "skin_tone": result["skin_tone"],
                "undertone": result["undertone"],
                "skin_sample_rgb": result["skin_sample_rgb"],
                "dimensions": result["dimensions"],
                "overlay": result["overlay"],
                "recommendations": result["recommendations"],
                "image_base64": payload.image_base64,
                "source": "impact_browser",
                "notes": payload.notes,
            }
        )
        stored = history_storage.create(create_model)
        history_id = str(stored.id)
        created_at = stored.created_at.isoformat()

    return BrowserAnalyzeResponse(result=result, history_id=history_id, created_at=created_at)


@router.post("/creative/generate", response_model=NanoBananaResponse)
async def creative_generate(payload: NanoBananaRequest) -> NanoBananaResponse:
    client = FalCreativeClient()
    image_urls = payload.image_urls or []

    if not image_urls:
        try:
            image_bytes = base64.b64decode(payload.image_base64 or "")
        except (binascii.Error, ValueError) as exc:
            raise HTTPException(status_code=400, detail="Invalid base64 image payload.") from exc

        if not image_bytes:
            raise HTTPException(status_code=400, detail="Provide image_urls or image_base64.")

        try:
            upload = await client.remix_bytes(image_bytes=image_bytes, prompt=payload.prompt)
        except FalCreativeError as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc
        return NanoBananaResponse(**upload)

    try:
        result = await client.edit_image(image_urls=image_urls, prompt=payload.prompt)
    except FalCreativeError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return NanoBananaResponse(**result)


@router.post("/creative/chatgpt", response_model=GPTCreativeResponse)
async def creative_chatgpt(payload: GPTCreativeRequest) -> GPTCreativeResponse:
    try:
        image_bytes = base64.b64decode(payload.image_base64)
    except (binascii.Error, ValueError) as exc:
        raise HTTPException(status_code=400, detail="Invalid base64 image payload.") from exc

    client = OpenAICreativeClient()
    try:
        generated = await client.generate_from_image(image_bytes=image_bytes, prompt=payload.prompt)
    except OpenAICreativeError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return GPTCreativeResponse(image_base64=generated)
