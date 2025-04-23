from fastapi import FastAPI, UploadFile, File
from faster_whisper import WhisperModel
import shutil, tempfile, torch

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
model = WhisperModel("medium", device=DEVICE, compute_type="int8")  # ajuste size

app = FastAPI()

@app.get("/healthz", include_in_schema=False)
def healthz():
    return {"status": "ok", "device": DEVICE}

@app.post("/transcribe")
async def transcribe(file: UploadFile = File(...)):
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        shutil.copyfileobj(file.file, tmp)
        tmp.flush()
        segments, _ = model.transcribe(tmp.name, language="pt")  # força PT
        text = " ".join([seg.text for seg in segments])
    return {"text": text}
