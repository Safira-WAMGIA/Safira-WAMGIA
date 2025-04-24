from faster_whisper import WhisperModel
from flask import Flask, request, jsonify
import tempfile
import os

app = Flask(__name__)
model_size = os.getenv("WHISPER_MODEL", "medium")
model = WhisperModel(model_size, compute_type="int8")

@app.route("/transcribe", methods=["POST"])
def transcribe():
    if 'file' not in request.files:
        return {"error": "No file provided"}, 400

    audio_file = request.files['file']
    with tempfile.NamedTemporaryFile(delete=False) as tmp:
        audio_file.save(tmp.name)
        segments, _ = model.transcribe(tmp.name)
        text = " ".join([seg.text for seg in segments])
        return jsonify({"transcription": text})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9000)
