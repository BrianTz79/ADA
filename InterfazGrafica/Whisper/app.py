from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from faster_whisper import WhisperModel
import shutil
import os
import time

app = FastAPI()

# Enable CORS for Flutter Web access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# /// Módulo diseñado para correr localmente en el nodo Edge (Raspberry Pi).
model_size = "base"
# Load the model directly into CPU and apply INT8 precision for optimal performance
model = WhisperModel(model_size, device="cpu", compute_type="int8")

@app.post("/transcribe")
async def transcribe_audio(audio: UploadFile = File(...)):
    print("\n[🎙️ WHISPER] Recibiendo audio...")
    start_time = time.time()
    
    # /// Endpoint para recibir el audio de Flutter, guardarlo y transcribirlo localmente.
    temp_file = f"temp_{audio.filename}"
    
    with open(temp_file, "wb") as buffer:
        shutil.copyfileobj(audio.file, buffer)
    
    try:
        segments, info = model.transcribe(
            temp_file, 
            beam_size=5,
            language="es",
            vad_filter=True,
            vad_parameters=dict(min_silence_duration_ms=1000, speech_pad_ms=400),
            initial_prompt="Instituto Tecnológico de Tijuana, ITT, constancia de estudios, servicio social, semestre, kárdex, retícula, galgos, ADA."
        )
        
        transcription = ""
        for segment in segments:
            transcription += segment.text + " "
            
        transcription = transcription.strip()
        
        print(f"[✅ WHISPER TRANSCRIPCIÓN]: \"{transcription}\"")
        elapsed_time = time.time() - start_time
        print(f"[⏱️ Tiempo de proceso: {elapsed_time:.2f} segundos]\n")
        
    finally:
        # Limpieza del archivo
        if os.path.exists(temp_file):
            os.remove(temp_file)
            
    return {"text": transcription}

if __name__ == "__main__":
    import uvicorn
    # /// Corriendo el microservicio en el puerto 5000 para separar tráfico backend
    uvicorn.run(app, host="0.0.0.0", port=5000)
