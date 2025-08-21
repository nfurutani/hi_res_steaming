#!/bin/bash

# Hi-Res Radio Docker Streaming Server

echo "🎵 Starting Hi-Res Radio with Docker..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if programs directory exists and has FLAC files
if [ ! -d "programs" ]; then
    echo "📁 Creating programs directory..."
    mkdir programs
fi

if [ -z "$(ls -A programs/*.flac 2>/dev/null)" ]; then
    echo "⚠️  No FLAC files found in programs directory"
    echo "Please add FLAC files to programs/ directory before starting"
    echo "Example: cp your_program.flac programs/"
    exit 1
fi

# Create logs directory if it doesn't exist
if [ ! -d "logs" ]; then
    echo "📁 Creating logs directory..."
    mkdir logs
fi

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose down 2>/dev/null

# Build and start containers
echo "🔨 Building Docker image..."
docker-compose build

echo "🚀 Starting containers..."
docker-compose up -d

# Wait for services to start
echo "⏳ Waiting for services to start..."
sleep 10

# Check if containers are running
echo "📊 Container status:"
docker-compose ps

# Display URLs
echo ""
echo "🎉 Hi-Res Radio is now streaming!"
echo ""
echo "📻 Stream URL: http://localhost:8000/stream.flac"
echo "🌍 Web Interface: http://localhost:3000"
echo "📊 Icecast Admin: http://localhost:8000/admin/ (admin/hackme)"
echo ""
echo "📋 Useful commands:"
echo "  View logs: docker-compose logs -f"
echo "  Stop all:  docker-compose down"
echo "  Restart:   docker-compose restart"
echo ""
echo "Press Ctrl+C to stop monitoring (containers will keep running)"

# Follow logs
trap 'echo "Monitoring stopped. Containers are still running."; exit 0' INT
docker-compose logs -f