"""Advanced voice memory system for consistent voice generation."""
import os
import torch
import torchaudio
import numpy as np
import random
import logging
from typing import Dict, List, Optional
from dataclasses import dataclass
from app.models import Segment

# Setup logging
logger = logging.getLogger(__name__)

# Path to store voice memories - use persistent location
VOICE_MEMORIES_DIR = "/app/voice_memories"
os.makedirs(VOICE_MEMORIES_DIR, exist_ok=True)

@dataclass
class VoiceMemory:
    """Store voice characteristics for consistent generation."""
    name: str  # Voice name (alloy, echo, etc.)
    speaker_id: int  # Speaker ID (0-5)
    # Store multiple audio segments for context
    audio_segments: List[torch.Tensor]  
    # Store text prompts that produced good results
    text_segments: List[str]
    # Base characteristics for this voice
    pitch_base: float  # Base pitch characteristic (Hz)
    timbre: str  # Voice quality descriptor
    
    def get_context_segments(self, device: torch.device, max_segments: int = 2) -> List[Segment]:
        """Get context segments for this voice."""
        if not self.audio_segments:
            return []
            
        # Select a limited number of segments to avoid context overflow
        num_segments = min(len(self.audio_segments), max_segments)
        indices = list(range(len(self.audio_segments)))
        random.shuffle(indices)
        selected_indices = indices[:num_segments]
        
        segments = []
        for i in selected_indices:
            segments.append(
                Segment(
                    speaker=self.speaker_id,
                    text=self.text_segments[i] if i < len(self.text_segments) else f"Voice sample {i}",
                    audio=self.audio_segments[i].to(device)
                )
            )
            
        return segments
    
    def update_with_new_audio(self, audio: torch.Tensor, text: str, max_stored: int = 5):
        """Update voice memory with newly generated audio."""
        # Add new audio and text
        self.audio_segments.append(audio.detach().cpu())
        self.text_segments.append(text)
        
        # Keep only the most recent segments
        if len(self.audio_segments) > max_stored:
            self.audio_segments = self.audio_segments[-max_stored:]
            self.text_segments = self.text_segments[-max_stored:]
            
    def save(self):
        """Save voice memory to persistent storage."""
        data = {
            "name": self.name,
            "speaker_id": self.speaker_id,
            "audio_segments": self.audio_segments,
            "text_segments": self.text_segments,
            "pitch_base": self.pitch_base,
            "timbre": self.timbre
        }
        
        # Save to the persistent directory
        save_path = os.path.join(VOICE_MEMORIES_DIR, f"{self.name}.pt")
        try:
            torch.save(data, save_path)
            logger.info(f"Saved voice memory for {self.name} to {save_path}")
        except Exception as e:
            logger.error(f"Error saving voice memory for {self.name}: {e}")
        
    @classmethod
    def load(cls, name: str) -> Optional['VoiceMemory']:
        """Load voice memory from persistent storage."""
        path = os.path.join(VOICE_MEMORIES_DIR, f"{name}.pt")
        if not os.path.exists(path):
            logger.info(f"No saved voice memory found for {name} at {path}")
            return None
            
        try:
            data = torch.load(path)
            return cls(
                name=data["name"],
                speaker_id=data["speaker_id"],
                audio_segments=data["audio_segments"],
                text_segments=data["text_segments"],
                pitch_base=data["pitch_base"],
                timbre=data["timbre"]
            )
        except Exception as e:
            logger.error(f"Error loading voice memory for {name}: {e}")
            return None

# Dictionary of voice memories
VOICE_MEMORIES: Dict[str, VoiceMemory] = {}

# Voice characteristics
VOICE_CHARACTERISTICS = {
    "alloy": {"pitch": 220.0, "timbre": "balanced", "description": "A balanced, natural voice with medium pitch"},
    "echo": {"pitch": 330.0, "timbre": "resonant", "description": "A resonant voice with a reverberant quality"},
    "fable": {"pitch": 523.0, "timbre": "bright", "description": "A bright, higher-pitched voice with clear articulation"},
    "onyx": {"pitch": 165.0, "timbre": "deep", "description": "A deep, authoritative voice with lower pitch"},
    "nova": {"pitch": 392.0, "timbre": "warm", "description": "A warm, smooth voice with pleasant midrange tone"},
    "shimmer": {"pitch": 587.0, "timbre": "light", "description": "A light, airy voice with higher frequencies"}
}

