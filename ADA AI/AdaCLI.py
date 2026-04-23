import os
import time
import json
import numpy as np
from sentence_transformers import CrossEncoder # Nueva dependencia
from langchain_ollama import ChatOllama, OllamaEmbeddings
from langchain_chroma import Chroma
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.output_parsers import StrOutputParser
from langchain_core.messages import HumanMessage, AIMessage

# ==========================================
# 1. INFRAESTRUCTURA DE DATOS (CHROMA DB)
# ==========================================
DB_DIR = "../../IA Scapping/ChromaVersions/Version3"
embeddings = OllamaEmbeddings(
    model="nomic-embed-text",
    base_url="http://100.81.207.20:11434"
)

vector_db = Chroma(
    collection_name="kiosco_docs", 
    persist_directory=DB_DIR, 
    embedding_function=embeddings
)

# Inicializamos el Re-ranker (BAAI/bge-reranker-base es el punto dulce entre velocidad y precisión)
print("📌 Cargando Re-ranker local...")
reranker = CrossEncoder('BAAI/bge-reranker-base')

# ==========================================
# 2. CEREBRO DEL SISTEMA (LLM CONFIG)
# ==========================================
llm = ChatOllama(
    model="llama3.2:3b", 
    temperature=0.1, 
    num_ctx=4096,
    base_url="http://100.81.207.20:11434"
)

# ==========================================
# 3. MOTOR DE BÚSQUEDA OPTIMIZADO
# ==========================================
def obtener_contexto_dinamico(query, k_inicial=40, k_final=5, threshold=-2.0):
    """
    Realiza una búsqueda híbrida:
    1. Recupera 'k_inicial' documentos de ChromaDB.
    2. Re-clasifica los resultados usando un Cross-Encoder.
    3. Filtra por umbral de relevancia.
    """
    docs = vector_db.similarity_search(query, k=k_inicial)
    
    if not docs:
        return []

    pares = []
    for d in docs:
        try:
            datos_json = json.loads(d.page_content)
            contenido = datos_json.get("contenido", d.page_content)
        except:
            contenido = d.page_content
        pares.append([query, contenido])

    scores = reranker.predict(pares)
    doc_scores = sorted(zip(docs, scores), key=lambda x: x[1], reverse=True)
    
    docs_relevantes = [d for d, s in doc_scores if s > threshold]
    return docs_relevantes[:k_final]

# ==========================================
# 4. INSTRUCCIONES DE COMPORTAMIENTO (PROMPT)
# ==========================================
prompt = ChatPromptTemplate.from_messages([
    ("system", """Eres "Ada", la amable y relajada asistente virtual del ITT (Instituto Tecnológico de Tijuana). 
Tu objetivo es ayudar a los estudiantes con sus trámites y dudas.

REGLAS DE ORO:
1. ROMPE LA CUARTA PARED (CRÍTICO): JAMÁS uses la palabra "contexto", "según la información provista", "los documentos establecen" o "en el enlace mencionado". ¡Compórtate como si supieras todo esto de memoria de forma natural! Dale al usuario los enlaces directamente de forma coloquial ("Te dejo el enlace aquí: ...").
2. USA EL CONTEXTO Y TU SENTIDO COMÚN: Basa tus respuestas puramente en el CONTEXTO provisto abajo, pero usa lógica para no mezclar temas sin sentido.
3. SÉ CONVERSACIONAL: Si el estudiante solo hace charla o saluda, respóndele de manera natural sin limitarte a trámites.
4. RESPUESTAS PARCIALES: Si la pregunta pide varios datos y solo tienes algunos, entrega ÚNICAMENTE la información que tienes. ¡NO inventes trámites, fechas ni reglas!
5. IGNORANCIA TOTAL: Si no hay NADA útil para responder, di con naturalidad: 'La verdad no tengo ese dato a la mano ahorita. Te sugiero checar la página oficial del Tec o directo en ventanilla'.
6. ANTI-GROSERÍAS: Si te dicen groserías o albures responde con tacto: 'Mejor hablemos del Tec, ¿en qué te ayudo?'

CONTEXTO AL RECUPERAR DATOS:
{context}"""),
    MessagesPlaceholder(variable_name="chat_history"),
    ("user", "{question}")
])

# ==========================================
# 5. LÓGICA DE EJECUCIÓN Y MÉTRICAS
# ==========================================
def ask_ada_rag(query, chat_history):
    t_start = time.time()
    
    # 🌟 MEJORA: Búsqueda Contextualizada con Memoria Corta
    search_query = query
    if chat_history:
        # Extraemos parte del último mensaje del usuario para no perder el hilo
        last_human_msg = next((msg.content for msg in reversed(chat_history) if isinstance(msg, HumanMessage)), "")
        # Limitamos a unas palabras por si era un mensaje largo
        search_query = f"{last_human_msg[:100]} | {query}"

    source_docs = obtener_contexto_dinamico(search_query)
    t_retrieval = time.time() - t_start
    
    textos_limpios = []
    for d in source_docs:
        try:
            datos_json = json.loads(d.page_content)
            texto_real = datos_json.get("contenido", d.page_content)
        except json.JSONDecodeError:
            texto_real = d.page_content
        textos_limpios.append(f"--- Fuente: {d.metadata.get('source', 'Web_ITT')} ---\n{texto_real}")

    context_text = "\n\n".join(textos_limpios) if source_docs else "No se encontraron documentos relevantes en la base de datos para esta consulta."
    
    if source_docs:
        print(f"\n--- 🕵️ CONTEXTO RE-CLASIFICADO (Búsqueda: '{search_query}') ---")
        print(context_text[:500] + "...\n----------------------------------------------\n")
    else:
        print(f"\n--- 🕵️ BÚSQUEDA VECTORIAL (Búsqueda: '{search_query}') ---\nNo se hallaron coincidencias. Pasando solo a memoria...\n----------------------------------------------\n")

    print(f"[⏱️ Búsqueda + Re-ranker: {t_retrieval:.3f}s | 📄 Chunks filtrados: {len(source_docs)}]")
    print("🤖 Ada > ", end="", flush=True)
    
    chain = prompt | llm | StrOutputParser()
    
    t_gen_start = time.time()
    first_token = True
    full_response = []
    
    for chunk in chain.stream({"context": context_text, "question": query, "chat_history": chat_history}):
        if first_token:
            print(f"(⚡) ", end="") 
            first_token = False
        print(chunk, end="", flush=True)
        full_response.append(chunk)
    
    print(f"\n\n[⏱️ Generación: {time.time() - t_gen_start:.3f}s]")
    return "".join(full_response)

# ==========================================
# 6. BUCLE PRINCIPAL
# ==========================================
if __name__ == "__main__":
    print("\n--- 🤖 ADA ITT INICIADA (CON RE-RANKING Y MEMORIA) 🤖 ---")
    chat_history = []
    
    while True:
        try:
            q = input("\n👉 Pregúntale a Ada: ")
            if q.lower() in ['salir', 'exit', 'quit']: break
            if not q.strip(): continue
            
            respuesta_ada = ask_ada_rag(q, chat_history)
            
            # Actualizamos memoria
            chat_history.extend([HumanMessage(content=q), AIMessage(content=respuesta_ada)])
            
            # Mantener solo los últimos 6 mensajes (3 intercambios)
            if len(chat_history) > 6:
                chat_history = chat_history[-6:]
                
        except KeyboardInterrupt:
            print("\nApagando a Ada... ¡Sobres!")
            break