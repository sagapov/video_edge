#!/bin/bash
set -e

# Destroy AWS infrastructure

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Video Edge Service - Destroy AWS Infrastructure"
echo "================================================"
echo ""
echo "WARNING: This will destroy all AWS resources created by Terraform."
echo ""

read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cancelled"
    exit 0
fi

cd "$PROJECT_DIR/terraform"

# Empty ECR repository first
ECR_REPO_NAME=$(terraform output -raw ecr_repository_url | cut -d'/' -f2)
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "Emptying ECR repository..."
aws ecr batch-delete-image \
    --repository-name $ECR_REPO_NAME \
    --image-ids "$(aws ecr list-images --repository-name $ECR_REPO_NAME --query 'imageIds[*]' --output json)" \
    --region $AWS_REGION 2>/dev/null || true

echo "Destroying infrastructure..."
terraform destroy -auto-approve

echo "Done!"
