import 'package:flutter/material.dart';
import 'dart:async'; 
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'tramites_modal.dart';
import 'horarios_modal.dart';
import 'teclado_virtual.dart'; // <--- Importamos nuestro nuevo teclado accesible
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart'; // <--- Paquete para el Modo Tutorial

void main() {
  runApp(const AdaKioskApp());
}

/// Raíz de la aplicación Kiosco ADA.
/// 
/// Configura el tema principal de la aplicación.
class AdaKioskApp extends StatelessWidget {
  const AdaKioskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kiosco ADA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white, 
        primaryColor: const Color(0xFF06B6D4), 
        useMaterial3: true,
        fontFamily: 'Roboto', 
      ),
      home: const AdaMainScreen(),
    );
  }
}

/// Pantalla principal interactiva del Kiosco.
/// 
/// Contiene la interfaz principal donde el usuario interactúa por voz o mediante
/// los botones de acceso rápido a los diferentes servicios.
class AdaMainScreen extends StatefulWidget {
  const AdaMainScreen({super.key});

  @override
  State<AdaMainScreen> createState() => _AdaMainScreenState();
}

/// Fases del kiosco para animar el layout dinámico.
enum KioskPhase { idle, listening, thinking, speaking }

/// Estado de la pantalla principal que controla la interacción del usuario.
/// 
/// Maneja la lógica visual de escucha, idioma, subtítulos en tiempo real
/// y la presentación de todos los modales informativos.
class _AdaMainScreenState extends State<AdaMainScreen> {
  KioskPhase _currentPhase = KioskPhase.idle;

  bool _isEnglish = false; 
  String _subtitleText = "Toca el botón o di 'Hola ADA' para empezar...";
  
  /// Control de texto y autoscroll
  final ScrollController _scrollController = ScrollController();
  int _karaokeWordIndex = -1;

  final AudioRecorder _audioRecorder = AudioRecorder(); // Instancia para la captura de audio

  // Mantenemos getter por compatibilidad si es necesario, o lo usamos directamente.
  bool get _isActive => _currentPhase != KioskPhase.idle;
  
  /// Claves globales para identificar los elementos de la UI en el Tutorial.
  /// Estas claves son usadas por [tutorial_coach_mark] para saber exactamente
  /// dónde recortar el overlay oscuro y enfocar la vista.
  final GlobalKey _micKey = GlobalKey();
  final GlobalKey _keyboardKey = GlobalKey();
  final GlobalKey _mapKey = GlobalKey();
  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey _proceduresKey = GlobalKey();
  final GlobalKey _schedulesKey = GlobalKey();
  final GlobalKey _helpKey = GlobalKey();
  final GlobalKey _langKey = GlobalKey();
  final GlobalKey _textPanelKey = GlobalKey();

  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel(); 
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // --- MÉTODOS PARA EL BACKEND ---

  /// Transición Visual: La interfaz cambia al modo de escucha reactiva y los subtítulos inferiores en el centro comienzan a llenarse progresivamente con las palabras del usuario a medida que habla.
  void updateTranscript(String text) {
    setState(() {
      _currentPhase = KioskPhase.listening;
      _subtitleText = text;
    });
    _scrollToBottom();
  }

  /// Transición Visual: El micrófono flotante cambia su estado visual a "pensando", y la frase "Procesando..." o "Processing..." reemplaza los subtítulos en la parte inferior de la pantalla para indicar espera.
  void setThinkingPhase() {
    setState(() {
      _currentPhase = KioskPhase.thinking;
      _subtitleText = _isEnglish ? "Processing..." : "Procesando...";
    });
  }

  /// Transición Visual: El Panel de Texto Dinámico permanece abierto mientras un texto de grandes proporciones aparece gradualmente, iluminando de color Cian cada palabra recitada por ADA en tiempo real (efecto Karaoke).
  void playKaraokeWord(int index, String fullResponse) {
    setState(() {
      _currentPhase = KioskPhase.speaking;
      _subtitleText = fullResponse;
      _karaokeWordIndex = index;
    });
    _scrollToBottom();
  }

