# Face Recognition System (Python + Flutter + FastAPI)

This repository contains a complete face-recognition workflow with:

- **Python pipeline** for face detection + embedding comparison
- **FastAPI backend** for remote/mobile processing
- **Flutter app** for desktop/mobile UI

The project is organized so it can be uploaded to GitHub cleanly, without large temporary/build files.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Repository Structure](#repository-structure)
3. [Prerequisites](#prerequisites)
4. [Installation](#installation)
5. [Running the System](#running-the-system)
6. [Model Weights](#model-weights)
7. [Documentation Map](#documentation-map)
8. [GitHub Readiness Notes](#github-readiness-notes)

## Project Overview

### Core Python pipeline

- `Face_Recognition_System.py` orchestrates the full flow
- `Face_Cropping.py` detects and crops faces
- `MTCNN_model.py` defines MTCNN face detection model code
- `inception_resnet_v1.py` generates face embeddings and computes distances

### API layer

- `server_api.py` exposes REST endpoints for upload/compare/clear/health

### Flutter app

- `lib/screens/home_screen.dart` handles image selection + run action
- `lib/screens/results_screen.dart` displays pair comparisons and summary
- `lib/services/face_recognition_service.dart` handles desktop local execution and mobile API calls

## Repository Structure

```text
Face Recognition System/
├── Face_Recognition_System.py
├── Face_Cropping.py
├── MTCNN_model.py
├── inception_resnet_v1.py
├── server_api.py
├── lib/
│   ├── main.dart
│   ├── screens/
│   └── services/
├── android/
├── windows/
├── MTweights/          # MTCNN weights (small, tracked)
├── weights/            # InceptionResnet weights (large *.pt ignored by default)
├── RawImages/          # Runtime input (gitignored)
├── pairs/              # Runtime output crops (gitignored)
├── results.txt         # Runtime output (gitignored)
├── QUICK_START.md
├── APP_STRUCTURE.md
├── FLUTTER_APP_README.md
├── requirements.txt
└── .gitignore
```

## Prerequisites

- **Python** 3.8+
- **Flutter** 3.x and Dart 3.x
- (Optional) CUDA-capable GPU for faster inference

## Installation

### 1) Install Python dependencies

```bash
python -m pip install --upgrade pip
pip install -r requirements.txt
```

### 2) Install Flutter dependencies

```bash
flutter pub get
```

## Running the System

### A) Python pipeline only

1. Put input images in `RawImages/`
2. Run:

```bash
python Face_Recognition_System.py --input-dir RawImages --output-dir pairs --threshold 1.0 --results-file results.txt
```

Output:

- Cropped faces in `pairs/`
- Comparison report in `results.txt`

### B) FastAPI backend

```bash
python -m uvicorn server_api:app --host 0.0.0.0 --port 8000
```

Endpoints:

- `GET /health`
- `POST /compare` (multipart images + threshold)
- `POST /clear`
- `GET /pairs/{image}` (served from `pairs/`)

### C) Flutter app

#### Desktop (local processing)

```bash
flutter run -d windows
```

#### Android emulator / mobile (remote processing)

1. Start the API server (previous section)
2. Run app:

```bash
flutter run -d emulator-5554
```

## Model Weights

- `MTweights/*.pt` are used by MTCNN face detection.
- `weights/20180402-114759-vggface2.pt` is required by `inception_resnet_v1.py`.

> Large weight files in `weights/*.pt` are intentionally gitignored to keep the repository GitHub-friendly and avoid file-size issues. Keep them locally or use Git LFS if you want to version them.

## Documentation Map

- **`QUICK_START.md`** → minimal commands to run quickly
- **`APP_STRUCTURE.md`** → architecture and data flow
- **`FLUTTER_APP_README.md`** → Flutter-focused usage and troubleshooting

## GitHub Readiness Notes

The root `.gitignore` excludes:

- Build artifacts and caches (`build/`, `.dart_tool/`, `__pycache__/`, etc.)
- Runtime outputs (`RawImages/`, `pairs/`, `results.txt`)
- Large local datasets (`test_images/`)
- Large model checkpoints in `weights/*.pt`
- IDE/editor/system noise files

### Suggested first push workflow

```bash
git init
git add .
git status
git commit -m "Initial project structure and documentation"
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```