# Voice intro texts - carefully crafted to capture voice characteristics
VOICE_INTROS = {
    "alloy": [
        "Hello, I'm Alloy. My voice is designed to be clear and balanced.",
        "This is the Alloy voice. I aim to sound natural and easy to understand.",
        "Welcome, I'm the voice known as Alloy. I have a balanced, medium-range tone."
    ],
    "echo": [
        "Hello, I'm Echo. My voice has a rich, resonant quality.",
        "This is the Echo voice. Notice my distinctive resonance and depth.",
        "Welcome, I'm the voice known as Echo. My tone is designed to resonate clearly."
    ],
    "fable": [
        "Hello, I'm Fable. My voice is bright and articulate.",
        "This is the Fable voice. I have a higher pitch with clear pronunciation.",
        "Welcome, I'm the voice known as Fable. I speak with a bright, energetic tone."
    ],
    "onyx": [
        "Hello, I'm Onyx. My voice is deep and authoritative.",
        "This is the Onyx voice. I speak with a lower pitch and commanding presence.",
        "Welcome, I'm the voice known as Onyx. My tone is deep and resonant."
    ],
    "nova": [
        "Hello, I'm Nova. My voice is warm and harmonious.",
        "This is the Nova voice. I have a smooth, pleasant mid-range quality.",
        "Welcome, I'm the voice known as Nova. I speak with a warm, friendly tone."
    ],
    "shimmer": [
        "Hello, I'm Shimmer. My voice is light and expressive.",
        "This is the Shimmer voice. I have a higher-pitched, airy quality.",
        "Welcome, I'm the voice known as Shimmer. My tone is bright and crisp."
    ]
}

def initialize_voices(sample_rate: int = 24000):
    """Initialize voice memories with consistent base samples."""
    global VOICE_MEMORIES
    
    # Check if persistent directory exists, create if needed
    os.makedirs(VOICE_MEMORIES_DIR, exist_ok=True)
    logger.info(f"Using voice memories directory: {VOICE_MEMORIES_DIR}")
    
    # First try to load existing memories from persistent storage
    for voice_name in ["alloy", "echo", "fable", "onyx", "nova", "shimmer"]:
        memory = VoiceMemory.load(voice_name)
        if memory:
            VOICE_MEMORIES[voice_name] = memory
            logger.info(f"Loaded existing voice memory for {voice_name} with {len(memory.audio_segments)} segments")
            continue
            
        # If no memory exists, create a new one
        speaker_id = ["alloy", "echo", "fable", "onyx", "nova", "shimmer"].index(voice_name)
        characteristics = VOICE_CHARACTERISTICS[voice_name]
        
        # Create deterministic seed audio
        np.random.seed(speaker_id + 42)
        duration = 1.0  # seconds
        t = np.linspace(0, duration, int(sample_rate * duration), endpoint=False)
        
        # Create characteristic waveform
        pitch = characteristics["pitch"]
        if voice_name == "alloy":
            audio = 0.5 * np.sin(2 * np.pi * pitch * t) + 0.3 * np.sin(2 * np.pi * pitch * 2 * t)
        elif voice_name == "echo":
            audio = np.sin(2 * np.pi * pitch * t) * np.exp(-t * 3)
        elif voice_name == "fable":
            audio = 0.7 * np.sin(2 * np.pi * pitch * t)
        elif voice_name == "onyx":
            audio = 0.8 * np.sin(2 * np.pi * pitch * t) + 0.1 * np.sin(2 * np.pi * pitch * 0.5 * t)
        elif voice_name == "nova":
            audio = 0.4 * np.sin(2 * np.pi * pitch * t) + 0.4 * np.sin(2 * np.pi * pitch * 0.5 * t)
        else:  # shimmer
            audio = 0.3 * np.sin(2 * np.pi * pitch * t) + 0.2 * np.sin(2 * np.pi * pitch * 1.5 * t) + 0.1 * np.sin(2 * np.pi * pitch * 2 * t)
            
        # Normalize
        audio = audio / np.max(np.abs(audio))
        
        # Convert to tensor
        audio_tensor = torch.tensor(audio, dtype=torch.float32)
        
        # Create voice memory
        memory = VoiceMemory(
            name=voice_name,
            speaker_id=speaker_id,
            audio_segments=[audio_tensor],
            text_segments=[f"This is the voice of {voice_name}"],
            pitch_base=characteristics["pitch"],
            timbre=characteristics["timbre"]
        )
        
        # Save the voice memory to persistent storage
        memory.save()
        
        # Store in dictionary
        VOICE_MEMORIES[voice_name] = memory
        
        # Save as wav for reference
        save_path = os.path.join(VOICE_MEMORIES_DIR, f"{voice_name}_seed.wav")
        torchaudio.save(save_path, audio_tensor.unsqueeze(0), sample_rate)
        
        logger.info(f"Initialized new voice memory for {voice_name}")

