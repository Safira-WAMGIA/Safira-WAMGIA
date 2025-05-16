from fastapi import FastAPI, Query
from pydantic import BaseModel
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

class Message(BaseModel):
    username: str
    message: str

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/dm/send")
def send_dm(data: Message):
    user_id = cl.user_id_from_username(data.username)
    cl.direct_send(data.message, [user_id])
    return {"status": "sent", "to": data.username}

@app.get("/dm/inbox")
def get_inbox():
    threads = cl.direct_threads(amount=10)
    return {"threads": [t.dict() for t in threads]}

@app.get("/dm/thread")
def get_thread(thread_id: str = Query(...)):
    messages = cl.direct_messages(thread_id)
    return {"messages": [m.dict() for m in messages]}
