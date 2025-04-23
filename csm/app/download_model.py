"""Download CSM-1B model from Hugging Face."""

import os
import argparse
from huggingface_hub import hf_hub_download

def download_model(output_dir="models"):
    """Download CSM-1B model from Hugging Face."""
    print("Downloading CSM-1B model...")
    os.makedirs(output_dir, exist_ok=True)
    
    # Download model
    model_path = hf_hub_download(
        repo_id="sesame/csm-1b",
        filename="ckpt.pt",
        local_dir=output_dir,
        local_dir_use_symlinks=False
    )
    
    print(f"Model downloaded to {model_path}")
    return model_path

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Download CSM-1B model")
    parser.add_argument("--output", type=str, default="models", help="Output directory")
    args = parser.parse_args()
    
    download_model(args.output)
