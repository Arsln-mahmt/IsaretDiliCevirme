from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import io
from PIL import Image
import numpy as np

# Load the YOLO model (assuming Ultralytics YOLOv8)
try:
    from ultralytics import YOLO
    # Ensure the path points to where you placed the model
    MODEL_PATH = "models/best.pt"
    model = YOLO(MODEL_PATH)
    MODEL_LOADED = True
    print(f"Model successfully loaded from {MODEL_PATH}")
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
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

class TranslationResponse(BaseModel):
    success: bool
    predicted_text: str
    confidence_score: float
    message: str

@app.get("/")
async def root():
    status = "Running and Model Loaded" if MODEL_LOADED else "Running but Model Loading Failed"
    return {"message": "Welcome to the Sign Language Translation API", "status": status}

@app.post("/api/v1/predict", response_model=TranslationResponse)
async def predict_sign_language(file: UploadFile = File(...)):
    """
    Endpoint for predicting sign language from an uploaded frame.
    In a live camera feed, iOS should capture frames (e.g., 3-5 times a second)
    and send each frame as a POST request to this endpoint.
    """
    if not MODEL_LOADED:
        raise HTTPException(status_code=503, detail="The ML model is not loaded on the server.")

    try:
        # 1. Read the uploaded image bytes
        image_bytes = await file.read()
        
        # 2. Convert bytes to a PIL Image, then to a numpy array for OpenCV/YOLO
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        image_np = np.array(image)

        # 3. Run model inference
        # The 'verbose=False' argument keeps the console output clean during rapid requests
        results = model.predict(source=image_np, conf=0.5, verbose=False)
        
        if not results or len(results[0].boxes) == 0:
            return TranslationResponse(
                success=True,
                predicted_text="",
                confidence_score=0.0,
                message="No sign language detected in the frame."
            )

        # 4. Extract the best prediction (highest confidence)
        best_box = results[0].boxes[0]  # Take the first detected box
        class_id = int(best_box.cls[0].item())
        confidence = float(best_box.conf[0].item())
        predicted_class_name = model.names[class_id]
        
        return TranslationResponse(
            success=True,
            predicted_text=predicted_class_name,
            confidence_score=confidence,
            message="Prediction successful."
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    # Run the server locally on port 8000
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
