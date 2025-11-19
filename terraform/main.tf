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

# VPC and Networking
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

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.video_edge.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "video-edge-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.video_edge.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "video-edge-public-b"
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

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "video_edge" {
  name        = "video-edge-sg"
  description = "Security group for video edge service"
  vpc_id      = aws_vpc.video_edge.id

  # RTMP ingress
  ingress {
    from_port   = 1935
    to_port     = 1935
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "RTMP"
  }

  # API ingress
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "API"
  }

  # HTTP ingress (node-media-server stats)
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP Stats"
  }

  # All outbound traffic
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

# ECR Repository
resource "aws_ecr_repository" "video_edge" {
  name                 = "video-edge-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "video-edge-service"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "video_edge" {
  name = "video-edge-cluster"

  tags = {
    Name = "video-edge-cluster"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "video_edge" {
  name              = "/ecs/video-edge-service"
  retention_in_days = 7

  tags = {
    Name = "video-edge-logs"
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "video-edge-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "video_edge" {
  family                   = "video-edge-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name  = "video-edge"
      image = "${aws_ecr_repository.video_edge.repository_url}:latest"

      portMappings = [
        {
          containerPort = 1935
          protocol      = "tcp"
        },
        {
          containerPort = 3000
          protocol      = "tcp"
        },
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "RTMP_PORT"
          value = "1935"
        },
        {
          name  = "API_PORT"
          value = "3000"
        },
        {
          name  = "HTTP_PORT"
          value = "8000"
        },
        {
          name  = "DEFAULT_PROVIDERS"
          value = var.default_providers
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.video_edge.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name = "video-edge-task"
  }
}

# ECS Service
resource "aws_ecs_service" "video_edge" {
  name            = "video-edge-service"
  cluster         = aws_ecs_cluster.video_edge.id
  task_definition = aws_ecs_task_definition.video_edge.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.video_edge.id]
    assign_public_ip = true
  }

  tags = {
    Name = "video-edge-service"
  }
}
