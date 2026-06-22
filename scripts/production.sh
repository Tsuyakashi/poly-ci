#!/bin/bash
(set -o posix; [ -f /usr/bin/dos2unix ] || (sudo apt-get update && sudo apt-get install -y dos2unix)) && dos2unix "$0"

# Install Docker    
sudo DEBIAN_FRONTEND=noninteractive apt-get update && \
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io

# Auth system docker with private gitlab repo
echo "$REGISTRY_PASSWORD" | sudo docker login registry.gitlab.com -u "$REGISTRY_USER" --password-stdin

# Pull image from registry if ready
sudo docker pull "$BASE_REGISTRY:python-latest" || echo "Warning: Python image is not ready in registry"
sudo docker pull "$BASE_REGISTRY:nodejs-latest" || echo "Warning: NodeJS image is not ready in registry"
sudo docker pull "$BASE_REGISTRY:go-latest" || echo "Warning: Go image is not ready in registry"

cd /app

export BASE_REGISTRY REGISTRY_USER REGISTRY_PASSWORD WATCHTOWER_TOKEN

sudo -E docker compose up -d
