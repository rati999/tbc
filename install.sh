#!/bin/bash
set -e

# Update package repository
sudo apt-get update

# Install prerequisites
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Set up the Docker repository
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Update package repository again
sudo apt-get update

# Install Docker
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Enable and start Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Create Docker network
docker network create monitoring

# Install and configure Prometheus
mkdir -p /opt/prometheus
cat << EOF > /opt/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

rule_files:
  - 'alert.rules'

alerting:
  alertmanagers:
  - static_configs:
    - targets:
      - 'alertmanager:9093'
EOF

cat << EOF > /opt/prometheus/alert.rules
groups:
- name: example
  rules:
  - alert: HighCPUUsage
    expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 10
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: High CPU usage detected
      description: CPU usage is above 10% for 5 minutes
EOF

docker run -d \
    --name prometheus \
    --network monitoring \
    -p 9090:9090 \
    -v /opt/prometheus:/etc/prometheus \
    prom/prometheus

# Install and configure Alertmanager
mkdir -p /opt/alertmanager
cat << EOF > /opt/alertmanager/config.yml
route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h
  receiver: 'web.hook'
receivers:
- name: 'web.hook'
  webhook_configs:
  - url: 'http://127.0.0.1:5001/'
EOF

docker run -d \
    --name alertmanager \
    --network monitoring \
    -p 9093:9093 \
    -v /opt/alertmanager:/etc/alertmanager \
    prom/alertmanager

# Install Node Exporter
docker run -d \
    --name node-exporter \
    --network monitoring \
    --pid="host" \
    -v "/:/host:ro,rslave" \
    quay.io/prometheus/node-exporter \
    --path.rootfs=/host

# Install WordPress
docker run -d -p 80:80 \
  --name wordpress \
  --network monitoring \
  -e WORDPRESS_DB_HOST=terraform-20240725221607873200000001.clcyocousbmq.eu-central-1.rds.amazonaws.com \
  -e WORDPRESS_DB_USER=admin \
  -e WORDPRESS_DB_PASSWORD=ratirati \
  -e WORDPRESS_DB_NAME=wordpress_db \
  wordpress

echo "Installation completed successfully!"