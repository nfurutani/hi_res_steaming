#!/bin/bash

# Hi-Res Radio Streaming Server Start Script

echo "🎵 Starting Hi-Res Radio Streaming Server..."

# Check if programs directory exists
if [ ! -d "programs" ]; then
    echo "Creating programs directory..."
    mkdir programs
    echo "📁 Please add your FLAC files to the 'programs' directory"
fi

# Check if FLAC files exist
if [ -z "$(ls -A programs/*.flac 2>/dev/null)" ]; then
    echo "⚠️  No FLAC files found in programs directory"
    echo "Please add FLAC files to programs/ directory before starting"
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check dependencies
echo "Checking dependencies..."

if ! command_exists icecast; then
    echo "❌ Icecast not found. Install with: brew install icecast"
    exit 1
fi

if ! command_exists liquidsoap; then
    echo "❌ Liquidsoap not found. Install with: brew install liquidsoap"
    echo "Installing liquidsoap..."
    brew install liquidsoap
fi

if ! command_exists node; then
    echo "❌ Node.js not found. Install with: brew install node"
    exit 1
fi

echo "✅ All dependencies found"

# Kill existing processes
echo "Stopping existing processes..."
pkill -f "icecast"
pkill -f "liquidsoap"
pkill -f "server.js"

sleep 2

# Start Icecast
echo "🌐 Starting Icecast server..."
icecast -c icecast.xml &
ICECAST_PID=$!

sleep 3

# Start Liquidsoap
echo "🎵 Starting Liquidsoap streaming..."
liquidsoap streaming.liq &
LIQUIDSOAP_PID=$!

sleep 3

# Start Web Server
echo "🌍 Starting Web Server..."
node server.js &
WEB_PID=$!

# Wait a bit and check if everything is running
sleep 5

echo ""
echo "🎉 Hi-Res Radio is now streaming!"
echo ""
echo "📻 Stream URL: http://localhost:8000/stream.flac"
echo "🌍 Web Interface: http://localhost:3000"
echo "📊 Icecast Admin: http://localhost:8000/admin/"
echo ""
echo "Process IDs:"
echo "  Icecast: $ICECAST_PID"
echo "  Liquidsoap: $LIQUIDSOAP_PID" 
echo "  Web Server: $WEB_PID"
echo ""
echo "To stop all services, run: ./stop-streaming.sh"
echo "Or press Ctrl+C to stop this script and kill all processes"

# Wait for Ctrl+C
trap 'echo -e "\n🛑 Stopping all services..."; kill $ICECAST_PID $LIQUIDSOAP_PID $WEB_PID 2>/dev/null; exit 0' INT

# Keep script running
wait