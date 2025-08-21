#!/bin/bash

# Hi-Res Radio Docker Stop Script

echo "🛑 Stopping Hi-Res Radio Docker containers..."

# Stop and remove containers
docker-compose down

# Optional: Remove images (uncomment if needed)
# docker-compose down --rmi all

# Optional: Remove volumes (uncomment if needed)  
# docker-compose down -v

echo "✅ All containers stopped"