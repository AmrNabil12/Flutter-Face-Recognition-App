# Quick Start

This guide gives the fastest path to run the project after cloning.

## 1) Install dependencies

### Python

```bash
python -m pip install --upgrade pip
pip install -r requirements.txt
```

### Flutter

```bash
flutter pub get
```

## 2) Run Python pipeline (local)

1. Put test images inside `RawImages/`
2. Run:

```bash
python Face_Recognition_System.py --input-dir RawImages --output-dir pairs --threshold 1.0 --results-file results.txt
```

Expected outputs:

- `pairs/` (cropped faces)
- `results.txt` (comparison report)

## 3) Run API backend (optional for mobile)

```bash
python -m uvicorn server_api:app --host 0.0.0.0 --port 8000
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

## 4) Run Flutter app

### Windows desktop

```bash
flutter run -d windows
```

### Android emulator (uses backend)

1. Keep FastAPI server running
2. Run:

```bash
flutter run -d emulator-5554
```

## Notes

- Desktop mode runs Python locally.
- Mobile mode sends images to FastAPI backend.
- The repository `.gitignore` excludes runtime folders (`RawImages/`, `pairs/`, `results.txt`) and heavy local files.
