import os
import time
import threading
import cv2
import requests
import base64
from datetime import datetime
from typing import Optional, Dict, Any
from .yolo_detector import YOLODetector
from .face_checker import FaceChecker

class VideoStreamWorker:
    """
    Background worker that manages an OpenCV VideoCapture stream (Webcam, RTSP, HTTP, or Video File),
    runs YOLO object detection at a throttled frame rate, and dispatches structured detection
    events to the Vigilis Node.js Express backend.
    """
    def __init__(
        self,
        yolo_detector: YOLODetector,
        face_checker: FaceChecker,
        backend_url: str = "http://localhost:5000/api/security/detections",
        service_secret: str = "vigilis_ai_secret_key_2026",
    ):
        self.yolo = yolo_detector
        self.face_checker = face_checker
        self.backend_url = backend_url
        self.service_secret = service_secret

        self._thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()
        self._is_running = False

        self.current_source: Optional[str] = None
        self.current_house_id: str = "HS-9982"
        self.current_camera_id: Optional[str] = None
        self.current_camera_name: str = "Live OpenCV Camera"
        self.frame_interval: float = 1.0 # 1 inference per second
        self.last_detection_summary: Dict[str, Any] = {}
        self.stats = {
            "frames_processed": 0,
            "events_dispatched": 0,
            "last_error": None,
            "started_at": None,
        }

    def is_active(self) -> bool:
        return self._is_running and self._thread is not None and self._thread.is_alive()

    def start(
        self,
        source: str = "0",
        house_id: str = "HS-9982",
        camera_id: Optional[str] = None,
        camera_name: str = "Live OpenCV Camera",
        interval: float = 1.0,
    ) -> bool:
        if self.is_active():
            self.stop()

        self.current_source = source
        self.current_house_id = house_id
        self.current_camera_id = camera_id
        self.current_camera_name = camera_name
        self.frame_interval = max(0.2, interval)
        self._stop_event.clear()

        self._thread = threading.Thread(target=self._run_loop, daemon=True)
        self._thread.start()
        self._is_running = True
        self.stats["started_at"] = datetime.utcnow().isoformat()
        print(f"🎬 [StreamWorker] Started processing source '{source}' for house '{house_id}' at {self.frame_interval}s interval.")
        return True

    def stop(self):
        self._stop_event.set()
        self._is_running = False
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2.0)
        self._thread = None
        print("🛑 [StreamWorker] Stream processing stopped.")

    def _run_loop(self):
        # Determine source (integer for local webcam or string for URL/file)
        src = self.current_source
        if isinstance(src, str) and src.isdigit():
            cap_source = int(src)
        else:
            cap_source = src

        cap = cv2.VideoCapture(cap_source)
        if not cap.isOpened():
            err = f"Failed to open video source '{src}'"
            print(f"❌ [StreamWorker] {err}")
            self.stats["last_error"] = err
            self._is_running = False
            return

        last_inference_time = 0.0

        try:
            while not self._stop_event.is_set():
                ret, frame = cap.read()
                if not ret or frame is None:
                    # If video file reached end, loop or wait
                    if isinstance(src, str) and not src.isdigit() and os.path.exists(src):
                        cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                        continue
                    else:
                        print("⚠️ [StreamWorker] Camera disconnected or empty frame received.")
                        time.sleep(1.0)
                        continue

                now = time.time()
                if now - last_inference_time >= self.frame_interval:
                    last_inference_time = now
                    self._process_single_frame(frame)

                # Short sleep to prevent busy loop
                time.sleep(0.02)
        except Exception as e:
            print(f"❌ [StreamWorker] Error in stream loop: {e}")
            self.stats["last_error"] = str(e)
        finally:
            cap.release()
            self._is_running = False

    def _process_single_frame(self, frame):
        self.stats["frames_processed"] += 1
        detections = self.yolo.detect(frame)

        if not detections:
            return

        self.last_detection_summary = {
            "timestamp": datetime.utcnow().isoformat(),
            "count": len(detections),
            "classes": [d["class_name"] for d in detections],
        }

        # Filter for key security classes
        security_detections = [
            d for d in detections if d.get("category") in ("person", "vehicle", "animal")
        ]

        if not security_detections:
            return

        # Check for face if person is detected
        has_face = False
        face_confidence = 0.0

        for det in security_detections:
            if det.get("category") == "person":
                box = det["box"]
                crop = frame[max(0, box["y1"]):box["y2"], max(0, box["x1"]):box["x2"]]
                face_res = self.face_checker.check_face_in_crop(crop)
                if face_res["has_face"]:
                    has_face = True
                    face_confidence = face_res["confidence"]
                    break

        primary_det = max(security_detections, key=lambda d: d["confidence"])

        # Create optional base64 thumbnail for security snapshot
        snapshot_b64 = None
        try:
            # Resize thumbnail to save bandwidth
            thumb = cv2.resize(frame, (480, 270))
            _, buffer = cv2.imencode(".jpg", thumb, [int(cv2.IMWRITE_JPEG_QUALITY), 65])
            snapshot_b64 = "data:image/jpeg;base64," + base64.b64encode(buffer).decode("utf-8")
        except Exception:
            pass

        # Dispatch structured detection payload to Node.js backend
        payload = {
            "house_id": self.current_house_id,
            "camera_id": self.current_camera_id,
            "camera_name": self.current_camera_name,
            "object_type": primary_det["category"],
            "class_name": primary_det["class_name"],
            "confidence": primary_det["confidence"],
            "bounding_box": primary_det["normalized_box"],
            "has_face": has_face,
            "face_confidence": face_confidence,
            "snapshot_data": snapshot_b64,
            "timestamp": datetime.utcnow().isoformat(),
        }

        self._dispatch_to_backend(payload)

    def _dispatch_to_backend(self, payload: Dict[str, Any]):
        headers = {
            "Content-Type": "application/json",
            "x-ai-service-key": self.service_secret,
        }
        try:
            res = requests.post(self.backend_url, json=payload, headers=headers, timeout=3.0)
            if res.status_code in (200, 201):
                self.stats["events_dispatched"] += 1
            else:
                print(f"⚠️ [StreamWorker] Backend returned status {res.status_code}: {res.text[:100]}")
        except Exception as e:
            # Backend might be temporarily starting or offline; fail gracefully
            self.stats["last_error"] = f"Backend dispatch failed: {e}"
