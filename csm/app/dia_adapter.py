"""Adapter for Dia TTS model to work with CSM API."""
import logging
import torch
import numpy as np
import tempfile
import os
import torchaudio
from typing import List, Optional
from app.models import Segment

logger = logging.getLogger(__name__)

class DiaAdapter:
    """Adapter for Dia TTS model to make it compatible with the CSM API."""
    
    def __init__(self, dia_model):
        self.dia_model = dia_model
        self.sample_rate = 44100  # Dia uses 44.1kHz
        self.device = next(dia_model.model.parameters()).device
    
    def generate(
        self,
        text: str,
        speaker: int,
        context: List[Segment] = None,
        max_audio_length_ms: float = 90_000,  
        temperature: float = 0.7,
        topk: int = 50,
    ) -> torch.Tensor:
        """Generate audio from text using Dia's interface."""
        logger.info(f"Generating audio with Dia: {len(text)} chars, speaker={speaker}")
        
        # Ensure text has speaker tags - Dia requires speaker tags
        if "[S1]" not in text and "[S2]" not in text:
            speaker_tag = f"[S{(speaker % 2) + 1}]"
            text = f"{speaker_tag} {text.strip()}"
            logger.info(f"Added speaker tag to text: {text}")
        
        # Prepare audio prompt if context is provided (for voice cloning)
        audio_prompt_path = None
        created_temp_file = False
        
        try:
            # Check if we have context for voice cloning
            if context and len(context) > 0:
                # Create a temporary file for the audio prompt
                temp_file = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
                audio_prompt_path = temp_file.name
                temp_file.close()
                created_temp_file = True
                
                # Process the audio from context
                audio_prompt = context[0].audio
                
                # Save to the temporary file
                torchaudio.save(
                    audio_prompt_path,
                    audio_prompt.unsqueeze(0).cpu(),
                    self.sample_rate
                )
                
                logger.info(f"Created audio prompt at {audio_prompt_path}")
            
            # Reset any state/cache before generation
            if hasattr(self.dia_model.model, 'reset_caches'):
                self.dia_model.model.reset_caches()
            
            # Generate the audio
            if audio_prompt_path:
                # Use the audio prompt for voice cloning
                logger.info(f"Generating with audio prompt from context")
                audio = self.dia_model.generate(
                    text=text,
                    audio_prompt_path=audio_prompt_path
                )
            else:
                # Standard generation without voice cloning
                logger.info(f"Generating without audio prompt")
                audio = self.dia_model.generate(text)
            
            logger.info(f"Generation complete, got {len(audio) if audio is not None else 0} samples")
            
            # Convert to tensor if successful
            if audio is not None and len(audio) > 0:
                audio_tensor = torch.tensor(audio, device=self.device, dtype=torch.float32)
                return audio_tensor
            else:
                logger.warning("No audio generated")
                return torch.zeros(self.sample_rate, device=self.device)
                
        except Exception as e:
            logger.error(f"Error generating audio: {e}", exc_info=True)
            return torch.zeros(self.sample_rate, device=self.device)
            
        finally:
            # Clean up the temporary file
            if created_temp_file and audio_prompt_path and os.path.exists(audio_prompt_path):
                try:
                    os.unlink(audio_prompt_path)
                except Exception as e:
                    logger.warning(f"Failed to delete temporary file: {e}")