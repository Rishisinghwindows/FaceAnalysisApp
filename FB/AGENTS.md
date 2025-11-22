# Repository Guidelines

## Project Structure & Module Organization
- `backend/` hosts the FastAPI service. Core code lives under `backend/app/` with `api/` for route definitions, `models/` for Pydantic schemas, `services/` for domain logic (analysis, history, authentication), and `core/` for configuration. Tests sit in `backend/tests/` with fixtures under `backend/tests/fixtures/`.
- `FaceAnalysisApp/FaceAnalysisApp/` contains the SwiftUI iOS client. Views are flatly organized, with supporting models (`AnalysisModels.swift`), services (`AnalysisService.swift`, `AuthService.swift`), and view models (`AnalysisViewModel.swift`, `LoginViewModel.swift`). Xcode project metadata resides in `FaceAnalysisApp/FaceAnalysisApp.xcodeproj/`.
- `profiles/` holds sample images useful when manually exercising upload flows.

## Build, Test, and Development Commands
- Backend setup: `cd backend && python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`.
- Run the API locally: `cd backend && uvicorn app.main:app --reload` (service mounts under `http://localhost:8000/api`).
- Execute backend tests: `cd backend && pytest`.
- iOS client: `open FaceAnalysisApp/FaceAnalysisApp.xcodeproj` to build and run in Xcode; use `xcodebuild -scheme FaceAnalysisApp -destination 'platform=iOS Simulator,name=iPhone 15' clean test` for automated validation.

## Coding Style & Naming Conventions
- Python code follows PEP 8 with 4-space indentation, type annotations, and descriptive module-level names. Prefer dependency injection over globals; keep services pure and side-effect aware.
- SwiftUI files use 4-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for properties/functions, and organize helper functions in private extensions near the bottom of the file. Favor Swift concurrency (`async/await`) and `ObservableObject` view models for side effects.
- Shared strings (e.g., API paths) should remain centralized in services to avoid drift between layers.

## Testing Guidelines
- Add backend tests under `backend/tests/` mirroring the module under test (e.g., `test_auth.py` for `services/auth.py`). Use pytest fixtures for sample payloads and keep assertions focused on response shape and status codes.
- For Swift, prefer lightweight unit tests with `XCTest` covering view models and services; snapshot/UI tests belong in dedicated targets if needed.
- Aim for coverage near critical flows (authentication, analysis, persistence) and exercise both success and failure paths.

## Commit & Pull Request Guidelines
- Write commits in the imperative mood (e.g., `Add login API`) and keep changes narrowly scoped. Run relevant tests before pushing.
- Pull requests should describe the problem, summarize the solution, note validation performed, and include screenshots or simulator recordings when UI changes are visible.
- Link to tracking issues when applicable and highlight migrations or configuration changes (e.g., new environment variables for demo login credentials).

## Security & Configuration Tips
- Demo login credentials default to `demo@facemapbeauty.ai` / `Beauty123!`; override via environment variables exposed in `backend/app/core/config.py` when deploying.
- Never commit real secrets or production API keys. Prefer `.env` files (ignored) or deployment-specific secret managers.
