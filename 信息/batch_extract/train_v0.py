# train_v0.py
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler

FEATURES = [
    "duration",
    "motion_mean",
    "motion_peak",
    "motion_contrast",
    "audio_delta",
]

def main():
    df = pd.read_csv("dataset_v0.csv")

    df = df.dropna(subset=["label"])

    if len(df) == 0:
        raise RuntimeError("No labeled samples found. Please fill the 'label' column.")

    X = df[FEATURES].values
    y = df["label"].astype(int).values

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    clf = LogisticRegression(
        multi_class="multinomial",
        max_iter=1000
    )
    clf.fit(X_scaled, y)

    print("\n=== Feature Weights ===")
    for cls_idx, cls in enumerate(clf.classes_):
        print(f"\nClass {cls}:")
        for feat, w in zip(FEATURES, clf.coef_[cls_idx]):
            print(f"  {feat:16s} {w:+.3f}")

if __name__ == "__main__":
    main()
