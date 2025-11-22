from __future__ import annotations

import io
from typing import Dict, List, Tuple

import cv2
import mediapipe as mp
import numpy as np
from PIL import Image


mp_face_mesh = mp.solutions.face_mesh


def analyze_image(image_bytes: bytes) -> Dict:
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    np_image = np.array(image)
    height, width, _ = np_image.shape

    with mp_face_mesh.FaceMesh(
        static_image_mode=True,
        max_num_faces=1,
        refine_landmarks=True,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    ) as mesh:
        results = mesh.process(cv2.cvtColor(np_image, cv2.COLOR_RGB2BGR))

    if not results.multi_face_landmarks:
        raise ValueError("No face detected. Please retake the selfie with better lighting.")

    landmarks = results.multi_face_landmarks[0]
    points = [(lm.x * width, lm.y * height) for lm in landmarks.landmark]

    dimensions = calculate_dimensions(points)
    shape = classify_face(dimensions)
    tone, undertone, sample_rgb = analyze_skin_tone(np_image, points)
    overlay = generate_overlay(shape, points)
    recommendations = build_recommendations(shape, undertone)

    response = {
        "dimensions": dimensions,
        "face_shape": shape,
        "skin_tone": tone,
        "undertone": undertone,
        "skin_sample_rgb": sample_rgb,
        "overlay": overlay,
        "recommendations": recommendations,
    }

    return response


def calculate_dimensions(points: List[Tuple[float, float]]) -> Dict[str, float]:
    def distance(a: Tuple[float, float], b: Tuple[float, float]) -> float:
        return float(np.linalg.norm(np.array(a) - np.array(b)))

    forehead = distance(points[108], points[338])
    cheekbone = distance(points[234], points[454])
    jaw = distance(points[58], points[288])
    face_length = distance(points[10], points[152])

    jaw_left = np.array(points[172])
    chin = np.array(points[152])
    jaw_right = np.array(points[397])
    v_left = jaw_left - chin
    v_right = jaw_right - chin
    cosine = np.dot(v_left, v_right) / (np.linalg.norm(v_left) * np.linalg.norm(v_right) + 1e-6)
    jaw_angle = float(np.arccos(np.clip(cosine, -1.0, 1.0)))

    return {
        "forehead_width": forehead,
        "cheekbone_width": cheekbone,
        "jaw_width": jaw,
        "face_length": face_length,
        "jaw_angle": jaw_angle,
    }


def classify_face(dimensions: Dict[str, float]) -> str:
    forehead = dimensions["forehead_width"]
    cheekbone = dimensions["cheekbone_width"]
    jaw = dimensions["jaw_width"]
    length = dimensions["face_length"]
    jaw_angle = dimensions["jaw_angle"]

    width_avg = (forehead + cheekbone + jaw) / 3.0
    length_ratio = length / (width_avg + 1e-6)
    cheek_to_jaw = cheekbone / (jaw + 1e-6)
    forehead_to_jaw = forehead / (jaw + 1e-6)

    if length_ratio < 1.05:
        if jaw_angle < np.pi / 3.4:
            return "square"
        if cheek_to_jaw > 1.05:
            return "heart"
        return "round"

    if length_ratio >= 1.35:
        if cheek_to_jaw > 1.1 and forehead_to_jaw < 0.95:
            return "diamond"
        return "oblong"

    if cheek_to_jaw > 1.15:
        return "heart"

    if jaw_angle < np.pi / 3.5:
        return "square"

    if cheek_to_jaw > 1.05 and forehead_to_jaw > 1.05:
        return "heart"

    return "oval"


