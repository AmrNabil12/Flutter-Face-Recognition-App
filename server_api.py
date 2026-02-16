from fastapi import FastAPI, UploadFile, File, Form
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from typing import List
from pathlib import Path
import shutil
import subprocess
import sys
import time
import os

app = FastAPI(title="Face Recognition API")

BASE_DIR = Path(__file__).resolve().parent
RAW_DIR = BASE_DIR / "RawImages"
PAIRS_DIR = BASE_DIR / "pairs"
RESULTS_FILE = BASE_DIR / "results.txt"
PYTHON_EXECUTABLE = os.environ.get("PYTHON_EXECUTABLE") or sys.executable

PAIRS_DIR.mkdir(parents=True, exist_ok=True)

app.mount("/pairs", StaticFiles(directory=str(PAIRS_DIR)), name="pairs")

def clear_raw_images() -> None:
    if RAW_DIR.exists():
        for item in RAW_DIR.iterdir():
            if item.is_file():
                item.unlink()
    else:
        RAW_DIR.mkdir(parents=True, exist_ok=True)


@app.post("/compare")
async def compare_faces(
    images: List[UploadFile] = File(...),
    threshold: float = Form(1.0),
):
    try:
        if len(images) < 2:
            return JSONResponse(
                status_code=400,
                content={"success": False, "error": "Please upload at least two images."},
            )

        clear_raw_images()

        for upload in images:
            filename = f"{int(time.time() * 1000)}_{upload.filename}"
            destination = RAW_DIR / filename
            with destination.open("wb") as buffer:
                shutil.copyfileobj(upload.file, buffer)

        result = subprocess.run(
            [
                PYTHON_EXECUTABLE,
                "Face_Recognition_System.py",
                "--input-dir",
                str(RAW_DIR),
                "--output-dir",
                str(PAIRS_DIR),
                "--threshold",
                str(threshold),
                "--results-file",
                str(RESULTS_FILE),
            ],
            cwd=str(BASE_DIR),
            capture_output=True,
            text=True,
        )

        if result.returncode != 0:
            return JSONResponse(
                status_code=500,
                content={
                    "success": False,
                    "error": result.stderr.strip() or "Face recognition failed.",
                    "output": result.stdout,
                },
            )

        if not RESULTS_FILE.exists():
            return JSONResponse(
                status_code=500,
                content={"success": False, "error": "Results file not found."},
            )

        results_text = RESULTS_FILE.read_text(encoding="utf-8")

        return {
            "success": True,
            "results": results_text,
            "output": result.stdout,
        }
    except Exception as exc:
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": str(exc)},
        )


@app.post("/clear")
async def clear_images():
    clear_raw_images()
    return {"success": True}


@app.get("/health")
async def health_check():
    return {"status": "ok", "python": PYTHON_EXECUTABLE}
