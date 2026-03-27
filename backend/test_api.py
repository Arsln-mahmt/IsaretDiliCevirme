from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_read_main():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Welcome to the Sign Language Translation API", "status": "Running"}
    print("GET / passed:", response.json())

def test_predict_endpoint():
    # Simulate a file upload
    files = {'file': ('test.jpg', b'test_image_data', 'image/jpeg')}
    response = client.post("/api/v1/predict", files=files)
    assert response.status_code == 200
    expected_response = {
        "success": True,
        "predicted_text": "Merhaba",
        "confidence_score": 0.95,
        "message": "Prediction successful (simulated)."
    }
    assert response.json() == expected_response
    print("POST /api/v1/predict passed:", response.json())

if __name__ == "__main__":
    test_read_main()
    test_predict_endpoint()
    print("All tests passed successfully.")