def analyze_skin_tone(image: np.ndarray, points: List[Tuple[float, float]]) -> Tuple[str, str, Tuple[int, int, int]]:
    cheek_indices = [93, 227, 137, 177]
    cheek_points = np.array([points[idx] for idx in cheek_indices], dtype=np.float32)

    mask = np.zeros((image.shape[0], image.shape[1]), dtype=np.uint8)
    cv2.fillConvexPoly(mask, cheek_points.astype(np.int32), 255)

    pixels = image[mask == 255]
    if pixels.size == 0:
        raise ValueError("Insufficient data for skin tone analysis. Try again.")

    avg_rgb = np.mean(pixels, axis=0)
    lab = rgb_to_lab(avg_rgb / 255.0)

    ita = np.degrees(np.arctan((lab[0] - 50.0) / (lab[2] + 1e-6)))
    if ita >= 55:
        tone = "very_light"
    elif ita >= 41:
        tone = "light"
    elif ita >= 28:
        tone = "medium"
    elif ita >= 10:
        tone = "tan"
    else:
        tone = "deep"

    if lab[1] < -2 and lab[2] < 10:
        undertone = "cool"
    elif lab[2] > 15:
        undertone = "warm"
    else:
        undertone = "neutral"

    return tone, undertone, tuple(int(v) for v in avg_rgb)


def rgb_to_lab(rgb: np.ndarray) -> np.ndarray:
    def gamma_correct(channel: np.ndarray) -> np.ndarray:
        return np.where(channel <= 0.04045, channel / 12.92, ((channel + 0.055) / 1.055) ** 2.4)

    r, g, b = gamma_correct(rgb)

    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = (0.2126 * r + 0.7152 * g + 0.0722 * b)
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(component: np.ndarray) -> np.ndarray:
        return np.where(component > 0.008856, component ** (1 / 3), (7.787 * component) + (16 / 116))

    fx, fy, fz = f(x), f(y), f(z)

    l = (116 * fy) - 16
    a = 500 * (fx - fy)
    b_val = 200 * (fy - fz)

    return np.array([l, a, b_val])


def generate_overlay(shape: str, points: List[Tuple[float, float]]) -> Dict[str, List[List[float]]]:
    xs, ys = zip(*points)
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    bounding_box = (min_x, min_y, max_x, max_y)

    def make_zone(zone_type: str, factor_y: float, height: float, inset: float) -> List[List[float]]:
        x1 = min_x + (max_x - min_x) * inset
        x2 = max_x - (max_x - min_x) * inset
        top = min_y + (max_y - min_y) * factor_y
        bottom = top + (max_y - min_y) * height
        return [[x1, bottom], [x1 + (max_x - min_x) * 0.05, top], [x2 - (max_x - min_x) * 0.05, top], [x2, bottom]]

    def ellipse(center_y_factor: float, width_factor: float, height_factor: float) -> List[List[float]]:
        center_x = (min_x + max_x) / 2
        center_y = min_y + (max_y - min_y) * center_y_factor
        radius_x = (max_x - min_x) * width_factor / 2
        radius_y = (max_y - min_y) * height_factor / 2
        points_list = []
        for degree in range(0, 360, 30):
            radians = np.radians(degree)
            x = center_x + np.cos(radians) * radius_x
            y = center_y + np.sin(radians) * radius_y
            points_list.append([float(x), float(y)])
        return points_list

    if shape == "round":
        zones = {
            "contour": make_zone("contour", 0.35, 0.4, 0.15),
            "blush": ellipse(0.55, 0.35, 0.25),
            "highlight": ellipse(0.4, 0.2, 0.2),
        }
    elif shape == "oval":
        zones = {
            "contour": make_zone("contour", 0.3, 0.4, 0.18),
            "blush": ellipse(0.6, 0.3, 0.2),
            "highlight": ellipse(0.38, 0.2, 0.18),
        }
    elif shape == "square":
        zones = {
            "contour": make_zone("contour", 0.3, 0.5, 0.1),
            "blush": ellipse(0.58, 0.32, 0.18),
            "highlight": ellipse(0.38, 0.22, 0.18),
        }
    elif shape == "heart":
        zones = {
            "contour": make_zone("contour", 0.25, 0.45, 0.12),
            "blush": ellipse(0.55, 0.28, 0.18),
            "highlight": ellipse(0.35, 0.2, 0.2),
        }
    elif shape == "oblong":
        zones = {
            "contour": make_zone("contour", 0.25, 0.5, 0.18),
            "blush": ellipse(0.6, 0.28, 0.18),
            "highlight": ellipse(0.42, 0.22, 0.18),
        }
    else:  # diamond
        zones = {
            "contour": make_zone("contour", 0.28, 0.45, 0.1),
            "blush": ellipse(0.55, 0.32, 0.2),
            "highlight": ellipse(0.36, 0.2, 0.18),
        }

    return {
        "bounding_box": list(bounding_box),
        "zones": {name: zone for name, zone in zones.items()},
    }


