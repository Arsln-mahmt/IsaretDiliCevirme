# Backend - Turkish Sign Language Translation API

This is the FastAPI backend for the iOS application. 

## Setup Instructions for PyCharm

1. Open PyCharm.
2. Select **Open** and choose the `backend` folder located here: `/Users/mahmutarslan/Desktop/TİDProject-Bitirme2/backend`.
3. PyCharm should automatically detect the `venv` virtual environment or offer to create one.
   * If it doesn't, go to **PyCharm > Preferences > Settings > Project > Python Interpreter**.
   * Add a new interpreter by selecting the existing `venv` folder (or creating a new virtual environment).
4. Install the requirements defined in `requirements.txt`. (PyCharm may prompt you to do this automatically). 
   ```bash
   pip install -r requirements.txt
   ```
5. Run the application locally by executing:
   ```bash
   uvicorn main:app --reload
   ```
   Or simply right-click `main.py` in PyCharm and click **Run 'main'**.

## API Endpoints

- `GET /` : Health check endpoint.
- `POST /api/v1/predict` : Endpoint that will take iOS requests (image/video file) and return the sign language translation response.
