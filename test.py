import os
import torch
from torch import nn
from torch.utils.data import DataLoader, Dataset
from torchvision import datasets, transforms
import random
import argparse
from inception_resnet_v1 import InceptionResnetV1

# ----------------------
# Triplet Dataset
# ----------------------
class TripletFaceDataset(Dataset):
    def __init__(self, root, transform=None):
        self.dataset = datasets.ImageFolder(root=root, transform=transform)
        self.transform = transform
        self.class_to_idx = self.dataset.class_to_idx
        self.idx_to_class = {v: k for k, v in self.class_to_idx.items()}

        # Group indices by class
        self.class_indices = {}
        for idx, (_, label) in enumerate(self.dataset.samples):
            self.class_indices.setdefault(label, []).append(idx)

        if len(self.class_indices) < 2:
            raise ValueError("Dataset must contain at least 2 classes for negative sampling.")

    def __getitem__(self, index):
        anchor_img, anchor_label = self.dataset[index]

        # Positive (same class)
        positive_index = index
        while positive_index == index:
            positive_index = random.choice(self.class_indices[anchor_label])
        positive_img, _ = self.dataset[positive_index]

        # Negative (different class)
        negative_label = anchor_label
        while negative_label == anchor_label:
            negative_label = random.choice(list(self.class_indices.keys()))
        negative_index = random.choice(self.class_indices[negative_label])
        negative_img, _ = self.dataset[negative_index]

        return anchor_img, positive_img, negative_img, anchor_label

    def __len__(self):
        return len(self.dataset)


# ----------------------
# Ensure tensor output
# ----------------------
def ensure_tensor(x):
    if torch.is_tensor(x):
        return x
    if hasattr(x, "logits") and torch.is_tensor(x.logits):
        return x.logits
    if isinstance(x, (tuple, list)):
        for e in x:
            if torch.is_tensor(e):
                return e
            if hasattr(e, "logits") and torch.is_tensor(e.logits):
                return e.logits
    raise TypeError(f"Unsupported model output: {type(x)}")


# ----------------------
# Evaluation Function
# ----------------------
def evaluate(model, dataloader, criterion, device, epochs=5, threshold=1):
    loss_history = []
    acc_history = []
    ap_history = []
    an_history = []

    for epoch in range(epochs):
        model.eval()
        total_loss = 0.0
        total_samples = 0
        correct = 0
        total_pairs = 0

        all_ap_dist = []
        all_an_dist = []

        with torch.no_grad():
            for step, (anchor, positive, negative, _) in enumerate(dataloader, 1):
                anchor, positive, negative = anchor.to(device), positive.to(device), negative.to(device)

                # Forward pass
                anchor_out = ensure_tensor(model(anchor))
                positive_out = ensure_tensor(model(positive))
                negative_out = ensure_tensor(model(negative))

                # Triplet loss
                loss = criterion(anchor_out, positive_out, negative_out)
                total_loss += loss.item()
                total_samples += 1

                # Distances
                ap_dist = torch.norm(anchor_out - positive_out, p=2, dim=1)
                an_dist = torch.norm(anchor_out - negative_out, p=2, dim=1)

                all_ap_dist.extend(ap_dist.cpu().numpy())
                all_an_dist.extend(an_dist.cpu().numpy())

                # Accuracy update
                correct += ((ap_dist < threshold).sum().item() +
                            (an_dist > threshold).sum().item())
                total_pairs += 2 * anchor.size(0)

        avg_loss = total_loss / max(total_samples, 1)
        accuracy = correct / max(total_pairs, 1)
        mean_ap = sum(all_ap_dist) / len(all_ap_dist)
        mean_an = sum(all_an_dist) / len(all_an_dist)

        loss_history.append(avg_loss)
        acc_history.append(accuracy)
        ap_history.append(mean_ap)
        an_history.append(mean_an)

        print(f"==> Epoch [{epoch+1}/{epochs}] Summary: "
              f"Loss: {avg_loss:.4f}, Accuracy: {accuracy:.4f}, "
              f"Mean AP dist: {mean_ap:.4f}, Mean AN dist: {mean_an:.4f}")

    return loss_history, acc_history, ap_history, an_history


# ----------------------
# Main
# ----------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data_dir", type=str, default="/test_images", help="Path to test dataset")
    parser.add_argument("--batch_size", type=int, default=32)
    parser.add_argument("--epochs", type=int, default=5)
    parser.add_argument("--threshold", type=float, default=0.8, help="Distance threshold for accuracy")
    parser.add_argument("--pretrained", type=str, default="vggface2", choices=["vggface2", "casia-webface"],
                        help="Choose pretrained weights to use")
    args = parser.parse_args(args=[])

    # ----------------------
    # Setup device and model
    # ----------------------
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print("Using device:", device)
    print(f"Loading InceptionResnetV1 model with {args.pretrained} weights...")

    model = InceptionResnetV1(pretrained=args.pretrained, classify=False, device=device)
    model.eval()
    print("Model loaded successfully.")

    # ----------------------
    # Dataset and Dataloader
    # ----------------------
    transform = transforms.Compose([
        transforms.Resize((160, 160)),  # typical input size for InceptionResnetV1
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.5, 0.5, 0.5], std=[0.5, 0.5, 0.5])
    ])

    dataset = TripletFaceDataset(root=args.data_dir, transform=transform)
    dataloader = DataLoader(dataset,
                            batch_size=args.batch_size,
                            shuffle=True,
                            num_workers=2,
                            pin_memory=(device.type == "cuda"))

    # ----------------------
    # Loss and Evaluation
    # ----------------------
    criterion = nn.TripletMarginLoss(margin=0.8, p=2)

    evaluate(model, dataloader, criterion, device,
             epochs=args.epochs, threshold=args.threshold)
