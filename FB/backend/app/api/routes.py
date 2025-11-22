import base64
import binascii
from typing import Optional

from fastapi import APIRouter, File, HTTPException, UploadFile, status
from fastapi.responses import JSONResponse

from app.core.messages import LOGIN_GENERIC_ERROR, LOGIN_INVALID_CREDENTIALS
from app.models.auth import AuthenticatedUser, LoginRequest, LoginResponse
from app.models.history import (
    AnalysisResultCreateModel,
    AnalysisResultModel,
    HistoryResponseModel,
    StatusResponseModel,
)
from app.models.browser import BrowserAnalyzeRequest, BrowserAnalyzeResponse
from app.services.analysis import analyze_image
from app.services.auth import InvalidCredentialsError, auth_service
from app.services.history import history_storage, metrics


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
