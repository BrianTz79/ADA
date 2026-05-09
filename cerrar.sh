#!/bin/bash

echo "Cerrando microservicios en los puertos 8000, 8080, 5000 y 5001..."

# Se obtienen los IDs de los procesos (PIDs) en los puertos indicados usando lsof -ti
PIDS=$(lsof -ti :8000,8080,5000,5001)

if [ -n "$PIDS" ]; then
    echo "PIDs encontrados: $PIDS"
    echo "Matando procesos..."
    
    # Se matan los procesos a la fuerza
    kill -9 $PIDS
    
    echo "✅ Procesos cerrados exitosamente."
else
    echo "⚠️ No se encontraron procesos corriendo en esos puertos."
fi
