import os
import urllib.request

# Repositorio oficial de Piper en HuggingFace (O en este caso, el repositorio de HirCoir)
MODEL_URL = "https://huggingface.co/spaces/HirCoir/Piper-TTS-Spanish/resolve/main/es_MX-cortana-19669-epoch-high.onnx"
CONFIG_URL = "https://huggingface.co/spaces/HirCoir/Piper-TTS-Spanish/resolve/main/es_MX-cortana-19669-epoch-high.onnx.json"

MODEL_FILE = "es_MX-cortana-19669-epoch-high.onnx"
CONFIG_FILE = "es_MX-cortana-19669-epoch-high.onnx.json"

def download_file(url, target_path):
    print(f"Descargando {target_path}...")
    try:
        urllib.request.urlretrieve(url, target_path)
        print(f"✅ Descarga exitosa: {target_path}")
    except Exception as e:
        print(f"❌ Error crítico al descargar {target_path}: {e}")
        print("Revisa tu conexión a internet o los firewalls institucionales.")

if __name__ == "__main__":
    print("="*60)
    print("Instalador de Voz Femenina Mexicana (Piper TTS) - Kiosco ADA")
    print("="*60)
    
    if not os.path.exists(MODEL_FILE):
        download_file(MODEL_URL, MODEL_FILE)
    else:
        print(f"El modelo {MODEL_FILE} ya existe. Omitiendo.")
        
    if not os.path.exists(CONFIG_FILE):
        download_file(CONFIG_URL, CONFIG_FILE)
    else:
        print(f"El archivo de configuración {CONFIG_FILE} ya existe. Omitiendo.")
        
    print("\n✨ ¡Artefactos acústicos instalados! El modelo local Edge está listo.")
