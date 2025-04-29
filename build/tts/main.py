from fastapi.staticfiles import StaticFiles
import io, os
import soundfile as sf
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from TTS.api import TTS

MODEL_NAME = os.getenv("TTS_MODEL_NAME", "tts_models/multilingual/multi-dataset/xtts_v2")
tts = TTS(model_name=MODEL_NAME, progress_bar=False, gpu=False)

app = FastAPI(title="Safira – TTS", version="1.0")
app.mount("/audio", StaticFiles(directory="/app/audio"), name="audio")
class TTSRequest(BaseModel):
    text: str
    language_id: str = "pt"
    speaker_wav: str | None = None

@app.post("/tts", summary="Texto → áudio (wav)")
async def tts_endpoint(req: TTSRequest):
    txt = req.text.strip()
    if not txt:
        raise HTTPException(400, "Campo 'text' vazio.")

    try:
        wav = tts.tts(
            text=txt,
            language=req.language_id,
            speaker_wav=req.speaker_wav
        )
    except Exception as e:
        raise HTTPException(500, f"Erro ao sintetizar áudio: {str(e)}")

    buf = io.BytesIO()
    sf.write(buf, wav, tts.synthesizer.output_sample_rate, format="WAV")
    buf.seek(0)
    return StreamingResponse(buf, media_type="audio/wav")

@app.get("/health")
async def health():
    return {"status": "ok"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", 5000)), proxy_headers=True)
