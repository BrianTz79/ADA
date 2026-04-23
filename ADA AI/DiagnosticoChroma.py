from langchain_chroma import Chroma
from langchain_ollama import OllamaEmbeddings
import os

# Usamos la ruta absoluta que me diste al inicio
DB_DIR = "/workspace/AI Workspace/ADA AI/vector_db"

print(f"🔍 1. Verificando ruta: {DB_DIR}")
if not os.path.exists(DB_DIR):
    print("❌ ERROR FATAL: La carpeta no existe en esa ruta.")
    exit()

print("✅ Carpeta encontrada. Conectando a ChromaDB...")

# Cargamos los embeddings
embeddings = OllamaEmbeddings(model="nomic-embed-text")
vector_db = Chroma(persist_directory=DB_DIR, embedding_function=embeddings)

# Contamos cuántos fragmentos de texto hay realmente guardados
cantidad_docs = vector_db._collection.count()
print(f"📦 2. Documentos en la base de datos: {cantidad_docs}")

if cantidad_docs == 0:
    print("\n❌ EL PROBLEMA: Tu base de datos está siendo leída como VACÍA.")
    print("¿Estás seguro de que se generó correctamente en esta ruta?")
else:
    print("\n✅ Los datos están ahí. Haciendo prueba de búsqueda cruda...")
    # Búsqueda directa sin LangChain de por medio
    resultados = vector_db.similarity_search("creditos complementarios", k=2)
    
    print(f"🎯 3. Resultados devueltos por la búsqueda: {len(resultados)}")
    if len(resultados) == 0:
        print("❌ EL PROBLEMA: Hay documentos, pero la búsqueda falla. ¡El modelo de Embeddings es incorrecto!")
    else:
        for i, doc in enumerate(resultados):
            print(f"\n--- Resultado {i+1} ---")
            print(doc.page_content[:150] + "...")