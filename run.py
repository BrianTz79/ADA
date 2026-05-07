import subprocess
import sys
import threading
import time
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

def stream_output(process, prefix):
    for line in iter(process.stdout.readline, b''):
        sys.stdout.buffer.write(f"{prefix} ".encode('utf-8') + line)
        sys.stdout.flush()

def start_process(cmd, cwd, prefix):
    process = subprocess.Popen(
        cmd,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL, # Evita que los procesos se pausen por SIGTTIN
        bufsize=0,
    )
    thread = threading.Thread(target=stream_output, args=(process, prefix), daemon=True)
    thread.start()
    return process

def main():
    print("==================================================")
    print("   🚀 INICIANDO ENTORNO KIOSCO ADA (Modo Unificado) 🚀")
    print("==================================================")

    processes = []
    
    try:
        # Backend Principal
        backend_cmd = [os.path.join(BASE_DIR, "ADA AI/venv/bin/python3"), "-u", "Ada-Backend_implementation.py"]
        backend_cwd = os.path.join(BASE_DIR, "ADA AI")
        processes.append(start_process(backend_cmd, backend_cwd, "[🧠 BACKEND]"))

        # Whisper
        whisper_cmd = [os.path.join(BASE_DIR, "InterfazGrafica/Whisper/venv/bin/python3"), "-u", "app.py"]
        whisper_cwd = os.path.join(BASE_DIR, "InterfazGrafica/Whisper")
        processes.append(start_process(whisper_cmd, whisper_cwd, "[🎙️ WHISPER]"))

        # Piper TTS
        piper_cmd = [os.path.join(BASE_DIR, "ADA AI/venv/bin/python3"), "-u", "tts_service.py"]
        piper_cwd = os.path.join(BASE_DIR, "ADA AI/PiperTTS")
        processes.append(start_process(piper_cmd, piper_cwd, "[🗣️ PIPER  ]"))

        print("⏳ Esperando 5 segundos para que los servicios arranquen...")
        time.sleep(5)

        # Frontend Flutter
        print("📱 Iniciando Frontend interactivo...")
        frontend_cmd = ["flutter", "run", "-d", "web-server", "--web-hostname", "0.0.0.0", "--web-port", "8080"]
        frontend_cwd = os.path.join(BASE_DIR, "InterfazGrafica")
        
        # Flutter corre de forma directa para mantener la interactividad
        flutter_process = subprocess.Popen(frontend_cmd, cwd=frontend_cwd)
        processes.append(flutter_process)
        
        flutter_process.wait()
        
    except KeyboardInterrupt:
        print("\n🛑 Deteniendo servidores de Kiosco ADA...")
    finally:
        for p in processes:
            try:
                p.terminate()
            except Exception:
                pass
        print("✅ Todos los servicios detenidos.")

if __name__ == "__main__":
    main()
