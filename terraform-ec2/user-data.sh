#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting Video Edge Service installation..."

# Update system
yum update -y

# Install Docker
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Git and Node.js (for development)
yum install -y git
curl -sL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs

# Create application directory
mkdir -p /opt/video-edge
cd /opt/video-edge

# Clone or create the application files
cat > package.json <<'EOF'
{
  "name": "video-edge-service",
  "version": "1.0.0",
  "description": "RTMP video edge service with multi-provider forwarding",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "ts-node src/index.ts"
  },
  "dependencies": {
    "express": "^4.18.2",
    "fluent-ffmpeg": "^2.1.2",
    "node-media-server": "^2.6.3"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/fluent-ffmpeg": "^2.1.24",
    "@types/node": "^20.10.0",
    "ts-node": "^10.9.2",
    "typescript": "^5.3.3"
  }
}
EOF

cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "moduleResolution": "node"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF

# Install FFmpeg
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm || true
amazon-linux-extras install epel -y
yum-config-manager --enable epel || true
yum install -y ffmpeg || amazon-linux-extras install epel -y && yum install -y ffmpeg

# Create Dockerfile
cat > Dockerfile <<'EOF'
FROM node:20-alpine

RUN apk add --no-cache ffmpeg

WORKDIR /app

COPY package*.json ./
COPY tsconfig.json ./

RUN npm install

COPY src/ ./src/

RUN npm run build

EXPOSE 1935 3000 8000

CMD ["npm", "start"]
EOF

# Create docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  video-edge:
    build: .
    ports:
      - "1935:1935"
      - "3000:3000"
      - "8000:8000"
    environment:
      - RTMP_PORT=1935
      - API_PORT=3000
      - HTTP_PORT=8000
      - DEFAULT_PROVIDERS=${default_providers}
    restart: unless-stopped
    container_name: video-edge-service
EOF

# Note: The actual source code would need to be deployed separately
# This is a simplified version. In production, you would:
# 1. Pull from ECR, or
# 2. Clone from Git repository, or
# 3. Use an AMI with the code pre-installed

# For now, create a placeholder
mkdir -p src
cat > src/index.ts <<'EOF'
console.log("Video Edge Service - Please deploy source code");
console.log("See README.md for deployment instructions");
EOF

# Set proper permissions
chown -R ec2-user:ec2-user /opt/video-edge

echo "Installation complete!"
echo "Note: Source code needs to be deployed separately"
echo "See documentation for full deployment steps"
