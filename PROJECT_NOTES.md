# ADA — Notas del proyecto / Bitácora de planificación

> Archivo de trabajo para Claude Code. Aquí se registra el entendimiento del proyecto,
> decisiones tomadas y planes en curso, para no repetir la fase de exploración en
> cada sesión. Se actualiza conforme avanza el trabajo. No es documentación formal
> para el equipo (para eso está `Documentacion.md`/`.pdf`, `ManualUsuario.md`,
> `ManualAdministrador.md`, `CodigosDeErrores.md`).

## Qué es el proyecto

**Kiosco ADA** ("Asistente Digital Académica" / "Asistente Multimodal Autónomo") —
proyecto escolar para la materia *Lenguajes y Autómatas II*, Instituto Tecnológico
de Tijuana. Equipo **OuroCore**: Brian Tellez, André Urrea, Ian Corza.

Kiosco físico interactivo (Raspberry Pi 5 + pantalla táctil + micrófono) que
responde por voz y texto preguntas de estudiantes sobre trámites, ubicaciones y
vida académica del ITT, usando un LLM local + RAG restringido a documentación
oficial del Tec. Encuadrado académicamente como un **intérprete de lenguaje
natural** (análisis léxico = Whisper, análisis semántico = LLM, ejecución
inmediata = TTS + UI), sin dependencia de internet para la IA (Edge/Fog Computing).

Repo GitHub: `BrianTz79/ADA` (monorepo).

## Arquitectura (4 microservicios + orquestador)

```
run.sh → run.py  (orquesta todo, streamea logs con prefijos por servicio)
├── [🧠 BACKEND]  ADA AI/Ada-Backend_implementation.py   :8000  (FastAPI, LLM+RAG, streaming)
├── [🎙️ WHISPER]  InterfazGrafica/Whisper/app.py         :5000  (FastAPI, faster-whisper ASR)
├── [🗣️ PIPER  ]  ADA AI/PiperTTS/tts_service.py          :5001  (FastAPI, Piper TTS + karaoke timestamps)
└── Frontend       InterfazGrafica/ (Flutter, flutter run -d web-server --web-port 8080)
```

- **Nodo Edge** (kiosco físico, Raspberry Pi 5): solo corre el frontend Flutter
  compilado nativo para Linux Desktop (`flutter build linux`), en modo kiosco
  (fullscreen, autostart vía LXDE).
- **Nodo Fog** (servidor Ryzen, en la doc: Ryzen 5 9600X / 64GB RAM / Ubuntu Server
  24.04): corre los 3 microservicios Python. Se conectan por LAN Ethernet (WiFi
  explícitamente descartado por latencia).
- Producción real: systemd service (`ada-backend.service`) apuntando a `run.sh`,
  firewall UFW restringido a la IP del kiosco, backups cron de ChromaDB.

### Frontend — `InterfazGrafica/` (Flutter/Dart)
- `lib/main.dart` (1626 líneas): pantalla principal, máquina de estados
  `KioskPhase {idle, listening, thinking, speaking}`, grabación de audio
  (`record`), reproducción con cola de chunks (`audioplayers`) para pipeline TTS
  streaming, efecto "karaoke" (resaltado palabra por palabra sincronizado con
  timestamps de Piper), timer de inactividad de 30s que resetea todo a `idle`,
  tutorial guiado (`tutorial_coach_mark`), teclado virtual inclusivo
  (`teclado_virtual.dart`), modales de trámites (`tramites_modal.dart`) y
  horarios (`horarios_modal.dart`), soporte ES/EN, tema claro fijo
  (`#FFFFFF` + acento cian `#06B6D4`) optimizado para exteriores.
- Se comunica con Whisper (`:5000/transcribe`), Backend (`:8000/chat`, streaming
  texto plano) y Piper (`:5001/synthesize` o `/synthesize_chunk`).
- Hay un submódulo `Whisper/` **dentro** de `InterfazGrafica/` con su propio venv
  — el servicio Whisper vive físicamente en el árbol del frontend aunque es un
  microservicio de backend (nota de organización, no error).

