"""
Vigilis Standalone Webcam Test Script
Tests OpenCV camera capture and Ultralytics YOLO real-time inference with visual window.
Press 'q' in the window to quit.
"""
import sys
import cv2
from services.yolo_detector import YOLODetector
from services.face_checker import FaceChecker

def main():
    print("🎥 Initializing Vigilis OpenCV Webcam Test...")
    detector = YOLODetector("yolov8n.pt", conf_threshold=0.45)
    face_checker = FaceChecker()

    camera_index = 0
    if len(sys.argv) > 1 and sys.argv[1].isdigit():
        camera_index = int(sys.argv[1])

    cap = cv2.VideoCapture(camera_index)
    if not cap.isOpened():
        print(f"❌ Error: Cannot open webcam index {camera_index}.")
        print("Tip: If you are running headless or on a virtual machine, use test_video.py instead.")
        return

    print(f"✅ Webcam {camera_index} connected! Processing frames. Press 'q' to exit.")

    frame_count = 0
    while True:
        ret, frame = cap.read()
        if not ret:
            print("⚠️ Failed to grab frame.")
            break

        frame_count += 1
        # Run YOLO inference
        detections = detector.detect(frame)

        # Check for face if person is in view
        for d in detections:
            if d["category"] == "person":
                box = d["box"]
                crop = frame[max(0, box["y1"]):box["y2"], max(0, box["x1"]):box["x2"]]
                face_info = face_checker.check_face_in_crop(crop)
                if face_info["has_face"]:
                    d["class_name"] += " [FACE]"

        # Draw bounding boxes and labels
        display_frame = detector.draw_detections(frame, detections)

        # Add status banner
        banner_text = f"VIGILIS AI RADAR | Objects: {len(detections)} | Frame: {frame_count}"
        cv2.putText(display_frame, banner_text, (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

        cv2.imshow("Vigilis YOLO + OpenCV Test", display_frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()
    print("🛑 Webcam test ended.")

if __name__ == "__main__":
    main()
