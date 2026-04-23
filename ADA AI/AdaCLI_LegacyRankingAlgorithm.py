import os
import time
import json
from langchain_ollama import ChatOllama, OllamaEmbeddings
from langchain_chroma import Chroma
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

# ==========================================
# 1. INFRAESTRUCTURA DE DATOS (CHROMA DB)
# ==========================================
DB_DIR = "../../IA Scapping/ChromaVersions/Version3"

embeddings = OllamaEmbeddings(model="nomic-embed-text")

vector_db = Chroma(
    collection_name="kiosco_docs", 
    persist_directory=DB_DIR, 
    embedding_function=embeddings
)

# ==========================================
# 2. CEREBRO DEL SISTEMA (LLM CONFIG)
# ==========================================
llm = ChatOllama(
    model="llama3.1:8b", 
    temperature=0.1, 
    num_ctx=4096 # AUMENTADO: Para que no se quede sin memoria al leer los 5 chunks
)

# ==========================================
# 3. MOTOR DE BÚSQUEDA
# ==========================================
def obtener_contexto_dinamico(query, k=5):
    docs = vector_db.similarity_search(query, k=k)
    return docs

# ==========================================
# 4. INSTRUCCIONES DE COMPORTAMIENTO (PROMPT)
# ==========================================
prompt = ChatPromptTemplate.from_messages([
    ("system", """Eres "Ada", la asistente virtual oficial del ITT (Instituto Tecnológico de Tijuana). 
Tu personalidad es relajada, amable, y servicial.
Tu objetivo es ayudar a los estudiantes con información precisa.

REGLAS DE ORO:
1. Usa ÚNICAMENTE el siguiente CONTEXTO para responder. 
2. RESPUESTAS PARCIALES: Si la pregunta pide varios datos y el contexto SOLO contiene una fracción de ellos, entrega ÚNICAMENTE la información que tienes. Aclara explícitamente qué dato te falta y sugiere preguntar en ventanilla por esa parte faltante. ESTÁ ESTRICTAMENTE PROHIBIDO inventar la parte que falta o rellenar con temas que el usuario no preguntó.
3. IGNORANCIA TOTAL: Si no hay absolutamente nada en el contexto que responda a la pregunta, responde EXACTAMENTE: 'Para ser honesta, no tengo ese dato a la mano. Te sugiero preguntar en ventanilla o checar la página oficial del Tec.' y detente.
4. DEFENSA ANTI-ALBUR: Si te dicen groserías o albures, responde: "Te parece si mejor hablemos del Tec, ¿en qué te ayudo con tus trámites?"

CONTEXTO:
{context}"""),
    ("user", "{question}")
])

# ==========================================
# 5. LÓGICA DE EJECUCIÓN Y MÉTRICAS
# ==========================================
def ask_ada_rag(query):
    t_start = time.time()
    
    source_docs = obtener_contexto_dinamico(query)
    t_retrieval = time.time() - t_start
    
    if not source_docs:
        print(f"\n[⏱️ Búsqueda: {t_retrieval:.3f}s | 📄 Chunks útiles: 0]")
        print("🤖 Ada > Para ser honesta, no tengo ese dato a la mano. Te sugiero preguntar en ventanilla o checar la página oficial del Tec.\n")
        return

    textos_limpios = []
    for d in source_docs:
        try:
            datos_json = json.loads(d.page_content)
            texto_real = datos_json.get("contenido", d.page_content)
        except json.JSONDecodeError:
            texto_real = d.page_content
            
        textos_limpios.append(f"--- Fuente: {d.metadata.get('source', 'Web_ITT')} ---\n{texto_real}")

    context_text = "\n\n".join(textos_limpios)
    
    print("\n--- 🕵️ LO QUE ADA ESTÁ LEYENDO (CONTEXTO LIMPIO) ---")
    print(context_text[:1500] + "...\n[Texto cortado para no saturar la pantalla]")
    print("----------------------------------------------\n")

    print(f"[⏱️ Búsqueda: {t_retrieval:.3f}s | 📄 Chunks útiles: {len(source_docs)}]")
    print("🤖 Ada > ", end="", flush=True)
    
    chain = prompt | llm | StrOutputParser()
    
    t_gen_start = time.time()
    first_token = True
    
    for chunk in chain.stream({"context": context_text, "question": query}):
        if first_token:
            print(f"(⚡) ", end="") 
            first_token = False
        print(chunk, end="", flush=True)
    
    print(f"\n\n[⏱️ Generación: {time.time() - t_gen_start:.3f}s]")

# ==========================================
# 6. BUCLE PRINCIPAL
# ==========================================
if __name__ == "__main__":
    print("--- 🤖 INICIANDO KIOSKO ITT (ADA) 🤖 ---")
    while True:
        try:
            q = input("\n👉 Pregúntale a Ada: ")
            if q.lower() in ['salir', 'exit', 'quit']: break
            if not q.strip(): continue
            ask_ada_rag(q)
        except KeyboardInterrupt:
            print("\nApagando a Ada... ¡Sobres!")
            break