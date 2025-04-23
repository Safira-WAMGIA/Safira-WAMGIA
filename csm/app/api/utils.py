def get_all_voices(app_state):
    """
    Get all available voices including standard and cloned voices.
    Returns them in a format compatible with OpenAI's API.
    """
    # Standard voices
    voices = [
        {"voice_id": "alloy", "name": "Alloy"},
        {"voice_id": "echo", "name": "Echo"},
        {"voice_id": "fable", "name": "Fable"},
        {"voice_id": "onyx", "name": "Onyx"},
        {"voice_id": "nova", "name": "Nova"},
        {"voice_id": "shimmer", "name": "Shimmer"}
    ]
    
    # Add cloned voices if available
    if hasattr(app_state, "voice_cloner") and app_state.voice_cloner is not None:
        cloned_voices = app_state.voice_cloner.list_voices()
        for voice in cloned_voices:
            voices.append({
                "voice_id": voice.id,
                "name": voice.name
            })
    
    return voices
