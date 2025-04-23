# app/api/schemas.py
from enum import Enum
from typing import Optional, List, Dict, Any, Union
from pydantic import BaseModel, Field

# Voice options as a non-restrictive string
class Voice(str):
    """Voice options for CSM model - allowing any string value"""
    pass

class ResponseFormat(str, Enum):
    mp3 = "mp3"
    opus = "opus"
    aac = "aac"
    flac = "flac"
    wav = "wav"

# Create SpeechRequest for compatibility with our new code
class SpeechRequest(BaseModel):
    model: Optional[str] = Field("csm-1b", description="The TTS model to use")
    input: str = Field(..., description="The text to generate audio for")
    voice: Optional[str] = Field("alloy", description="The voice to use for generation")
    response_format: Optional[ResponseFormat] = Field(ResponseFormat.mp3, description="The format of the audio response")
    speed: Optional[float] = Field(1.0, description="The speed of the audio", ge=0.25, le=4.0)
    # CSM-specific parameters
    max_audio_length_ms: Optional[float] = Field(90000, description="Maximum audio length in milliseconds")
    temperature: Optional[float] = Field(0.9, description="Sampling temperature", ge=0.0, le=2.0)
    topk: Optional[int] = Field(50, description="Top-k for sampling", ge=1, le=100)
    
    class Config:
        populate_by_name = True
        extra = "ignore"  # Allow extra fields without error

# Maintain TTSRequest for backward compatibility
class TTSRequest(SpeechRequest):
    """Legacy alias for SpeechRequest for backward compatibility"""
    pass

class TTSResponse(BaseModel):
    """Only used for API documentation"""
    pass