def get_voice_context(voice_name: str, device: torch.device, max_segments: int = 2) -> List[Segment]:
    """Get context segments for a given voice."""
    if not VOICE_MEMORIES:
        initialize_voices()
        
    if voice_name in VOICE_MEMORIES:
        return VOICE_MEMORIES[voice_name].get_context_segments(device, max_segments=max_segments)
        
    # Default to alloy if voice not found
    logger.warning(f"Voice {voice_name} not found, defaulting to alloy")
    return VOICE_MEMORIES["alloy"].get_context_segments(device, max_segments=max_segments)

def update_voice_memory(voice_name: str, audio: torch.Tensor, text: str):
    """Update voice memory with newly generated audio and save to persistent storage."""
    if not VOICE_MEMORIES:
        initialize_voices()
        
    if voice_name in VOICE_MEMORIES:
        VOICE_MEMORIES[voice_name].update_with_new_audio(audio, text)
        VOICE_MEMORIES[voice_name].save()
        logger.info(f"Updated voice memory for {voice_name}, now has {len(VOICE_MEMORIES[voice_name].audio_segments)} segments")

def generate_voice_samples(app_state):
    """Generate high-quality voice samples for each voice.
    
    Args:
        app_state: The FastAPI app state containing the generator
    """
    generator = app_state.generator
    if not generator:
        logger.error("Cannot generate voice samples: generator not available")
        return
    
    logger.info("Beginning voice sample generation...")
    
    # Ensure persistent directory exists
    os.makedirs(VOICE_MEMORIES_DIR, exist_ok=True)
    
    for voice_name in ["alloy", "echo", "fable", "onyx", "nova", "shimmer"]:
        speaker_id = ["alloy", "echo", "fable", "onyx", "nova", "shimmer"].index(voice_name)
        
        # Get multiple sample texts for this voice
        sample_texts = VOICE_INTROS[voice_name]
        
        # Generate a collection of samples for this voice
        logger.info(f"Generating samples for voice: {voice_name}")
        audio_segments = []
        text_segments = []
        
        for i, sample_text in enumerate(sample_texts):
            try:
                # Check if we already have a sample
                sample_path = os.path.join(VOICE_MEMORIES_DIR, f"{voice_name}_sample_{i}.wav")
                if os.path.exists(sample_path):
                    logger.info(f"Found existing sample {i+1} for {voice_name}, loading from {sample_path}")
                    audio_tensor, sr = torchaudio.load(sample_path)
                    if sr != generator.sample_rate:
                        audio_tensor = torchaudio.functional.resample(
                            audio_tensor.squeeze(0), orig_freq=sr, new_freq=generator.sample_rate
                        )
                    else:
                        audio_tensor = audio_tensor.squeeze(0)
                    audio_segments.append(audio_tensor)
                    text_segments.append(sample_text)
                    continue
                    
                # Generate without context first for seed samples
                logger.info(f"Generating sample {i+1}/{len(sample_texts)} for {voice_name}: '{sample_text}'")
                
                # Use a lower temperature for more stable output
                audio = generator.generate(
                    text=sample_text,
                    speaker=speaker_id,
                    context=[],  # No context for initial samples
                    max_audio_length_ms=10000,
                    temperature=0.7,  # Lower temperature for more stable output
                    topk=30,
                )
                
                # Save this segment
                audio_segments.append(audio.detach().cpu())
                text_segments.append(sample_text)
                
                # Save as WAV for reference to persistent storage
                torchaudio.save(sample_path, audio.unsqueeze(0).cpu(), generator.sample_rate)
                
                logger.info(f"Generated sample {i+1} for {voice_name}, length: {audio.shape[0]/generator.sample_rate:.2f}s")
            
            except Exception as e:
                logger.error(f"Error generating sample {i+1} for {voice_name}: {e}")
        
        # Use the generated samples to update the voice memory
        if voice_name in VOICE_MEMORIES and audio_segments:
            # Replace existing samples with these high quality ones
            VOICE_MEMORIES[voice_name].audio_segments = audio_segments
            VOICE_MEMORIES[voice_name].text_segments = text_segments
            VOICE_MEMORIES[voice_name].save()
            
            logger.info(f"Updated voice memory for {voice_name} with {len(audio_segments)} high-quality samples")
        
        # Now generate a second pass with context from these samples
        if len(audio_segments) >= 2:
            try:
                # Check if we already have a character sample
                character_path = os.path.join(VOICE_MEMORIES_DIR, f"{voice_name}_character.wav")
                if os.path.exists(character_path):
                    logger.info(f"Found existing character sample for {voice_name}, loading from {character_path}")
                    audio_tensor, sr = torchaudio.load(character_path)
                    if sr != generator.sample_rate:
                        audio_tensor = torchaudio.functional.resample(
                            audio_tensor.squeeze(0), orig_freq=sr, new_freq=generator.sample_rate
                        )
                    else:
                        audio_tensor = audio_tensor.squeeze(0)
                
                    character_sample_text = f"I'm the voice assistant known as {voice_name}. I'm designed to have a distinctive voice that you can easily recognize."
                    VOICE_MEMORIES[voice_name].audio_segments.append(audio_tensor)
                    VOICE_MEMORIES[voice_name].text_segments.append(character_sample_text)
                    VOICE_MEMORIES[voice_name].save()
                    continue
                
                # Get intro and conclusion prompts that build voice consistency
                context = [
                    Segment(
                        speaker=speaker_id,
                        text=text_segments[0],
                        audio=audio_segments[0].to(generator.device)
                    )
                ]
                
                # Create a longer sample with the voice characteristics now established
                character_sample_text = f"I'm the voice assistant known as {voice_name}. I'm designed to have a distinctive voice that you can easily recognize. My speech patterns and tone should remain consistent throughout our conversation."
                
                logger.info(f"Generating character sample for {voice_name} with context")
                character_audio = generator.generate(
                    text=character_sample_text,
                    speaker=speaker_id,
                    context=context,
                    max_audio_length_ms=15000,
                    temperature=0.7, 
                    topk=30,
                )
                
                # Save this comprehensive character sample to persistent storage
                torchaudio.save(character_path, character_audio.unsqueeze(0).cpu(), generator.sample_rate)
                
                # Add this to the memory as well
                VOICE_MEMORIES[voice_name].audio_segments.append(character_audio.detach().cpu()) 
                VOICE_MEMORIES[voice_name].text_segments.append(character_sample_text)
                VOICE_MEMORIES[voice_name].save()
                
                logger.info(f"Generated character sample for {voice_name}, length: {character_audio.shape[0]/generator.sample_rate:.2f}s")
                
            except Exception as e:
                logger.error(f"Error generating character sample for {voice_name}: {e}")

