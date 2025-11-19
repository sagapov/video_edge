# Video Edge Service

A simple RTMP video edge service that receives streams and forwards them to multiple streaming providers.

## Features

- **RTMP Ingestion**: Receive RTMP streams on a configurable port
- **Multi-Provider Forwarding**: Forward streams to multiple streaming platforms simultaneously
- **Per-Stream Configuration**: Configure different provider URLs for each stream
- **Default Fallback**: Use default providers when no stream-specific config exists
- **REST API**: Simple API to manage configurations dynamically
- **Zero Re-encoding**: Streams are copied without transcoding for minimal latency

## Requirements

- Node.js 18+
- FFmpeg installed on the system (required for stream forwarding)

## Installation

```bash
npm install
```

## Building

```bash
npm run build
```

## Running

### Development Mode

```bash
npm run dev
```

### Production Mode

```bash
npm run build
npm start
```

### Using Docker

```bash
# Build and run with docker-compose
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

Or build and run manually:

```bash
# Build image
docker build -t video-edge-service .

# Run container
docker run -d \
  -p 1935:1935 \
  -p 3000:3000 \
  -p 8000:8000 \
  --name video-edge \
  video-edge-service
```

## AWS Deployment

The service can be deployed to AWS using either ECS (Fargate) or EC2. Both options include complete Terraform configurations.

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Docker (for ECS deployment)

### Option 1: Deploy to AWS ECS (Fargate) - Recommended

ECS with Fargate provides a serverless container deployment with automatic scaling capabilities.

```bash
# Run the automated deployment script
./scripts/deploy-ecs.sh

# Or deploy manually:
cd terraform
terraform init
terraform apply

# Build and push Docker image
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url)
docker build -t video-edge-service .
docker tag video-edge-service:latest $(terraform output -raw ecr_repository_url):latest
docker push $(terraform output -raw ecr_repository_url):latest

# Force new deployment
aws ecs update-service --cluster $(terraform output -raw ecs_cluster_name) --service $(terraform output -raw ecs_service_name) --force-new-deployment

# Get the service public IP
./scripts/get-service-ip.sh
```

**ECS Configuration:**
- Default CPU: 1 vCPU (1024 units)
- Default Memory: 2 GB (2048 MB)
- Auto-scaling: Not configured by default (can be added)
- Cost: ~$30-40/month for a single task running 24/7

### Option 2: Deploy to AWS EC2

EC2 deployment provides more control and can be more cost-effective for always-on workloads.

```bash
# Generate SSH key pair first
ssh-keygen -t rsa -b 4096 -f ~/.ssh/video-edge-key

# Deploy infrastructure
cd terraform-ec2
terraform init
terraform apply -var="public_key_path=~/.ssh/video-edge-key.pub"

# Get connection info
terraform output
```

**EC2 Configuration:**
- Default Instance Type: t3.medium (2 vCPU, 4 GB RAM)
- Elastic IP: Included for stable addressing
- SSH Access: Enabled on port 22
- Cost: ~$30-35/month for t3.medium

After deployment, you'll need to deploy your application code:

```bash
# SSH to the instance
ssh -i ~/.ssh/video-edge-key ec2-user@<public-ip>

# Clone your repository or copy files
cd /opt/video-edge
# Copy your source code here

# Build and start with Docker
docker-compose up -d
```

### AWS Resources Created

Both deployment options create:
- VPC with public subnets
- Internet Gateway
- Security Groups (RTMP: 1935, API: 3000, HTTP: 8000)
- CloudWatch Logs (ECS only)
- ECR Repository (ECS only)

### Customizing the Deployment

Edit `terraform/variables.tf` or `terraform-ec2/variables.tf`:

```hcl
# For ECS
variable "ecs_cpu" {
  default = "2048"  # 2 vCPU
}

variable "ecs_memory" {
  default = "4096"  # 4 GB
}

# For EC2
variable "instance_type" {
  default = "t3.large"
}
```

### Destroying AWS Resources

```bash
# For ECS
./scripts/destroy-ecs.sh

# For EC2
cd terraform-ec2
terraform destroy

# Manual cleanup if needed
aws ecr delete-repository --repository-name video-edge-service --force
```

### Monitoring and Logs

**ECS:**
```bash
# View logs
aws logs tail /ecs/video-edge-service --follow

# Check service status
aws ecs describe-services --cluster video-edge-cluster --services video-edge-service
```

**EC2:**
```bash
# SSH to instance
ssh -i ~/.ssh/video-edge-key ec2-user@<public-ip>

# View application logs
docker-compose logs -f

