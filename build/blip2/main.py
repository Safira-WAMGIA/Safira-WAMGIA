from lavis.models import load_model_and_preprocess
from PIL import Image
from flask import Flask, request, jsonify
import torch
import os

app = Flask(__name__)
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model, vis_processors, _ = load_model_and_preprocess("blip2_t5", "pretrain_flant5xl", device=device)

@app.route("/describe", methods=["POST"])
def describe():
    if 'file' not in request.files:
        return {"error": "No file part"}, 400
    image = Image.open(request.files['file'].stream).convert("RGB")
    image_tensor = vis_processors["eval"](image).unsqueeze(0).to(device)
    output = model.generate({"image": image_tensor})
    return jsonify({"description": output[0]})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9003)