def build_recommendations(shape: str, undertone: str) -> Dict[str, Dict[str, List[str] | str]]:
    def shade_palette(category: str) -> List[str]:
        palettes = {
            "warm": {
                "blush": ["Peach", "Apricot", "Warm coral"],
                "eyes": ["Bronze", "Warm taupe", "Olive green"],
                "lips": ["Terracotta", "Warm nude", "Rust red"],
            },
            "cool": {
                "blush": ["Rose", "Soft berry", "Cool pink"],
                "eyes": ["Plum", "Soft grey", "Slate blue"],
                "lips": ["Berry", "Cool mauve", "Blue-based red"],
            },
            "neutral": {
                "blush": ["Dusty rose", "Neutral coral", "Soft mauve"],
                "eyes": ["Champagne", "Neutral brown", "Soft copper"],
                "lips": ["Rosewood", "Balanced nude", "Classic red"],
            },
        }
        return palettes.get(undertone, palettes["neutral"])[category]

    shape_guidance = {
        "round": {
            "blush": "Sweep blush above the apples and pull back toward temples.",
            "contour": "Contour beneath cheekbones and jawline for definition.",
            "highlight": "Highlight center of forehead, nose bridge, and chin.",
        },
        "oval": {
            "blush": "Apply to apples and blend outward along cheekbones.",
            "contour": "Light contour under cheekbones and temples.",
            "highlight": "Highlight cheekbone tops, brow bone, and cupid's bow.",
        },
        "square": {
            "blush": "Focus on cheek centers and blend softly to diffuse angles.",
            "contour": "Soften jawline and outer forehead, blending well.",
            "highlight": "Highlight center of face and cheekbone peaks.",
        },
        "heart": {
            "blush": "Place blush lower on cheeks and blend upward.",
            "contour": "Shade sides of forehead and lightly under cheekbones.",
            "highlight": "Highlight cheekbones and cupid's bow subtly on forehead.",
        },
        "oblong": {
            "blush": "Apply horizontally across cheeks to add width.",
            "contour": "Contour forehead top and chin to shorten appearance.",
            "highlight": "Highlight cheekbones and cupid's bow, skip chin.",
        },
        "diamond": {
            "blush": "Tap blush on apples and curve outward to soften cheekbones.",
            "contour": "Contour under cheekbones tapering toward temples.",
            "highlight": "Highlight forehead center, nose bridge, and chin.",
        },
    }

    base = shape_guidance.get(shape, shape_guidance["oval"])

    return {
        "blush": {
            "details": base["blush"],
            "suggested_shades": shade_palette("blush"),
        },
        "contour": {
            "details": base["contour"],
            "suggested_finishes": ["Soft matte stick", "Sheer cream", "Buildable powder"],
        },
        "highlight": {
            "details": base["highlight"],
            "suggested_finishes": ["Cream luminizer", "Soft pearl powder", "Liquid glow"],
        },
        "eyes": {
            "details": "Choose shades that complement your undertone and layer from matte to shimmer.",
            "suggested_shades": shade_palette("eyes"),
        },
        "lips": {
            "details": "Match lip families to undertone; adjust intensity for day or night looks.",
            "suggested_shades": shade_palette("lips"),
        },
    }
