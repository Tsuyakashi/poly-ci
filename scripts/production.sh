#!/bin/bash
(set -o posix; [ -f /usr/bin/dos2unix ] || (sudo apt-get update && sudo apt-get install -y dos2unix)) && dos2unix "$0"

# Install Docker    
echo "Installing docker & docker compose plugin"
if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get update &>/dev/null && \
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-v2 &>/dev/null
fi

echo "Auth system docker with private gitlab repo"
echo "$REGISTRY_PASSWORD" | sudo docker login registry.gitlab.com -u "$REGISTRY_USER" --password-stdin

# sudo tee /etc/docker/daemon.json > /dev/null <<EOF
# {
#     "insecure-registries": ["192.168.56.10:5000"]
# }
# EOF
# sudo systemctl restart docker

cd /app

export BASE_REGISTRY REGISTRY_USER REGISTRY_PASSWORD WATCHTOWER_TOKEN

echo "Pulling docker images"
sudo -E docker compose pull &>/dev/null

echo "Running docker containers"
sudo -E docker compose up -d
