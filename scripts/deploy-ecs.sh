#!/bin/bash
set -e

# Video Edge Service - AWS ECS Deployment Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPO_NAME="video-edge-service"

echo -e "${GREEN}Video Edge Service - AWS ECS Deployment${NC}"
echo "================================================"

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"

# Step 1: Initialize and apply Terraform
echo -e "\n${YELLOW}Step 1: Deploying infrastructure with Terraform${NC}"
cd "$PROJECT_DIR/terraform"

terraform init
terraform plan
read -p "Apply Terraform changes? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

terraform apply -auto-approve

# Get ECR repository URL
ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
echo "ECR Repository: $ECR_REPO_URL"

# Step 2: Build and push Docker image
echo -e "\n${YELLOW}Step 2: Building and pushing Docker image${NC}"
cd "$PROJECT_DIR"

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URL

# Build image
echo "Building Docker image..."
# Use --platform linux/amd64 for compatibility with ECS Fargate (required for Apple Silicon Macs)
docker build --platform linux/amd64 -t $ECR_REPO_NAME .

# Tag and push
echo "Tagging and pushing image..."
docker tag $ECR_REPO_NAME:latest $ECR_REPO_URL:latest
docker push $ECR_REPO_URL:latest

# Step 3: Force new deployment
echo -e "\n${YELLOW}Step 3: Deploying to ECS${NC}"
cd "$PROJECT_DIR/terraform"

ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
ECS_SERVICE=$(terraform output -raw ecs_service_name)

echo "Forcing new deployment..."
aws ecs update-service \
    --cluster $ECS_CLUSTER \
    --service $ECS_SERVICE \
    --force-new-deployment \
    --region $AWS_REGION

# Step 4: Get service endpoint
echo -e "\n${YELLOW}Step 4: Getting service endpoint${NC}"
echo "Waiting for task to start..."
sleep 30

TASK_ARN=$(aws ecs list-tasks \
    --cluster $ECS_CLUSTER \
    --service-name $ECS_SERVICE \
    --desired-status RUNNING \
    --query 'taskArns[0]' \
    --output text \
    --region $AWS_REGION)

if [ "$TASK_ARN" != "None" ] && [ ! -z "$TASK_ARN" ]; then
    ENI_ID=$(aws ecs describe-tasks \
        --cluster $ECS_CLUSTER \
        --tasks $TASK_ARN \
        --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
        --output text \
        --region $AWS_REGION)

    PUBLIC_IP=$(aws ec2 describe-network-interfaces \
        --network-interface-ids $ENI_ID \
        --query 'NetworkInterfaces[0].Association.PublicIp' \
        --output text \
        --region $AWS_REGION)

    echo -e "\n${GREEN}Deployment successful!${NC}"
    echo "================================================"
    echo "Service Endpoints:"
    echo "  RTMP: rtmp://$PUBLIC_IP:1935/live/<stream-key>"
    echo "  API:  http://$PUBLIC_IP:3000/api"
    echo "  Stats: http://$PUBLIC_IP:8000"
    echo ""
    echo "Example: Stream with OBS to rtmp://$PUBLIC_IP:1935/live with key 'mystream'"
else
    echo -e "${YELLOW}Task is starting... Run this script again to get the IP address${NC}"
fi

echo -e "\n${GREEN}Done!${NC}"
