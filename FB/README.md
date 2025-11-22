# FaceMap Beauty

FaceMap Beauty is a privacy-first beauty assistant that analyzes a user’s selfie entirely on-device to produce personalized makeup recommendations. The project includes:

- A native SwiftUI iOS application that captures a selfie, performs facial landmark analysis (face shape, dimensions, skin tone), renders guided overlays, and surfaces curated shade suggestions.
- A complementary FastAPI backend that mirrors the on-device pipeline for desktop experimentation or future cross-platform experiences. All computation happens locally wherever the service runs.

## Repository Structure

```
.
├── FaceAnalysisApp/
│   ├── FaceAnalysisApp.xcodeproj/
│   └── FaceAnalysisApp/
│       ├── AnalysisModels.swift
│       ├── AnalysisService.swift
│       ├── AnalysisHistoryStore.swift
│       ├── AnalysisViewModel.swift
│       ├── Color+Palette.swift
│       ├── ContentView.swift
│       ├── FaceAnalysisApp.swift
│       ├── FaceAnalysisResultView.swift
│       ├── HomeContainerView.swift
│       ├── LoginView.swift
│       ├── RootView.swift
│       ├── SettingsView.swift
│       ├── SplashView.swift
│       ├── TutorialView.swift
│       ├── HistoryView.swift
│       ├── NotificationsView.swift
│       ├── TermsView.swift
│       ├── AboutView.swift
│       ├── CameraPicker.swift / ImagePicker.swift
│       └── Assets.xcassets
└── backend/
    ├── app/
    │   ├── api/
    │   ├── core/
    │   ├── services/
    │   └── main.py
    └── requirements.txt
```

## iOS Application

### Requirements

- macOS with Xcode 15+
- iOS 16+ deployment target
- Swift 5.7 or later

### Running the App

1. Open the project workspace:
   ```bash
   open FaceAnalysisApp/FaceAnalysisApp.xcodeproj
   ```
2. Select an iOS simulator (or a physical device with camera permissions).
3. Build & run (`⌘ + R`).

### Key Features

- **Launch sequence**: Splash, login (with optional skip), and a guided tutorial introduce the workflow before entering the main tabs.
- **Capture guidance**: Primary “Analyze” tab provides camera/photo library intake with live status indicators for analysis stages.
- **Network-backed analysis**: Selected selfies are sent to the FastAPI service (default `http://localhost:8000/api/analyze`) and parsed into reusable models.
- **History & persistence**: Successful results are cached on-device (Application Support) and can be revisited or cleared from the History or Settings screens.
- **Face map overlay**: Result view renders contour, blush, and highlight zones on top of the captured image using the backend polygon data.
- **Recommendations engine**: Detailed cards surface blush, contour, highlight, eye, and lip guidance with shade/finish chips tailored to undertone.
- **Settings toolkit**: Profile tab exposes notification preferences, tutorial replay, sign out, and history management.
- **Golden ratio insights**: Each scan compares facial length-to-width balance against the classical 1:1.618 proportion, offering harmony-focused tips while reinforcing that beauty goes beyond a single number.

### Privacy & Offline Mode

- All image capture happens on-device. Analysis requests are sent to the FastAPI instance you control (defaults to `localhost`).
- History entries and images are stored locally in Application Support and never synced to remote services.
- Optional sharing leverages the standard iOS share sheet under user control.

## FastAPI Backend

The backend mirrors the mobile logic, allowing local experimentation or integration with other clients while preserving the privacy-first architecture (run it on the same device where images are analyzed).

### Requirements

- Python 3.9+
- A virtual environment is recommended

### Setup

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install --upgrade pip
pip install -r requirements.txt
uvicorn app.main:app --reload
```


### REST API

| Method | Path | Description |
| ------ | ---- | ----------- |
| POST | `/api/analyze` | Accepts an image via `multipart/form-data` (`file`) and returns dimensions, tones, overlay coordinates, and recommendations. |
| GET | `/api/status` | Health/status payload with API version, uptime, and stored history count. |
| GET | `/api/history` | Returns persisted analysis results (use `?limit=` to trim the list). |
| POST | `/api/history` | Persists an analysis record (same structure as the app payload; server assigns `id` and `created_at`). |
| DELETE | `/api/history/{id}` | Removes a specific history entry. |
| DELETE | `/api/history` | Clears the entire history store. |
| POST | `/impact_analyze_browser` | Accepts a base64-encoded image JSON payload (for browsers) and optionally stores the result. |

### Sample Request

```bash
curl -X POST http://localhost:8000/api/analyze \
  -F "file=@/path/to/selfie.jpg"
```

### Implementation Notes

- Uses MediaPipe Face Mesh for landmark extraction and OpenCV/Numpy for geometry.
- Color sampling from cheek region feeds LAB + ITA computations identical to the iOS pipeline.
- Recommendations are deterministic and mirror the on-device rule set.
- History entries are stored as JSON in `backend/app/history_store.json`; delete the file if you want to reset the data.

## Testing & Validation

- The iOS project compiles under Xcode 15+; run on simulator/device to validate capture and overlay flows.
- For backend verification, issue curl requests or use a REST client once dependencies are installed locally. Ensure the host machine has AVX-capable CPU for MediaPipe.

## Future Enhancements

- Day/night look toggles with alternate palettes.
- Hairstyle or eyewear suggestions keyed off face shape.
- Optional on-device profile storage with secure enclave for history tracking.

## Privacy Statement

FaceMap Beauty is designed so that analytics never leave the device. If integrating the FastAPI layer, deploy it locally or within trusted infrastructure to maintain the same privacy guarantees.
