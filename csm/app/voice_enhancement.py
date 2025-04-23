"""Advanced voice enhancement and consistency system for CSM-1B."""
import os
import torch
import torchaudio
import numpy as np
import soundfile as sf
from typing import Dict, List, Optional, Tuple
import logging
from dataclasses import dataclass
from scipy import signal

# Setup logging
logger = logging.getLogger(__name__)

# Define persistent paths
VOICE_REFERENCES_DIR = "/app/voice_references"
VOICE_PROFILES_DIR = "/app/voice_profiles"

# Ensure directories exist
os.makedirs(VOICE_REFERENCES_DIR, exist_ok=True)
os.makedirs(VOICE_PROFILES_DIR, exist_ok=True)

@dataclass
class VoiceProfile:
    """Detailed voice profile with acoustic characteristics."""
    name: str
    speaker_id: int
    # Acoustic parameters
    pitch_range: Tuple[float, float]  # Min/max pitch in Hz
    intensity_range: Tuple[float, float]  # Min/max intensity (volume)
    spectral_tilt: float  # Brightness vs. darkness
    prosody_pattern: str  # Pattern of intonation and rhythm
    speech_rate: float  # Relative speech rate (1.0 = normal)
    formant_shift: float  # Formant frequency shift (1.0 = no shift)
    # Reference audio
    reference_segments: List[torch.Tensor]
    # Normalization parameters
    target_rms: float = 0.2
    target_peak: float = 0.95
    
    def get_enhancement_params(self) -> Dict:
        """Get parameters for enhancing generated audio."""
        return {
            "target_rms": self.target_rms,
            "target_peak": self.target_peak,
            "pitch_range": self.pitch_range,
            "formant_shift": self.formant_shift,
            "speech_rate": self.speech_rate,
            "spectral_tilt": self.spectral_tilt
        }

# Voice profiles with carefully tuned parameters
VOICE_PROFILES = {
    "alloy": VoiceProfile(
        name="alloy",
        speaker_id=0,
        pitch_range=(85, 180),  # Hz - balanced range
        intensity_range=(0.15, 0.3),  # moderate intensity
        spectral_tilt=0.0,  # neutral tilt
        prosody_pattern="balanced",
        speech_rate=1.0,  # normal rate
        formant_shift=1.0,  # no shift
        reference_segments=[],
        target_rms=0.2,
        target_peak=0.95
    ),
    "echo": VoiceProfile(
        name="echo",
        speaker_id=1,
        pitch_range=(75, 165),  # Hz - lower, resonant 
        intensity_range=(0.2, 0.35),  # slightly stronger
        spectral_tilt=-0.2,  # more low frequencies
        prosody_pattern="deliberate",
        speech_rate=0.95,  # slightly slower
        formant_shift=0.95,  # slightly lower formants
        reference_segments=[],
        target_rms=0.22,  # slightly louder
        target_peak=0.95
    ),
    "fable": VoiceProfile(
        name="fable",
        speaker_id=2,
        pitch_range=(120, 250),  # Hz - higher range
        intensity_range=(0.15, 0.28),  # moderate intensity
        spectral_tilt=0.2,  # more high frequencies
        prosody_pattern="animated",
        speech_rate=1.05,  # slightly faster
        formant_shift=1.05,  # slightly higher formants
        reference_segments=[],
        target_rms=0.19,
        target_peak=0.95
    ),
    "onyx": VoiceProfile(
        name="onyx",
        speaker_id=3,
        pitch_range=(65, 150),  # Hz - deeper range
        intensity_range=(0.18, 0.32),  # moderate-strong
        spectral_tilt=-0.3,  # more low frequencies
        prosody_pattern="authoritative",
        speech_rate=0.93,  # slightly slower
        formant_shift=0.9,  # lower formants
        reference_segments=[],
        target_rms=0.23,  # stronger
        target_peak=0.95
    ),
    "nova": VoiceProfile(
        name="nova",
        speaker_id=4,
        pitch_range=(90, 200),  # Hz - warm midrange
        intensity_range=(0.15, 0.27),  # moderate
        spectral_tilt=-0.1,  # slightly warm
        prosody_pattern="flowing",
        speech_rate=1.0,  # normal rate
        formant_shift=1.0,  # no shift
        reference_segments=[],
        target_rms=0.2,
        target_peak=0.95
    ),
    "shimmer": VoiceProfile(
        name="shimmer",
        speaker_id=5,
        pitch_range=(140, 280),  # Hz - brighter, higher
        intensity_range=(0.15, 0.25),  # moderate-light
        spectral_tilt=0.3,  # more high frequencies
        prosody_pattern="light",
        speech_rate=1.07,  # slightly faster
        formant_shift=1.1,  # higher formants
        reference_segments=[],
        target_rms=0.18,  # slightly softer
        target_peak=0.95
    )
}

