#!/bin/bash
/usr/local/bin/docker-entrypoint.sh &

until curl -s -u "elastic:${ELASTIC_PASSWORD}" http://localhost:9200/_cluster/health | grep -q 'yellow\|green'; do
  sleep 2
done

curl -s -X POST -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/json' \
  http://localhost:9200/_security/user/kibana_system/_password \
  -d "{\"password\": \"${KIBANA_SYSTEM_PASSWORD}\"}"

wait
