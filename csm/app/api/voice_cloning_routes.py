"""Voice cloning API routes for CSM-1B TTS API."""
import os
import io
import time
import tempfile
from typing import Dict, List, Optional, Any
import torch
import torchaudio
from fastapi import APIRouter, Request, Response, HTTPException, UploadFile, File, Form, Body
from fastapi.responses import StreamingResponse, JSONResponse
from app.voice_cloning import ClonedVoice

# Create router
router = APIRouter(prefix="/voice-cloning", tags=["Voice Cloning"])

@router.post("/clone", summary="Clone a new voice")
async def clone_voice(
    request: Request,
    audio_file: UploadFile = File(...),
    name: str = Form(...),
    transcript: Optional[str] = Form(None),
    description: Optional[str] = Form(None)
):
    """
    Clone a new voice from an audio file.
    
    - **audio_file**: Audio file with the voice to clone (MP3, WAV, etc.)
    - **name**: Name for the cloned voice
    - **transcript**: Optional transcript of the audio
    - **description**: Optional description of the voice
    """
    if not hasattr(request.app.state, "voice_cloner"):
        raise HTTPException(status_code=503, detail="Voice cloning service not available")
    
    voice_cloner = request.app.state.voice_cloner
    
    try:
        voice = await voice_cloner.clone_voice(
            audio_file=audio_file,
            voice_name=name,
            transcript=transcript,
            description=description
        )
        
        return {
            "status": "success",
            "message": "Voice cloned successfully",
            "voice": voice
        }
    except Exception as e:
        import traceback
        error_trace = traceback.format_exc()
        request.app.state.logger.error(f"Voice cloning failed: {e}\n{error_trace}")
        raise HTTPException(status_code=500, detail=f"Voice cloning failed: {str(e)}")

@router.get("/voices", summary="List cloned voices")
async def list_voices(request: Request):
    """List all cloned voices available in the system."""
    if not hasattr(request.app.state, "voice_cloner"):
        raise HTTPException(status_code=503, detail="Voice cloning service not available")
    
    voice_cloner = request.app.state.voice_cloner
    voices = voice_cloner.list_voices()
    
    return {
        "voices": voices
    }

@router.delete("/voices/{voice_id}", summary="Delete a cloned voice")
async def delete_voice(request: Request, voice_id: str):
    """Delete a cloned voice by ID."""
    if not hasattr(request.app.state, "voice_cloner"):
        raise HTTPException(status_code=503, detail="Voice cloning service not available")
    
    voice_cloner = request.app.state.voice_cloner
    success = voice_cloner.delete_voice(voice_id)
    
    if not success:
        raise HTTPException(status_code=404, detail=f"Voice with ID {voice_id} not found")
    
    return {
        "status": "success",
        "message": f"Voice {voice_id} deleted successfully"
    }

@router.post("/clone-from-youtube", summary="Clone a voice from YouTube")
async def clone_voice_from_youtube(
    request: Request,
    data: dict = Body(...)  # Use a single body parameter to avoid conflicts
):
    """
    Clone a voice from a YouTube video.
    
    - **youtube_url**: URL of the YouTube video
    - **voice_name**: Name for the cloned voice
    - **start_time**: Start time in seconds (default: 0)
    - **duration**: Duration to extract in seconds (default: 180)
    - **description**: Optional description of the voice
    """
    if not hasattr(request.app.state, "voice_cloner"):
        raise HTTPException(status_code=503, detail="Voice cloning service not available")
    
    voice_cloner = request.app.state.voice_cloner
    
    # Extract parameters from the request body
    youtube_url = data.get("youtube_url")
    voice_name = data.get("voice_name")
    start_time = data.get("start_time", 0)
    duration = data.get("duration", 180)
    description = data.get("description")
    
    # Validate required parameters
    if not youtube_url or not voice_name:
        raise HTTPException(status_code=400, detail="Missing required parameters: youtube_url and voice_name")
    
    try:
        voice = await voice_cloner.clone_voice_from_youtube(
            youtube_url=youtube_url,
            voice_name=voice_name,
            start_time=start_time,
            duration=duration,
            description=description
        )
        
        return {
            "status": "success",
            "message": "Voice cloned successfully from YouTube",
            "voice": voice
        }
    except Exception as e:
        import traceback
        error_trace = traceback.format_exc()
        request.app.state.logger.error(f"YouTube voice cloning failed: {e}\n{error_trace}")
        raise HTTPException(status_code=500, detail=f"YouTube voice cloning failed: {str(e)}")
    
