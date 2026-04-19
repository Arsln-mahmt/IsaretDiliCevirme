"""
Webcam Test Script — Tests the YOLOv8 model directly with your Mac's camera.
Opens a window showing the camera feed with real-time detections overlaid.

Usage:
    python test_webcam.py

Press 'q' to quit.
"""

import cv2
from ultralytics import YOLO

MODEL_PATH = "models/best.pt"

def main():
    # Load model
    print(f"Loading model from {MODEL_PATH}...")
    model = YOLO(MODEL_PATH)
    print(f"Model loaded! Classes: {model.names}")
    print(f"Total classes: {len(model.names)}")
    print("-" * 50)
    
    # Open webcam (0 = default camera)
    cap = cv2.VideoCapture(0)
    
    if not cap.isOpened():
        print("❌ Could not open webcam!")
        return
    
    print("✅ Webcam opened. Press 'q' to quit.")
    print("-" * 50)
    
    while True:
        ret, frame = cap.read()
        if not ret:
            print("❌ Could not read frame from webcam")
            break
        
        # Run YOLO prediction
        results = model.predict(source=frame, conf=0.25, verbose=False)
        
        # Draw results on frame
        if results and len(results[0].boxes) > 0:
            for box in results[0].boxes:
                # Get box coordinates
                x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())
                cls_id = int(box.cls[0].item())
                conf = float(box.conf[0].item())
                class_name = model.names[cls_id]
                
                # Draw bounding box
                color = (0, 255, 0)  # Green
                cv2.rectangle(frame, (x1, y1), (x2, y2), color, 3)
                
                # Draw label with background
                label = f"{class_name} {conf:.0%}"
                label_size, _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 1.2, 3)
                cv2.rectangle(frame, (x1, y1 - label_size[1] - 15), (x1 + label_size[0], y1), color, -1)
                cv2.putText(frame, label, (x1, y1 - 8), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 0, 0), 3)
                
                # Print to terminal
                print(f"✅ Detected: {class_name} ({conf:.0%})")
        
        # Show "No detection" text when nothing found
        if not results or len(results[0].boxes) == 0:
            cv2.putText(frame, "Hareket algilanmadi...", (30, 50), 
                       cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 0, 255), 2)
        
        # Show the frame
        cv2.imshow("YOLOv8 Sign Language Detection - Press 'q' to quit", frame)
        
        # Press 'q' to quit
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break
    
    cap.release()
    cv2.destroyAllWindows()
    print("Webcam closed.")

if __name__ == "__main__":
    main()
