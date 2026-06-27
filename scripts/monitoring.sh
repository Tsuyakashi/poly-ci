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

echo "Waiting for Kibana..."
kibana_timeout=0
until curl -sf http://localhost:5601/api/status | grep -q '"level":"available"'; do
  sleep 5
  if [ "$kibana_timeout" -ge 24 ]; then
    echo "Kibana didn't start in time"
    exit 1
  fi
  ((kibana_timeout += 1))
done

echo "Importing Kibana dashboards..."
curl -s -X POST "http://localhost:5601/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  --form file=@/app/configs/kibana/dashboards.ndjson
