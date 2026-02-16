#!/usr/bin/env python3
"""
Complete Face Recognition System
===============================

This script combines face detection/cropping and face comparison into a single workflow.
It processes images from the RawImages folder, crops faces using MTCNN, and compares ALL
pairs of detected faces using InceptionResnetV1.

Usage:
    python Face_Recognition_System.py [options]

Options:
    --input-dir INPUT_DIR     Input directory containing images (default: RawImages)
    --output-dir OUTPUT_DIR   Output directory for cropped faces (default: pairs)
    --threshold THRESHOLD     Distance threshold for face matching (default: 1.0)
    --device {cuda,cpu}       Device to run models on
    --verbose                 Enable verbose output
"""
import os
import sys
import argparse
import torch
from PIL import Image
from pathlib import Path
from typing import List, Tuple, Optional
import logging
import numpy as np
from inception_resnet_v1 import InceptionResnetV1

class FaceRecognitionSystem:
    """Complete face recognition system combining detection and comparison."""

    def __init__(self, device: Optional[str] = None, verbose: bool = False):
        self.verbose = verbose
        self._setup_logging()

        if device is None:
            self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        else:
            self.device = torch.device(device)

        self.logger.info(f"Using device: {self.device}")
        self._init_models()

    def _setup_logging(self):
        level = logging.INFO if self.verbose else logging.WARNING
        logging.basicConfig(
            level=level,
            format='%(asctime)s - %(levelname)s - %(message)s',
            datefmt='%H:%M:%S'
        )
        self.logger = logging.getLogger(__name__)

    def _init_models(self):

        self.logger.info("Initializing InceptionResnetV1...")
        try:
            self.model = InceptionResnetV1(
                pretrained='vggface2',
                classify=False,
                device=self.device
            )
            self.model.eval()
        except ImportError as e:
            print(f"Error loading InceptionResnetV1: {e}")
            sys.exit(1)

    def crop_faces_from_directory(self, input_dir: str, output_dir: str) -> List[str]:
        import subprocess
        import time

        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        for item in output_path.iterdir():
            if item.is_file() and item.suffix.lower() in {".jpg", ".jpeg", ".png"}:
                item.unlink()

        self.logger.info("Running Face_Cropping.py...")
        result = subprocess.run(
            [
                sys.executable,
                'Face_Cropping.py',
                '--input-dir',
                input_dir,
                '--output-dir',
                output_dir,
                '--device',
                self.device.type,
            ],
            capture_output=True,
            text=True,
            cwd=os.getcwd()
        )

        if result.returncode != 0:
            self.logger.error(result.stderr)
            return []

        time.sleep(1)

        saved_faces = []
        i = 1

        while True:
            img = output_path / f"{i}.jpg"
            if img.exists():
                saved_faces.append(str(img))
                i += 1
            else:
                break

        return saved_faces

    def load_image(self, image_path: str) -> torch.Tensor:
        img = Image.open(image_path).convert('RGB')
        img = img.resize((160, 160))

        img_array = np.array(img).astype(np.float32)
        img_tensor = torch.from_numpy(img_array).permute(2, 0, 1)

        img_tensor = img_tensor / 255.0
        img_tensor = (img_tensor - 0.5) / 0.5

        return img_tensor.unsqueeze(0).to(self.device)

    def compare_faces(self, img1_path: str, img2_path: str) -> float:
        img1 = self.load_image(img1_path)
        img2 = self.load_image(img2_path)

        with torch.no_grad():
            emb1 = self.model(img1)
            emb2 = self.model(img2)

        return torch.norm(emb1 - emb2, p=2).item()

    def compare_all_pairs(
        self,
        face_images: List[str],
        threshold: float
    ) -> List[Tuple[str, str, float, bool]]:

        if len(face_images) < 2:
            self.logger.warning("Need at least two faces.")
            return []

        results = []

        for i in range(len(face_images)):
            for j in range(i + 1, len(face_images)):
                d = self.compare_faces(face_images[i], face_images[j])
                same = d < threshold
                results.append((face_images[i], face_images[j], d, same))

        return results


def main():
    parser = argparse.ArgumentParser(
        description="Face recognition system (compare ALL face pairs)"
    )

    parser.add_argument('--input-dir', default='RawImages')
    parser.add_argument('--output-dir', default='pairs')
    parser.add_argument('--threshold', type=float, default=1.0)
    parser.add_argument('--device', choices=['cuda', 'cpu'], default=None)
    parser.add_argument('--verbose', action='store_true')
    parser.add_argument('--results-file',default='results.txt',help='Output file to save comparison results')


    args = parser.parse_args()

    system = FaceRecognitionSystem(
        device=args.device,
        verbose=args.verbose
    )

    print(f"\n=== Step 1: Cropping faces from {args.input_dir} ===")
    faces = system.crop_faces_from_directory(
        args.input_dir,
        args.output_dir
    )

    if not faces:
        print("No faces detected.")
        return

    print(f"Cropped {len(faces)} faces.")

    print(f"\n=== Step 2: Comparing ALL face pairs ===")
    results = system.compare_all_pairs(faces, args.threshold)

    if not results:
        print("No comparisons made.")
        return

    same_count = 0
    results_path = Path(args.results_file)

    with open(results_path, "w", encoding="utf-8") as f:
        f.write("=== Face Recognition Results ===\n\n")

        for img1, img2, dist, same in results:
            line = (
                f"{Path(img1).name} vs {Path(img2).name} -> "
                f"{dist:.4f} ({'SAME' if same else 'DIFFERENT'})\n"
            )
            f.write(line)

            if same:
                same_count += 1

        f.write("\n=== Summary ===\n")
        f.write(f"Total comparisons: {len(results)}\n")
        f.write(f"Same person: {same_count}\n")
        f.write(f"Different persons: {len(results) - same_count}\n")

    print(f"\nResults saved to: {results_path.resolve()}")

if __name__ == "__main__":
    main()
