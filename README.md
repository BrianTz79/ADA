# Kiosco ADA

## Descripción del Proyecto
El proyecto Kiosco ADA consiste en un asistente virtual interactivo dotado de inteligencia artificial, diseñado específicamente para operar como un punto de información automatizado. Su propósito principal es brindar asistencia, resolver dudas y guiar a los usuarios de manera intuitiva y conversacional.

## Propósito y Objetivos
El objetivo fundamental del Kiosco ADA es facilitar el acceso a la información mediante una interfaz amigable y accesible, utilizando tecnologías de vanguardia en procesamiento de lenguaje natural y síntesis de voz. 

Los objetivos específicos incluyen:
- Proveer respuestas precisas y contextualizadas a las consultas de los usuarios.
- Implementar una comunicación natural a través de interacciones por voz (Speech-to-Text y Text-to-Speech).
- Desplegar una interfaz gráfica interactiva, fluida y con un diseño dinámico.
- Operar mediante una arquitectura modular y escalable que permita la ejecución simultánea y estable del sistema.

## Tecnologías Utilizadas
El desarrollo del proyecto integra diversas herramientas y frameworks de alto rendimiento:
- **Python**: Lenguaje de programación principal para la lógica de los servicios de inteligencia artificial.
- **Flutter**: Framework empleado para el desarrollo de la interfaz gráfica web (Frontend).
- **Whisper**: Tecnología utilizada para el reconocimiento automático de voz y transcripción (Speech-to-Text).
- **Piper TTS**: Sistema de síntesis de voz neuronal de baja latencia para la generación de audio a partir de texto (Text-to-Speech).
- **Bash/Shell Scripting**: Para la automatización del despliegue y control de los procesos de ejecución.

## Arquitectura de Microservicios
El sistema está estructurado en una arquitectura modular, componiéndose de cuatro microservicios principales que operan de forma interconectada:

1. **Microservicio Backend**: Encargado de procesar la lógica principal, gestionar el contexto de la conversación y generar las respuestas mediante el modelo de lenguaje artificial.
2. **Microservicio Whisper**: Responsable de capturar el audio emitido por el usuario en el entorno físico y transcribirlo a texto para que el sistema lo comprenda.
3. **Microservicio Piper**: Recibe el texto estructurado por el backend y lo convierte en audio sintetizado con voz humana, permitiendo que el kiosco responda verbalmente.
4. **Página / Interfaz Gráfica (Frontend)**: Aplicación web donde interactúa el usuario final, la cual integra los controles de micrófono, las animaciones visuales de estado y la visualización de los diálogos en tiempo real.

## Instrucciones de Ejecución
Para inicializar el proyecto y poner en marcha todos los microservicios de manera orquestada, se ha automatizado el proceso de arranque. 

Se debe ejecutar el script principal de inicialización en la raíz del proyecto. Este script de Bash invoca internamente un archivo de Python (`run.py`) que gestiona el inicio de todos los componentes de forma paralela:

```bash
./run.sh
```

Al ejecutar este comando, el sistema levantará automáticamente el Backend, Whisper, Piper y el servidor de la página web de Flutter. El mismo proceso mostrará los registros de actividad de cada microservicio en la consola y dejará el Kiosco ADA completamente operativo.
