from __future__ import annotations

from datetime import datetime
from typing import Dict, List, Optional
from uuid import UUID, uuid4

from pydantic import BaseModel, Field, validator


class FaceDimensionsModel(BaseModel):
    forehead_width: float = Field(..., ge=0)
    cheekbone_width: float = Field(..., ge=0)
    jaw_width: float = Field(..., ge=0)
    face_length: float = Field(..., ge=0)
    jaw_angle: float = Field(..., ge=0)


class OverlayModel(BaseModel):
    bounding_box: List[float]
    zones: Dict[str, List[List[float]]]

    @validator("bounding_box")
    def validate_bounding_box(cls, value: List[float]) -> List[float]:
        if len(value) != 4:
            raise ValueError("bounding_box must contain four float values [min_x, min_y, max_x, max_y]")
        return value


class RecommendationModel(BaseModel):
    details: Optional[str]
    suggested_shades: Optional[List[str]]
    suggested_finishes: Optional[List[str]]


class FeatureRatioModel(BaseModel):
    name: str
    value: float
    ideal: float
    delta: float
    message: str


class ToneSummaryModel(BaseModel):
    hex: str
    keywords: List[str]
    finish_tips: List[str]


class FeatureInsightsModel(BaseModel):
    symmetry_score: float
    symmetry_description: str
    eye_alignment_difference: float
    guidance: str
    brow_balance_score: float
    jaw_definition_score: float
    feature_ratios: List[FeatureRatioModel]
    tone_summary: ToneSummaryModel


class AnalysisResultModel(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    face_shape: str
    skin_tone: str
    undertone: str
    skin_sample_rgb: List[int]
    dimensions: FaceDimensionsModel
    overlay: OverlayModel
    recommendations: Dict[str, RecommendationModel]
    image_base64: Optional[str] = None
    source: str = Field(default="app")
    notes: Optional[str] = None
    insights: Optional[FeatureInsightsModel] = None

    @validator("skin_sample_rgb")
    def validate_rgb(cls, value: List[int]) -> List[int]:
        if len(value) != 3:
            raise ValueError("skin_sample_rgb must contain three integer values")
        for channel in value:
            if not 0 <= channel <= 255:
                raise ValueError("RGB channel values must be in range 0-255")
        return value


class AnalysisResultCreateModel(BaseModel):
    face_shape: str
    skin_tone: str
    undertone: str
    skin_sample_rgb: List[int]
    dimensions: FaceDimensionsModel
    overlay: OverlayModel
    recommendations: Dict[str, RecommendationModel]
    image_base64: Optional[str] = None
    source: str = Field(default="app")
    notes: Optional[str] = None
    insights: Optional[FeatureInsightsModel] = None

    def to_result(self) -> AnalysisResultModel:
        return AnalysisResultModel(
            face_shape=self.face_shape,
            skin_tone=self.skin_tone,
            undertone=self.undertone,
            skin_sample_rgb=self.skin_sample_rgb,
            dimensions=self.dimensions,
            overlay=self.overlay,
            recommendations=self.recommendations,
            image_base64=self.image_base64,
            source=self.source,
            insights=self.insights,
        )


class HistoryResponseModel(BaseModel):
    items: List[AnalysisResultModel]
    total: int


class StatusResponseModel(BaseModel):
    name: str
    version: str
    uptime_seconds: float
    history_entries: int
