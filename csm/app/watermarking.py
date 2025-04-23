"""Stub for watermarking module.

The original CSM code has a watermarking module that adds
an imperceptible watermark to generated audio.
"""

# Watermark key used by CSM
CSM_1B_GH_WATERMARK = "CSM1B@GitHub"

def load_watermarker(device="cpu"):
    """Stub for watermarker loading.
    
    In a real implementation, this would load the actual watermarker.
    """
    return None

def watermark(watermarker, audio, sample_rate, key):
    """Stub for watermarking function.
    
    In a real implementation, this would add the watermark.
    """
    return audio, sample_rate
