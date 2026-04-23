import 'package:flutter/material.dart';

/// Estructura de datos que representa una Carrera académica.
/// 
/// Contiene el nombre, el icono representativo y la lista de rutas a las imágenes
/// que muestran los horarios de las materias de dicha carrera.
class Carrera {
  final String nombre;
  final IconData icono;
  final List<String> imagenesHorarios;

  Carrera({
    required this.nombre,
    required this.icono,
    this.imagenesHorarios = const [], // Por defecto está vacío
  });
}

/// Ventana modal interactiva que permite al usuario seleccionar su carrera y ver los horarios.
/// 
/// Presenta una cuadrícula de botones para cada carrera. Al seleccionar una,
/// despliega un carrusel de imágenes con los horarios correspondientes.
class HorariosModal extends StatelessWidget {
  HorariosModal({super.key});

  // 2. Base de datos de Carreras (Sistemas Computacionales primero)
  final List<Carrera> listaCarreras = [
    Carrera(
      nombre: 'Ing. en Sistemas Computacionales',
      icono: Icons.computer,
      imagenesHorarios: [
        'assets/Horarios/SistemasComputacionales/1.jpg',
        'assets/Horarios/SistemasComputacionales/2.jpg',
        'assets/Horarios/SistemasComputacionales/3.jpg',
        'assets/Horarios/SistemasComputacionales/4.jpg',
        'assets/Horarios/SistemasComputacionales/5.jpg',
        'assets/Horarios/SistemasComputacionales/6.jpg',
      ],
    ),
    Carrera(nombre: 'Arquitectura', icono: Icons.architecture),
    Carrera(nombre: 'Lic. en Administración', icono: Icons.business_center),
    Carrera(nombre: 'Contador Público', icono: Icons.account_balance_wallet),
    Carrera(nombre: 'Ing. Ambiental', icono: Icons.eco),
    Carrera(nombre: 'Ing. Biomédica', icono: Icons.medical_services),
    Carrera(nombre: 'Ing. Civil', icono: Icons.construction),
    Carrera(nombre: 'Ing. en Diseño Industrial', icono: Icons.design_services),
    Carrera(nombre: 'Ing. Electrónica', icono: Icons.memory),
    Carrera(nombre: 'Ing. en Gestión Empresarial', icono: Icons.trending_up),
    Carrera(nombre: 'Ing. en Logística', icono: Icons.local_shipping),
    Carrera(nombre: 'Ing. en Nanotecnología', icono: Icons.science),
    Carrera(nombre: 'Ing. Química', icono: Icons.science_outlined),
    Carrera(nombre: 'Ing. Aeronáutica', icono: Icons.flight_takeoff),
    Carrera(nombre: 'Ing. Bioquímica', icono: Icons.biotech),
    Carrera(nombre: 'Ing. Electromecánica', icono: Icons.electrical_services),
    Carrera(nombre: 'Ing. Informática', icono: Icons.data_object),
    Carrera(nombre: 'Ing. en Tecnologías de la Información y Comunicaciones', icono: Icons.router),
    Carrera(nombre: 'Ing. en Ciberseguridad', icono: Icons.security),
    Carrera(nombre: 'Ing. en Inteligencia Artificial', icono: Icons.smart_toy),
    Carrera(nombre: 'Ing. Industrial', icono: Icons.precision_manufacturing),
    Carrera(nombre: 'Ing. Mecánica', icono: Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Row(
        children: [
          Icon(Icons.calendar_month, color: Color(0xFF06B6D4)),
          SizedBox(width: 10),
          Text('Horarios por Carrera', style: TextStyle(color: Colors.black87)),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.7,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 450,
            childAspectRatio: 2.2, // Tarjetas más alargadas
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
          ),
          itemCount: listaCarreras.length,
          itemBuilder: (context, index) {
            final carrera = listaCarreras[index];
            return Card(
              color: Colors.grey[100],
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _abrirCarrusel(context, carrera),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      Icon(carrera.icono, color: const Color(0xFF06B6D4), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          carrera.nombre,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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

  /// Abre la vista detallada de los horarios de una carrera seleccionada.
  /// 
  /// Si la carrera no tiene horarios sincronizados, muestra un aviso.
  /// De lo contrario, abre el carrusel de imágenes de horarios.
  void _abrirCarrusel(BuildContext context, Carrera carrera) {
    if (carrera.imagenesHorarios.isEmpty) {
      // Si la carrera no tiene imágenes aún, mostramos un aviso
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(carrera.nombre, style: const TextStyle(color: Colors.black87)),
          content: const Text(
            'Los horarios para esta carrera aún no han sido sincronizados.\nPor favor, intenta más tarde.',
            style: TextStyle(color: Colors.black54, fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Regresar', style: TextStyle(color: Color(0xFF06B6D4))),
            ),
          ],
        ),
      );
    } else {
      // Si tiene imágenes, abrimos el carrusel interactivo
      showDialog(
        context: context,
        builder: (context) => CarruselHorariosDialog(carrera: carrera),
      );
    }
  }
}

/// Modal que actúa como un carrusel interactivo para navegar entre imágenes de horarios.
/// 
/// Permite deslizar las imágenes (Swipe) o usar botones de navegación.
/// Soporta zoom interactivo para ver los horarios a detalle.
class CarruselHorariosDialog extends StatefulWidget {
  final Carrera carrera;

  const CarruselHorariosDialog({super.key, required this.carrera});

  @override
  State<CarruselHorariosDialog> createState() => _CarruselHorariosDialogState();
}

class _CarruselHorariosDialogState extends State<CarruselHorariosDialog> {
  final PageController _pageController = PageController();
  int _paginaActual = 0;

  void _cambiarPagina(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF06B6D4), width: 2),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Horarios: ${widget.carrera.nombre}',
              style: const TextStyle(color: Colors.black87, fontSize: 22),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'Página ${_paginaActual + 1} de ${widget.carrera.imagenesHorarios.length}',
            style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 16),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.75,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // El visualizador deslizable (Swipe)
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _paginaActual = index;
                });
              },
              itemCount: widget.carrera.imagenesHorarios.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  panEnabled: true,
                  minScale: 1.0,
                  maxScale: 4.0, // Permite Zoom
                  child: Image.asset(
                    widget.carrera.imagenesHorarios[index],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text("Error al cargar la imagen", style: TextStyle(color: Colors.red)),
                    ),
                  ),
                );
              },
            ),

            // Flecha Izquierda
            if (_paginaActual > 0)
              Positioned(
                left: 10,
                child: IconButton(
                  iconSize: 50,
                  icon: const Icon(Icons.arrow_circle_left, color: Color(0xFF06B6D4)),
                  onPressed: () => _cambiarPagina(_paginaActual - 1),
                ),
              ),

            // Flecha Derecha
            if (_paginaActual < widget.carrera.imagenesHorarios.length - 1)
              Positioned(
                right: 10,
                child: IconButton(
                  iconSize: 50,
                  icon: const Icon(Icons.arrow_circle_right, color: Color(0xFF06B6D4)),
                  onPressed: () => _cambiarPagina(_paginaActual + 1),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar Horarios', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 18)),
        ),
      ],
    );
  }
}