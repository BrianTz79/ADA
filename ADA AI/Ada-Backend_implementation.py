import os
import json
import numpy as np
import time
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
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
    model="llama3.1:8b", 
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
    try:
        docs = vector_db.similarity_search(query, k=k_inicial)
    except Exception as e:
        # /// [MANUAL_ERROR: ERR_ADA_DB_01]
        # /// Descripción: Falla de lectura/escritura en ChromaDB o base vectorial.
        # /// Causa: Base de índices corrupta o motor vectorial inalcanzable, impidiendo recuperar contexto.
        # /// Solución: Verificar si existe DB_DIR y permisos, o regenerar índices mediante el scraper.
        print("Error en DB Vectorial:", str(e))
        raise HTTPException(status_code=500, detail="ERR_ADA_DB_01")
    
    if not docs:
        return []

    pares = []
    for d in docs:
        try:
            datos_json = json.loads(d.page_content)
            contenido = datos_json.get("contenido", d.page_content)
        except Exception as e:
            # /// [MANUAL_ERROR: ERR_ADA_RAG_01]
            # /// Descripción: Falla al parsear un documento de contexto de la base vectorial.
            # /// Causa: El texto scrapeado almacenado en la DB no cumple con esquema JSON estricto o está corrupto.
            # /// Solución: Limpiar la base vectorizada y usar el Scraper en su modalidad normalizada restrictiva.
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
def ask_ada_rag_stream(query, chat_history):
    t_start = time.time()
    
    # 🌟 MEJORA: Búsqueda Contextualizada con Memoria Corta
    search_query = query
    if chat_history:
        last_human_msg = next((msg.content for msg in reversed(chat_history) if isinstance(msg, HumanMessage)), "")
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
    
    try:
        for chunk in chain.stream({"context": context_text, "question": query, "chat_history": chat_history}):
            if first_token:
                print(f"(⚡) ", end="") 
                first_token = False
            print(chunk, end="", flush=True)
            full_response.append(chunk)
            yield chunk
    except Exception as e:
        # /// [MANUAL_ERROR: ERR_ADA_LLM_01]
        # /// Descripción: Falla de respuesta de Ollama (timeout, modelo caído o generación abortada).
        # /// Causa: Ollama Llama3 colapsó por saturación de VRAM, GPU sobreasignada o caída del socket local.
        # /// Solución: Reiniciar servicio Ollama nativo e inspeccionar terminal de base de datos vectorial local.
        print(f"\n[Error LLM] La generación colapsó: {str(e)}")
        raise HTTPException(status_code=500, detail="ERR_ADA_LLM_01")
    
    print(f"\n\n[⏱️ Generación: {time.time() - t_gen_start:.3f}s]")
    
    # Manejar historia global de memoria
    chat_history.extend([HumanMessage(content=query), AIMessage(content="".join(full_response))])
    while len(chat_history) > 6:
        chat_history.pop(0)

# ==========================================
# 6. SERVIDOR WEB (FASTAPI)
# ==========================================
app = FastAPI(title="Kiosco ADA Backend", description="API para la Interfaz Gráfica Flutter del ITT")

# Configuración CORS para permitir peticiones del frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatRequest(BaseModel):
    query: str

# Memoria global básica para mantener el hilo
chat_history_global = []
last_interaction_time = 0.0

@app.post("/chat")
async def chat_endpoint(request: ChatRequest):
    global chat_history_global, last_interaction_time
    
    current_time = time.time()
    # Reiniciar la memoria de conversación si han pasado más de 30 segundos
    if current_time - last_interaction_time > 30.0:
        chat_history_global.clear()
        print("\n[🕒] Conversación reseteada por inactividad (> 30s).")
        
    last_interaction_time = current_time

    if not request.query.strip():
        raise HTTPException(status_code=400, detail="La solicitud está vacía")
        
    try:
        # Retornamos el Flujo Infinito (Generador) como StreamingResponse
        # text/plain previene que el front sufra armando el buffer.
        return StreamingResponse(ask_ada_rag_stream(request.query, chat_history_global), media_type="text/plain")
        
    except HTTPException:
        raise
    except Exception as e:
        # /// [MANUAL_ERROR: ERR_ADA_SYS_01]
        # /// Descripción: Falla crítica inesperada en el endpoint o en la tubería FAST API generadora.
        # /// Causa: Referencia nula extrema o interrupción forzosa de FastAPI.
        # /// Solución: Reiniciar manualmente el servicio central usando el backend daemon (run.sh).
        print(f"Error procesando query: {str(e)}")
        raise HTTPException(status_code=500, detail="ERR_ADA_SYS_01")

if __name__ == "__main__":
    import uvicorn
    print("\n--- 🚀 SERVIDOR ADA ENCENDIDO EN EL PUERTO 8000 🚀 ---")
    uvicorn.run(app, host="0.0.0.0", port=8000)