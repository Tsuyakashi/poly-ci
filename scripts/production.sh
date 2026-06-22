#!/bin/bash
(set -o posix; [ -f /usr/bin/dos2unix ] || (sudo apt-get update && sudo apt-get install -y dos2unix)) && dos2unix "$0"

# Install Docker    
if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get update && \
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-v2
fi

# Auth system docker with private gitlab repo
echo "$REGISTRY_PASSWORD" | sudo docker login registry.gitlab.com -u "$REGISTRY_USER" --password-stdin

cd /app

export BASE_REGISTRY REGISTRY_USER REGISTRY_PASSWORD WATCHTOWER_TOKEN

sudo -E docker compose up -d
