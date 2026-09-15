import cv2
import numpy as np
from typing import Optional, Dict, Any, Tuple

class FaceChecker:
    """
    OpenCV Face Detection module.
    Evaluates person crops identified by YOLO, checks for visible human faces,
    and extracts facial bounding regions for resident authorization matching.
    """
    def __init__(self):
        # Initialize standard OpenCV Haar Cascade for fast, dependency-free face detection
        cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        self.face_cascade = cv2.CascadeClassifier(cascade_path)
        if self.face_cascade.empty():
            print("⚠️ [FaceChecker] Warning: haarcascade_frontalface_default could not be loaded.")
        else:
            print("✅ [FaceChecker] OpenCV Face Cascade loaded successfully.")

    def check_face_in_crop(self, person_crop: np.ndarray) -> Dict[str, Any]:
        """
        Inspects a person crop for presence of a frontal human face.
        """
        if person_crop is None or person_crop.size == 0 or self.face_cascade.empty():
            return {"has_face": False, "confidence": 0.0, "face_box": None}

        gray = cv2.cvtColor(person_crop, cv2.COLOR_BGR2GRAY)
        gray = cv2.equalizeHist(gray)

        faces = self.face_cascade.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=4,
            minSize=(30, 30),
            flags=cv2.CASCADE_SCALE_IMAGE
        )

        if len(faces) > 0:
            # Largest detected face
            fx, fy, fw, fh = max(faces, key=lambda b: b[2] * b[3])
            return {
                "has_face": True,
                "confidence": 0.90,
                "face_box": {"x": int(fx), "y": int(fy), "w": int(fw), "h": int(fh)}
            }

        return {"has_face": False, "confidence": 0.0, "face_box": None}
