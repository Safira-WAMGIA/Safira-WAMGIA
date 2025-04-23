"""Audio utilities for CSM-1B API."""

import io
import tempfile
from typing import Optional
import os

import torch
import torchaudio
import ffmpeg


def convert_audio_format(
    audio_tensor: torch.Tensor,
    sample_rate: int,
    format: str = "mp3",
    bit_rate: Optional[str] = "128k",
) -> bytes:
    """Convert audio tensor to specified format.
    
    Args:
        audio_tensor: Audio tensor (channels, samples)
        sample_rate: Sample rate
        format: Output format (mp3, opus, aac, flac, wav)
        bit_rate: Bit rate for lossy formats
    
    Returns:
        Audio bytes in specified format
    """
    # Create temporary files
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_wav:
        wav_path = temp_wav.name
    
    temp_out = tempfile.NamedTemporaryFile(suffix=f".{format}", delete=False)
    out_path = temp_out.name
    temp_out.close()
    
    try:
        # Save as WAV first (native format for torchaudio)
        torchaudio.save(wav_path, audio_tensor.unsqueeze(0) if audio_tensor.dim() == 1 else audio_tensor, 
                        sample_rate)
        
        # Convert to desired format using ffmpeg
        if format == "mp3":
            ffmpeg.input(wav_path).output(out_path, format=format, audio_bitrate=bit_rate).run(quiet=True)
        elif format in ["opus", "aac"]:
            ffmpeg.input(wav_path).output(out_path, format=format).run(quiet=True)
        elif format == "flac":
            ffmpeg.input(wav_path).output(out_path, format=format).run(quiet=True)
        elif format == "wav":
            # Already saved as WAV
            pass
        
        # Read the output file
        with open(out_path if format != "wav" else wav_path, "rb") as f:
            audio_bytes = f.read()
        
        return audio_bytes
    
    finally:
        # Clean up temporary files
        for path in [wav_path, out_path]:
            if os.path.exists(path):
                os.unlink(path)