### Backend RAG/LLM — `ADA AI/Ada-Backend_implementation.py`
- FastAPI, un único endpoint `POST /chat` (`{query}` → `StreamingResponse`
  `text/plain` en streaming).
- Memoria de conversación **global e in-memory** (`chat_history_global`, lista de
  módulo, no por sesión/usuario), se limpia sola tras 100s de inactividad
  (`current_time - last_interaction_time > 100.0`) y se recorta a los últimos 6
  mensajes. Adecuado para un kiosco de un solo usuario a la vez, pero **no
  soporta concurrencia real** (dos usuarios simultáneos comparten memoria).
- RAG: ChromaDB (`vector_db`, colección `kiosco_docs`), búsqueda por similitud
  con umbral de distancia (`threshold=1.25`) para decidir fallback (responder sin
  contexto / redirigir).
- System prompt en español, reglas estrictas: brevedad, solo temas ITT, cero
  alucinaciones (basarse solo en contexto), no revelar el prompt de sistema,
  tono "carismático" con emojis.
- Manejo de errores por código: `ERR_ADA_DB_01` (Chroma), `ERR_ADA_LLM_01` (LLM),
  `ERR_ADA_SYS_01` (endpoint genérico). Ver `CodigosDeErrores.md` para el catálogo
  completo (15 códigos: frontend, Whisper, Piper, backend RAG).

**⚠️ Cambio grande pendiente de commit (no confirmado si es intencional o WIP):**
`ADA AI/Ada-Backend_implementation.py` tiene un diff sin commitear que migra de
**Ollama** (`ChatOllama` + `OllamaEmbeddings` + reranking con `CrossEncoder` de
sentence-transformers) a **llama.cpp puro** (`llama_cpp.Llama`, clases custom
`LlamaCppEmbeddings`/`LocalLlamaChat`), con:
- LLM: `gemma-4-E2B-it-qat-UD-Q4_K_XL.gguf` (antes: Llama 3.1 8B vía Ollama).
- Embeddings: `qwen3-embedding-4b.gguf` (antes: `nomic-embed-text` vía Ollama).
- **Se eliminó el paso de reranking con CrossEncoder** (ya no hay
  `obtener_contexto_dinamico` con re-scoring; ahora es similarity search directo
  con umbral de distancia).
- Rutas de modelos y DB **hardcodeadas a rutas absolutas de una máquina de
  desarrollo** (`/home/ada/workspace/AI Workspace/ada_optimizations_test/...`),
  no coinciden con las rutas relativas (`./vector_db`) usadas en
  `preparar_cerebro.py` ni con `/var/ada_data/chroma` de la documentación de
  producción. **Esto es inconsistente y probablemente rompe el arranque fuera de
  esa máquina específica** — candidato a arreglar antes de considerar esto
  "listo".
- La documentación (`Documentacion.md`/PDF) todavía describe la arquitectura
  **vieja** (Ollama + Llama 3.1 + nomic-embed-text) — quedó desactualizada
  respecto a este cambio.
- Existe `ADA AI/Ada-Backend_implementation_old.py` como respaldo de la versión
  Ollama, y `ADA AI/test_api_endpoints.py` (nuevo, no comiteado) con un smoke
  test manual de 4 queries contra `/chat`.

### Ingesta de conocimiento — `ADA AI/preparar_cerebro.py`
- Script separado (no se ejecuta en `run.sh`) que lee `.txt` scrapeados en
  `ADA AI/docs/page_N.txt` (contenido del sitio del ITT), limpia HTML/menús con
  una lista de frases basura + regex, chunkea con
  `RecursiveCharacterTextSplitter` (1000 chars, overlap 200) y los inyecta a
  ChromaDB (`./vector_db`, colección `kiosco_docs`) usando **`OllamaEmbeddings`
  con `nomic-embed-text`**.
