import os
import re
from langchain_core.documents import Document
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_ollama import OllamaEmbeddings
from langchain_chroma import Chroma

# ==========================================
# CONFIGURACIÓN DE RUTAS
# ==========================================
INPUT_FOLDER = "docs"          # La carpeta donde tu compañero dejó los page_x.txt
DB_DIR = "./vector_db"         # Donde vive el cerebro de Ada
COLLECTION_NAME = "kiosco_docs" # El cajón correcto

def sanitizar_texto_itt(texto_crudo):
    """
    Filtro de limpieza extrema para quitar la basura del HTML del Tec.
    """
    # 1. Frases exactas que no aportan nada (Menús, redes sociales, etc.)
    basura_conocida = [
        "SUBMENUSUBMENU", "MENUMENU", "Efemérides – Tecnológico Nacional de México – Tijuana",
        "¿Necesitas Ayuda?", "Me gusta enFacebook", "Síguenos enTwitter", 
        "Síguenos enYouYube", "Síguenos enInstagram", "Síguenos enTikTok",
        "Deja tu Comentario", "Tu dirección de correo electrónico no será publicada.",
        "Los campos obligatorios están marcados con *Comentario * Nombre",
        "Correo electrónico", "Web", "Δ", 
        "Este sitio usa Akismet para reducir el spam.  Aprende cómo se procesan los datos de tus comentarios.",
        "Tecnológico Nacional de México – Tijuana"
    ]
    
    texto_limpio = texto_crudo
    for frase in basura_conocida:
        texto_limpio = texto_limpio.replace(frase, "")
        
    # 2. Limpieza con Expresiones Regulares (Regex)
    # Quitar múltiples saltos de línea vacíos (deja máximo 2 juntos para separar párrafos)
    texto_limpio = re.sub(r'\n{3,}', '\n\n', texto_limpio)
    # Quitar tabulaciones o espacios larguísimos
    texto_limpio = re.sub(r'[ \t]+', ' ', texto_limpio)
    
    return texto_limpio.strip()

def cargar_y_limpiar_documentos():
    """Lee los txt, los limpia y los convierte en formato Document de LangChain"""
    documentos = []
    
    if not os.path.exists(INPUT_FOLDER):
        print(f"❌ ¡Error! No encuentro la carpeta '{INPUT_FOLDER}'.")
        return []
        
    archivos = [f for f in os.listdir(INPUT_FOLDER) if f.endswith('.txt')]
    print(f"📂 Encontrados {len(archivos)} archivos de texto extraídos de la web.")
    
    for archivo in archivos:
        ruta = os.path.join(INPUT_FOLDER, archivo)
        with open(ruta, "r", encoding="utf-8", errors="ignore") as f:
            texto = f.read()
            
            # Sanitizamos el texto
            texto_limpio = sanitizar_texto_itt(texto)
            
            # Solo guardamos si quedó información real (más de 50 caracteres)
            if len(texto_limpio) > 50:
                # El metadata ayuda a saber de qué archivo vino la info
                doc = Document(page_content=texto_limpio, metadata={"source": archivo})
                documentos.append(doc)
                
    return documentos

def inyectar_conocimiento():
    docs_limpios = cargar_y_limpiar_documentos()
    
    if not docs_limpios:
        print("⚠️ No hay documentos válidos para procesar tras la limpieza.")
        return

    # ==========================================
    # CHUNKING INTELIGENTE (Adiós al corte por 500 palabras)
    # ==========================================
    print("✂️ Cortando los documentos respetando párrafos y oraciones...")
    # RecursiveCharacterTextSplitter intenta cortar primero por párrafos (\n\n), 
    # luego por oraciones (\n), luego por puntos (.), evitando romper ideas a la mitad.
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=1000,       # Caracteres, no palabras (aprox 200-250 palabras)
        chunk_overlap=200,     # Traslape para no perder el hilo entre un chunk y otro
        separators=["\n\n", "\n", ". ", " ", ""]
    )
    
    chunks = text_splitter.split_documents(docs_limpios)
    print(f"🧩 Textos convertidos en {len(chunks)} fragmentos (chunks) de conocimiento.")

    # ==========================================
    # INYECCIÓN A CHROMADB
    # ==========================================
    print("🧠 Generando vectores con Nomic y guardando en ChromaDB (esto puede tardar)...")
    embeddings = OllamaEmbeddings(model="nomic-embed-text")
    
    # Esto sobrescribe o añade a la colección kiosco_docs
    vector_db = Chroma.from_documents(
        documents=chunks,
        embedding=embeddings,
        persist_directory=DB_DIR,
        collection_name=COLLECTION_NAME
    )
    
    print("\n✅ ¡INYECCIÓN COMPLETADA! El cerebro de Ada ha sido actualizado.")
    print(f"📦 Total de chunks alojados en '{COLLECTION_NAME}': {vector_db._collection.count()}")

if __name__ == "__main__":
    print("--- 🛠️ INICIANDO PROCESO DE SANITIZACIÓN E INYECCIÓN 🛠️ ---")
    inyectar_conocimiento()