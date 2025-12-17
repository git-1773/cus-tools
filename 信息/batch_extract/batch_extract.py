# batch_extract.py
import os
import csv
from feature_extract import extract_features

CLIP_DIR = "clips"
OUT_CSV = "dataset_v0.csv"


def main():
    clips = sorted(
        f for f in os.listdir(CLIP_DIR)
        if f.lower().endswith(".mp4")
    )

    if not clips:
        raise RuntimeError("No .mp4 files found in clips/")

    rows = []

    for fname in clips:
        path = os.path.join(CLIP_DIR, fname)
        print(f"Processing {fname} ...")

        feats = extract_features(path)

        row = {
            "clip": fname,
            **feats,
            "visible_ratio": "",  # 人工填 0 / 1
            "label": ""           # 人工填 0 / 1 / 2
        }
        rows.append(row)

    with open(OUT_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nSaved {len(rows)} rows to {OUT_CSV}")


if __name__ == "__main__":
    main()
