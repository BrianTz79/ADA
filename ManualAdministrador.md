# MANUAL DE ADMINISTRADOR DEL SISTEMA

**“KIOSCO INTERACTIVO CON IA”**

**TecNM - INSTITUTO TECNOLÓGICO DE TIJUANA**
**DEPARTAMENTO:** Sistemas y Computación
**MATERIA:** Lenguajes y Autómatas II  
**PERIODO:** Enero - Junio
**NOMBRE DEL MAESTRO:** Luis Alfonso Gaxiola Vega
**FECHA:** 23 de Abril de 2026

---

## 1. ALCANCE TÉCNICO

Este manual expide el nivel de directrices operacionales y directivas de administración para la gestión topológica, de inferencia e inyecciones de código generativo en la infraestructura subyacente del **Kiosco ADA**. 

*   **Mantenimiento Objetivo:** Hardening y administración de puertos, manipulación directa de inferencia en CPU/GPU y reestructuración del cluster de base de datos vectorial y modelos `ONNX`.
*   **Nivel Técnico Requerido:** Administrador de Sistemas Integrados (SysAdmin), Ingeniero DevOps o Ingeniero BackEnd en Python y Sistemas Estructurales Linux.

---

## 2. INFORMACIÓN GENERAL DEL ECOSISTEMA Y ARQUITECTURA

ADA opera bajo el paradigma de vanguardia **Fog Computing / Edge Nodes**, fracturando responsabilidades de cómputo para lograr latencias bajas:

*   **Nodo Edge (Cara del Kiosco Pública):** Microterminal operando la reactividad en UI mediante **Flutter (Dart)** corriendo de manera compilada nativa sobre el Desktop en una máquina ARM (Raspberry Pi). Contiene integraciones táctiles (Push-to-Talk) y gestos lógicos asíncronos.
*   **Nodo Central (Core - Servidor Clandestino):** Un clúster transaccional gestionado con **FastAPI** (Python). Alberga 4 pilares:
    1.  **Reconocimiento de Voz (ASR):** Open-AI `faster-whisper`.
    2.  **Síntesis Vocal (TTS):** Generador fonético `PiperTTS` con bindings nativos al runtime local.
    3.  **Generación Neural (LLMs):** `Ollama` orquestando familias de LLM3 con Inferencia.
    4.  **Base Vectorial de Recuperación Contextual (RAG):** Repositorios empotrados de `ChromaDB` filtrados vía `Sentence-Transformers`.

---

## 3. REQUISITOS TÉCNICOS INTEGRALES

*   **Servidor Maestro (Core Node):**
    *   **SO:** Entornos minimalistas en Linux. (Preferible CachyOS para tuning agresivo del Scheduler, o Ubuntu Server 24.04 LTS).
    *   **RAM/VRAM Limit:** Obligatorio poseer mínimo 32GB RAM e interconexiones para SWAP, a modo de alimentar consistentemente a Ollama cuantizado manteniendo su peso en memoria asíncrona.
*   **Nodo Hardware Físico (Edge):**
    *   Raspberry Pi 5 o placa SBC, ligada a un micrófono de captura direccional robusto y Display multi-táctil.

---

## 4. INSTALACIÓN Y CONFIGURACIÓN CRÍTICA

### Clonaje e Inicialización del Clúster Backend
Asegúrate de ejecutar tus scripts de instalación de Ollama pertinentes. ADA requiere contenedores locales y Python para montar su FastAPI y PiperTTS de inmediato:

```bash
git clone https://github.com/BrianTz79/ADA-Backend.git && cd ADA-Backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
# (Y para el entorno fonético en ADA AI/PiperTTS): 
# pip install -r requirements_tts.txt && python3 download_model.py
```
Posterior a crear el contexto, para levantar un enrutador cruzado entre los puertos lógicos basta con otorgarle permisos de ejecución de sistema a tu `run.sh` inicial:
```bash
chmod +x run.sh
./run.sh
```

---

## 5. GESTIÓN Y PROTOCOLOS DE USUARIOS (EXTREMA IMPORTANCIA)

**Kiosco UI (Usuarios Públicos):** Está estrictamente prohibido introducir autenticación tipo Login, Oauth, o Base de Usuarios (Credentials) al frontend Flutter. El entorno es altamente concurrente para atención universitaria.
**Gestión Real Administrativa:** La verdadera administración de sistema está limitada al control de acceso de los mantenedores al servidor Ryzen subyacente. Únicamente se permite la inserción SSH mediante Llaves Asimétricas (Public/Private Keys RSA/Ed25519) desde el pool de administradores hacia el servidor backend. Las contraseñas de shell deben estar desactivadas o severamente rotadas.

---

## 6. ADMINISTRACIÓN DEL SISTEMA LOCAL

Los enrutadores de inferencia requieren mantenerse erguidos como Daemons a nivel del sistema Operativo (`systemd`).
*   **Puertos Centrales Vitales:**
    *   `8000`: Transacciones generativas FastAPI del RAG Central.
    *   `5001 / 5000`: Micros-Servidor Whisper Transcriptor & FastAPI PiperTTS.
