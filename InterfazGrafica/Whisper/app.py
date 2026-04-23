from fastapi import FastAPI, UploadFile, File, HTTPException
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
    
    try:
        with open(temp_file, "wb") as buffer:
            shutil.copyfileobj(audio.file, buffer)
        if os.path.getsize(temp_file) < 100:
            raise ValueError("File too small")
    except Exception as e:
        """
        /// [MANUAL_ERROR: ERR_WHP_FILE]
        /// Descripción: El archivo de audio recibido está corrupto, es inválido o no es un audio.
        /// Causa: El cliente subió una trama truncada o el sistema de archivos falló al escribir.
        /// Solución: Revisar el espacio en disco de la Raspberry, y validar los permisos de lectura/escritura.
        """
        raise HTTPException(status_code=500, detail="ERR_WHP_FILE")
    
    try:
        try:
            segments, info = model.transcribe(
                temp_file, 
                beam_size=5,
                language="es",
                vad_filter=True,
                vad_parameters=dict(min_silence_duration_ms=1000, speech_pad_ms=400),
                initial_prompt="Instituto Tecnológico de Tijuana, ITT, constancia de estudios, servicio social, semestre, kárdex, retícula, galgos, ADA."
            )
        except Exception as e:
            """
            /// [MANUAL_ERROR: ERR_WHP_MODEL]
            /// Descripción: Falla interna por falta de memoria (crashing) en el Motor Whisper.
            /// Causa: Faster-whisper se quedó sin RAM suficiente o el VAD falló al filtrar canales.
            /// Solución: Reducir el model_size a "tiny" o revisar la sobrecarga general de la CPU en la Pi.
            """
            raise HTTPException(status_code=500, detail="ERR_WHP_MODEL")
        
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
