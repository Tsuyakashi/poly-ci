#!/bin/bash
(set -o posix; [ -f /usr/bin/dos2unix ] || (sudo apt-get update && sudo apt-get install -y dos2unix)) && dos2unix "$0"

# Install Docker    
echo "Installing docker & docker compose plugin"
if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get update &>/dev/null && \
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-v2 &>/dev/null
fi

cd /app

export ELASTIC_PASSWORD KIBANA_SYSTEM_PASSWORD

echo "Pulling docker images"
sudo -E docker compose pull &>/dev/null

echo "Running docker containers"
sudo -E docker compose up -d
