# Catálogo y Documentación de Códigos de Error (Kiosco ADA)

A continuación se detalla la red de excepciones diseñadas para evitar el quiebre de la interfaz general. Cada código se encarga de interceptar y devolver fluidamente el estado general a su inactividad (KioskPhase.idle) o denegar operaciones destructivas, y proporciona los datos suficientes para reparaciones técnicas.

---

## 1. Frontend (Flutter)

### Hardware y Sistema

*   **Código:** `ERR_MIC_01`
    *   **Descripción:** Falla al acceder u obtener permisos sobre el hardware del micrófono.
    *   **Causa:** El sistema operativo nativo o el navegador han bloqueado proactivamente el acceso al micrófono, o la placa/USB que provee el hardware de entrada digital no ha sido detectada.
    *   **Solución:** Navegar a la configuración maestra del quiosco para forzar permisos, o certificar la correcta alimentación energética y listado de drivers conectados mediante la terminal de Linux.
    *   **Catálogo:** Manual de Administrador / Técnico. (El usuario verá: *"Tuvimos un problema con el Micrófono"*).

*   **Código:** `ERR_SYS_01`
    *   **Descripción:** Falla crítica del sistema maestro en la interfaz al intentar proyectar árboles o ventanas de interfaz flotantes masivos (Overlay Tutorial).
    *   **Causa:** El "framework" topó con un estado inválido a razón de un puntero perdido en el árbol lógico de Widgets antes o durante la renderización animada y asíncrona.
    *   **Solución:** Éste es un error grave de núcleo y normalmente significa corrupción del árbol. Requiere recargar los servicios base (Soft Reboot de la terminal con CTRL+R o el Script Daemon).
    *   **Catálogo:** Manual de Administrador / Técnico.

### Red, Lógica y APIs 

*   **Código:** `ERR_NET_01`
    *   **Descripción:** Falla de latencia por tiempo extremadamente prolongado (*Timeout* > 15/40 SEGS).
    *   **Causa:** Ya sea el servidor RAG u Ollama generativo principal, o el transcriptor, no completaron ni el análisis ni la tubería de devolución dentro de un tiempo de vida humano saludable. Resulta regularmente de una memoria RAM estrangulada en procesos o lentitud en transacciones complejas.
    *   **Solución:** Analizar la curva de rendimiento y procesadores colmados a fin de determinar una subida de cuota límite. Re-ejecutar subrutinas si persiste.
    *   **Catálogo:** Manual de Administrador / Analista.

*   **Código:** `ERR_API_01`
    *   **Descripción:** Negociación colapsada con Backend nativo principal, afectando transacciones *LLM* estables.
    *   **Causa:** El flujo entre Flutter y el host de lógica `8000` ha arrojado una respuesta con estatus malformado HTTP distinto a "200 OK". Puede también deberse a que el *stream socket* es cortado prematuramente por firewalls o caída local.
    *   **Solución:** Vigilar trazas en bitácoras como `backend.log`. Activar interrupciones de seguridad si el modelo de red RAG arroja excepciones directas de base de datos o falló *Ollama*.
    *   **Catálogo:** Manual de Administrador.

*   **Código:** `ERR_WHP_01`
    *   **Descripción:** Falla de conexión a tubería Whisper (Connection Refused).
    *   **Causa:** La API asíncrona no fue detectada por Flutter al buscar en su terminal designada `localhost:5000`.
    *   **Solución:** Validar y re-instanciar el script de transcripción, o confirmar la inexistencia de puertos en uso.
    *   **Catálogo:** Manual de Administrador.

*   **Código:** `ERR_PAR_01`
    *   **Descripción:** Falla local de parseo de texto devuelto (JSON incomprensible o roto).
    *   **Causa:** Uno de los enrutadores en el entorno en Python capturó una excepción que desembocó en devolver un error en Texto Natural o HTML del propio de FastAPI, perdiendo la integridad de paquete a descifrar "json".
    *   **Solución:** Seguir los rastros de `whisper.log` donde un stacktrace claro evidenciará la anomalía del módulo en Python.
    *   **Catálogo:** Manual de Administrador / Analista de Soporte.

### Interfaz General e Interacciones UI

*   **Código:** `ERR_IMG_01`
    *   **Descripción:** Fallo de renderización de recursos visuales y componentes (Carrusel / Grid).
    *   **Causa:** El explorador de la aplicación intentó resolver una imagen interna en `assets` pero el nombre difiere del enlistado en `pubspec.yaml` u omite ser empaquetable (corrupto/no registrado).
    *   **Solución:** Revisar el esquema estricto de minúsculas e imágenes del recurso ausente y reparar metadatos o compilar nuevamente.
    *   **Catálogo:** Manual de Usuario Técnico / Administrador. (El usuario final percibe el error encapsulado y reportará no ver el documento al personal de biblioteca o mantenimiento).