def create_custom_voice(
    app_state,
    name: str, 
    initial_text: str, 
    speaker_id: int = 0,
    pitch: Optional[float] = None,
    timbre: str = "custom"
) -> Dict:
    """Create a new custom voice.
    
    Args:
        app_state: The FastAPI app state containing the generator
        name: Name for the new voice
        initial_text: Text for the initial voice sample
        speaker_id: Base speaker ID (0-5)
        pitch: Base pitch in Hz (optional)
        timbre: Voice quality descriptor
        
    Returns:
        Dict with creation status and voice info
    """
    generator = app_state.generator
    if not generator:
        return {"status": "error", "message": "Generator not available"}
    
    # Check if voice already exists
    if not VOICE_MEMORIES:
        initialize_voices()
        
    if name in VOICE_MEMORIES:
        return {"status": "error", "message": f"Voice '{name}' already exists"}
    
    # Generate a voice sample
    try:
        logger.info(f"Creating custom voice '{name}' with text: '{initial_text}'")
        
        audio = generator.generate(
            text=initial_text,
            speaker=speaker_id,
            context=[],
            max_audio_length_ms=10000,
            temperature=0.7,
        )
        
        # Determine base pitch if not provided
        if pitch is None:
            if speaker_id == 0:  # alloy
                pitch = 220.0
            elif speaker_id == 1:  # echo
                pitch = 330.0
            elif speaker_id == 2:  # fable
                pitch = 523.0
            elif speaker_id == 3:  # onyx
                pitch = 165.0
            elif speaker_id == 4:  # nova
                pitch = 392.0
            else:  # shimmer
                pitch = 587.0
        
        # Create a new voice memory
        memory = VoiceMemory(
            name=name,
            speaker_id=speaker_id,
            audio_segments=[audio.detach().cpu()],
            text_segments=[initial_text],
            pitch_base=pitch,
            timbre=timbre
        )
        
        # Save the voice memory to persistent storage
        memory.save()
        VOICE_MEMORIES[name] = memory
        
        # Save sample as WAV for reference to persistent storage
        sample_path = os.path.join(VOICE_MEMORIES_DIR, f"{name}_sample.wav")
        torchaudio.save(sample_path, audio.unsqueeze(0).cpu(), generator.sample_rate)
        
        logger.info(f"Created custom voice '{name}' successfully")
        
        return {
            "status": "success",
            "message": f"Voice '{name}' created successfully",
            "voice": {
                "name": name,
                "speaker_id": speaker_id,
                "pitch": pitch,
                "timbre": timbre,
                "sample_length_seconds": audio.shape[0] / generator.sample_rate
            }
        }
    
    except Exception as e:
        logger.error(f"Error creating custom voice '{name}': {e}")
        return {
            "status": "error",
            "message": f"Error creating voice: {str(e)}"
        }