  /// Transición Visual: La lista de texto fluye hacia arriba suavemente mediante una animación de desplazamiento automático cada vez que el texto excede la altura visible inferior.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 50,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Transición Visual: Forma una estructura de tipografía donde las palabras habladas adquieren gran tamaño; la palabra activa resalta en Cian vibrante y peso Bold frente al resto del trazo negro.
  Widget _buildKaraokeText() {
    if (_currentPhase != KioskPhase.speaking) {
      return Text(
        _subtitleText,
        style: const TextStyle(
          fontSize: 36, // Tamaño accesible
          color: Colors.black87,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Efecto Karaoke
    List<String> words = _subtitleText.split(' ');
    List<TextSpan> spans = [];

    for (int i = 0; i < words.length; i++) {
      bool isHighlighted = i <= _karaokeWordIndex;
      spans.add(
        TextSpan(
          text: "${words[i]} ",
          style: TextStyle(
            fontSize: 42, // Texto de respuesta aún más grande
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            color: isHighlighted ? const Color(0xFF06B6D4) : Colors.black87,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  String get _formattedTime {
    return "${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}";
  }

  String get _formattedDate {
    return "${_currentTime.day.toString().padLeft(2, '0')}/${_currentTime.month.toString().padLeft(2, '0')}/${_currentTime.year}";
  }

  /// Inicia la grabación de audio al mantener presionado (Push-to-Talk)
  /// /// Este módulo está diseñado para correr localmente en el nodo Edge (Raspberry Pi).
  Future<void> _startRecording() async {
    if (await _audioRecorder.isRecording()) return;
    try {
      if (await _audioRecorder.hasPermission()) {
        setState(() {
          _currentPhase = KioskPhase.listening;
          _subtitleText = _isEnglish ? "Recording..." : "Grabando...";
        });
        _karaokeWordIndex = -1;

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: 'kiosco_recording.wav',
        );
      } else {
        /// [MANUAL_ERROR: ERR_MIC_01]
        /// Descripción: Falla al acceder al hardware del micrófono o falta de permisos.
        /// Causa: El sistema operativo o el navegador bloqueó el acceso al micrófono, o no hay hardware de audio detectado.
        /// Solución: Revisar los permisos de la aplicación o navegador, y verificar la conexión física del micrófono en la Raspberry Pi.
        setState(() {
          _currentPhase = KioskPhase.idle;
          _subtitleText = _isEnglish 
              ? "Sorry, I had a technical problem. Please try again. (Code: ERR_MIC_01)" 
              : "Lo siento, tuve un problema técnico. Por favor, intenta de nuevo. (Código: ERR_MIC_01)";
        });
      }
    } catch (e) {
      /// [MANUAL_ERROR: ERR_MIC_01]
      /// Descripción: Falla al acceder al hardware del micrófono o falta de permisos.
      /// Causa: Error interno al inicializar el objeto `_audioRecorder` o el dispositivo de audio.
      /// Solución: Reiniciar la aplicación y comprobar si `arecord` funciona en la Raspberry.
      setState(() {
        _currentPhase = KioskPhase.idle;
        _subtitleText = _isEnglish 
            ? "Sorry, I had a technical problem. Please try again. (Code: ERR_MIC_01)" 
            : "Lo siento, tuve un problema técnico. Por favor, intenta de nuevo. (Código: ERR_MIC_01)";
      });
    }
  }

  /// Detiene la grabación y envía el audio a Python (Push-to-Talk)
  /// /// Este módulo está diseñado para correr localmente en el nodo Edge (Raspberry Pi).
  Future<void> _stopRecording() async {
    if (!(await _audioRecorder.isRecording())) return;

    setState(() {
      _currentPhase = KioskPhase.thinking;
      _subtitleText = _isEnglish ? "Processing..." : "Procesando...";
    });

    final path = await _audioRecorder.stop();
    if (path != null) {
      try {
        final request = http.MultipartRequest('POST', Uri.parse('http://localhost:5000/transcribe'));
        if (kIsWeb) {
          final info = await http.get(Uri.parse(path));
          request.files.add(http.MultipartFile.fromBytes('audio', info.bodyBytes, filename: 'audio.wav'));
        } else {
          request.files.add(await http.MultipartFile.fromPath('audio', path));
        }

        final response = await request.send().timeout(const Duration(seconds: 20), onTimeout: () {
          throw Exception("ERR_NET_01");
        });
        
        if (response.statusCode == 200) {
          final resStr = await response.stream.bytesToString();
          var data;
          try {
            data = json.decode(resStr);
          } catch (e) {
            /// [MANUAL_ERROR: ERR_PAR_01]
            /// Descripción: Falla de lectura de datos. La respuesta del servidor no tiene un formato válido.
            /// Causa: El microservicio Whisper arrojó una excepción fatal o devolvió HTML/texto plano en lugar de JSON.
            /// Solución: Revisar logs en `whisper.log` para identificar excepciones de Python.
            setState(() {
              _currentPhase = KioskPhase.idle;
              _subtitleText = _isEnglish 
                  ? "Sorry, I had a technical problem. Please try again. (Code: ERR_PAR_01)" 
                  : "Lo siento, tuve un problema técnico. Por favor, intenta de nuevo. (Código: ERR_PAR_01)";
            });
            return;
          }
          final text = data['text'] ?? '';
          
          if (text.toString().trim().isNotEmpty) {
            _askAda(text); // Pasa lo transcrito a nuestro backend principal
          } else {
            // Guard Clause contra alucinaciones vacías
            setState(() {
              _currentPhase = KioskPhase.idle;
              _subtitleText = _isEnglish 
                  ? "Tap the button or say 'Hi ADA' to start..." 
                  : "Toca el botón o di 'Hola ADA' para empezar...";
            });
          }
        } else {
          /// [MANUAL_ERROR: ERR_WHP_01]
          /// Descripción: Falla de conexión con el microservicio Whisper (Timeout o Connection Refused).
          /// Causa: El servidor devolvió un código HTTP diferente de 200, indicando fallo en el procesamiento.
          /// Solución: Revisar los logs de la terminal de Whisper (`whisper.log`) para ver detalles del error interno.
          setState(() {
            _currentPhase = KioskPhase.idle;
            _subtitleText = _isEnglish 
                ? "Sorry, I had a technical problem. Please try again. (Code: ERR_WHP_01)" 
                : "Lo siento, tuve un problema técnico. Por favor, intenta de nuevo. (Código: ERR_WHP_01)";
          });
        }
      } catch (e) {
        if (e.toString().contains("ERR_NET_01") || e.toString().contains("TimeoutException")) {
          /// [MANUAL_ERROR: ERR_NET_01]
          /// Descripción: Falla de red por tiempo agotado (Timeout).
          /// Causa: El servidor tardó demasiado en responder a la carga de audio, posiblemente por sobrecarga en CPU.
          /// Solución: Revisar latencia de red y uso de procesador htop en la Raspberry Pi.
          setState(() {
            _currentPhase = KioskPhase.idle;
            _subtitleText = _isEnglish 
                ? "Sorry, I had a technical problem. Please try again. (Code: ERR_NET_01)" 
                : "Lo siento, tuve un problema técnico. Por favor, intenta de nuevo. (Código: ERR_NET_01)";
          });
        } else {
          /// [MANUAL_ERROR: ERR_WHP_01]
          /// Descripción: Falla de conexión con el microservicio Whisper (Timeout o Connection Refused).
          /// Causa: No se pudo establecer conexión de red (SocketException) con `localhost:5000`.
          /// Solución: Asegurarse de que el script de Whisper está corriendo activamente y el puerto 5000 está libre.
          setState(() {
            _currentPhase = KioskPhase.idle;
            _subtitleText = _isEnglish 
                ? "Sorry, I had a technical problem. Please try again. (Code: ERR_WHP_01)" 
                : "Lo siento, tuve un problema técnico. Por favor, intenta de nuevo. (Código: ERR_WHP_01)";
          });
        }
      }
    } else {
      setState(() {
         _currentPhase = KioskPhase.idle;
         _subtitleText = _isEnglish 
            ? "Tap the button or say 'Hi ADA' to start..." 
            : "Toca el botón o di 'Hola ADA' para empezar...";
      });
    }
  }

  /// Transición Visual: Toda la interfaz del kiosco (textos, modales, etiquetas y subtítulos activos) intercambia instantáneamente sus cadenas de caracteres de Español a Inglés (o viceversa) sin recargar la pantalla.
  void _toggleLanguage() {
    setState(() {
      _isEnglish = !_isEnglish;
      if (_currentPhase == KioskPhase.idle) {
         _subtitleText = _isEnglish 
            ? "Tap the button or say 'Hi ADA' to start..." 
            : "Toca el botón o di 'Hola ADA' para empezar...";
      } else {
         _subtitleText = _isEnglish 
            ? "Listening... How can I help you?" 
            : "Escuchando... ¿En qué te puedo ayudar?";
      }
    });
  }

  // --- MODO TUTORIAL (GUIDED TOUR) ---

  /// Transición Visual: El entorno de la aplicación se oscurece con una suave película negra con 80% de opacidad.
  /// Sucesivamente se recortan siluetas iluminadas sobre los botones principales.
  /// En simultáneo, emerge en primer plano una tarjeta blanca estilizada con bordes Cian describiendo interactividad.
  void _showTutorial() {
    final targets = [
      TargetFocus(
        identify: "micTarget",
        keyTarget: _micKey,
        alignSkip: Alignment.topRight,
        color: Colors.black,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTutorialCard(
                title: _isEnglish ? "Natural Interaction" : "Interacción Natural",
                description: _isEnglish 
                    ? "Tap here or say 'Hi ADA' to talk to the assistant naturally." 
                    : "Toca aquí o di 'Hola ADA' para hablar con el asistente de forma natural.",
                controller: controller,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "keyboardTarget",
        keyTarget: _keyboardKey,
        alignSkip: Alignment.topRight,
        color: Colors.black,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              /// [REF_IMAGEN_MANUAL: PASO_2_TECLADO_VIRTUAL]
              return _buildTutorialCard(
                title: _isEnglish ? "Virtual Keyboard" : "Teclado Virtual",
                description: _isEnglish 
                    ? "If it's too noisy, use this giant virtual keyboard to type your question." 
                    : "Si hay mucho ruido, usa este teclado virtual gigante para escribir tu pregunta.",
                controller: controller,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "mapTarget",
        keyTarget: _mapKey,
        alignSkip: Alignment.topRight,
        color: Colors.black,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              /// [REF_IMAGEN_MANUAL: PASO_3_MAPA_CAMPUS]
              return _buildTutorialCard(
                title: _isEnglish ? "Campus Map" : "Mapa del Campus",
                description: _isEnglish 
                    ? "Open an interactive map to find your classroom or building inside the campus." 
                    : "Abre un mapa interactivo para encontrar tu salón o edificio dentro de la Unidad Tomás Aquino.",
                controller: controller,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "calendarTarget",
        keyTarget: _calendarKey,
        alignSkip: Alignment.topRight,
        color: Colors.black,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              /// [REF_IMAGEN_MANUAL: PASO_4_CALENDARIO]
              return _buildTutorialCard(
                title: _isEnglish ? "Calendar" : "Calendario",
                description: _isEnglish 
                    ? "Check important dates for the semester, holidays, and evaluation periods." 
                    : "Consulta las fechas importantes del semestre, días inhábiles y periodos de evaluación.",
                controller: controller,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "proceduresTarget",
        keyTarget: _proceduresKey,
        alignSkip: Alignment.topRight,
        color: Colors.black,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              /// [REF_IMAGEN_MANUAL: PASO_5_TRAMITES]
              return _buildTutorialCard(
                title: _isEnglish ? "Procedures" : "Trámites",
                description: _isEnglish 
                    ? "Know the requirements for your procedures and scan QR codes directly with your phone." 
                    : "Conoce los requisitos para tus trámites y escanea los códigos QR directamente con tu celular.",
                controller: controller,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "schedulesTarget",
        keyTarget: _schedulesKey,
        alignSkip: Alignment.topRight,
        color: Colors.black,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              /// [REF_IMAGEN_MANUAL: PASO_6_HORARIOS]
              return _buildTutorialCard(
                title: _isEnglish ? "Schedules" : "Horarios",
                description: _isEnglish 
                    ? "Check the grid and class schedules organized by each major." 
                    : "Revisa la retícula y los horarios de materias organizados por cada ingeniería.",
                controller: controller,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "helpTarget",
        keyTarget: _helpKey,
        alignSkip: Alignment.topRight,
        color: Colors.black,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              /// [REF_IMAGEN_MANUAL: PASO_7_AYUDA]
              return _buildTutorialCard(
                title: _isEnglish ? "Help" : "Ayuda",
                description: _isEnglish 
                    ? "Information about the ADA system and the OuroCore development team." 
                    : "Información sobre el sistema ADA y el equipo desarrollador OuroCore.",
                controller: controller,
                onNextPressed: () {
                  /// Transición Visual: El orbe del micrófono se desliza hacia la esquina de la pantalla.
                  /// En simultáneo, un gran panel blanco alargado aparece desenrollandose desde la derecha
                  /// habilitando la pizarra de transcripción que será iluminada por el tutorial.
                  setState(() {
                    _currentPhase = KioskPhase.listening;
                  });
                  controller.next();
                },
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "textPanelTarget",
        keyTarget: _textPanelKey,
        alignSkip: Alignment.topRight,
        color: Colors.black,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.bottom, // <--- Forzamos Bottom para renderizar debajo del título pequeño
            builder: (context, controller) {
              /// [REF_IMAGEN_MANUAL: PASO_8_TRANSCRIPCION_DINAMICA]
              return SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildTutorialCard(
                        title: _isEnglish ? "Dynamic Transcript" : "Transcripción Dinámica",
                        description: _isEnglish 
                            ? "Here you will see your speech in real-time, and read ADA's response word by word as you hear it." 
                            : "Aquí podrás ver lo que dices en tiempo real, y leer la respuesta de ADA palabra por palabra mientras la escuchas.",
                        controller: controller,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "langTarget",
        keyTarget: _langKey,
        alignSkip: Alignment.topRight,
        color: Colors.black,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              /// [REF_IMAGEN_MANUAL: PASO_9_IDIOMA]
              return _buildTutorialCard(
                title: _isEnglish ? "Language Options" : "Opciones de Idioma",
                description: _isEnglish 
                    ? "Switch the entire interface and responses between Spanish and English." 
                    : "Cambia toda la interfaz y las respuestas entre Español e Inglés.",
                controller: controller,
                isLastStep: true,
              );
            },
          ),
        ],
      ),
    ];

    try {
      TutorialCoachMark(
        targets: targets,
        colorShadow: Colors.black54, // Capa semitransparente requerida
        textSkip: _isEnglish ? "SKIP" : "SALTAR",
        paddingFocus: 10,
        opacityShadow: 0.8,
        hideSkip: true, // Ocultamos el saltar por defecto para usar nuestros propios botones
        onFinish: () {
          /// Transición Visual: El velo oscuro desaparece y el sistema vuelve orgánicamente al diseño centrado.
          setState(() => _currentPhase = KioskPhase.idle);
        },
        onClickTarget: (target) {},
        onSkip: () {
          /// Transición Visual: La tarjeta flotante se esfuma y los componentes recuperan su posición inactiva original (idle).
          setState(() => _currentPhase = KioskPhase.idle);
          return true;
        },
      ).show(context: context);
    } catch (e) {
      /// [MANUAL_ERROR: ERR_SYS_01]
      /// Descripción: Falla crítica del sistema al levantar componentes flotantes masivos de la UI.
      /// Causa: Estado inesperado, variables corruptas en la matriz de widgets, o pérdida del árbol estructural.
      /// Solución: Este error requiere que el kiosco completo sea refrescado desde cero (Command+R o reiniciar app principal).
      setState(() {
        _currentPhase = KioskPhase.idle;
        _subtitleText = _isEnglish 
            ? "System error processing UI. (Code: ERR_SYS_01)" 
            : "Error de sistema al procesar UI. (Código: ERR_SYS_01)";
      });
    }
  }

  /// Transición Visual: Un pequeño domo o tarjeta interactiva surge suspendida cerca del elemento enfocado, 
  /// con un fuerte borde azul y títulos masivos que atrapan la atención sobre la zona oscura.
  Widget _buildTutorialCard({
    required String title,
    required String description,
    required TutorialCoachMarkController controller,
    bool isLastStep = false,
    VoidCallback? onNextPressed,
  }) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500), // Ancho máximo para accesibilidad táctil
        child: Container(
          padding: const EdgeInsets.all(30), // Padding más grande interior
          decoration: BoxDecoration(
            color: Colors.white, // Fondo blanco (Light mode)
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF06B6D4), width: 4), // Borde llamativo cian
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF06B6D4),
                  fontWeight: FontWeight.bold,
                  fontSize: 28, // Letras gigantes
                ),
              ),
              const SizedBox(height: 15),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 24, // Letras gigantes
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () => controller.skip(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30), // Botones Gigantes
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text(
                      _isEnglish ? "Skip" : "Cerrar",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: onNextPressed ?? () => controller.next(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30), // Botones Gigantes
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text(
                      isLastStep 
                        ? (_isEnglish ? "Finish" : "Finalizar")
                        : (_isEnglish ? "Next" : "Siguiente"),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CONEXIÓN BACKEND ---
  /// Envía la pregunta del usuario al servidor local y muestra la respuesta
  /// fluyendo en tiempo real en los subtítulos de la pantalla.
  Future<void> _askAda(String question) async {
    if (question.trim().isEmpty) return;

    setThinkingPhase();

    try {
      // Usamos Uri.base.host para detectar la IP del servidor real si entras de otro dispositivo
      String apiHost = Uri.base.host;
      if (apiHost.isEmpty) apiHost = '127.0.0.1';

      final request = http.Request('POST', Uri.parse('http://$apiHost:8000/chat'));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({'query': question});

      // Limpiamos el texto preparándonos para la cascada de letras
      setState(() {
        _currentPhase = KioskPhase.speaking;
        _subtitleText = "";
        _karaokeWordIndex = -1; // -1 significa que entra flujo nuevo
      });

      final response = await http.Client().send(request).timeout(const Duration(seconds: 40), onTimeout: () {
        throw Exception("ERR_NET_01");
      });

      if (response.statusCode == 200) {
        // Escuchamos la tubería de bytes en tiempo real
        response.stream.transform(utf8.decoder).listen((unPedacitoDeTexto) {
          setState(() {
            _subtitleText += unPedacitoDeTexto;
          });
          _scrollToBottom();
        }, onError: (error) {
          /// [MANUAL_ERROR: ERR_API_01]
          /// Descripción: Falla de conexión con el Backend principal (Ollama/RAG) durante el straming.
          /// Causa: El socket de respuesta en tiempo real fue abortado.
          /// Solución: Revisar la estabilidad de red y los logs del backend.
          setState(() {
            _currentPhase = KioskPhase.idle;
            _subtitleText = _isEnglish 
                ? "Sorry, I had a technical problem. Please try again. (Code: ERR_API_01)" 
                : "Lo siento, tuve un problema técnico. Por favor, intenta de nuevo. (Código: ERR_API_01)";
          });
        });
      } else {
        /// [MANUAL_ERROR: ERR_API_01]
        /// Descripción: Falla de conexión con el Backend principal (Ollama/RAG).
        /// Causa: El backend (puerto 8000) arrojó un código de error HTTP en la respuesta.
        /// Solución: Revisar `backend.log` para trazas de errores internos (ej. caída de Ollama).
        setState(() {
          _currentPhase = KioskPhase.idle;
          _subtitleText = _isEnglish 
              ? "Sorry, I had a technical problem. Please try again. (Code: ERR_API_01)" 
              : "Lo siento, tuve un problema técnico. Por favor, intenta de nuevo. (Código: ERR_API_01)";
        });
      }
    } catch (e) {
      if (e.toString().contains("ERR_NET_01") || e.toString().contains("TimeoutException")) {
        /// [MANUAL_ERROR: ERR_NET_01]
        /// Descripción: Falla de red por tiempo agotado (Timeout).
        /// Causa: El motor backend principal de ADA tardó demasiado en iniciar el streaming de la respuesta.
        /// Solución: Revisar cuellos de botella en Ollama y rendimiento de hardware.
        setState(() {
          _currentPhase = KioskPhase.idle;
          _subtitleText = _isEnglish 
              ? "Sorry, I had a technical problem. Please try again. (Code: ERR_NET_01)" 
              : "Lo siento, tuve un problema técnico. Por favor, intenta de nuevo. (Código: ERR_NET_01)";
        });
      } else {
        /// [MANUAL_ERROR: ERR_API_01]
        /// Descripción: Falla de conexión con el Backend principal (Ollama/RAG).
        /// Causa: Conexión de red rechazada, el servidor principal en el puerto 8000 no se está ejecutando.
        /// Solución: Iniciar el backend con el script respectivo o revisar firewall.
        setState(() {
          _currentPhase = KioskPhase.idle;
          _subtitleText = _isEnglish 
              ? "Sorry, I had a technical problem. Please try again. (Code: ERR_API_01)" 
              : "Lo siento, tuve un problema técnico. Por favor, intenta de nuevo. (Código: ERR_API_01)";
        });
      }
    }
  }

  // --- MODALES ---

  /// Transición Visual: El fondo se desvanece dejando protagonismo a una ventana masiva de bordes curvos
  /// que ocupa el 90% del monitor. Aparece un campo de texto gigante y teclas holográficas claras optimizadas para presión con el pulgar.
  void _showTecladoModal() {
    TextEditingController textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF06B6D4), width: 2),
            ),
            title: Row(
              children: [
                const Icon(Icons.keyboard, color: Color(0xFF06B6D4), size: 36),
                const SizedBox(width: 15),
                Text(
                  _isEnglish ? 'Type your question' : 'Escribe tu pregunta', 
                  style: const TextStyle(color: Colors.black87, fontSize: 26) // Título más grande
                ),
              ],
            ),
            content: SizedBox(
              // Hacemos el modal gigante (90% de la pantalla) para que el teclado luzca
              width: MediaQuery.of(context).size.width * 0.9, 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    readOnly: false, 
                    showCursor: true, 
                    style: const TextStyle(color: Colors.black87, fontSize: 32), // Letra de lo que escribe más grande
                    decoration: InputDecoration(
                      hintText: _isEnglish ? "E.g. Where is building 500?" : "Ej. ¿Dónde está el edificio 500?",
                      hintStyle: const TextStyle(color: Colors.black54),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20), // Campo de texto más "gordo"
                    ),
                  ),
                  const SizedBox(height: 30), // Más separación entre texto y teclado
                  
                  // AQUI MANDAMOS A LLAMAR A NUESTRO TECLADO EXTERNO
                  AdaVirtualKeyboard(
                    onKeyPressed: (key) {
                      setStateModal(() {
                        if (key == 'BACKSPACE') {
                          if (textController.text.isNotEmpty) {
                            textController.text = textController.text.substring(0, textController.text.length - 1);
                          }
                        } else if (key == 'SPACE') {
                          textController.text += ' ';
                        } else {
                          textController.text += key;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  _isEnglish ? 'Cancel' : 'Cancelar', 
                  style: const TextStyle(color: Colors.grey, fontSize: 22)
                ),
              ),
              const SizedBox(width: 20), // Separación entre botones
              ElevatedButton(
                onPressed: () {
                  String userQuery = textController.text;
                  Navigator.pop(context);
                  _askAda(userQuery); // Lanzamos la pregunta a FastAPI
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20), // Botón enviar más grande
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isEnglish ? 'Send' : 'Enviar', 
                  style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  /// Transición Visual: Interrumpe limpiamente la vista actual abriendo un popup de dimensiones épicas que 
  /// exhibe en alta definición la cartografía 2D arquitectónica del plantel.
  void _showMapaModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(_isEnglish ? 'Campus Map' : 'Mapa del Campus', style: const TextStyle(color: Colors.black87)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8, 
          height: MediaQuery.of(context).size.height * 0.6,
          child: InteractiveViewer(
            panEnabled: true, 
            minScale: 1.0,
            maxScale: 4.0, 
            child: Image.asset(
              'assets/mapa.jpg', 
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Center(child: Text("Error: Imagen no encontrada")),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isEnglish ? 'Close' : 'Cerrar', style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 18)),
          ),
        ],
      ),
    );
  }

  /// Transición Visual: Una pizarra fotográfica gigante sobrepone el lienzo con las fechas codificadas en colores.
  /// Incluye zoom interactivo deslizable y un botón prominente turquesa para cerrar ventana de inmediato.
  void _showCalendarioModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(_isEnglish ? 'Academic Calendar' : 'Calendario Académico', style: const TextStyle(color: Colors.black87)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8, 
          height: MediaQuery.of(context).size.height * 0.6,
          child: InteractiveViewer(
            panEnabled: true, 
            minScale: 1.0,
            maxScale: 4.0, 
            child: Image.asset(
              'assets/calendario.jpeg', 
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Center(child: Text("Error: Imagen de calendario no encontrada")),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isEnglish ? 'Close' : 'Cerrar', style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 18)),
          ),
        ],
      ),
    );
  }

  /// Transición Visual: Entra a primer plano una cascada de tarjetas modulares o un tablón que separa rigurosamente los procesos administrativos en lista.
  void _showTramitesModal() {
    showDialog(
      context: context,
      builder: (context) => TramitesModal(), 
    );
  }

  /// Transición Visual: Modifica el enfoque y expande un visualizador detallado subdividido por áreas de ingeniería.
  void _showHorariosModal() {
    showDialog(
      context: context,
      builder: (context) => HorariosModal(), 
    );
  }

  /// Transición Visual: Se centra sutilmente una discreta pero elegante tarjeta de presentación que da crédito a los autores.
  void _showAyudaModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF06B6D4)),
            const SizedBox(width: 10),
            Text(_isEnglish ? 'About the Project' : 'Acerca del Proyecto', style: const TextStyle(color: Colors.black87)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nombre del Proyecto:', style: TextStyle(color: Colors.black54, fontSize: 14)),
            Text('Kiosco ADA (Asistente Digital Académica)', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 15),
            Text('Desarrollado por el equipo:', style: TextStyle(color: Colors.black54, fontSize: 14)),
            Text('OuroCore', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 15),
            Text('Integrantes:', style: TextStyle(color: Colors.black54, fontSize: 14)),
            Text('• Andre Urrea\n• Brian Tellez', style: TextStyle(color: Colors.black87, fontSize: 18)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isEnglish ? 'Close' : 'Cerrar', style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 18)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- CABECERA ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school, color: Color(0xFF06B6D4), size: 40),
                      const SizedBox(width: 16),
                      const Text(
                        'ADA',
                        style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isEnglish ? '| Digital Academic Assistant' : '| Asistente Digital Académica',
                        style: const TextStyle(fontSize: 24, color: Colors.black54),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // --- BOTÓN DE TUTORIAL ---
                      IconButton(
                        onPressed: _showTutorial,
                        icon: const Icon(Icons.help_center, color: Color(0xFF06B6D4), size: 36),
                        tooltip: _isEnglish ? 'Tutorial' : 'Tutorial',
                      ),
                      const SizedBox(width: 15),

                      // --- SWITCH DE IDIOMA ---
                      GestureDetector(
                        key: _langKey,
                        onTap: _toggleLanguage,
                        child: Container(
                          width: 80,
                          height: 35,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: Stack(
                            children: [
                              AnimatedAlign(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                alignment: _isEnglish ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  width: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF06B6D4),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Center(
                                    child: Text(
                                      'ES',
                                      style: TextStyle(
                                        color: !_isEnglish ? Colors.white : Colors.black54,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      'EN',
                                      style: TextStyle(
                                        color: _isEnglish ? Colors.white : Colors.black54,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 30),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formattedTime,
                            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          Text(
                            _formattedDate,
                            style: const TextStyle(fontSize: 24, color: Color(0xFF06B6D4)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              
              // --- ÁREA DINÁMICA (IDLE VS ACTIVO) ---
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // PANEL IZQUIERDO (Micrófono, Teclado, y Placeholder de Mascota)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      // Si está inactivo, no ocupa un ancho fijo extremo, se centra.
                      // Si está activo, ocupa un espacio reducido a la izquierda.
                      width: _isActive ? MediaQuery.of(context).size.width * 0.35 : MediaQuery.of(context).size.width * 0.5,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Placeholder de Mascota (Solo visible en Activo)
                          AnimatedOpacity(
                            opacity: _isActive ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 400),
                            child: _isActive 
                              ? Container(
                                  margin: const EdgeInsets.only(bottom: 30),
                                  width: 250,
                                  height: 250,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.grey[400]!, width: 2),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.image, size: 80, color: Colors.black26),
                                      SizedBox(height: 10),
                                      Text("Mascota Avatar", style: TextStyle(color: Colors.black38, fontSize: 18)),
                                      // /// TODO: Reemplazar con asset de mascota (GIF/Rive)
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                          ),

                          // Orbe del Micrófono
                          /// Se utiliza [Listener] en lugar de GestureDetector para evitar
                          /// la cancelación inmediata por "finger drift" en pantallas táctiles de kioscos.
                          Listener(
                            key: _micKey,
                            onPointerDown: (_) => _startRecording(),
                            onPointerUp: (_) => _stopRecording(),
                            onPointerCancel: (_) => _stopRecording(),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: _currentPhase == KioskPhase.listening ? 220 : 200,
                              width: _currentPhase == KioskPhase.listening ? 220 : 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentPhase == KioskPhase.listening 
                                    ? const Color(0xFF06B6D4).withOpacity(0.2) 
                                    : Colors.grey[200],
                                border: Border.all(
                                  color: _currentPhase == KioskPhase.listening ? const Color(0xFF06B6D4) : Colors.grey[400]!,
                                  width: _currentPhase == KioskPhase.listening ? 4 : 2,
                                ),
                                boxShadow: _currentPhase == KioskPhase.listening
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF06B6D4).withOpacity(0.3),
                                          blurRadius: 30,
                                          spreadRadius: 10,
                                        )
                                      ]
                                    : [],
                              ),
                              child: Icon(
                                Icons.mic,
                                size: 80,
                                color: _currentPhase == KioskPhase.listening ? const Color(0xFF06B6D4) : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          
                          // Botón de Teclado
                          TextButton.icon(
                            key: _keyboardKey,
                            onPressed: _showTecladoModal,
                            icon: const Icon(Icons.keyboard, color: Colors.black54, size: 30),
                            label: Text(
                              _isEnglish ? 'Type instead' : 'Escribir con teclado',
                              style: const TextStyle(color: Colors.black54, fontSize: 24, decoration: TextDecoration.underline),
                            ),
                          ),
                          
                          // Subtítulo pequeño cuando está inactivo (se oculta en Activo)
                          if (!_isActive) ...[
                            const SizedBox(height: 30),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(
                                _subtitleText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),

                    // PANEL DERECHO (Panel de Texto Avanzado - Solo visible en Activo)
                    if (_isActive)
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: _isActive ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 500),
                          child: Container(
                            margin: const EdgeInsets.only(left: 20, right: 20),
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: const Color(0xFF06B6D4), width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  key: _textPanelKey,
                                  children: [
                                    Icon(
                                      _currentPhase == KioskPhase.listening 
                                          ? Icons.hearing 
                                          : _currentPhase == KioskPhase.thinking 
                                              ? Icons.memory 
                                              : Icons.record_voice_over,
                                      color: const Color(0xFF06B6D4),
                                      size: 40,
                                    ),
                                    const SizedBox(width: 15),
                                    Text(
                                      _currentPhase == KioskPhase.listening 
                                          ? (_isEnglish ? "You said:" : "Tú dijiste:")
                                          : _currentPhase == KioskPhase.thinking 
                                              ? (_isEnglish ? "ADA is thinking..." : "ADA está pensando...")
                                              : (_isEnglish ? "ADA says:" : "ADA dice:"),
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_currentPhase == KioskPhase.thinking)
                                      const SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: CircularProgressIndicator(color: Color(0xFF06B6D4), strokeWidth: 3),
                                      ),
                                  ],
                                ),
                                const Divider(height: 40, thickness: 2),
                                Expanded(
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    child: _buildKaraokeText(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // --- BOTONES DE ACCIÓN RÁPIDA ---
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 20, 
                runSpacing: 20, 
                children: [
                  _buildQuickActionButton(Icons.map, _isEnglish ? "Campus Map" : "Mapa del Campus", _showMapaModal, key: _mapKey),
                  _buildQuickActionButton(Icons.calendar_today, _isEnglish ? "Calendar" : "Calendario", _showCalendarioModal, key: _calendarKey),
                  _buildQuickActionButton(Icons.document_scanner, _isEnglish ? "Procedures" : "Trámites", _showTramitesModal, key: _proceduresKey),
                  _buildQuickActionButton(Icons.calendar_month, _isEnglish ? "Schedules" : "Horarios", _showHorariosModal, key: _schedulesKey),
                  _buildQuickActionButton(Icons.help_outline, _isEnglish ? "Help" : "Ayuda", _showAyudaModal, key: _helpKey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye un botón de acción rápida con icono y texto.
  Widget _buildQuickActionButton(IconData icon, String label, VoidCallback onTap, {GlobalKey? key}) {
    return ElevatedButton.icon(
      key: key,
      onPressed: onTap,
      icon: Icon(icon, color: Colors.black87),
      label: Text(
        label,
        style: const TextStyle(fontSize: 24, color: Colors.black87),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[200], // Fondo claro invitable al toque
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.grey[300]!), // Borde claro
        ),
      ),
    );
  }
}