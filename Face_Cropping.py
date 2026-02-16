import os
import argparse
from PIL import Image
from MTCNN_model import MTCNN
import torch

def _parse_args():
    parser = argparse.ArgumentParser(description="Crop faces from images.")
    parser.add_argument("--input-dir", default="RawImages")
    parser.add_argument("--output-dir", default="pairs")
    parser.add_argument(
        "--device",
        choices=["cpu", "cuda"],
        default="cuda" if torch.cuda.is_available() else "cpu",
        help="Device to run models on.",
    )
    return parser.parse_args()


args = _parse_args()

# Input and output folders
input_dir = args.input_dir
output_dir = args.output_dir

device = torch.device(args.device)
if args.device == "cuda" and torch.cuda.is_available():
    print("Currently using GPU")

# Keep multiple_faces=True so MTCNN returns all detected faces
mtcnn = MTCNN(image_size=299, margin=20, post_process=True, device=device, keep_all=True)

# Create output directory if not exists
os.makedirs(output_dir, exist_ok=True)

# Counter for sequential filenames
face_counter = 1

for root, dirs, files in os.walk(input_dir):
    for file in files:
        if not file.lower().endswith(('.png', '.jpg', '.jpeg')):
            continue

        img_path = os.path.join(root, file)
        try:
            img = Image.open(img_path).convert("RGB")

            # Detect all faces
            faces, probs = mtcnn(img, return_prob=True)

            if faces is not None and len(faces) > 0:
                # Get bounding boxes
                boxes, _ = mtcnn.detect(img)
                if boxes is not None:
                    # Choose the largest face by area
                    areas = [(x2 - x1) * (y2 - y1) for (x1, y1, x2, y2) in boxes]
                    largest_idx = areas.index(max(areas))
                    face = faces[largest_idx]

                    # Convert [-1,1] -> [0,255]
                    face = (face + 1) / 2
                    face = face.permute(1, 2, 0).mul(255).byte().cpu().numpy()

                    face_img = Image.fromarray(face)
                    # Save with sequential number
                    save_file = os.path.join(output_dir, f"{face_counter}.jpg")
                    face_img.save(save_file)
                    face_counter += 1  # increment for next face
                else:
                    print(f" No valid bounding box in {img_path}")
            else:
                print(f" No face detected in {img_path}")

        except Exception as e:
            print(f" Could not process {img_path}: {e}")
