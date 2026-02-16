# Flutter App Guide

This document focuses on the Flutter frontend and how it integrates with the Python/FastAPI backend.

## Features

- Multi-image selection
- Local desktop processing (runs Python script directly)
- Remote mobile processing (uploads to FastAPI)
- Results summary + per-pair comparison view
- Clear/reset uploaded image set

## Flutter Dependencies

Defined in `pubspec.yaml`:

- `image_picker`
- `http`
- `path_provider`
- `permission_handler`

Install with:

```bash
flutter pub get
```

## Main Files

- `lib/main.dart`
  - App entrypoint

- `lib/screens/home_screen.dart`
  - Pick images
  - Trigger recognition
  - Show progress/status

- `lib/screens/results_screen.dart`
  - Parse `results.txt`/API response text
  - Render summary and pair cards

- `lib/services/face_recognition_service.dart`
  - `runFaceRecognition()` for desktop local execution
  - `runRemoteFaceRecognition()` for FastAPI mode
  - `parseResults()` to map output text into UI model

## Running

### Desktop mode (Windows)

```bash
flutter run -d windows
```

Desktop uses local Python execution via `Process.run`.

### Mobile mode (Android emulator)

Start backend first:

```bash
python -m uvicorn server_api:app --host 0.0.0.0 --port 8000
```

Then run:

```bash
flutter run -d emulator-5554
```

`FaceRecognitionService` uses `http://10.0.2.2:8000` for Android emulator.

## Troubleshooting

### Python command not found (desktop)

- Ensure Python is installed and available on PATH.
- Or update the command in `face_recognition_service.dart` to a full Python executable path.

### Mobile cannot connect to backend

- Verify FastAPI is running.
- Ensure emulator uses `10.0.2.2` (not `localhost`) for host machine access.

### No results shown

- Check `results.txt` generation in Python pipeline.
- Confirm response body from `/compare` contains `success: true` and `results` text.

## Build Release (Windows)

```bash
flutter build windows --release
```

Output is placed under:

- `build/windows/runner/Release/`
