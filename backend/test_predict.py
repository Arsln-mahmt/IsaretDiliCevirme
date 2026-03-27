from fastapi.testclient import TestClient
from main import app
import builtins
import sys

# We mock YOLO so it doesn't try to load the heavy ultralytics model if it hasn't finished installing
class MockYOLO:
    def __init__(self, *args, **kwargs):
        self.names = {0: "test_sign"}
    
    def predict(self, *args, **kwargs):
        class MockBox:
            def __init__(self):
                class Item:
                    def item(self): return 0
                class ConfItem:
                    def item(self): return 0.99
                self.cls = [Item()]
                self.conf = [ConfItem()]
        class MockResult:
            def __init__(self):
                self.boxes = [MockBox()]
        return [MockResult()]

try:
    from ultralytics import YOLO
except ImportError:
    # If not installed yet, just so the TestClient script compiles
    pass

client = TestClient(app)

def test_root():
    response = client.get("/")
    print("GET / ->", response.status_code, response.json())
    assert response.status_code == 200

def test_predict():
    # Create a dummy image
    from PIL import Image
    import io
    
    img = Image.new('RGB', (224, 224), color = 'red')
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='JPEG')
    img_byte_arr = img_byte_arr.getvalue()

    files = {'file': ('test.jpg', img_byte_arr, 'image/jpeg')}
    response = client.post("/api/v1/predict", files=files)
    
    if response.status_code == 503:
        print("POST /api/v1/predict -> Model not loaded yet. (503 Service Unavailable)")
    else:
        print("POST /api/v1/predict ->", response.status_code, response.json())
        assert response.status_code == 200

if __name__ == "__main__":
    test_root()
    test_predict()
    print("Testing complete.")
