#!/bin/bash

# Determine the directory where the script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$BASE_DIR/ADA AI"
FRONTEND_DIR="$BASE_DIR/InterfazGrafica"

# Function to clean up background processes on exit
cleanup() {
    echo "Stopping backend server..."
    if [ -n "$BACKEND_PID" ]; then
        # Check if process is still running before killing
        if kill -0 $BACKEND_PID 2>/dev/null; then
            kill $BACKEND_PID
        fi
    fi
    echo "Servers stopped."
}

# Trap SIGINT (Ctrl+C), SIGTERM, and EXIT to run cleanup
trap cleanup SIGINT SIGTERM EXIT

# Start the Backend
echo "Starting backend server..."
cd "$BACKEND_DIR"
source venv/bin/activate
python3 Ada-Backend_implementation.py &
BACKEND_PID=$!

# Wait a few seconds for the backend to initialize
echo "Waiting for backend to start..."
sleep 5

# Start the Frontend
echo "Starting frontend server..."
cd "$FRONTEND_DIR"
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