# Check service status
docker-compose ps
```

## Configuration

### Environment Variables

- `RTMP_PORT`: RTMP server port (default: 1935)
- `HTTP_PORT`: HTTP server port (default: 8000)
- `API_PORT`: API server port (default: 3000)
- `DEFAULT_PROVIDERS`: Comma-separated list of default RTMP URLs

Example:

```bash
export RTMP_PORT=1935
export API_PORT=3000
export DEFAULT_PROVIDERS="rtmp://live.twitch.tv/app/your_key,rtmp://a.rtmp.youtube.com/live2/your_key"
npm start
```

## Usage

### Publishing Streams

Publish your RTMP stream to:

```
rtmp://localhost:1935/live/{streamKey}
```

Example with OBS Studio:
- Server: `rtmp://localhost:1935/live`
- Stream Key: `mystream`

Example with FFmpeg:

```bash
ffmpeg -re -i input.mp4 -c copy -f flv rtmp://localhost:1935/live/mystream
```

### REST API

#### Get API Documentation

```bash
curl http://localhost:3000/api
```

#### Set Default Providers

```bash
curl -X POST http://localhost:3000/api/config/defaults \
  -H "Content-Type: application/json" \
  -d '{
    "urls": [
      "rtmp://live.twitch.tv/app/YOUR_STREAM_KEY",
      "rtmp://a.rtmp.youtube.com/live2/YOUR_STREAM_KEY"
    ]
  }'
```

#### Get Default Providers

```bash
curl http://localhost:3000/api/config/defaults
```

#### Set Stream-Specific Providers

```bash
curl -X POST http://localhost:3000/api/config/streams/mystream \
  -H "Content-Type: application/json" \
  -d '{
    "urls": [
      "rtmp://live.twitch.tv/app/STREAM_KEY_1",
      "rtmp://live-api-s.facebook.com:80/rtmp/STREAM_KEY_2"
    ]
  }'
```

#### Get Stream Configuration

```bash
curl http://localhost:3000/api/config/streams/mystream
```

#### Delete Stream Configuration

```bash
curl -X DELETE http://localhost:3000/api/config/streams/mystream
```

#### Get All Configurations

```bash
curl http://localhost:3000/api/config
```

#### Get Active Streams

```bash
curl http://localhost:3000/api/streams/active
```

#### Stop a Stream

```bash
curl -X POST http://localhost:3000/api/streams/mystream/stop
```

## Example Workflow

1. **Start the service**:
   ```bash
   npm start
   ```

2. **Configure default providers** (optional):
   ```bash
   curl -X POST http://localhost:3000/api/config/defaults \
     -H "Content-Type: application/json" \
     -d '{"urls": ["rtmp://provider1.com/app/key1"]}'
   ```

3. **Configure stream-specific providers**:
   ```bash
   curl -X POST http://localhost:3000/api/config/streams/event1 \
     -H "Content-Type: application/json" \
     -d '{
       "urls": [
         "rtmp://live.twitch.tv/app/YOUR_KEY",
         "rtmp://a.rtmp.youtube.com/live2/YOUR_KEY"
       ]
     }'
   ```

4. **Start streaming** to `rtmp://localhost:1935/live/event1`

5. **Monitor active streams**:
   ```bash
   curl http://localhost:3000/api/streams/active
   ```

## Architecture

```
┌─────────────┐
│   RTMP      │
│  Publisher  │
│  (OBS, etc) │
└──────┬──────┘
       │
       │ RTMP Stream
       ▼
┌─────────────────┐
│  RTMP Server    │
│  (port 1935)    │
└────────┬────────┘
         │
         │ Triggers
         ▼
┌──────────────────┐      ┌──────────────────┐
│ Stream Forwarder │◄─────┤ Config Manager   │
│  (FFmpeg)        │      │                  │
└────────┬─────────┘      └────────▲─────────┘
         │                         │
         │ Forwards to             │ Managed by
         │ Multiple                │
         │ Providers               │
         ▼                         │
┌─────────────────┐         ┌──────────────┐
│  Provider 1     │         │  REST API    │
│  (Twitch, etc)  │         │ (port 3000)  │
├─────────────────┤         └──────────────┘
│  Provider 2     │
│  (YouTube, etc) │
├─────────────────┤
│  Provider N     │
└─────────────────┘
```

## Components

- **ConfigManager**: Manages default and per-stream provider configurations
- **RTMPServer**: Receives incoming RTMP streams
- **StreamForwarder**: Uses FFmpeg to forward streams to multiple providers
- **ApiServer**: Provides REST API for configuration management

## License

MIT
