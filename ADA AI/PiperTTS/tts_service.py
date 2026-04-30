import io
import wave
import base64
import time
import os
import tempfile
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from piper.voice import PiperVoice

app = FastAPI()

# Configuramos cabeceras CORS para acceso irrestricto desde Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# /// Target del Modelo Acústico Femenino# --- MODEL CONFIGURATION ---
MODEL_PATH = "es_MX-cortana-19669-epoch-high.onnx"
CONFIG_PATH = "es_MX-cortana-19669-epoch-high.onnx.json"

try:
    print("[ADA🎙️] Inicializando Red Neuronal de Síntesis en Memoria...")
    voice = PiperVoice.load(MODEL_PATH, config_path=CONFIG_PATH)
    print("[ADA✅] Piper TTS montado localmente con éxito.")
except Exception as e:
    print(f"[ALERTA] Infracción al cargar el modelo Piper. ¿Descargaste el ONNX? Detalles: {e}")
    voice = None

class SynthesisRequest(BaseModel):
    text: str

def get_word_timestamps(text: str, total_duration: float) -> list:
    """
    Divide y proporciona sincronización espacial (timestamps) de las palabras para el UI.
    Como los bindings nativos de Piper Python simplifican la extracción aislando los 
    fonemas crudos, empleamos una aproximación matemática confiable basada en caracteres
    y cadencia para emular la silabicación, garantizando un Karaoke fluido y sin costuras.
    """
    words = text.split()
    timestamps = []
    
    if not words:
        return timestamps
        
    total_chars = sum(len(w) for w in words)
    current_time = 0.0
    
    for word in words:
        # Lógica heurística: Mayor número de letras = mayor duración consumiendo buffer
        word_duration = (len(word) / total_chars) * total_duration
        timestamps.append({
            "word": word,
            "start": round(current_time, 2),
            "end": round(current_time + word_duration, 2)
        })
        current_time += word_duration
        
    return timestamps

@app.post("/synthesize")
async def synthesize_text(request: SynthesisRequest):
    if not voice:
        # /// [MANUAL_ERROR: ERR_TTS_01]
        # /// Descripción: Falla en la carga estructural del motor remoto TTS o modelo inalcanzable.
        # /// Causa: El archivo binario `.onnx` o el descriptor `.json` no existen en la ruta o deniegan acceso a Python.
        # /// Solución: Ejecutar con éxito el script `download_model.py` o verificar permisos `chmod`.
        raise HTTPException(status_code=500, detail="ERR_TTS_01|Model not loaded")
        
    texto_a_hablar = request.text.strip()
    if not texto_a_hablar:
        raise HTTPException(status_code=400, detail="Text cannot be empty")
        
    try:
        start_process = time.time()
        print(f"\n[ADA TTS] Sintetizando: '{texto_a_hablar[:50]}...'")
        
        # 1. Crear un archivo temporal físico seguro
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_audio:
            temp_path = temp_audio.name

        try:
            # 2. Síntesis en disco duro (File Descriptor real para el motor C++)
            with wave.open(temp_path, "wb") as wav_file:
                wav_file.setnchannels(1)
                wav_file.setsampwidth(2)
                wav_file.setframerate(voice.config.sample_rate)
                voice.synthesize_wav(texto_a_hablar, wav_file)

            # 3. Leer el archivo ya cerrado y procesado
            with open(temp_path, "rb") as f:
                audio_bytes = f.read()

            # 4. Cálculo matemático
            nframes = (len(audio_bytes) - 44) // 2
            duration = nframes / voice.config.sample_rate

            if duration <= 0:
                raise Exception(f"Duration 0. Bytes: {len(audio_bytes)}. (Posible fallo de espeak-ng)")

            # 5. Timestamps y Base64
            timestamps = get_word_timestamps(texto_a_hablar, duration)
            audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
            
        finally:
            # 6. Limpieza garantizada del disco
            if os.path.exists(temp_path):
                os.remove(temp_path)
        
        print(f"[ADA TTS] Síntesis renderizada OK. Toma: {time.time() - start_process:.2f}s")
        
        return {
            "original_text": texto_a_hablar,
            "timestamps": timestamps,
            "audio_base64": audio_base64
        }
        
    except Exception as e:
        # /// [MANUAL_ERROR: ERR_TTS_02]
        # /// Descripción: Falla interna por consumo o colapso al trazar audios (Inferencia Rota).
        # /// Causa: Al modelo se le inyectaron caracteres desconocidos UTF-8 crudos, Emoji, o hubo escasez de RAM.
        # /// Solución: Implementar librerías de limpieza Regex previo al TTS o verificar desborde Linux SWAP.
        raise HTTPException(status_code=500, detail=f"ERR_TTS_02|{str(e)}")

if __name__ == "__main__":
    import uvicorn
    # Levantamos en el puerto designado para el motor vocal
    uvicorn.run(app, host="0.0.0.0", port=5001)
