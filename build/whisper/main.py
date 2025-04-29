import os, tempfile, subprocess, uuid, json, wave
from flask import Flask, request, jsonify
from faster_whisper import WhisperModel


MODEL_SIZE   = os.getenv("WHISPER_MODEL", "large-v3") 
LANGUAGE     = os.getenv("WHISPER_LANGUAGE", "pt") 
DEVICE       = os.getenv("WHISPER_DEVICE", "cpu")
COMPUTE_TYPE = os.getenv("WHISPER_COMPUTE_TYPE", "int8")

model = WhisperModel(MODEL_SIZE, device=DEVICE, compute_type=COMPUTE_TYPE)
print(f"Whisper {MODEL_SIZE} carregado em {DEVICE} ({COMPUTE_TYPE})")

app = Flask(__name__)

@app.route("/healthz")
def healthz():
    return "ok", 200

@app.route("/transcribe", methods=["POST"])
def transcribe():
    if "file" not in request.files:
        return jsonify(error="campo 'file' ausente"), 400

    raw = tempfile.NamedTemporaryFile(delete=False, suffix=".bin")
    request.files["file"].save(raw.name)

    wav_path = f"/tmp/{uuid.uuid4()}.wav"
    cmd = ["ffmpeg", "-y", "-i", raw.name, "-ac", "1", "-ar", "16000", wav_path]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    segments, info = model.transcribe(wav_path, language=LANGUAGE, beam_size=5)
    transcription = " ".join([s.text.strip() for s in segments])

    os.remove(raw.name)
    os.remove(wav_path)

    return jsonify({
        "transcription": transcription,
        "language": info.language,
        "language_probability": round(info.language_probability, 3)
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9000)