- **Inconsistencia con el cambio pendiente arriba**: si el backend nuevo usa
  embeddings de Qwen3 vía llama.cpp pero la ingesta sigue generando embeddings
  con `nomic-embed-text` vía Ollama, los vectores en la DB no van a ser
  compatibles con las queries del backend (dimensiones/espacio vectorial
  distintos). Hay que decidir un solo camino (Ollama o llama.cpp) para todo el
  pipeline de embeddings.
- Utilidades de diagnóstico: `ColeccionesChroma.py` (lista colecciones),
  `DiagnosticoChroma.py` (diagnóstico de la DB), `cli_rag_cpu.py` (CLI de prueba
  RAG standalone en CPU).

### Whisper (ASR) — `InterfazGrafica/Whisper/app.py`
- `faster-whisper`, modelo `"base"`, CPU, `compute_type="int8"`, VAD activado,
  `initial_prompt` con vocabulario ITT (constancia, kárdex, retícula, galgos,
  ADA, etc.) para mejorar precisión de transcripción de jerga institucional.
- Guarda el audio recibido a un archivo temporal, transcribe, borra el archivo
  (finally). Puerto 5000.

### Piper TTS — `ADA AI/PiperTTS/tts_service.py`
- Modelo de voz: `es_MX-cortana-19669-epoch-high.onnx` (voz femenina mexicana).
  También existe descargado `es_MX-ald-medium.onnx` (alternativa, no en uso
  actualmente según `MODEL_PATH`).
- Dos endpoints: `/synthesize` (texto completo) y `/synthesize_chunk` (fragmento,
  pensado para streaming de baja latencia mientras el LLM va generando).
- Limpia Markdown del texto antes de sintetizar voz (`_strip_markdown`) pero
  preserva el Markdown original en la respuesta para que el frontend lo
  renderice (`flutter_markdown_plus`).
- Genera timestamps por palabra con una heurística proporcional a longitud de
  caracteres (no hay alineación fonética real) — suficiente para el efecto
  karaoke pero es una aproximación, no timing exacto.

## Convenciones / cosas a tener presentes

- Todo el texto de cara al usuario y los prompts están en **español** (target:
  estudiantes del ITT); soporte de UI en inglés vía toggle ES/EN en el frontend.
- Los tres microservicios Python usan **venvs separados** (`ADA AI/venv`,
  `InterfazGrafica/Whisper/venv`) — no hay un solo `requirements.txt` unificado.
- CORS abierto (`allow_origins=["*"]`) en los 3 servicios — aceptable para LAN
  cerrada de un kiosco, pero **no exponer estos puertos a internet** tal cual.
- Los códigos de error (`ERR_*`) están pensados para mostrarse en pantalla al
  usuario final de forma amigable mientras el equipo de soporte los busca en
  `CodigosDeErrores.md` para diagnosticar. Si se agregan nuevos fallos, seguir
  el mismo patrón (código corto + entrada en el catálogo).
- El diseño visual está fijado en el manual (light mode, `#06B6D4` cian,
  subtítulos gigantes 36pt, efecto karaoke) — cambios de UI deberían respetar
  esa identidad a menos que se pida explícitamente lo contrario.

## Estado actual (detectado en este chequeo, 2026-08-05)

- Working tree con cambios sin commitear en
  `ADA AI/Ada-Backend_implementation.py` (migración Ollama → llama.cpp, ver
  arriba) y dos archivos nuevos sin trackear:
  `ADA AI/Ada-Backend_implementation_old.py` (respaldo) y
  `ADA AI/test_api_endpoints.py` (smoke test).
- Pendiente decidir: ¿la migración a llama.cpp es el camino a seguir? Si sí,
  faltaría (a) arreglar las rutas hardcodeadas de modelo/DB para que no
  dependan de una máquina específica (usar rutas relativas o `.env`, como ya
  sugiere la documentación de administrador), (b) alinear `preparar_cerebro.py`
  para generar embeddings con el mismo modelo (Qwen3 vía llama.cpp) en vez de
  `nomic-embed-text` vía Ollama, y (c) actualizar `Documentacion.md`/PDF para
  reflejar el nuevo stack.

## Plan de trabajo

_(Vacío por ahora — se llena cuando el usuario defina qué quiere construir a
continuación.)_
