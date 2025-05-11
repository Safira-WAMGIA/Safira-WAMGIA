from fastapi import FastAPI
from instagrapi import Client
import os

app = FastAPI()
cl = Client()

@app.on_event("startup")
def login():
    session_path = "session/session.json"
    if os.path.exists(session_path):
        cl.load_settings(session_path)
        cl.login(os.getenv("IG_USERNAME"), os.getenv("IG_PASSWORD"))
        cl.dump_settings(session_path)
    else:
        cl.login(os.getenv("IG_USERNAME"), os.getenv("IG_PASSWORD"))
        cl.dump_settings(session_path)

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/post")
def post_image(caption: str = "Teste", path: str = "post.jpg"):
    media = cl.photo_upload(path, caption)
    return {"media_id": media.pk}
