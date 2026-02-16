# Application Structure

This document describes the high-level architecture and data flow for the Face Recognition System.

## 1) Components

### A. Python recognition pipeline

- `Face_Recognition_System.py`
  - Main orchestrator
  - Runs cropping and pairwise comparison
  - Writes final report to `results.txt`

- `Face_Cropping.py`
  - Reads images from `RawImages/`
  - Uses MTCNN to detect faces
  - Writes cropped faces to `pairs/`

- `MTCNN_model.py`
  - MTCNN implementation and helper functions
  - Uses `MTweights/*.pt`

- `inception_resnet_v1.py`
  - InceptionResnetV1 architecture
  - Loads embedding model weights from `weights/`

### B. Backend API

- `server_api.py` (FastAPI)
  - `POST /compare`: upload images and run recognition
  - `POST /clear`: clear uploaded images
  - `GET /health`: health endpoint
  - Static mount `/pairs`: serve cropped face images

### C. Flutter frontend

- `lib/main.dart`
  - App entrypoint and theme setup

- `lib/screens/home_screen.dart`
  - Image selection
  - Run recognition action
  - Mode-aware behavior (desktop local vs mobile remote)

- `lib/screens/results_screen.dart`
  - Parses and displays comparison report
  - Shows summary and per-pair details

- `lib/services/face_recognition_service.dart`
  - Local mode: executes Python process directly
  - Remote mode: sends multipart requests to FastAPI

## 2) Runtime Data Folders

- `RawImages/` → input images (runtime, gitignored)
- `pairs/` → cropped faces output (runtime, gitignored)
- `results.txt` → text report output (runtime, gitignored)

## 3) End-to-End Flow

```text
User selects images (Flutter)
        |
        +--> Desktop mode:
        |      save to RawImages/ and run local Python script
        |
        +--> Mobile mode:
               upload to FastAPI /compare
                        |
                        v
                Face_Recognition_System.py
                        |
            Face_Cropping.py -> pairs/
                        |
          InceptionResnet comparison (all pairs)
                        |
                   results.txt
                        |
      Flutter parses and displays result summary/details
```

## 4) Key Design Notes

- The same Python pipeline is reused by both desktop and mobile flows.
- Output format in `results.txt` is intentionally simple for easy parsing in Flutter.
- `.gitignore` is configured to avoid committing large generated data and local build artifacts.
