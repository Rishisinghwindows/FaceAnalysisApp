from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router


def create_app() -> FastAPI:
    app = FastAPI(
        title="FaceMap Beauty API",
        description="On-device style face analysis pipeline for FaceMap Beauty.",
        version="1.0.0",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(router, prefix="/api")
    return app


app = create_app()