# Voice-specific prompt templates - crafted to establish voice identity clearly
VOICE_PROMPTS = {
    "alloy": [
        "Hello, I'm Alloy. I speak with a balanced, natural tone that's easy to understand.",
        "This is Alloy speaking. My voice is designed to be clear and conversational.",
        "Alloy here - I have a neutral, friendly voice with balanced tone qualities."
    ],
    "echo": [
        "Hello, I'm Echo. I speak with a resonant, deeper voice that carries well.",
        "This is Echo speaking. My voice has a rich, resonant quality with depth.",
        "Echo here - My voice is characterized by its warm, resonant tones."
    ],
    "fable": [
        "Hello, I'm Fable. I speak with a bright, higher-pitched voice that's full of energy.",
        "This is Fable speaking. My voice is characterized by its clear, bright quality.",
        "Fable here - My voice is light, articulate, and slightly higher-pitched."
    ],
    "onyx": [
        "Hello, I'm Onyx. I speak with a deep, authoritative voice that commands attention.",
        "This is Onyx speaking. My voice has a powerful, deep quality with gravitas.",
        "Onyx here - My voice is characterized by its depth and commanding presence."
    ],
    "nova": [
        "Hello, I'm Nova. I speak with a warm, pleasant mid-range voice that's easy to listen to.",
        "This is Nova speaking. My voice has a smooth, harmonious quality.",
        "Nova here - My voice is characterized by its warm, friendly mid-tones."
    ],
    "shimmer": [
        "Hello, I'm Shimmer. I speak with a light, bright voice that's expressive and clear.",
        "This is Shimmer speaking. My voice has an airy, higher-pitched quality.",
        "Shimmer here - My voice is characterized by its bright, crystalline tones."
    ]
}

def initialize_voice_profiles():
    """Initialize voice profiles with default settings.
    
    This function loads existing voice profiles from disk if available,
    or initializes them with default settings.
    """
    global VOICE_PROFILES
    
    # Try to load existing profiles from persistent storage
    profile_path = os.path.join(VOICE_PROFILES_DIR, "voice_profiles.pt")
    
    if os.path.exists(profile_path):
        try:
            logger.info(f"Loading voice profiles from {profile_path}")
            saved_profiles = torch.load(profile_path)
            
            # Update existing profiles with saved data
            for name, data in saved_profiles.items():
                if name in VOICE_PROFILES:
                    VOICE_PROFILES[name].reference_segments = [
                        seg.to(torch.device("cpu")) for seg in data.get('reference_segments', [])
                    ]
            
            logger.info(f"Loaded voice profiles for {len(saved_profiles)} voices")
        except Exception as e:
            logger.error(f"Error loading voice profiles: {e}")
            logger.info("Using default voice profiles")
    else:
        logger.info("No saved voice profiles found, using defaults")
    
    # Ensure all voices have at least empty reference segments
    for name, profile in VOICE_PROFILES.items():
        if not hasattr(profile, 'reference_segments'):
            profile.reference_segments = []
    
    logger.info(f"Voice profiles initialized for {len(VOICE_PROFILES)} voices")
    return VOICE_PROFILES

def normalize_audio(audio: torch.Tensor, target_rms: float = 0.2, target_peak: float = 0.95) -> torch.Tensor:
    """Apply professional-grade normalization to audio.
    
    Args:
        audio: Audio tensor
        target_rms: Target RMS level for normalization
        target_peak: Target peak level for limiting
        
    Returns:
        Normalized audio tensor
    """
    # Ensure audio is on CPU for processing
    audio_cpu = audio.detach().cpu()
    
    # Handle silent audio
    if audio_cpu.abs().max() < 1e-6:
        logger.warning("Audio is nearly silent, returning original")
        return audio
    
    # Calculate current RMS
    current_rms = torch.sqrt(torch.mean(audio_cpu ** 2))
    
    # Apply RMS normalization
    if current_rms > 0:
        gain = target_rms / current_rms
        normalized = audio_cpu * gain
    else:
        normalized = audio_cpu
        
    # Apply peak limiting
    current_peak = normalized.abs().max()
    if current_peak > target_peak:
        normalized = normalized * (target_peak / current_peak)
    
    # Return to original device
    return normalized.to(audio.device)

