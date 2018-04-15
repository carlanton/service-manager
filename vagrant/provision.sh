#!/bin/bash

cat > /opt/services.json <<EOL
[
  {
    "name": "nginx",
    "address": "172.18.0.1:8000"
  }
]
EOL
systemctl daemon-reload


echo "[waiting for CouchDb]"
while true
do
  curl -sf http://127.0.0.1:5984/_up && break
  sleep 1
done

echo "[creating service database]"
curl -s -XPUT http://127.0.0.1:5984/services > /dev/null

echo "[creating service: nginx]"
curl -s -XPOST -H 'Content-Type: application/json' -d@- http://127.0.0.1:5984/services >/dev/null <<EOL
{
  "_id": "nginx",
  "port": 80,
  "health_check": "http",
  "image": "nginx:latest"
}
EOL

echo "[start service: nginx]"
systemctl start nginx@manager.service

curl -sI 172.18.0.1:8000

echo "[update service: nginx]"
curl -s http://127.0.0.1:5984/services/nginx |\
  jq '.environment = {TEST: "a"}' |\
  curl -s -H 'Content-Type: application/json' -d@- http://127.0.0.1:5984/services

