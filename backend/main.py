from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

app = FastAPI(
    title="Turkish Sign Language Translation API",
    description="Backend API for the iOS application to handle sign language video/image predictions.",
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
    return {"message": "Welcome to the Sign Language Translation API", "status": "Running"}

@app.post("/api/v1/predict", response_model=TranslationResponse)
async def predict_sign_language(file: UploadFile = File(...)):
    """
    Dummy endpoint for predicting sign language from an uploaded file (video or image).
    """
    # 1. Validate file extension or type if needed.
    # 2. Save the uploaded file temporarily.
    # 3. Pass the file to your Colab-trained model for inference.
    # 4. Return the prediction result.
    
    # For now, we simulate a successful prediction:
    try:
        # Simulate processing time or model inference here
        simulated_prediction = "Merhaba"
        simulated_confidence = 0.95
        
        return TranslationResponse(
            success=True,
            predicted_text=simulated_prediction,
            confidence_score=simulated_confidence,
            message="Prediction successful (simulated)."
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    # Run the server locally on port 8000
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