def apply_anti_muffling(audio: torch.Tensor, sample_rate: int, clarity_boost: float = 1.2) -> torch.Tensor:
    """Apply anti-muffling to improve clarity.
    
    Args:
        audio: Audio tensor
        sample_rate: Audio sample rate
        clarity_boost: Amount of high frequency boost (1.0 = no boost)
        
    Returns:
        Processed audio tensor
    """
    # Convert to numpy for filtering
    audio_np = audio.detach().cpu().numpy()
    
    try:
        # Design a high shelf filter to boost high frequencies
        # Use a standard high-shelf filter that's supported by scipy.signal
        # We'll use a second-order Butterworth high-pass filter as an alternative
        cutoff = 2000  # Hz
        b, a = signal.butter(2, cutoff/(sample_rate/2), btype='high', analog=False)
        
        # Apply the filter with the clarity boost gain
        boosted = signal.filtfilt(b, a, audio_np, axis=0) * clarity_boost
        
        # Mix with original to maintain some warmth
        mix_ratio = 0.7  # 70% processed, 30% original
        processed = mix_ratio * boosted + (1-mix_ratio) * audio_np
        
    except Exception as e:
        logger.warning(f"Audio enhancement failed, using original: {e}")
        # Return original audio if enhancement fails
        return audio
    
    # Convert back to tensor on original device
    return torch.tensor(processed, dtype=audio.dtype, device=audio.device)

def enhance_audio(audio: torch.Tensor, sample_rate: int, voice_profile: VoiceProfile) -> torch.Tensor:
    """Apply comprehensive audio enhancement based on voice profile.
    
    Args:
        audio: Audio tensor
        sample_rate: Audio sample rate
        voice_profile: Voice profile containing enhancement parameters
        
    Returns:
        Enhanced audio tensor
    """
    if audio is None or audio.numel() == 0:
        logger.error("Cannot enhance empty audio")
        return audio
        
    try:
        # Step 1: Normalize audio levels
        params = voice_profile.get_enhancement_params()
        normalized = normalize_audio(
            audio, 
            target_rms=params["target_rms"],
            target_peak=params["target_peak"]
        )
        
        # Step 2: Apply anti-muffling based on spectral tilt
        # Positive tilt means brighter voice so less clarity boost needed
        clarity_boost = 1.0 + max(0, -params["spectral_tilt"]) * 0.5
        clarified = apply_anti_muffling(
            normalized,
            sample_rate,
            clarity_boost=clarity_boost
        )
        
        # Log the enhancement
        logger.debug(
            f"Enhanced audio for {voice_profile.name}: "
            f"RMS: {audio.pow(2).mean().sqrt().item():.3f}->{clarified.pow(2).mean().sqrt().item():.3f}, "
            f"Peak: {audio.abs().max().item():.3f}->{clarified.abs().max().item():.3f}"
        )
        
        return clarified
        
    except Exception as e:
        logger.error(f"Error in audio enhancement: {e}")
        return audio  # Return original audio if enhancement fails

