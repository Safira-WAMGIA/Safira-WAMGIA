from TTS.api import TTS
from flask import Flask, request, send_file
import uuid
import os

app = Flask(__name__)
tts = TTS(model_name=os.getenv("COQUI_MODEL", "tts_models/en/ljspeech/tacotron2-DDC"), progress_bar=False, gpu=False)

@app.route("/speak", methods=["POST"])
def speak():
    text = request.json.get("text", "")
    if not text:
        return {"error": "No text provided"}, 400
    output_path = f"/tmp/{uuid.uuid4()}.wav"
    tts.tts_to_file(text=text, file_path=output_path)
    return send_file(output_path, mimetype="audio/wav")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9001)
