from dataclasses import dataclass
from typing import List, Tuple

import torch


@dataclass
class Segment:
    """A segment of speech with text, speaker, and audio."""
    speaker: int
    text: str
    # (num_samples,), sample_rate = 24_000
    audio: torch.Tensor
