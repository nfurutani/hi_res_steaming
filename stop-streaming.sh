#!/bin/bash

# Hi-Res Radio Streaming Server Stop Script

echo "🛑 Stopping Hi-Res Radio Streaming Server..."

# Kill all related processes
pkill -f "icecast"
pkill -f "liquidsoap"
pkill -f "server.js"

sleep 2

echo "✅ All streaming services stopped"