output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.video_edge.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.video_edge.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.video_edge.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.video_edge.id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.video_edge.id
}

output "instructions" {
  description = "Next steps"
  value       = <<-EOT

    Deployment created successfully!

    Next steps:
    1. Build and push Docker image to ECR:
       aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.video_edge.repository_url}
       docker build -t video-edge-service .
       docker tag video-edge-service:latest ${aws_ecr_repository.video_edge.repository_url}:latest
       docker push ${aws_ecr_repository.video_edge.repository_url}:latest

    2. Get the public IP of your ECS task:
       aws ecs list-tasks --cluster ${aws_ecs_cluster.video_edge.name} --service-name ${aws_ecs_service.video_edge.name}
       aws ecs describe-tasks --cluster ${aws_ecs_cluster.video_edge.name} --tasks <task-arn>

    3. Access your service:
       RTMP: rtmp://<public-ip>:1935/live/<stream-key>
       API: http://<public-ip>:3000/api
       Stats: http://<public-ip>:8000

  EOT
}