def validate_generated_audio(
    audio: torch.Tensor, 
    voice_name: str, 
    sample_rate: int,
    min_expected_duration: float = 0.5
) -> Tuple[bool, torch.Tensor, str]:
    """Validate and fix generated audio.
    
    Args:
        audio: Audio tensor to validate
        voice_name: Name of the voice used
        sample_rate: Audio sample rate
        min_expected_duration: Minimum expected duration in seconds
        
    Returns:
        Tuple of (is_valid, fixed_audio, message)
    """
    if audio is None:
        return False, torch.zeros(1), "Audio is None"
    
    # Check for NaN values
    if torch.isnan(audio).any():
        logger.warning(f"Audio for {voice_name} contains NaN values, replacing with zeros")
        audio = torch.where(torch.isnan(audio), torch.zeros_like(audio), audio)
    
    # Check audio duration
    duration = audio.shape[0] / sample_rate
    if duration < min_expected_duration:
        logger.warning(f"Audio for {voice_name} is too short ({duration:.2f}s < {min_expected_duration}s)")
        return False, audio, f"Audio too short: {duration:.2f}s"
    
    # Check for silent sections - this can indicate generation problems
    rms = torch.sqrt(torch.mean(audio ** 2))
    if rms < 0.01:  # Very low RMS indicates near silence
        logger.warning(f"Audio for {voice_name} is nearly silent (RMS: {rms:.6f})")
        return False, audio, f"Audio nearly silent: RMS = {rms:.6f}"
    
    # Check if audio suddenly cuts off - this detects premature stopping
    # Calculate RMS in the last 100ms
    last_samples = int(0.1 * sample_rate)
    if audio.shape[0] > last_samples:
        end_rms = torch.sqrt(torch.mean(audio[-last_samples:] ** 2))
        if end_rms > 0.1:  # High RMS at the end suggests an abrupt cutoff
            logger.warning(f"Audio for {voice_name} may have cut off prematurely (end RMS: {end_rms:.3f})")
            return True, audio, "Audio may have cut off prematurely"
    
    return True, audio, "Audio validation passed"

def create_voice_segments(app_state, regenerate: bool = False):
    """Create high-quality voice reference segments.
    
    Args:
        app_state: Application state containing generator
        regenerate: Whether to regenerate existing references
    """
    generator = app_state.generator
    if not generator:
        logger.error("Cannot create voice segments: generator not available")
        return
    
    # Use persistent directory for voice reference segments
    os.makedirs(VOICE_REFERENCES_DIR, exist_ok=True)
    
    for voice_name, profile in VOICE_PROFILES.items():
        voice_dir = os.path.join(VOICE_REFERENCES_DIR, voice_name)
        os.makedirs(voice_dir, exist_ok=True)
        
        # Check if we already have references
        if not regenerate and profile.reference_segments:
            logger.info(f"Voice {voice_name} already has {len(profile.reference_segments)} reference segments")
            continue
        
        # Get prompts for this voice
        prompts = VOICE_PROMPTS[voice_name]
        
        # Generate reference segments
        logger.info(f"Generating reference segments for voice: {voice_name}")
        reference_segments = []
        
        for i, prompt in enumerate(prompts):
            ref_path = os.path.join(voice_dir, f"{voice_name}_ref_{i}.wav")
            
            # Skip if file exists and we're not regenerating
            if not regenerate and os.path.exists(ref_path):
                try:
                    # Load existing reference
                    audio_tensor, sr = torchaudio.load(ref_path)
                    if sr != generator.sample_rate:
                        audio_tensor = torchaudio.functional.resample(
                            audio_tensor.squeeze(0), orig_freq=sr, new_freq=generator.sample_rate
                        )
                    else:
                        audio_tensor = audio_tensor.squeeze(0)
                    reference_segments.append(audio_tensor.to(generator.device))
                    logger.info(f"Loaded existing reference {i+1}/{len(prompts)} for {voice_name}")
                    continue
                except Exception as e:
                    logger.warning(f"Failed to load existing reference {i+1} for {voice_name}: {e}")
            
            try:
                # Use a lower temperature for more stability in reference samples
                logger.info(f"Generating reference {i+1}/{len(prompts)} for {voice_name}: '{prompt}'")
                
                # We want references to be as clean as possible
                audio = generator.generate(
                    text=prompt,
                    speaker=profile.speaker_id,
                    context=[],  # No context for initial samples to prevent voice bleed
                    max_audio_length_ms=6000,  # Shorter for more control
                    temperature=0.7,  # Lower temperature for more stability
                    topk=30,  # More focused sampling
                )
                
                # Validate and enhance the audio
                is_valid, audio, message = validate_generated_audio(
                    audio, voice_name, generator.sample_rate
                )
                
                if is_valid:
                    # Enhance the audio
                    audio = enhance_audio(audio, generator.sample_rate, profile)
                    
                    # Save the reference to persistent storage
                    torchaudio.save(ref_path, audio.unsqueeze(0).cpu(), generator.sample_rate)
                    reference_segments.append(audio)
                    logger.info(f"Generated reference {i+1} for {voice_name}: {message}")
                else:
                    logger.warning(f"Invalid reference for {voice_name}: {message}")
                    # Try again with different settings if invalid
                    if i < len(prompts) - 1:
                        logger.info(f"Trying again with next prompt")
                        continue
            
            except Exception as e:
                logger.error(f"Error generating reference for {voice_name}: {e}")
        
        # Update the voice profile with references
        if reference_segments:
            VOICE_PROFILES[voice_name].reference_segments = reference_segments
            logger.info(f"Updated {voice_name} with {len(reference_segments)} reference segments")
    
    # Save the updated profiles to persistent storage
    save_voice_profiles()

