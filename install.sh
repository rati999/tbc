#!/bin/bash
 
# Function to check if Docker is installed
check_docker() {
  if ! command -v docker &> /dev/null
  then
    echo "Docker is not installed. Installing Docker..."
    install_docker
  else
    echo "Docker is already installed."
  fi
}
 
# Function to install Docker
install_docker() {
  echo "Updating package database..."
  sudo apt-get update -y
 
  echo "Installing necessary packages..."
  sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
 
  echo "Adding Docker’s official GPG key..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
 
  echo "Setting up the Docker stable repository..."
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
 
  echo "Updating package database again..."
  sudo apt-get update -y
 
  echo "Installing Docker Engine..."
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io
 
  echo "Starting Docker..."
  sudo systemctl start docker
 
  echo "Enabling Docker to start on boot..."
  sudo systemctl enable docker
 
  echo "Docker installed successfully."
}
 
# Function to prune the system
prune_system() {
  echo "Pruning the Docker system..."
  docker system prune -af --volumes
}
 
# Function to create Docker network
create_network() {
  echo "Creating Docker network..."
  docker network create monitoring-network
}
 
# Function to remove existing container
remove_container() {
  local container_name=$1
  if [ "$(docker ps -aq -f name=${container_name})" ]; then
    echo "Removing existing container: ${container_name}"
    docker rm -f ${container_name}
  fi
}
 
# Function to install and configure Prometheus
install_prometheus() {
  echo "Installing Prometheus..."
  mkdir -p /opt/prometheus
  cat <<EOF > /opt/prometheus/prometheus.yml
global:
  scrape_interval: 15s
 
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
 
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOF
 
  remove_container prometheus
 
  docker run -d --name prometheus \
    --network monitoring-network \
    -p 9090:9090 \
    -v /opt/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
    prom/prometheus
}
 
# Function to install and configure Node Exporter
install_node_exporter() {
  echo "Installing Node Exporter..."
 
  remove_container node-exporter
 
  docker run -d --name node-exporter \
    --network monitoring-network \
    -p 9100:9100 \
    prom/node-exporter
}
 
# Function to install and configure Alertmanager
install_alertmanager() {
  echo "Installing Alertmanager..."
  mkdir -p /opt/alertmanager
  cat <<EOF > /opt/alertmanager/alertmanager.yml
global:
  resolve_timeout: 5m
 
route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h
  receiver: 'webhook'
 
receivers:
- name: 'webhook'
  webhook_configs:
  - url: 'http://your-webhook-url'
EOF
 
  remove_container alertmanager
 
  docker run -d --name alertmanager \
    --network monitoring-network \
    -p 9093:9093 \
    -v /opt/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
    prom/alertmanager
}
 
# Function to install and configure WordPress
install_wordpress() {
  echo "Installing WordPress..."
 
  remove_container wordpress
 
  docker run -d --name wordpress \
    --network monitoring-network \
    -p 80:80 \
    -e WORDPRESS_DB_HOST=terraform-20240726011257722100000002.clcyocousbmq.eu-central-1.rds.amazonaws.com \
    -e WORDPRESS_DB_USER=admin \
    -e WORDPRESS_DB_PASSWORD=ratirati \
    -e WORDPRESS_DB_NAME=wordpress_db \
    wordpress
}
 
# Check Docker installation
check_docker
 
# Prune the system
prune_system
 
# Create Docker network
create_network
 
# Install Prometheus
install_prometheus
 
# Install Node Exporter
install_node_exporter
 
# Install Alertmanager
install_alertmanager
 
# Install WordPress
install_wordpress
 
echo "Installation and configuration complete!"
