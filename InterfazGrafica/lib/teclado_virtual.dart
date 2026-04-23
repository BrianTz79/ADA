import 'package:flutter/material.dart';

/// Widget que renderiza un teclado virtual en pantalla.
/// 
/// Permite al usuario introducir texto en el sistema sin depender del teclado 
/// nativo del sistema operativo. Es ideal para pantallas táctiles de uso público 
/// donde se requiere una interfaz controlada y botones grandes.
class AdaVirtualKeyboard extends StatelessWidget {
  final Function(String) onKeyPressed;

  AdaVirtualKeyboard({super.key, required this.onKeyPressed});

  /// Define la estructura matricial de las teclas del teclado virtual (QWERTY).
  /// Contiene letras y teclas especiales como SPACE y BACKSPACE.
  final List<List<String>> keys = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ñ'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M', '?', 'BACKSPACE'],
    ['SPACE']
  ];

  @override
  Widget build(BuildContext context) {
    // Calculamos el ancho de la pantalla para que las teclas se adapten y sean muy grandes
    double screenWidth = MediaQuery.of(context).size.width;
    // Dividimos el 80% de la pantalla entre 11 para que quepan holgadamente 10 teclas
    double keyWidth = (screenWidth * 0.8) / 11; 
    double keyHeight = 80.0; // Hacemos las teclas mucho más altas (antes eran 50)

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 15.0), // Más separación vertical
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((keyLabel) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0), // Más separación horizontal
                child: _buildKey(keyLabel, keyWidth, keyHeight),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  /// Construye individualmente cada tecla visual.
  /// 
  /// Define los colores claros (Light Mode), bordes cian, tamaño y comportamiento 
  /// visual de la tecla al ser presionada para garantizar contraste en exteriores.
  Widget _buildKey(String label, double baseWidth, double baseHeight) {
    bool isSpecialKey = label == 'BACKSPACE' || label == 'SPACE';
    
    // Asignamos el ancho dependiendo de si es tecla normal, espacio o borrar
    double width = baseWidth;
    if (label == 'SPACE') width = baseWidth * 6; // Barra espaciadora muy ancha
    if (label == 'BACKSPACE') width = baseWidth * 1.5; // Botón de borrar un poco más ancho

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          try {
            onKeyPressed(label);
          } catch (e) {
            /// [MANUAL_ERROR: ERR_KEY_01]
            /// Descripción: Fallo crítico al registrar inserción desde el teclado táctil virtual.
            /// Causa: La función callback que maneja la inserción de texto arrojó una excepción no controlada en su lógica.
            /// Solución: Revisar las validaciones del estado (setState) en main.dart al invocar `onKeyPressed`.
            debugPrint("ERR_KEY_01: $e");
          }
        },
        borderRadius: BorderRadius.circular(12), // Bordes más redondeados
        child: Container(
          width: width,
          height: baseHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSpecialKey ? Colors.grey[300] : Colors.grey[100], // Fondo claro de alto contraste
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF06B6D4), width: 2), // Borde cian sin opacidad
            boxShadow: const [
              BoxShadow(
                color: Colors.black12, // Sombra suave adaptada al modo claro
                blurRadius: 6,
                offset: Offset(0, 4),
              )
            ]
          ),
          child: label == 'BACKSPACE'
              ? const Icon(Icons.backspace, color: Colors.black87, size: 32) // Icono oscuro
              : Text(
                  label == 'SPACE' ? 'ESPACIO' : label,
                  style: const TextStyle(
                    color: Colors.black87, // Texto oscuro para máxima legibilidad bajo el sol
                    fontSize: 28, // Letra gigante para accesibilidad
                    fontWeight: FontWeight.bold
                  ),
                ),
        ),
      ),
    );
  }
}