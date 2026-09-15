import os
import cv2
import numpy as np
from typing import List, Dict, Any, Tuple

# Categories mapping from standard 80-class COCO dataset
OBJECT_CATEGORIES = {
    "person": "person",
    "bicycle": "vehicle",
    "car": "vehicle",
    "motorcycle": "vehicle",
    "bus": "vehicle",
    "truck": "vehicle",
    "dog": "animal",
    "cat": "animal",
    "bird": "animal",
    "horse": "animal",
    "sheep": "animal",
    "cow": "animal",
    "backpack": "package",
    "suitcase": "package",
    "handbag": "package",
}

class YOLODetector:
    def __init__(self, model_name: str = "yolov8n.pt", conf_threshold: float = 0.45):
        self.model_name = model_name
        self.conf_threshold = conf_threshold
        self.model = None
        self._load_model()

    def _load_model(self):
        try:
            from ultralytics import YOLO
            print(f"📦 [YOLO] Loading model '{self.model_name}'...")
            self.model = YOLO(self.model_name)
            print(f"✅ [YOLO] Model '{self.model_name}' initialized successfully.")
        except Exception as e:
            print(f"⚠️ [YOLO] Error loading Ultralytics model: {e}")
            self.model = None

    def is_ready(self) -> bool:
        return self.model is not None

    def detect(self, frame: np.ndarray, conf: float = None) -> List[Dict[str, Any]]:
        """
        Runs YOLO object detection on a BGR or RGB image (numpy array).
        Returns list of structured detection dictionaries.
        """
        if self.model is None:
            return []

        threshold = conf if conf is not None else self.conf_threshold
        results = self.model(frame, conf=threshold, verbose=False)
        detections = []

        h, w = frame.shape[:2]

        for r in results:
            boxes = r.boxes
            for box in boxes:
                cls_id = int(box.cls[0].item())
                cls_name = self.model.names.get(cls_id, str(cls_id))
                confidence = float(box.conf[0].item())
                
                # Bounding box coordinates [x1, y1, x2, y2]
                xyxy = box.xyxy[0].tolist()
                x1, y1, x2, y2 = [int(v) for v in xyxy]

                box_w = max(0, x2 - x1)
                box_h = max(0, y2 - y1)

                category = OBJECT_CATEGORIES.get(cls_name.lower(), "other")

                detections.append({
                    "class_name": cls_name,
                    "category": category,
                    "confidence": round(confidence, 4),
                    "box": {
                        "x1": x1,
                        "y1": y1,
                        "x2": x2,
                        "y2": y2,
                        "w": box_w,
                        "h": box_h,
                    },
                    "normalized_box": {
                        "x": round(x1 / w, 4) if w > 0 else 0,
                        "y": round(y1 / h, 4) if h > 0 else 0,
                        "w": round(box_w / w, 4) if w > 0 else 0,
                        "h": round(box_h / h, 4) if h > 0 else 0,
                    }
                })

        return detections

    def draw_detections(self, frame: np.ndarray, detections: List[Dict[str, Any]]) -> np.ndarray:
        """
        Draws visual bounding boxes, labels, and confidence tags on the OpenCV frame.
        """
        annotated = frame.copy()
        for det in detections:
            box = det["box"]
            cls_name = det["class_name"]
            conf = det["confidence"]
            cat = det.get("category", "other")

            # Color coding by category
            if cat == "person":
                color = (0, 255, 255) # Yellow/Cyan
            elif cat == "vehicle":
                color = (255, 165, 0) # Orange
            elif cat == "animal":
                color = (0, 255, 0)   # Green
            else:
                color = (200, 200, 200)

            x1, y1, x2, y2 = box["x1"], box["y1"], box["x2"], box["y2"]
            cv2.rectangle(annotated, (x1, y1), (x2, y2), color, 2)

            label = f"{cls_name.upper()} {int(conf * 100)}%"
            (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
            cv2.rectangle(annotated, (x1, max(0, y1 - 20)), (x1 + tw + 6, max(0, y1)), color, -1)
            cv2.putText(annotated, label, (x1 + 3, max(14, y1 - 5)), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 1, cv2.LINE_AA)

        return annotated
