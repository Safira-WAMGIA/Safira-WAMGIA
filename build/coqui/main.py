import io, os
import soundfile as sf
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from TTS.api import TTS

# Carrega o modelo uma única vez
MODEL_NAME = os.getenv("TTS_MODEL_NAME", "tts_models/pt/cv/vits")
tts = TTS(model_name=MODEL_NAME, progress_bar=False, gpu=False)

app = FastAPI(title="Safira – Coqui TTS", version="1.0")

class TTSRequest(BaseModel):
    text: str
    language_id: str = "pt"
    speaker_wav: str | None = None

@app.post("/tts")
async def tts_endpoint(req: TTSRequest):
    wav = tts.tts(
        req.text,
        speaker_wav=req.speaker_wav,
        language=req.language_id
    )
@app.post("/tts", summary="Texto → áudio (wav)")
async def tts_endpoint(req: TTSRequest):
    txt = req.text.strip()
    if not txt:
        raise HTTPException(400, "Campo 'text' vazio.")
    # Sintetiza
    wav = tts.tts(txt)
    buf = io.BytesIO()
    sf.write(buf, wav, tts.synthesizer.output_sample_rate, format="WAV")
    buf.seek(0)
    return StreamingResponse(buf, media_type="audio/wav")

# Ping healthcheck opcional
@app.get("/health")
async def health():
    return {"status": "ok"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=int(os.getenv("PORT", 5000)),
        proxy_headers=True,
    )

