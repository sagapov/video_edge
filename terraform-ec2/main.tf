terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC and Networking (reusing same structure)
resource "aws_vpc" "video_edge" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "video-edge-vpc"
  }
}

resource "aws_internet_gateway" "video_edge" {
  vpc_id = aws_vpc.video_edge.id

  tags = {
    Name = "video-edge-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.video_edge.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "video-edge-public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.video_edge.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.video_edge.id
  }

  tags = {
    Name = "video-edge-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "video_edge" {
  name        = "video-edge-sg"
  description = "Security group for video edge service"
  vpc_id      = aws_vpc.video_edge.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  # RTMP
  ingress {
    from_port   = 1935
    to_port     = 1935
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "RTMP"
  }

  # API
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "API"
  }

  # HTTP Stats
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP Stats"
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "video-edge-sg"
  }
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "video-edge-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ecr" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "video-edge-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Key Pair (you'll need to create this manually or provide your own)
# Run: ssh-keygen -t rsa -b 4096 -f ~/.ssh/video-edge-key
# Then: terraform apply -var="public_key_path=~/.ssh/video-edge-key.pub"

resource "aws_key_pair" "video_edge" {
  key_name   = "video-edge-key"
  public_key = file(var.public_key_path)
}

# Latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# User data script
data "template_file" "user_data" {
  template = file("${path.module}/user-data.sh")

  vars = {
    default_providers = var.default_providers
  }
}

# EC2 Instance
resource "aws_instance" "video_edge" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.video_edge.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = aws_key_pair.video_edge.key_name

  user_data = data.template_file.user_data.rendered

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "video-edge-server"
  }
}

# Elastic IP for stable addressing
resource "aws_eip" "video_edge" {
  instance = aws_instance.video_edge.id
  domain   = "vpc"

  tags = {
    Name = "video-edge-eip"
  }
}
