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

cd /app

export BASE_REGISTRY REGISTRY_USER REGISTRY_PASSWORD WATCHTOWER_TOKEN

echo "Pulling docker images"
sudo -E docker compose pull &>/dev/null

echo "Running docker containers"
sudo -E docker compose up -d

echo "Waiting for Kibana..."
kibana_timeout=0
until curl -sf http://localhost/kibana/api/status | grep -q '"level":"available"'; do
  sleep 5
  if [ "$kibana_timeout" -lt 12 ]; then
    ((kibana_timeout += 1))
  else
    echo "Kibana didn't start in time"
    exit 1
  fi
done

for view in \
  'nginx-logs-view:nginx-logs-*:Nginx Logs' \
  'apps-logs-view:apps-logs-*:Apps Logs'
do
  id="${view%%:*}"; rest="${view#*:}"
  pattern="${rest%%:*}"; name="${rest##*:}"
  curl -sf -X POST "http://localhost/kibana/api/data_views/data_view" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d "{\"data_view\":{\"id\":\"${id}\",\"title\":\"${pattern}\",\"name\":\"${name}\",\"timeFieldName\":\"@timestamp\"},\"override\":true}" || true
done