*   **Reinicios Seguros:** Aplique los *Soft-Resets* usando los *services* del SO garantizando que el socket local de Ollama levante antes que los módulos de la aplicación.

---

## 7. BASE DE DATOS (CHROMA DB)

La retención contextual semántica yace incrustada dentro de colecciones de Chroma. 
*   **Ruta Vital de Vectores:** Se ubica localmente en las rutas como `ChromaVersions/Version3` de `IA Scapping`.
*   **Backups:** Las copias de seguridad de las extensiones `SQLite` internas de esta carpeta deben de empaquetarse en zip semanalmente antes de un `db_clean` masivo, pues encriptan toda respuesta institucional a la inferencia. 

---

## 8. DEFENSA Y SEGURIDAD

*   **Cortafuegos (UFW / Iptables):** Todos los puertos de red en los servidores deben estar por Default a `DENY`. Exclusivamente deben existir agujeros *Whitelist* para las IP Intranet estáticas que porta la Raspberry Pi para llegar de manera aislada al puerto `8000` y `5001`.
*   **Restricciones de Software Interfaz:** Los permisos del micrófono deben estar listados bajo perfiles autoritativos nativos ALSA, previendo secuestro del explorador. Se implementan políticas CORS irrestrictas localmente para el Web Socket entre el frontal y la máquina host de Python.

---

## 9. MONITOREO LOGÍSTICO Y EVENTUALIDADES

Use terminales segregadas o exportadores de recolección de metadatos apuntando a las salidas estándar y logs:
*   `backend.log`: Bitácora del motor RAG, crucial para revisar la traída indexada (similitud de scores) de `Chroma` a los prompts, y las mediciones `"Tiempo de Inferencia"`.
*   `whisper.log:` Análisis al milisegundo e interrupciones fonéticas del intérprete.

---

## 10. ACTUALIZACIONES CONTINUAS (ROLLING UPGRADES)

*   **Nuevas Voces:** Sustituir localmente modelos acústicos descargando binarios válidos `.onnx` configurando en manual el flag.
*   **LLMs Abiertos (Meta / Qwen):** `ollama rm llama3.1 && ollama pull llamaNuevo:8b` actualiza el cerebro sin tocar una sola línea de FastAPI.

---

## 11. SOLUCIÓN DE PROBLEMAS (TROUBLESHOOTING CRÍTICO)

A continuación el registro exacto de incidentes de excepción programados en núcleo ante caídas:

### Fallos De Frontera (Frontend Flutter y UI)
*   **`ERR_MIC_01`:** Sistema nativo denegó lectura del micrófono. -> *Validar listado de hardware Alsa Linux en la Raspberry.*
*   **`ERR_SYS_01`:** Puntero huérfano asíncrono o error gigante al renderizar menús UI. -> *Requiere refresco global o reinicio al gestor de pantalla táctil.*
*   **`ERR_NET_01`:** Alto latigazo local; la espera se rebotó debido a la lentitud de CPU. -> *Aumentar los Timeout settings o revisar picos de `htop`.*
*   **`ERR_API_01` y `ERR_WHP_01`:** Excepciones en FastAPI o servidor fonétizado (Rechazado HTTP/Socket). -> *Revisa caídas de Daemons, arranca `run.sh` o desbloquea UFW.*
*   **`ERR_PAR_01`:** Excepción local capturando un JSON malformado proveniente de respuesta Python. -> *Excepciones internas reventaron el modelo, inspecciona consola traceback de `whisper`.*
*   **`ERR_IMG_01` / `ERR_KEY_01` / `ERR_CTX_01`:** Sub-errores del componente UI en modales. -> *No se instanció imagen asset válida en YAML o se arruinó el `setState` interno lógico.*

### Fallos Estructurales Nucleares (Backend Python y RAG)
*   **`ERR_ADA_DB_01`:** Imposibilidad de instancia Lectura/Escritura dentro de la persistencia (Chroma DB). -> *Reevaluar permisos 777 UNIX carpeta `DB_DIR` y la corrupción del vector embebido.*
*   **`ERR_ADA_RAG_01`:** Chunk corrupto. El híbrido RAG recuperó texto sin sintaxis sana JSON. -> *El Backend omite el parseo y lee natural, se recomienda normalizar manual vía Scraper Python Script.*
*   **`ERR_ADA_LLM_01`:** El Socket generador del Engine Llama se ahogó tras la inyección. -> *Servicio Ollama asfixiado (OOM Killed). Reinicia brutalmente su servicio nativo `systemctl restart ollama`.*
*   **`ERR_ADA_SYS_01`:** Endpoint FastApi arrojó excepción general no manejada fuera del espectro. -> *Auditoría a los requests internos (`backend.log`) obligatoria.*
*   **`ERR_WHP_FILE` y `ERR_WHP_MODEL`:** Falla transicional del Audio nativo de C++. (Bytes corruptos detectados: Ej. Archivo resultante de 44 Bytes exactos) o motor inestable. -> *Librerías C están inyectando en punteros vacíos; asegúrate de manejar `tempfile` físico en vez de abstracciones virtuales del RAM.*