def get_voice_segments(voice_name: str, device: torch.device) -> List:
    """Get context segments for a given voice.
    
    Args:
        voice_name: Name of the voice to use
        device: Device to place tensors on
        
    Returns:
        List of context segments
    """
    from app.models import Segment
    
    if voice_name not in VOICE_PROFILES:
        logger.warning(f"Voice {voice_name} not found, defaulting to alloy")
        voice_name = "alloy"
    
    profile = VOICE_PROFILES[voice_name]
    
    # If we don't have reference segments yet, create them
    if not profile.reference_segments:
        try:
            # Try to load from disk - use persistent storage
            voice_dir = os.path.join(VOICE_REFERENCES_DIR, voice_name)
            
            if os.path.exists(voice_dir):
                reference_segments = []
                prompts = VOICE_PROMPTS[voice_name]
                
                for i, prompt in enumerate(prompts):
                    ref_path = os.path.join(voice_dir, f"{voice_name}_ref_{i}.wav")
                    if os.path.exists(ref_path):
                        audio_tensor, sr = torchaudio.load(ref_path)
                        audio_tensor = audio_tensor.squeeze(0)
                        reference_segments.append(audio_tensor)
                
                if reference_segments:
                    profile.reference_segments = reference_segments
                    logger.info(f"Loaded {len(reference_segments)} reference segments for {voice_name}")
        except Exception as e:
            logger.error(f"Error loading reference segments for {voice_name}: {e}")
    
    # Create context segments from references
    context = []
    if profile.reference_segments:
        for i, ref_audio in enumerate(profile.reference_segments):
            # Use corresponding prompt if available, otherwise use a generic one
            text = VOICE_PROMPTS[voice_name][i] if i < len(VOICE_PROMPTS[voice_name]) else f"Voice reference for {voice_name}"
            
            context.append(
                Segment(
                    speaker=profile.speaker_id,
                    text=text,
                    audio=ref_audio.to(device)
                )
            )
    
    logger.info(f"Returning {len(context)} context segments for {voice_name}")
    return context

def save_voice_profiles():
    """Save voice profiles to persistent storage."""
    os.makedirs(VOICE_PROFILES_DIR, exist_ok=True)
    profile_path = os.path.join(VOICE_PROFILES_DIR, "voice_profiles.pt")
    
    # Create a serializable version of the profiles
    serializable_profiles = {}
    for name, profile in VOICE_PROFILES.items():
        serializable_profiles[name] = {
            'reference_segments': [seg.cpu() for seg in profile.reference_segments]
        }
    
    # Save to persistent storage
    torch.save(serializable_profiles, profile_path)
    logger.info(f"Saved voice profiles to {profile_path}")
    
def process_generated_audio(
    audio: torch.Tensor, 
    voice_name: str, 
    sample_rate: int,
    text: str
) -> torch.Tensor:
    """Process generated audio for consistency and quality.
    
    Args:
        audio: Audio tensor
        voice_name: Name of voice used
        sample_rate: Audio sample rate  
        text: Text that was spoken
        
    Returns:
        Processed audio tensor
    """
    # Validate the audio
    is_valid, audio, message = validate_generated_audio(audio, voice_name, sample_rate)
    if not is_valid:
        logger.warning(f"Generated audio validation issue: {message}")
    
    # Get voice profile for enhancement
    profile = VOICE_PROFILES.get(voice_name, VOICE_PROFILES["alloy"])
    
    # Enhance the audio based on voice profile
    enhanced = enhance_audio(audio, sample_rate, profile)
    
    # Log the enhancement
    original_duration = audio.shape[0] / sample_rate
    enhanced_duration = enhanced.shape[0] / sample_rate
    logger.info(
        f"Processed audio for '{voice_name}': "
        f"Duration: {original_duration:.2f}s->{enhanced_duration:.2f}s, "
        f"RMS: {audio.pow(2).mean().sqrt().item():.3f}->{enhanced.pow(2).mean().sqrt().item():.3f}"
    )
    
    return enhanced