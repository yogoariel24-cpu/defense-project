import os
import io
import base64
import cv2
import numpy as np
from datetime import datetime
from typing import Optional, Dict, Any, List
from fastapi import FastAPI, File, UploadFile, HTTPException, Query, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

from services.yolo_detector import YOLODetector
from services.face_checker import FaceChecker
from services.video_stream_worker import VideoStreamWorker

load_dotenv()

PORT = int(os.getenv("PORT", "5001"))
HOST = os.getenv("HOST", "0.0.0.0")
MODEL_NAME = os.getenv("YOLO_MODEL", "yolov8n.pt")
CONF_THRESHOLD = float(os.getenv("CONFIDENCE_THRESHOLD", "0.45"))
NODE_BACKEND_URL = os.getenv("NODE_BACKEND_URL", "http://localhost:5000/api/security/detections")
AI_SERVICE_SECRET = os.getenv("AI_SERVICE_SECRET", "vigilis_ai_secret_key_2026")

app = FastAPI(
    title="Vigilis AI Vision Service",
    description="Dedicated YOLO + OpenCV Edge-AI Detection Microservice for Vigilis Security Monitoring",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize AI Components
yolo = YOLODetector(model_name=MODEL_NAME, conf_threshold=CONF_THRESHOLD)
face_checker = FaceChecker()
stream_worker = VideoStreamWorker(
    yolo_detector=yolo,
    face_checker=face_checker,
    backend_url=NODE_BACKEND_URL,
    service_secret=AI_SERVICE_SECRET
)

class StreamStartRequest(BaseModel):
    source: str = "0"  # "0" for webcam, or rtsp/http url or file path
    house_id: str = "HS-9982"
    camera_id: Optional[str] = "cam_front_01"
    camera_name: str = "Perimeter Camera"
    interval: float = 1.0

class ImageDetectPayload(BaseModel):
    image_base64: str
    house_id: Optional[str] = "HS-9982"
    camera_id: Optional[str] = None
    camera_name: Optional[str] = "Virtual Camera"

@app.get("/health")
def health():
    return {
        "status": "ONLINE",
        "service": "Vigilis YOLO + OpenCV AI Detection Service",
        "timestamp": datetime.utcnow().isoformat(),
        "model_loaded": yolo.is_ready(),
        "model_name": MODEL_NAME,
        "stream_active": stream_worker.is_active(),
        "stats": stream_worker.stats,
    }

@app.post("/detect")
async def detect_from_upload(file: UploadFile = File(...)):
    """
    Accepts an uploaded image file (JPEG/PNG), runs OpenCV decoding and YOLO detection,
    and returns structured detections.
    """
    if not yolo.is_ready():
        raise HTTPException(status_code=503, detail="YOLO model is not ready or failed to initialize.")

    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if frame is None:
            raise HTTPException(status_code=400, detail="Invalid image file format.")

        detections = yolo.detect(frame)
        has_person = any(d["category"] == "person" for d in detections)
        has_face = False

        if has_person:
            for d in detections:
                if d["category"] == "person":
                    box = d["box"]
                    crop = frame[max(0, box["y1"]):box["y2"], max(0, box["x1"]):box["x2"]]
                    face_res = face_checker.check_face_in_crop(crop)
                    if face_res["has_face"]:
                        has_face = True
                        break

        return {
            "success": True,
            "filename": file.filename,
            "timestamp": datetime.utcnow().isoformat(),
            "count": len(detections),
            "has_person": has_person,
            "has_face": has_face,
            "detections": detections,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inference error: {str(e)}")

@app.post("/detect/base64")
async def detect_from_base64(payload: ImageDetectPayload):
    """
    Accepts base64 image data, decodes via OpenCV, and runs YOLO inference.
    """
    if not yolo.is_ready():
        raise HTTPException(status_code=503, detail="YOLO model is not ready.")

    try:
        data = payload.image_base64
        if "," in data:
            data = data.split(",")[1]

        image_bytes = base64.b64decode(data)
        nparr = np.frombuffer(image_bytes, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if frame is None:
            raise HTTPException(status_code=400, detail="Could not decode base64 image.")

        detections = yolo.detect(frame)
        has_person = any(d["category"] == "person" for d in detections)
        has_face = False

        if has_person:
            for d in detections:
                if d["category"] == "person":
                    box = d["box"]
                    crop = frame[max(0, box["y1"]):box["y2"], max(0, box["x1"]):box["x2"]]
                    face_res = face_checker.check_face_in_crop(crop)
                    if face_res["has_face"]:
                        has_face = True
                        break

        return {
            "success": True,
            "house_id": payload.house_id,
            "camera_id": payload.camera_id,
            "timestamp": datetime.utcnow().isoformat(),
            "count": len(detections),
            "has_person": has_person,
            "has_face": has_face,
            "detections": detections,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inference error: {str(e)}")

@app.post("/stream/start")
def start_stream(req: StreamStartRequest):
    """
    Starts the continuous background OpenCV stream worker (Webcam, RTSP, or sample video).
    """
    success = stream_worker.start(
        source=req.source,
        house_id=req.house_id,
        camera_id=req.camera_id,
        camera_name=req.camera_name,
        interval=req.interval,
    )
    return {
        "success": success,
        "message": f"Stream worker started for source '{req.source}'",
        "house_id": req.house_id,
        "interval": req.interval,
    }

@app.post("/stream/stop")
def stop_stream():
    """
    Stops the continuous stream worker.
    """
    stream_worker.stop()
    return {
        "success": True,
        "message": "Stream worker stopped successfully.",
    }

@app.get("/stream/status")
def stream_status():
    return {
        "is_active": stream_worker.is_active(),
        "source": stream_worker.current_source,
        "house_id": stream_worker.current_house_id,
        "camera_name": stream_worker.current_camera_name,
        "stats": stream_worker.stats,
        "last_detection": stream_worker.last_detection_summary,
    }

if __name__ == "__main__":
    import uvicorn
    print(f"🚀 Starting Vigilis AI Service on http://{HOST}:{PORT}...")
    uvicorn.run(app, host=HOST, port=PORT)
