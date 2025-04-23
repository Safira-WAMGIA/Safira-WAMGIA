"""Utility functions for managing voice references and profiles."""
import os
import logging
import torch
import torchaudio
import shutil
from typing import Dict, List, Optional, Any

logger = logging.getLogger(__name__)

# Define persistent paths
VOICE_REFERENCES_DIR = "/app/voice_references"
VOICE_PROFILES_DIR = "/app/voice_profiles"
VOICE_MEMORIES_DIR = "/app/voice_memories"

# Ensure directories exist
os.makedirs(VOICE_REFERENCES_DIR, exist_ok=True)
os.makedirs(VOICE_PROFILES_DIR, exist_ok=True)
os.makedirs(VOICE_MEMORIES_DIR, exist_ok=True)

def backup_voice_data(backup_dir: str = "/app/voice_backups"):
    """Create a backup of all voice data."""
    os.makedirs(backup_dir, exist_ok=True)
    timestamp = torch.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = os.path.join(backup_dir, f"voice_backup_{timestamp}")
    os.makedirs(backup_path, exist_ok=True)
    
    # Backup voice references
    if os.path.exists(VOICE_REFERENCES_DIR):
        refs_backup = os.path.join(backup_path, "voice_references")
        shutil.copytree(VOICE_REFERENCES_DIR, refs_backup)
        
    # Backup voice profiles
    if os.path.exists(VOICE_PROFILES_DIR):
        profiles_backup = os.path.join(backup_path, "voice_profiles")
        shutil.copytree(VOICE_PROFILES_DIR, profiles_backup)
        
    # Backup voice memories
    if os.path.exists(VOICE_MEMORIES_DIR):
        memories_backup = os.path.join(backup_path, "voice_memories")
        shutil.copytree(VOICE_MEMORIES_DIR, memories_backup)
        
    logger.info(f"Voice data backed up to {backup_path}")
    return backup_path

def restore_default_voices():
    """Reset voices to their default state by removing existing voice data."""
    for voice_dir in [VOICE_REFERENCES_DIR, VOICE_PROFILES_DIR, VOICE_MEMORIES_DIR]:
        if os.path.exists(voice_dir):
            # Create a backup before deleting
            backup_path = backup_voice_data()
            
            # Remove existing data
            for item in os.listdir(voice_dir):
                item_path = os.path.join(voice_dir, item)
                if os.path.isdir(item_path):
                    shutil.rmtree(item_path)
                else:
                    os.remove(item_path)
                    
            logger.info(f"Removed existing voice data from {voice_dir}")
            
    logger.info(f"Voices reset to default state (backup created at {backup_path})")
    return backup_path

def verify_voice_references():
    """Check if voice references are complete and valid."""
    standard_voices = ["alloy", "echo", "fable", "onyx", "nova", "shimmer"]
    missing_voices = []
    
    for voice in standard_voices:
        voice_dir = os.path.join(VOICE_REFERENCES_DIR, voice)
        # Check if directory exists and contains reference files
        if not os.path.exists(voice_dir) or len(os.listdir(voice_dir)) == 0:
            missing_voices.append(voice)
            
    return {
        "complete": len(missing_voices) == 0,
        "missing_voices": missing_voices,
        "references_dir": VOICE_REFERENCES_DIR
    }

def get_voice_storage_info() -> Dict[str, Any]:
    """Get information about voice storage usage and status."""
    result = {
        "voice_references": {
            "path": VOICE_REFERENCES_DIR,
            "exists": os.path.exists(VOICE_REFERENCES_DIR),
            "voices": [],
            "total_size_mb": 0
        },
        "voice_profiles": {
            "path": VOICE_PROFILES_DIR,
            "exists": os.path.exists(VOICE_PROFILES_DIR),
            "file_count": 0,
            "total_size_mb": 0
        },
        "voice_memories": {
            "path": VOICE_MEMORIES_DIR,
            "exists": os.path.exists(VOICE_MEMORIES_DIR),
            "voices": [],
            "total_size_mb": 0
        }
    }
    
    # Get voice references info
    if result["voice_references"]["exists"]:
        for voice in os.listdir(VOICE_REFERENCES_DIR):
            voice_dir = os.path.join(VOICE_REFERENCES_DIR, voice)
            if os.path.isdir(voice_dir):
                file_count = len([f for f in os.listdir(voice_dir) if f.endswith('.wav')])
                dir_size = sum(os.path.getsize(os.path.join(voice_dir, f)) for f in os.listdir(voice_dir) if os.path.isfile(os.path.join(voice_dir, f)))
                result["voice_references"]["voices"].append({
                    "name": voice,
                    "file_count": file_count,
                    "size_mb": dir_size / (1024 * 1024)
                })
                result["voice_references"]["total_size_mb"] += dir_size / (1024 * 1024)
                
    # Get voice profiles info
    if result["voice_profiles"]["exists"]:
        files = [f for f in os.listdir(VOICE_PROFILES_DIR) if os.path.isfile(os.path.join(VOICE_PROFILES_DIR, f))]
        result["voice_profiles"]["file_count"] = len(files)
        result["voice_profiles"]["total_size_mb"] = sum(os.path.getsize(os.path.join(VOICE_PROFILES_DIR, f)) for f in files) / (1024 * 1024)
        
    # Get voice memories info
    if result["voice_memories"]["exists"]:
        files = [f for f in os.listdir(VOICE_MEMORIES_DIR) if os.path.isfile(os.path.join(VOICE_MEMORIES_DIR, f))]
        result["voice_memories"]["voices"] = [f.replace('.pt', '') for f in files if f.endswith('.pt')]
        result["voice_memories"]["total_size_mb"] = sum(os.path.getsize(os.path.join(VOICE_MEMORIES_DIR, f)) for f in files) / (1024 * 1024)
        
    return result
