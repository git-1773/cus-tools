# feature_extract.py
import cv2
import numpy as np
import librosa
import subprocess
import tempfile
import os


def extract_motion_features(video_path, target_fps=10):
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"Cannot open video: {video_path}")

    orig_fps = cap.get(cv2.CAP_PROP_FPS)
    if orig_fps <= 0:
        orig_fps = 25

    step = max(1, int(orig_fps // target_fps))

    prev_gray = None
    diffs = []

    frame_idx = 0
    while True:
        ret, frame = cap.read()
        if not ret:
            break

        if frame_idx % step != 0:
            frame_idx += 1
            continue

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        if prev_gray is not None:
            diff = cv2.absdiff(gray, prev_gray)
            diffs.append(np.mean(diff))

        prev_gray = gray
        frame_idx += 1

    cap.release()

    if not diffs:
        return 0.0, 0.0, 0.0

    motion_mean = float(np.mean(diffs))
    motion_peak = float(np.max(diffs))
    motion_contrast = motion_peak / (motion_mean + 1e-6)

    return motion_mean, motion_peak, motion_contrast


def extract_audio_delta(video_path):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav_path = tmp.name

    try:
        subprocess.run(
            [
                "ffmpeg", "-y",
                "-i", video_path,
                "-ac", "1",
                "-ar", "22050",
                wav_path
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )

        y, sr = librosa.load(wav_path, sr=None)
        if y.size == 0:
            return 0.0

        rms = librosa.feature.rms(y=y)[0]
        return float(np.max(rms) - np.min(rms))

    finally:
        if os.path.exists(wav_path):
            os.remove(wav_path)


def extract_features(video_path):
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"Cannot open video: {video_path}")

    frame_count = cap.get(cv2.CAP_PROP_FRAME_COUNT)
    fps = cap.get(cv2.CAP_PROP_FPS)
    cap.release()

    if fps <= 0:
        fps = 25

    duration = float(frame_count / fps)

    motion_mean, motion_peak, motion_contrast = extract_motion_features(video_path)
    audio_delta = extract_audio_delta(video_path)

    return {
        "duration": round(duration, 3),
        "motion_mean": round(motion_mean, 4),
        "motion_peak": round(motion_peak, 4),
        "motion_contrast": round(motion_contrast, 4),
        "audio_delta": round(audio_delta, 4),
    }
