#!/bin/bash

# Determinar directorios
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$BASE_DIR/ADA AI"
FRONTEND_DIR="$BASE_DIR/InterfazGrafica"
WHISPER_DIR="$FRONTEND_DIR/Whisper" # <-- Nueva ruta de Whisper
PIPER_DIR="$BACKEND_DIR/PiperTTS" # <-- Ruta de Piper TTS

# Función para limpiar procesos al cerrar
cleanup() {
    echo -e "\n🛑 Deteniendo servidores..."
    if [ -n "$BACKEND_PID" ] && kill -0 $BACKEND_PID 2>/dev/null; then
        kill $BACKEND_PID
    fi
    if [ -n "$WHISPER_PID" ] && kill -0 $WHISPER_PID 2>/dev/null; then
        kill $WHISPER_PID
    fi
    if [ -n "$PIPER_PID" ] && kill -0 $PIPER_PID 2>/dev/null; then
        kill $PIPER_PID
    fi
    echo "✅ Servidores detenidos."
}

# Atrapar cierre (Ctrl+C)
trap cleanup SIGINT SIGTERM EXIT

echo "=================================================="
echo "   🚀 INICIANDO ENTORNO KIOSCO ADA 🚀"
echo "=================================================="

# 1. Iniciar Backend (Ollama/RAG) en segundo plano
echo "🧠 Iniciando Backend Principal... (Logs guardados en backend.log)"
cd "$BACKEND_DIR"
source venv/bin/activate
# Guardamos todo lo que diga en un archivo .log
python3 Ada-Backend_implementation.py > "$BASE_DIR/backend.log" 2>&1 &
BACKEND_PID=$!

# 2. Iniciar Whisper en segundo plano
echo "🎙️ Iniciando Microservicio Whisper... (Logs guardados en whisper.log)"
cd "$WHISPER_DIR"
source venv/bin/activate
# Dependiendo de cómo lo configuró Antigravity, usamos python3 o uvicorn:
python3 app.py > "$BASE_DIR/whisper.log" 2>&1 &
WHISPER_PID=$!

# 3. Iniciar Piper TTS en segundo plano
echo "🗣️ Iniciando Microservicio Piper TTS... (Logs guardados en piper.log)"
cd "$PIPER_DIR"
source ../venv/bin/activate
python3 tts_service.py > "$BASE_DIR/piper.log" 2>&1 &
PIPER_PID=$!

echo "⏳ Esperando 5 segundos para que los servicios arranquen..."
sleep 5

# 3. Iniciar Frontend (Flutter) en primer plano
echo "📱 Iniciando Frontend..."
cd "$FRONTEND_DIR"
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080


# Cómo ver las terminales por separado en VS Code ahora?
#
#   Ejecutas tu ./run.sh en tu terminal principal de VS Code. Verás que levanta Flutter.
#
#   Le das al ícono de "Dividir Terminal" (el cuadrito que parece dividido a la mitad en la ventana de terminal de VS Code).
#
#   En esa nueva terminal que se abrió al lado, escribes: tail -f backend.log (Ahí verás los logs de Ollama y el RAG en vivo).
#
#   Divides la terminal otra vez y escribes: tail -f whisper.log (Ahí verás los nuevos logs de los micrófonos que le acabamos de pedir a Antigravity).