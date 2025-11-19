output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.video_edge.id
}

output "public_ip" {
  description = "Public IP address (Elastic IP)"
  value       = aws_eip.video_edge.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to instance"
  value       = "ssh -i ~/.ssh/video-edge-key ec2-user@${aws_eip.video_edge.public_ip}"
}

output "rtmp_url" {
  description = "RTMP streaming URL"
  value       = "rtmp://${aws_eip.video_edge.public_ip}:1935/live/<stream-key>"
}

output "api_url" {
  description = "API URL"
  value       = "http://${aws_eip.video_edge.public_ip}:3000/api"
}

output "stats_url" {
  description = "Stats URL"
  value       = "http://${aws_eip.video_edge.public_ip}:8000"
}

output "instructions" {
  description = "Next steps"
  value       = <<-EOT

    EC2 Instance deployed successfully!

    Connection Information:
    ======================
    Public IP: ${aws_eip.video_edge.public_ip}
    SSH: ssh -i ~/.ssh/video-edge-key ec2-user@${aws_eip.video_edge.public_ip}

    Service Endpoints:
    ==================
    RTMP: rtmp://${aws_eip.video_edge.public_ip}:1935/live/<stream-key>
    API:  http://${aws_eip.video_edge.public_ip}:3000/api
    Stats: http://${aws_eip.video_edge.public_ip}:8000

    The service is being installed via cloud-init.
    It may take 5-10 minutes to complete.

    Check installation status:
    ssh -i ~/.ssh/video-edge-key ec2-user@${aws_eip.video_edge.public_ip} 'tail -f /var/log/cloud-init-output.log'

  EOT
}
