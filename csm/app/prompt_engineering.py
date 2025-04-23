"""Prompt engineering for consistent voice generation."""
import re
import random
from typing import List, Dict, Optional
import logging

# Set up logging
logger = logging.getLogger(__name__)

# Voice style descriptors for consistent prompting
VOICE_STYLES = {
    "alloy": {
        "adjectives": ["balanced", "natural", "clear", "articulate", "neutral", "conversational"],
        "characteristics": ["medium pitch", "even pacing", "neutral tone", "balanced resonance"],
        "speaking_style": "conversational and balanced"
    },
    "echo": {
        "adjectives": ["resonant", "deep", "reverberant", "rich", "sonorous", "full"],
        "characteristics": ["lower pitch", "deliberate pacing", "resonant tone", "deeper timbre"],
        "speaking_style": "rich and resonant"
    },
    "fable": {
        "adjectives": ["bright", "light", "clear", "energetic", "articulate", "animated"],
        "characteristics": ["higher pitch", "lively pacing", "bright tone", "clear articulation"],
        "speaking_style": "bright and energetic"
    },
    "onyx": {
        "adjectives": ["deep", "authoritative", "powerful", "commanding", "strong", "resolute"],
        "characteristics": ["low pitch", "measured pacing", "authoritative tone", "strong projection"],
        "speaking_style": "deep and authoritative"
    },
    "nova": {
        "adjectives": ["warm", "pleasant", "smooth", "harmonious", "gentle", "comforting"],
        "characteristics": ["medium pitch", "smooth pacing", "warm tone", "pleasant timbre"],
        "speaking_style": "warm and smooth"
    },
    "shimmer": {
        "adjectives": ["light", "airy", "bright", "crystalline", "delicate", "expressive"],
        "characteristics": ["higher pitch", "quick pacing", "light tone", "bright timbre"],
        "speaking_style": "light and expressive"
    },
    "custom": {
        "adjectives": ["clear", "distinct", "authentic", "natural", "personalized", "unique"],
        "characteristics": ["natural rhythm", "authentic tone", "personal inflection", "distinctive sound"],
        "speaking_style": "authentic and natural"
    }
}

def initialize_templates():
    """Initialize prompt templates - placeholder for any future setup."""
    logger.info("Prompt templates initialized")
    return VOICE_STYLES

def split_into_segments(text: str, max_chars: int = 150) -> List[str]:
    """Split text into optimal segments for better generation.
    Args:
        text: Text to split
        max_chars: Maximum characters per segment
    Returns:
        List of text segments
    """
    # Handle empty or very short text
    if not text or len(text) <= max_chars:
        return [text]
    
    # Split by sentences first
    sentences = re.split(r'(?<=[.!?])\s+', text)
    
    # Initialize segments
    segments = []
    current_segment = ""
    
    for sentence in sentences:
        # If adding this sentence would exceed max_chars
        if len(current_segment) + len(sentence) > max_chars:
            # If current segment is not empty, add it to segments
            if current_segment:
                segments.append(current_segment.strip())
                current_segment = ""
                
            # If this sentence alone exceeds max_chars, split it by phrases
            if len(sentence) > max_chars:
                phrases = re.split(r'(?<=[,;:])\s+', sentence)
                for phrase in phrases:
                    if len(phrase) > max_chars:
                        # Split long phrases into chunks
                        words = phrase.split()
                        chunk = ""
                        for word in words:
                            if len(chunk) + len(word) + 1 <= max_chars:
                                chunk += " " + word if chunk else word
                            else:
                                segments.append(chunk.strip())
                                chunk = word
                        if chunk:
                            segments.append(chunk.strip())
                    else:
                        if len(current_segment) + len(phrase) <= max_chars:
                            current_segment += " " + phrase if current_segment else phrase
                        else:
                            segments.append(current_segment.strip())
                            current_segment = phrase
            else:
                current_segment = sentence
        else:
            current_segment += " " + sentence if current_segment else sentence
            
    # Add the last segment
    if current_segment:
        segments.append(current_segment.strip())
        
    logger.info(f"Split text into {len(segments)} segments")
    return segments

def format_text_for_voice(text: str, voice_name: str, segment_index: int = 0, total_segments: int = 1) -> str:
    """Format text with voice characteristics for more consistent generation.
    Args:
        text: Text to format
        voice_name: Name of the voice
        segment_index: Index of this segment (for multi-segment texts)
        total_segments: Total number of segments
    Returns:
        Formatted text optimized for consistent voice generation
    """
    # IMPORTANT: We no longer add voice instructions in brackets since CSM reads them aloud
    # Instead, we're using speaker IDs to control voice identity which is what the model expects
    
    # Just return the unmodified text - the Generator class will handle proper formatting
    return text