import io
import re
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

_MD_STRIP = re.compile(
    r'```.*?```'           # bloques de código cercados
    r'|`[^`]*`'            # código inline
    r'|#{1,6}\s*'          # encabezados
    r'|\*{1,3}([^*]*)\*{1,3}'  # negrita/cursiva → captura el contenido
    r'|_{1,3}([^_]*)_{1,3}'    # negrita/cursiva con _
    r'|^\s*[-*+]\s+'       # viñetas de lista
    r'|^\s*\d+\.\s+'       # listas numeradas
    r'|^\s*>\s*'           # blockquotes
    r'|\[([^\]]*)\]\([^)]*\)'  # enlaces → captura el texto del enlace
    r'|~~[^~]*~~'          # tachado
    r'|\|',                # separadores de tabla
    re.MULTILINE | re.DOTALL,
)

def _strip_markdown(text: str) -> str:
    """Elimina símbolos de formato Markdown conservando el contenido legible.
    Solo se aplica al texto enviado a PiperTTS; el Markdown original se preserva
    en la respuesta del backend para que el frontend lo renderice correctamente."""
    def _replace(m: re.Match) -> str:
        # Devuelve el primer grupo capturado que tenga contenido (texto del enlace,
        # interior de negrita/cursiva, etc.), o cadena vacía para los marcadores puros.
        for g in m.groups():
            if g is not None:
                return g
        return ''
    cleaned = _MD_STRIP.sub(_replace, text)
    # Colapsar múltiples espacios/líneas en blanco que puedan quedar
    cleaned = re.sub(r'\n{2,}', ' ', cleaned)
    cleaned = re.sub(r'[ \t]{2,}', ' ', cleaned)
    return cleaned.strip()

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

def _synthesize_to_bytes(texto: str) -> tuple[bytes, float]:
    """Sintetiza texto a bytes WAV y retorna (audio_bytes, duration_seconds)."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_audio:
        temp_path = temp_audio.name
    try:
        with wave.open(temp_path, "wb") as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(voice.config.sample_rate)
            voice.synthesize_wav(texto, wav_file)
        with open(temp_path, "rb") as f:
            audio_bytes = f.read()
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

    nframes = (len(audio_bytes) - 44) // 2
    duration = nframes / voice.config.sample_rate
    if duration <= 0:
        raise Exception(f"Duration 0. Bytes: {len(audio_bytes)}. (Posible fallo de espeak-ng)")
    return audio_bytes, duration


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
        texto_voz = _strip_markdown(texto_a_hablar)
        if not texto_voz:
            raise HTTPException(status_code=400, detail="Text cannot be empty after stripping markdown")
        print(f"\n[ADA TTS] Sintetizando: '{texto_voz[:50]}...'")

        audio_bytes, duration = _synthesize_to_bytes(texto_voz)
        timestamps = get_word_timestamps(texto_voz, duration)
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')

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


@app.post("/synthesize_chunk")
async def synthesize_chunk(request: SynthesisRequest):
    """Sintetiza un fragmento de texto (oración) de forma optimizada para baja latencia.
    Retorna audio_base64 + timestamps, igual que /synthesize, pero pensado para
    fragmentos cortos enviados en tiempo real durante el streaming del LLM."""
    if not voice:
        raise HTTPException(status_code=500, detail="ERR_TTS_01|Model not loaded")

    texto = request.text.strip()
    if not texto:
        raise HTTPException(status_code=400, detail="Text cannot be empty")

    try:
        start_process = time.time()
        texto_voz = _strip_markdown(texto)
        if not texto_voz:
            raise HTTPException(status_code=400, detail="Text cannot be empty after stripping markdown")
        print(f"[ADA TTS chunk] '{texto_voz[:60]}'")

        audio_bytes, duration = _synthesize_to_bytes(texto_voz)
        timestamps = get_word_timestamps(texto_voz, duration)
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')

        print(f"[ADA TTS chunk] OK en {time.time() - start_process:.2f}s")

        return {
            "original_text": texto,
            "timestamps": timestamps,
            "audio_base64": audio_base64,
            "duration": round(duration, 3),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ERR_TTS_02|{str(e)}")

if __name__ == "__main__":
    import uvicorn
    # Levantamos en el puerto designado para el motor vocal
    uvicorn.run(app, host="0.0.0.0", port=5001)
