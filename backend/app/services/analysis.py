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
    bounding_box = tuple(overlay["bounding_box"])
    recommendations = build_recommendations(shape, undertone)
    insights = build_insights(points, bounding_box, dimensions, (tone, undertone, sample_rgb), shape)

    response = {
        "dimensions": dimensions,
        "face_shape": shape,
        "skin_tone": tone,
        "undertone": undertone,
        "skin_sample_rgb": sample_rgb,
        "overlay": overlay,
        "recommendations": recommendations,
        "insights": insights,
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


def build_insights(
    points: List[Tuple[float, float]],
    bounding_box: Tuple[float, float, float, float],
    dimensions: Dict[str, float],
    skin_tone: Tuple[str, str, Tuple[int, int, int]],
    face_shape: str,
) -> Dict:
    min_x, min_y, max_x, max_y = bounding_box
    width = max(max_x - min_x, 1e-6)
    height = max(max_y - min_y, 1e-6)

    symmetry = compute_symmetry(points, bounding_box)
    ratios = build_feature_ratios(dimensions)
    tone_summary = build_tone_summary(skin_tone[0], skin_tone[1], skin_tone[2])
    brow_score = compute_brow_balance(points, height)
    jaw_score = compute_jaw_definition(dimensions)

    return {
        "symmetry_score": symmetry["score"],
        "symmetry_description": symmetry["description"],
        "eye_alignment_difference": symmetry["eye_delta"],
        "guidance": symmetry["guidance"],
        "brow_balance_score": brow_score,
        "jaw_definition_score": jaw_score,
        "feature_ratios": ratios,
        "tone_summary": tone_summary,
        "face_shape": face_shape,
    }


def compute_symmetry(points: List[Tuple[float, float]], bounding_box: Tuple[float, float, float, float]) -> Dict[str, float | str]:
    min_x, min_y, max_x, max_y = bounding_box
    height = max(max_y - min_y, 1e-6)
    width = max(max_x - min_x, 1e-6)
    mid_x = (min_x + max_x) / 2

    def point(idx: int) -> Optional[Tuple[float, float]]:
        try:
            return points[idx]
        except IndexError:
            return None

    nose = point(1) or (mid_x, (min_y + max_y) / 2)
    left_cheek = point(234) or (min_x, (min_y + max_y) / 2)
    right_cheek = point(454) or (max_x, (min_y + max_y) / 2)

    left_dist = np.linalg.norm(np.array(left_cheek) - np.array(nose))
    right_dist = np.linalg.norm(np.array(right_cheek) - np.array(nose))

    max_dist = max(left_dist, right_dist, 1e-6)
    balance_delta = abs(left_dist - right_dist) / max_dist
    symmetry_score = max(0.0, 1.0 - min(1.0, balance_delta))

    if symmetry_score >= 0.9:
        description = "Highly balanced proportions across both sides of the face."
    elif symmetry_score >= 0.75:
        description = "Soft asymmetric accents add character and are easy to balance."
    else:
        description = "Cheek widths vary more noticeably; thoughtful contour can even things out."

    if symmetry_score >= 0.85:
        guidance = "Mirror highlight and blush placement to emphasize your natural balance."
    elif symmetry_score >= 0.65:
        guidance = "Concentrate highlight on the higher cheekbone and blend contour upward on the fuller side."
    else:
        guidance = "Use diagonal blush placement and tapered contour strokes to visually lift the softer side."

    left_eye = point(159) or (min_x, nose[1])
    right_eye = point(386) or (max_x, nose[1])
    eye_delta = abs(left_eye[1] - right_eye[1])
    eye_alignment_degrees = float(np.degrees(np.arctan2(eye_delta, width)))

    return {
        "score": symmetry_score,
        "description": description,
        "guidance": guidance,
        "eye_delta": eye_alignment_degrees,
    }


def compute_brow_balance(points: List[Tuple[float, float]], height: float) -> float:
    left_idx = 70
    right_idx = 300
    try:
        left = points[left_idx][1]
        right = points[right_idx][1]
    except IndexError:
        return 0.8

    delta = abs(left - right) / max(height, 1e-6)
    return max(0.0, 1.0 - min(1.0, delta * 3))


def compute_jaw_definition(dimensions: Dict[str, float]) -> float:
    jaw_angle = dimensions["jaw_angle"]
    normalized = max(0.0, min(1.0, (jaw_angle - np.radians(25)) / np.radians(25)))
    return 1.0 - abs(normalized - 0.5)


def build_feature_ratios(dimensions: Dict[str, float]) -> List[Dict[str, float | str]]:
    ratios: List[Dict[str, float | str]] = []

    def add_ratio(name: str, value: float, ideal: float, formatter) -> None:
        delta = value - ideal
        ratios.append(
            {
                "name": name,
                "value": value,
                "ideal": ideal,
                "delta": delta,
                "message": formatter(delta),
            }
        )

    length = dimensions["face_length"]
    cheek = max(dimensions["cheekbone_width"], 1e-6)
    length_ratio = length / cheek
    add_ratio(
        "Face length vs. width",
        length_ratio,
        1.33,
        lambda delta: "Elongated" if delta > 0.15 else ("Balanced" if abs(delta) < 0.05 else "Softly wider"),
    )

    forehead_to_jaw = dimensions["forehead_width"] / max(dimensions["jaw_width"], 1e-6)
    add_ratio(
        "Forehead vs. jaw width",
        forehead_to_jaw,
        1.0,
        lambda delta: "Stronger forehead" if delta > 0.1 else ("Even width" if abs(delta) < 0.05 else "Defined jaw"),
    )

    cheek_to_jaw = dimensions["cheekbone_width"] / max(dimensions["jaw_width"], 1e-6)
    add_ratio(
        "Cheekbone vs. jaw width",
        cheek_to_jaw,
        1.05,
        lambda delta: "Pronounced cheekbones" if delta > 0.1 else ("Balanced" if abs(delta) < 0.05 else "Softer cheeks"),
    )

    return ratios


def build_tone_summary(tone: str, undertone: str, rgb: Tuple[int, int, int]) -> Dict[str, object]:
    hex_color = "#{:02X}{:02X}{:02X}".format(*rgb)
    undertone_keywords = {
        "warm": ["Golden", "Sunlit", "Honey"],
        "cool": ["Rosy", "Berry", "Icy"],
        "neutral": ["Balanced", "Adaptive", "Versatile"],
    }
    finish_tips = {
        "warm": [
            "Lean toward softly glazed or dewy finishes to amplify warmth.",
            "Use bronze or caramel contour shades for seamless blending.",
        ],
        "cool": [
            "Pearl or opal highlights complement cooler undertones.",
            "Cool mauve or berry lip finishes add balance.",
        ],
        "neutral": [
            "You can mix warm and cool blushes to shift the look effortlessly.",
            "Try satin finishes for contour to maintain flexibility.",
        ],
    }

    return {
        "hex": hex_color,
        "keywords": undertone_keywords.get(undertone, undertone_keywords["neutral"]),
        "finish_tips": finish_tips.get(undertone, finish_tips["neutral"]),
    }
