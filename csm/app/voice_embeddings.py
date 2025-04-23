"""Voice embeddings for consistent voice generation."""
import os
import torch
import torchaudio
import numpy as np
from typing import Dict

# Path to store voice samples
VOICE_SAMPLES_DIR = os.path.join(os.path.dirname(__file__), "voice_samples")
os.makedirs(VOICE_SAMPLES_DIR, exist_ok=True)

# Dictionary to store voice embeddings/samples
VOICE_DICT: Dict[str, torch.Tensor] = {}


def initialize_voices(sample_rate: int = 24000):
    """Initialize voice dictionary with consistent samples."""
    # Generate consistent seed audio for each voice
    for voice_id in range(6):
        voice_name = ["alloy", "echo", "fable", "onyx", "nova", "shimmer"][voice_id]
        
        # Create deterministic audio sample for each voice
        np.random.seed(voice_id + 42)  # Use a fixed seed based on voice ID
        
        # Generate 1 second of "seed" audio with deterministic characteristics
        # This differs per voice but remains consistent across runs
        duration = 1.0  # seconds
        t = np.linspace(0, duration, int(sample_rate * duration), endpoint=False)
        
        # Create a distinctive waveform for each voice
        if voice_id == 0:  # alloy - rich mid tones
            freq1, freq2 = 220, 440
            audio = 0.5 * np.sin(2 * np.pi * freq1 * t) + 0.3 * np.sin(2 * np.pi * freq2 * t)
        elif voice_id == 1:  # echo - reverberant
            freq = 330
            audio = np.sin(2 * np.pi * freq * t) * np.exp(-t * 3)
        elif voice_id == 2:  # fable - bright, higher pitch
            freq = 523
            audio = 0.7 * np.sin(2 * np.pi * freq * t)
        elif voice_id == 3:  # onyx - deep and resonant
            freq = 165
            audio = 0.8 * np.sin(2 * np.pi * freq * t)
        elif voice_id == 4:  # nova - warm and smooth
            freq1, freq2 = 392, 196
            audio = 0.4 * np.sin(2 * np.pi * freq1 * t) + 0.4 * np.sin(2 * np.pi * freq2 * t)
        else:  # shimmer - airy and light
            freq1, freq2, freq3 = 587, 880, 1174
            audio = 0.3 * np.sin(2 * np.pi * freq1 * t) + 0.2 * np.sin(2 * np.pi * freq2 * t) + 0.1 * np.sin(2 * np.pi * freq3 * t)
            
        # Normalize
        audio = audio / np.max(np.abs(audio))
        
        # Convert to tensor
        audio_tensor = torch.tensor(audio, dtype=torch.float32)
        
        # Store the audio tensor
        VOICE_DICT[voice_name] = audio_tensor
        
        # Save as wav for reference
        save_path = os.path.join(VOICE_SAMPLES_DIR, f"{voice_name}_seed.wav")
        torchaudio.save(save_path, audio_tensor.unsqueeze(0), sample_rate)
        
        print(f"Initialized voice seed for {voice_name}")


def get_voice_sample(voice_name: str) -> torch.Tensor:
    """Get the voice sample for a given voice name."""
    if not VOICE_DICT:
        initialize_voices()
    
    if voice_name in VOICE_DICT:
        return VOICE_DICT[voice_name]
        
    # Default to alloy if voice not found
    print(f"Voice {voice_name} not found, defaulting to alloy")
    return VOICE_DICT["alloy"]


def update_voice_sample(voice_name: str, audio: torch.Tensor):
    """Update the voice sample with recently generated audio."""
    # Only update if we've already initialized
    if VOICE_DICT:
        # Take the last second of audio (or whatever is available)
        sample_length = min(24000, audio.shape[0])
        VOICE_DICT[voice_name] = audio[-sample_length:].detach().cpu()
