# EC2 Deployment Option (Alternative to ECS)
# Uncomment this file if you prefer EC2 over ECS

# data "aws_ami" "amazon_linux_2" {
#   most_recent = true
#   owners      = ["amazon"]
#
#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#   }
# }

# resource "aws_instance" "video_edge" {
#   ami           = data.aws_ami.amazon_linux_2.id
#   instance_type = var.ec2_instance_type
#   subnet_id     = aws_subnet.public_a.id
#   vpc_security_group_ids = [aws_security_group.video_edge.id]
#
#   user_data = file("${path.module}/user-data.sh")
#
#   tags = {
#     Name = "video-edge-server"
#   }
# }
#
# output "ec2_public_ip" {
#   description = "EC2 instance public IP"
#   value       = aws_instance.video_edge.public_ip
# }
