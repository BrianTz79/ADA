import chromadb

DB_DIR = "/workspace/AI Workspace/ADA AI/vector_db"
print("🔍 Conectando a la base de datos física...")

# Conectamos directamente con el cliente nativo de Chroma
cliente = chromadb.PersistentClient(path=DB_DIR)

# Pedimos la lista de todas las colecciones que existen ahí adentro
colecciones = cliente.list_collections()

if not colecciones:
    print("❌ Definitivamente no hay ninguna colección aquí. La DB se creó mal.")
else:
    print("\n✅ ¡Colecciones encontradas!")
    for c in colecciones:
        print(f" -> Nombre de la colección: '{c.name}'")
        print(f" -> Cantidad de chunks guardados: {c.count()}\n")