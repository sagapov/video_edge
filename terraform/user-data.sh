#!/bin/bash
set -e

# Update system
yum update -y

# Install Docker
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Clone or download the application
mkdir -p /opt/video-edge
cd /opt/video-edge

# Create docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  video-edge:
    image: YOUR_ECR_REPO_URL:latest
    ports:
      - "1935:1935"
      - "3000:3000"
      - "8000:8000"
    environment:
      - RTMP_PORT=1935
      - API_PORT=3000
      - HTTP_PORT=8000
      - DEFAULT_PROVIDERS=${DEFAULT_PROVIDERS:-}
    restart: unless-stopped
EOF

# Login to ECR and start the service
# Note: Replace with your actual ECR repo and region
# aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ECR_REPO_URL
# docker-compose up -d

echo "Setup complete. Configure ECR credentials and start the service."
