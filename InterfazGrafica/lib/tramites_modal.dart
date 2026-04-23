import 'package:flutter/material.dart';

/// Estructura de datos que representa un trámite escolar.
/// 
/// Contiene la información necesaria para mostrar en la tarjeta de resumen
/// y en la vista detallada de los requisitos del trámite.
class Tramite {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final String detalle;

  Tramite({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.detalle,
  });
}

/// Ventana modal que muestra el catálogo de trámites disponibles.
/// 
/// Presenta una cuadrícula de tarjetas con los trámites más comunes.
/// Al seleccionar una tarjeta, se abre el detalle del trámite.
class TramitesModal extends StatelessWidget {
  TramitesModal({super.key});

  // 2. Base de datos simulada con la redacción mejorada
  final List<Tramite> listaTramites = [
    Tramite(
      titulo: 'Constancias Digitales',
      subtitulo: 'Descarga inmediata (Sencilla, Kardex, etc.)',
      icono: Icons.qr_code_2,
      detalle: 'Obtén constancias de forma inmediata las 24 horas en días hábiles.\n\n'
          'Tipos disponibles:\n'
          '• Sencilla\n'
          '• Con horario\n'
          '• Historial académico (Kardex)\n'
          '• Egresado\n'
          '• Reporte CONACYT\n\n'
          'Escanea el QR general o visita: constancias.tijuana.tecnm.mx',
    ),
    Tramite(
      titulo: 'Constancias Presenciales',
      subtitulo: 'Para VISA u otros formatos físicos',
      icono: Icons.document_scanner,
      detalle: 'Si necesitas una constancia física (ej. para trámite de VISA):\n\n'
          '1. Acude a Recursos Financieros (Unidad Tomás Aquino) y paga \$30 pesos.\n'
          '2. Lleva tu recibo a Servicios Escolares de tu unidad.\n\n'
          'Tiempo de entrega: 24 a 48 horas.\n'
          'Nota para VISA: Debes llevar una fotografía tamaño infantil.',
    ),
    Tramite(
      titulo: 'Seguro IMSS (Facultativo)',
      subtitulo: 'Afíliate gratis si eres alumno vigente',
      icono: Icons.local_hospital,
      detalle: 'Servicio exclusivo para alumnos inscritos que no cuenten con seguro médico por parte de padres, cónyuge o trabajo.\n\n'
          'El trámite tarda aprox. 72 horas hábiles tras tu solicitud.\n'
          'Nota: Los alumnos de primer semestre se afilian automáticamente si lo solicitaron en su inscripción.\n\n'
          '¡No esperes a que ocurra una emergencia, afíliate!',
    ),
    Tramite(
      titulo: 'Consulta de Kardex',
      subtitulo: 'Revisa tus calificaciones',
      icono: Icons.checklist,
      detalle: 'Existen dos formas de consultarlo:\n\n'
          '• Digital (Inmediato): Entra a sitec.tijuana.tecnm.mx. Si necesitas el documento para un trámite, descárgalo con código QR en la página de constancias.\n\n'
          '• Físico/Tradicional: Paga \$30 pesos en Recursos Financieros y solicítalo en Servicios Escolares. (Entrega de 24 a 48 horas).',
    ),
    Tramite(
      titulo: 'Credenciales',
      subtitulo: 'Física y digital',
      icono: Icons.badge,
      detalle: '• Credencial Digital: Se envía automáticamente a tu correo institucional (@tijuana.tecnm.mx).\n\n'
          '• Credencial Física: Se recoge en el Departamento de Servicios Escolares.\n\n'
          'En caso de extravío, deberás pagar la reposición en Recursos Financieros (Tomás Aquino) y llevar la solicitud a Servicios Escolares.',
    ),
    Tramite(
      titulo: 'Bajas Definitivas',
      subtitulo: 'Proceso de baja institucional',
      icono: Icons.exit_to_app,
      detalle: 'Para tramitar tu baja definitiva de la institución:\n\n'
          'Puedes acudir personalmente a la Unidad Tomás Aquino o enviar un correo electrónico institucional a: claudia.enriquez@tectijuana.edu.mx\n\n'
          'El tiempo de entrega varía tras la revisión de tu documentación.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Row(
        children: [
          Icon(Icons.folder_shared, color: Color(0xFF06B6D4)),
          SizedBox(width: 10),
          Text('Trámites y Procedimientos', style: TextStyle(color: Colors.black87)),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.7,
        // Usamos un GridView para mostrar las tarjetas en cuadrícula
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 450, // Ancho máximo de cada tarjeta
            childAspectRatio: 1.8, // Proporción ancho/alto
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
          ),
          itemCount: listaTramites.length,
          itemBuilder: (context, index) {
            final tramite = listaTramites[index];
            return Card(
              color: Colors.grey[100],
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  try {
                    _mostrarDetalleTramite(context, tramite);
                  } catch (e) {
                    /// [MANUAL_ERROR: ERR_CTX_01]
                    /// Descripción: Falla inminente al intentar levantar un modal informativo sobre los módulos UI.
                    /// Causa: Pérdida del identificador `BuildContext` original antes de invocar la animación de la ventana flotante AlertDialog.
                    /// Solución: Evitar reconstrucciones asíncronas no controladas y asegurar el uso de un NavigationKey estático.
                    debugPrint('ERR_CTX_01: $e');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Icon(tramite.icono, color: const Color(0xFF06B6D4), size: 30),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tramite.titulo,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              tramite.subtitulo,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 18)),
        ),
      ],
    );
  }

  /// Abre una ventana emergente con la información detallada y pasos a seguir
  /// del trámite seleccionado.
  void _mostrarDetalleTramite(BuildContext context, Tramite tramite) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF06B6D4), width: 2),
        ),
        title: Row(
          children: [
            Icon(tramite.icono, color: const Color(0xFF06B6D4), size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tramite.titulo,
                style: const TextStyle(color: Colors.black87, fontSize: 24),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            tramite.detalle,
            style: const TextStyle(color: Colors.black87, fontSize: 18, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Regresar', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 18)),
          ),
        ],
      ),
    );
  }
}