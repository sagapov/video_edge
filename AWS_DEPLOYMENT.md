# AWS Deployment Guide

Quick reference guide for deploying the Video Edge Service to AWS.

## Quick Start - ECS Deployment (Recommended)

```bash
# 1. Ensure prerequisites are met
aws --version
terraform --version
docker --version

# 2. Configure AWS credentials
aws configure

# 3. Run deployment script
./scripts/deploy-ecs.sh

# 4. Get your service IP
./scripts/get-service-ip.sh
```

That's it! Your service will be running at the displayed IP addresses.

## Quick Start - EC2 Deployment

```bash
# 1. Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/video-edge-key

# 2. Deploy infrastructure
cd terraform-ec2
terraform init
terraform apply -var="public_key_path=~/.ssh/video-edge-key.pub"

# 3. Copy source code to instance
INSTANCE_IP=$(terraform output -raw public_ip)
scp -i ~/.ssh/video-edge-key -r ../src ../package.json ../tsconfig.json ../Dockerfile ../docker-compose.yml ec2-user@$INSTANCE_IP:/opt/video-edge/

# 4. SSH and start service
ssh -i ~/.ssh/video-edge-key ec2-user@$INSTANCE_IP
cd /opt/video-edge
npm install
npm run build
docker-compose up -d
```

## Architecture Comparison

| Feature | ECS (Fargate) | EC2 |
|---------|---------------|-----|
| Setup Complexity | Low (fully automated) | Medium (requires code deployment) |
| Management | Fully managed | Self-managed |
| Scaling | Easy (change desired_count) | Manual (modify instance) |
| Cost (always-on) | ~$30-40/month | ~$30-35/month |
| SSH Access | No | Yes |
| Customization | Limited | Full control |
| Best For | Production, hands-off | Development, customization |

## Cost Breakdown

### ECS (Fargate)
- Fargate vCPU: 1 vCPU × $0.04048/hour × 730 hours = $29.55/month
- Fargate Memory: 2 GB × $0.004445/GB/hour × 730 hours = $6.49/month
- Data Transfer: Variable (first 100 GB free)
- ECR Storage: ~$0.10/month for Docker images
- **Total: ~$36-40/month**

### EC2 (t3.medium)
- Instance: $0.0416/hour × 730 hours = $30.37/month
- EBS Storage: 30 GB × $0.10/GB = $3.00/month
- Elastic IP: Free (while instance running)
- Data Transfer: Variable (first 100 GB free)
- **Total: ~$33-38/month**

## Regions

The default region is `us-east-1`. To use a different region:

```bash
# For ECS
cd terraform
terraform apply -var="aws_region=eu-west-1"

# For EC2
cd terraform-ec2
terraform apply -var="aws_region=eu-west-1"
```

## Security Considerations

### Network Security
- Security groups restrict access to necessary ports only
- RTMP (1935), API (3000), HTTP (8000) are publicly accessible
- Consider using CloudFront or API Gateway for the API endpoint
- Use VPN or IP whitelisting for administrative access

### Secrets Management
- Never commit streaming provider keys to Git
- Use AWS Secrets Manager or Systems Manager Parameter Store
- Configure providers via API after deployment
- Rotate keys regularly

### Recommended Security Enhancements

1. **Add HTTPS/TLS:**
   - Use Application Load Balancer with ACM certificate
   - Terminate SSL at the load balancer
   - Update security groups accordingly

2. **Restrict API Access:**
   - Add authentication to the API endpoints
   - Use API Gateway with API keys
   - Implement rate limiting

3. **Enable Monitoring:**
   - Set up CloudWatch alarms for CPU/memory
   - Create SNS topics for alerts
   - Enable VPC Flow Logs

4. **Backup Configuration:**
   - Export configurations regularly via API
   - Store in S3 or version control
   - Document provider URLs securely

## Troubleshooting

### ECS Task Not Starting

```bash
# Check task status
aws ecs describe-tasks --cluster video-edge-cluster --tasks $(aws ecs list-tasks --cluster video-edge-cluster --service-name video-edge-service --query 'taskArns[0]' --output text)

# View logs
aws logs tail /ecs/video-edge-service --follow

# Common issues:
# - Image not found: Push to ECR again
# - Resource limits: Increase CPU/memory in variables.tf
# - Network issues: Check security groups and VPC configuration
```

### EC2 Instance Not Accessible

```bash
# Check instance status
aws ec2 describe-instances --filters "Name=tag:Name,Values=video-edge-server"

# Check security group
aws ec2 describe-security-groups --filters "Name=group-name,Values=video-edge-sg"

# View user-data logs
ssh -i ~/.ssh/video-edge-key ec2-user@<ip> 'sudo tail -f /var/log/cloud-init-output.log'

# Common issues:
# - SSH key mismatch: Verify key path in terraform apply
# - Security group rules: Ensure port 22 is open from your IP
# - Instance not ready: Wait 5-10 minutes for cloud-init
```

### Streams Not Forwarding

```bash
# Check FFmpeg is installed
docker exec video-edge-service ffmpeg -version

# Check active streams via API
curl http://<ip>:3000/api/streams/active

# Check provider configuration
curl http://<ip>:3000/api/config

# View service logs
# ECS:
aws logs tail /ecs/video-edge-service --follow

# EC2:
ssh -i ~/.ssh/video-edge-key ec2-user@<ip>
docker-compose logs -f
```

## Scaling

### Horizontal Scaling (Multiple Instances)

For ECS:
```bash
# Update desired count
cd terraform
terraform apply -var="desired_count=3"
```

**Note:** Multiple instances require:
- Load balancer for API (not included by default)
- Sticky sessions for RTMP (complex setup)
- Consider using a separate load balancer for RTMP streams

### Vertical Scaling (More Resources)

For ECS:
```bash
cd terraform
terraform apply -var="ecs_cpu=2048" -var="ecs_memory=4096"
```

For EC2:
```bash
cd terraform-ec2
terraform apply -var="instance_type=t3.large"
```

## Updates and Maintenance

### Updating the Application

**ECS:**
```bash
# Build new image
docker build -t video-edge-service .
docker tag video-edge-service:latest <ecr-url>:latest
docker push <ecr-url>:latest

# Force deployment
aws ecs update-service --cluster video-edge-cluster --service video-edge-service --force-new-deployment
```

**EC2:**
```bash
# SSH to instance
ssh -i ~/.ssh/video-edge-key ec2-user@<ip>

# Update code
cd /opt/video-edge
git pull  # or copy new files

# Rebuild and restart
npm run build
docker-compose up -d --build
```

### Backup and Restore

```bash
# Export configuration
curl http://<ip>:3000/api/config > config-backup.json

# Restore configuration
# Parse JSON and use API to restore settings
cat config-backup.json | jq -r '.defaults[]' | while read url; do
  curl -X POST http://<ip>:3000/api/config/defaults -H "Content-Type: application/json" -d "{\"urls\":[\"$url\"]}"
done
```

## Support

For issues specific to:
- **AWS Infrastructure**: Check AWS documentation and CloudWatch logs
- **Application**: See main README.md
- **Terraform**: Refer to Terraform documentation
- **Networking**: Review VPC and Security Group configurations
