from fastapi import FastAPI, UploadFile, File
from transformers import Blip2Processor, Blip2ForConditionalGeneration
import torch, io
from PIL import Image

app = FastAPI()
device = "cuda" if torch.cuda.is_available() else "cpu"

model_id = "Salesforce/blip2-opt-2.7b"
processor = Blip2Processor.from_pretrained(model_id)
model = Blip2ForConditionalGeneration.from_pretrained(
    model_id, device_map=device, torch_dtype="auto"
)

@app.get("/healthz", include_in_schema=False)
def healthz():
    return {"status": "ok"}

@app.post("/caption")
async def caption(image: UploadFile = File(...)):
    img_bytes = await image.read()
    img = Image.open(io.BytesIO(img_bytes)).convert("RGB")

    inputs = processor(images=img, return_tensors="pt").to(device)
    tokens = model.generate(**inputs, max_new_tokens=30)
    text = processor.decode(tokens[0], skip_special_tokens=True).strip()

    return {"caption": text}
