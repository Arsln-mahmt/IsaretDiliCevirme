from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import io
import os
from PIL import Image, ImageOps
import numpy as np
import cv2

# Load the YOLO model (assuming Ultralytics YOLOv8)
try:
    from ultralytics import YOLO
    MODEL_PATH = "models/best.pt"
    model = YOLO(MODEL_PATH)
    MODEL_LOADED = True
    print(f"Model successfully loaded from {MODEL_PATH}")
    print(f"Model classes: {model.names}")
except Exception as e:
    print(f"Failed to load model from models/best.pt: {e}")
    MODEL_LOADED = False

app = FastAPI(
    title="Turkish Sign Language Translation API",
    description="Backend API for the iOS application to handle sign language predictions from camera frames.",
    version="1.0.0",
)

# Enable CORS for local testing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create debug folder to save frames for debugging
DEBUG_FRAMES = True
if DEBUG_FRAMES:
    os.makedirs("debug_frames", exist_ok=True)

frame_counter = 0

class TranslationResponse(BaseModel):
    success: bool
    predicted_text: str
    confidence_score: float
    message: str

@app.get("/")
async def root():
    status = "Running and Model Loaded" if MODEL_LOADED else "Running but Model Loading Failed"
    classes = list(model.names.values()) if MODEL_LOADED else []
    return {
        "message": "Welcome to the Sign Language Translation API",
        "status": status,
        "model_classes": classes
    }


def try_all_orientations(image_np):
    """
    Try the image in multiple orientations and return the best detection.
    This handles the fact that iOS cameras may send frames in unexpected orientations.
    """
    orientations = [
        ("original", image_np),
        ("rot90cw", cv2.rotate(image_np, cv2.ROTATE_90_CLOCKWISE)),
        ("rot90ccw", cv2.rotate(image_np, cv2.ROTATE_90_COUNTERCLOCKWISE)),
        ("rot180", cv2.rotate(image_np, cv2.ROTATE_180)),
        ("flip_h", cv2.flip(image_np, 1)),  # horizontal flip (mirror)
        ("rot90cw+flip", cv2.flip(cv2.rotate(image_np, cv2.ROTATE_90_CLOCKWISE), 1)),
        ("rot90ccw+flip", cv2.flip(cv2.rotate(image_np, cv2.ROTATE_90_COUNTERCLOCKWISE), 1)),
        ("rot180+flip", cv2.flip(cv2.rotate(image_np, cv2.ROTATE_180), 1)),
    ]
    
    best_result = None
    best_confidence = 0.0
    best_orientation = None
    
    for name, img in orientations:
        results = model.predict(source=img, conf=0.25, verbose=False)
        if results and len(results[0].boxes) > 0:
            for box in results[0].boxes:
                conf = float(box.conf[0].item())
                if conf > best_confidence:
                    best_confidence = conf
                    best_result = results
                    best_orientation = name
    
    return best_result, best_orientation, best_confidence


@app.post("/api/v1/predict", response_model=TranslationResponse)
async def predict_sign_language(file: UploadFile = File(...)):
    """
    Endpoint for predicting sign language from an uploaded frame.
    """
    global frame_counter
    
    if not MODEL_LOADED:
        raise HTTPException(status_code=503, detail="The ML model is not loaded on the server.")

    try:
        # 1. Read the uploaded image bytes
        image_bytes = await file.read()
        
        # 2. Convert bytes to a PIL Image
        image = Image.open(io.BytesIO(image_bytes))
        image = ImageOps.exif_transpose(image)
        image = image.convert("RGB")
        image_np = np.array(image)
        
        print(f"[API] 📷 Frame #{frame_counter}: shape={image_np.shape}")
        
        # Save debug frame
        if DEBUG_FRAMES and frame_counter % 10 == 0:
            debug_path = f"debug_frames/frame_{frame_counter}.jpg"
            image.save(debug_path)

        frame_counter += 1

        # 3. Try all orientations to find the best detection
        best_result, best_orientation, best_conf = try_all_orientations(image_np)
        
        if best_result is None:
            print(f"[API] ❌ No detection in any orientation")
            return TranslationResponse(
                success=True,
                predicted_text="",
                confidence_score=0.0,
                message="No sign language detected in the frame."
            )

        # 4. Extract the best prediction
        best_box = best_result[0].boxes[0]
        class_id = int(best_box.cls[0].item())
        confidence = float(best_box.conf[0].item())
        predicted_class_name = model.names[class_id]
        
        print(f"[API] ✅ Detected: '{predicted_class_name}' conf={confidence:.2f} orientation={best_orientation}")
        
        return TranslationResponse(
            success=True,
            predicted_text=predicted_class_name,
            confidence_score=confidence,
            message="Prediction successful."
        )
    except Exception as e:
        print(f"[API] 💥 Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
