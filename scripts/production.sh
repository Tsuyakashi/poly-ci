#!/bin/bash
(set -o posix; [ -f /usr/bin/dos2unix ] || (sudo apt-get update && sudo apt-get install -y dos2unix)) && dos2unix "$0"

# Install Docker    
sudo DEBIAN_FRONTEND=noninteractive apt-get update && \
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io

# Auth system docker with private gitlab repo
echo "$REGISTRY_PASSWORD" | sudo docker login registry.gitlab.com -u "$REGISTRY_USER" --password-stdin

# Pull image from registry
sudo docker pull "$BASE_REGISTRY:python-latest" || echo "Warning: Python image is not ready in registry"
sudo docker pull "$BASE_REGISTRY:nodejs-latest" || echo "Warning: NodeJS image is not ready in registry"
sudo docker pull "$BASE_REGISTRY:go-latest" || echo "Warning: Go image is not ready in registry"

#  Run containers if images are ready
if sudo docker image inspect "$BASE_REGISTRY:python-latest" >/dev/null 2>&1; then
    sudo docker rm -f python-app 2>/dev/null || true
    sudo docker run -d \
    --name python-app \
    -p 8001:80 \
    --restart unless-stopped \
    "$BASE_REGISTRY:python-latest"
fi
if sudo docker image inspect "$BASE_REGISTRY:nodejs-latest" >/dev/null 2>&1; then
    sudo docker rm -f nodejs-app 2>/dev/null || true
    sudo docker run -d \
    --name nodejs-app \
    -p 8002:80 \
    --restart unless-stopped \
    "$BASE_REGISTRY:nodejs-latest"
fi
if sudo docker image inspect "$BASE_REGISTRY:go-latest" >/dev/null 2>&1; then
    sudo docker rm -f go-app 2>/dev/null || true
    sudo docker run -d \
    --name go-app \
    -p 8003:80 \
    --restart unless-stopped \
    "$BASE_REGISTRY:go-latest"
fi

# Remove old watchtower container if exists to avoid conflicts
sudo docker rm -f watchtower 2>/dev/null || true

# Configure watchtower
sudo docker run -d \
    --name watchtower \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -p 8080:8080 \
    --restart unless-stopped \
    -e REPO_USER="$REGISTRY_USER" \
    -e REPO_PASS="$REGISTRY_PASSWORD" \
    -e DOCKER_API_VERSION="1.44" \
    containrrr/watchtower \
    --interval 300 \
    --http-api-update \
    --http-api-token "$WATCHTOWER_TOKEN" \
    --cleanup