*   **Código:** `ERR_KEY_01`
    *   **Descripción:** Fallo inminente al encadenar la inserción visual desde las teclas virtuales asíncronas de captura.
    *   **Causa:** Inconsistencia de los delegados que transportan los "Strings" entre pantallas y re-construyen agresivamente un estado o *Buffer*, ahogándose o intentando actuar en instancias desmanteladas.
    *   **Solución:** Comprobar logs locales de aplicación de interfaz y descartar desbordamiento intencional mediante la debida comprobación a largo plazo.
    *   **Catálogo:** Manual Técnico / Administrador.

*   **Código:** `ERR_CTX_01`
    *   **Descripción:** Suspensión instantánea de peticiones emergentes y modales flotantes (Ventana Trámites).
    *   **Causa:** Flutter pierde el ciclo de vida o rastro del plano activo (`context`) antes de concluir la operación que levantaba el modal decorado.
    *   **Solución:** Prevenir re-construcciones prematuras por capas estáticas forzadas del entorno táctil o *setState* sin protecciones.
    *   **Catálogo:** Manual de Administrador.

---

## 2. Backend (Microservicio Whisper en Python)

### Manipulación de Modelos y Datos en Local

*   **Código:** `ERR_WHP_FILE`
    *   **Descripción:** Manipulación corrompida, vacía, o alterada de Audio transitorio.
    *   **Causa:** Archivo o memoria de bloque recibida pero mutilada. Su longitud es de solo bytes minúsculos lo que dispara alertas de pre-cuestiones inoperantes en el disco local antes que ingrese al entorno. O denegación de espacio de disco duro en la host de la Raspberry Pi.
    *   **Solución:** Investigar a fondo permisos read/write de almacenamiento o liberar estrés probando archivos nativos simulados por cable para determinar corrupción natural o física.
    *   **Catálogo:** Manual de Administrador / Usuario Técnico. (El usuario notará que no detecta su voz sin sentido aparente).

*   **Código:** `ERR_WHP_MODEL`
    *   **Descripción:** Excepción interna extrema del sistema del motor conversor `faster-whisper`.
    *   **Causa:** Insuficiente RAM (Swaps) o estrangulación general de variables nativas al momento de interactuar con el Voice Activity Detector, cortando subitamente la librería binaria en CPU.
    *   **Solución:** Forzar un reingreso manual del servicio limitando estrictamente el modelo de datos.
    *   **Catálogo:** Manual de Administrador Experto.

---

## 3. Backend (ADA AI - Cerebro y RAG)

### Operaciones de Base de Datos y Generación LLM

*   **Código:** `ERR_ADA_DB_01`
    *   **Descripción:** Falla de lectura/escritura en ChromaDB o base vectorial.
    *   **Causa:** Base de índices corrupta o motor vectorial inalcanzable, imposibilitando la recuperación del contexto (`kiosco_docs`).
    *   **Solución:** Verificar si existe el directorio físico de la base de datos y sus permisos; de lo contrario, regenerar los índices con el Scraper RAG.
    *   **Catálogo:** Manual de Administrador.

*   **Código:** `ERR_ADA_RAG_01`
    *   **Descripción:** Falla al cargar/leer los documentos de contexto semántico extraídos.
    *   **Causa:** El texto almacenado o recuperado por el modelo híbrido no cumple con el esquema JSON esperado o está dañado en su sintaxis.
    *   **Solución:** Inspeccionar los chunks incrustados locales e invocar el proceso normalizador del RAG para limpiar los payloads.
    *   **Catálogo:** Manual de Administrador / Analista.

*   **Código:** `ERR_ADA_LLM_01`
    *   **Descripción:** Falla de respuesta de Ollama (timeout, modelo caído o generación abortada).
    *   **Causa:** El orquestador de Ollama procesando Llama3 colapsó por saturación de VRAM o el *stream socket* cortó la comunicación a la mitad.
    *   **Solución:** Monitorear `ollama serve` en la placa base y reiniciar el contenedor daemon nativo (`systemctl restart ollama`).
    *   **Catálogo:** Manual de Administrador Técnico.

*   **Código:** `ERR_ADA_SYS_01`
    *   **Descripción:** Falla crítica inesperada en el endpoint transaccional principal.
    *   **Causa:** El flujo global del enrutador de FastAPI fue interrumpido en crudo por referencias nulas, excepciones sin atrapar o el streaming principal estalló a nivel sistema.
    *   **Solución:** Reiniciar el backend local empleando el script principal de inicialización `./run.sh`.
    *   **Catálogo:** Manual de Administrador.
