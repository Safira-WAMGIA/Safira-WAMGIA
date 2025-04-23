"""Scheduled tasks for the TTS API."""
import asyncio
import logging
import time
from datetime import datetime

logger = logging.getLogger(__name__)

async def periodic_voice_profile_backup(app_state, interval_hours=6):
    """
    Periodically save voice profiles to persistent storage.
    
    Args:
        app_state: The application state object
        interval_hours: Backup interval in hours
    """
    while True:
        try:
            # Wait for the specified interval
            await asyncio.sleep(interval_hours * 3600)
            
            # Log the backup
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            logger.info(f"Scheduled voice profile backup started at {timestamp}")
            
            # Save voice profiles
            if hasattr(app_state, "voice_enhancement_enabled") and app_state.voice_enhancement_enabled:
                from app.voice_enhancement import save_voice_profiles
                save_voice_profiles()
                logger.info("Voice profiles saved successfully")
                
            # Save voice memories
            if hasattr(app_state, "voice_memory_enabled") and app_state.voice_memory_enabled:
                for voice_name in app_state.voice_cache:
                    if voice_name in ["alloy", "echo", "fable", "onyx", "nova", "shimmer"]:
                        from app.voice_memory import VOICE_MEMORIES
                        if voice_name in VOICE_MEMORIES:
                            VOICE_MEMORIES[voice_name].save()
                logger.info("Voice memories saved successfully")
                
        except Exception as e:
            logger.error(f"Error in periodic voice profile backup: {e}")
