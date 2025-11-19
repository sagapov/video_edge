#!/bin/bash
set -e

# Get the public IP of the ECS service

AWS_REGION="${AWS_REGION:-us-east-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR/terraform"

if [ ! -f "terraform.tfstate" ]; then
    echo "Error: No terraform state found. Run deploy-ecs.sh first."
    exit 1
fi

ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
ECS_SERVICE=$(terraform output -raw ecs_service_name)

echo "Getting service information..."

TASK_ARN=$(aws ecs list-tasks \
    --cluster $ECS_CLUSTER \
    --service-name $ECS_SERVICE \
    --query 'taskArns[0]' \
    --output text \
    --region $AWS_REGION)

if [ "$TASK_ARN" = "None" ] || [ -z "$TASK_ARN" ]; then
    echo "No running tasks found"
    exit 1
fi

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

echo ""
echo "Service Endpoints:"
echo "  RTMP: rtmp://$PUBLIC_IP:1935/live/<stream-key>"
echo "  API:  http://$PUBLIC_IP:3000/api"
echo "  Stats: http://$PUBLIC_IP:8000"
echo ""
echo "Example: Stream with OBS to rtmp://$PUBLIC_IP:1935/live with key 'mystream'"