@router.post("/generate", summary="Generate speech with cloned voice")
async def generate_speech(
    request: Request,
    voice_id: str = Body(..., embed=True),
    text: str = Body(..., embed=True),
    temperature: float = Body(0.65, embed=True),
    response_format: str = Body("mp3", embed=True)
):
    """
    Generate speech using a cloned voice.
    
    - **voice_id**: ID of the cloned voice to use
    - **text**: Text to synthesize
    - **temperature**: Sampling temperature (lower = more stable, higher = more varied)
    - **response_format**: Audio format (mp3, wav, etc.)
    """
    if not hasattr(request.app.state, "voice_cloner"):
        raise HTTPException(status_code=503, detail="Voice cloning service not available")
    
    voice_cloner = request.app.state.voice_cloner
    
    # Validate voice ID
    if voice_id not in voice_cloner.cloned_voices:
        raise HTTPException(status_code=404, detail=f"Voice with ID {voice_id} not found")
    
    # MIME type mapping
    mime_types = {
        "mp3": "audio/mpeg",
        "wav": "audio/wav",
        "ogg": "audio/ogg",
        "flac": "audio/flac",
        "m4a": "audio/mp4",
    }
    
    # Set default if format not specified
    if response_format not in mime_types:
        response_format = "mp3"
    
    try:
        # Generate speech with the cloned voice - IMPORTANT: This is a synchronous operation
        # Remove the await keyword here
        audio = voice_cloner.generate_speech(
            text=text,
            voice_id=voice_id,
            temperature=temperature
        )
        
        # Create temporary file for audio conversion
        with tempfile.NamedTemporaryFile(suffix=f".{response_format}", delete=False) as temp_file:
            temp_path = temp_file.name
            
        # Save to WAV first (direct format for torchaudio)
        wav_path = f"{temp_path}.wav"
        torchaudio.save(wav_path, audio.unsqueeze(0).cpu(), voice_cloner.sample_rate)
        
        # Convert to requested format
        import ffmpeg
        
        if response_format == "mp3":
            (
                ffmpeg.input(wav_path)
                .output(temp_path, format='mp3', audio_bitrate='128k')
                .run(quiet=True, overwrite_output=True)
            )
        elif response_format == "ogg":
            (
                ffmpeg.input(wav_path)
                .output(temp_path, format='ogg')
                .run(quiet=True, overwrite_output=True)
            )
        elif response_format == "flac":
            (
                ffmpeg.input(wav_path)
                .output(temp_path, format='flac')
                .run(quiet=True, overwrite_output=True)
            )
        elif response_format == "m4a":
            (
                ffmpeg.input(wav_path)
                .output(temp_path, format='mp4')
                .run(quiet=True, overwrite_output=True)
            )
        else:  # wav
            temp_path = wav_path
        
        # Clean up the temporary WAV file if we created a different format
        if temp_path != wav_path and os.path.exists(wav_path):
            os.unlink(wav_path)
        
        # Return audio file as response
        def iterfile():
            with open(temp_path, 'rb') as f:
                yield from f
            # Clean up temp file after streaming
            if os.path.exists(temp_path):
                os.unlink(temp_path)
        
        return StreamingResponse(
            iterfile(),
            media_type=mime_types.get(response_format, "application/octet-stream"),
            headers={'Content-Disposition': f'attachment; filename="speech.{response_format}"'}
        )
    
    except Exception as e:
        import traceback
        error_trace = traceback.format_exc()
        request.app.state.logger.error(f"Speech generation failed: {e}\n{error_trace}")
        raise HTTPException(status_code=500, detail=f"Speech generation failed: {str(e)}")

@router.post("/voices/{voice_id}/preview", summary="Generate a preview of a cloned voice")
async def generate_preview(
    request: Request,
    voice_id: str,
    text: Optional[str] = Body("This is a preview of my cloned voice.", embed=True),
    response_format: str = Body("mp3", embed=True)
):
    """
    Generate a preview of a cloned voice with a standard text.
    
    - **voice_id**: ID of the cloned voice to use
    - **text**: Optional custom text for the preview
    - **response_format**: Audio format (mp3, wav, etc.)
    """
    # Use the generate_speech endpoint with a standard text
    return await generate_speech(
        request=request,
        voice_id=voice_id,
        text=text,
        temperature=0.7,
        response_format=response_format
    )

@router.get("/openai-compatible-voices", summary="List cloned voices in OpenAI format")
async def list_voices_openai_format(request: Request):
    """List all cloned voices in OpenAI-compatible format."""
    if not hasattr(request.app.state, "voice_cloner"):
        raise HTTPException(status_code=503, detail="Voice cloning service not available")
    
    voice_cloner = request.app.state.voice_cloner
    voices = voice_cloner.list_voices()
    
    # Format voices in OpenAI-compatible format
    openai_voices = []
    for voice in voices:
        openai_voices.append({
            "voice_id": voice.id,
            "name": voice.name,
            "preview_url": f"/v1/voice-cloning/voices/{voice.id}/preview",
            "description": voice.description or f"Cloned voice: {voice.name}",
            "languages": [{"language_code": "en", "name": "English"}],
            "cloned": True
        })
    
    return {"voices": openai_voices}