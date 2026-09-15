"""
Vigilis Sample Video / Image Test Script
Tests YOLO + OpenCV object detection on a video file or test image without requiring physical cameras.
"""
import os
import sys
import cv2
import numpy as np
from services.yolo_detector import YOLODetector
from services.face_checker import FaceChecker

def create_synthetic_security_frame() -> np.ndarray:
    """Generates a synthetic surveillance test frame if no external file is supplied."""
    frame = np.zeros((480, 640, 3), dtype=np.uint8)
    # Background porch / door
    cv2.rectangle(frame, (0, 0), (640, 480), (35, 30, 30), -1)
    cv2.rectangle(frame, (240, 100), (400, 450), (60, 50, 50), -1) # Door
    cv2.circle(frame, (380, 270), 8, (180, 180, 80), -1) # Doorknob

    # Draw a simulated figure
    cv2.circle(frame, (320, 180), 30, (200, 160, 140), -1) # Head
    cv2.rectangle(frame, (290, 210), (350, 350), (80, 80, 180), -1) # Torso

    cv2.putText(frame, "SYNTHETIC SURVEILLANCE FEED (PORCH)", (20, 40),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
    return frame

def main():
    print("🎬 Initializing Vigilis Video / Image Test...")
    detector = YOLODetector("yolov8n.pt", conf_threshold=0.40)
    face_checker = FaceChecker()

    if len(sys.argv) > 1:
        input_path = sys.argv[1]
    else:
        input_path = None

    if input_path and os.path.isfile(input_path):
        print(f"📁 Opening file: {input_path}")
        cap = cv2.VideoCapture(input_path)
        is_video = True
    else:
        print("ℹ️ No file specified. Running synthetic surveillance test frame...")
        cap = None
        is_video = False

    if is_video:
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                continue

            detections = detector.detect(frame)
            display = detector.draw_detections(frame, detections)
            cv2.imshow("Vigilis Video Test (Press 'q' to quit)", display)
            if cv2.waitKey(25) & 0xFF == ord('q'):
                break
        cap.release()
        cv2.destroyAllWindows()
    else:
        frame = create_synthetic_security_frame()
        detections = detector.detect(frame)
        print(f"✅ Detection Results on Synthetic Frame: {len(detections)} objects found.")
        for d in detections:
            print(f"   - Class: {d['class_name']}, Conf: {d['confidence']}, Category: {d['category']}")
        annotated = detector.draw_detections(frame, detections)
        out_file = "test_detection_output.jpg"
        cv2.imwrite(out_file, annotated)
        print(f"💾 Annotated test output saved to: {out_file}")

if __name__ == "__main__":
    main()
