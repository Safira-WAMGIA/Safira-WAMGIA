import os, subprocess, wave, json, uuid, tempfile
from flask import Flask, request, jsonify
import stt                       # Coqui-STT engine

MODEL_PATH  = os.getenv("STT_MODEL",  "/models/model.tflite")
SCORER_PATH = os.getenv("STT_SCORER", "/models/model.scorer")

model  = stt.Model(MODEL_PATH)
model.enableExternalScorer(SCORER_PATH)

app = Flask(__name__)

@app.route("/healthz")
def healthz():
    return "ok", 200

@app.route("/transcribe", methods=["POST"])
def transcribe():
    if "audio" not in request.files:
        return jsonify(error="file field 'audio' missing"), 400

    # salva áudio temporário
    raw = tempfile.NamedTemporaryFile(suffix=".bin", delete=False)
    request.files["audio"].save(raw.name)

    # converte p/ wav 16 kHz mono
    wav_path = f"/tmp/{uuid.uuid4()}.wav"
    cmd = ["ffmpeg", "-y", "-i", raw.name, "-ac", "1", "-ar", "16000", wav_path]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # lê bytes e transcreve
    with wave.open(wav_path, "rb") as w:
        audio = w.readframes(w.getnframes())
    text = model.stt(audio)

    # limpa
    os.remove(raw.name)
    os.remove(wav_path)

    return jsonify(text=text)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9002)
