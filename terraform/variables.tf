variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "ecs_cpu" {
  description = "CPU units for ECS task (1024 = 1 vCPU)"
  type        = string
  default     = "1024"
}

variable "ecs_memory" {
  description = "Memory for ECS task in MB"
  type        = string
  default     = "2048"
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "default_providers" {
  description = "Comma-separated list of default RTMP provider URLs"
  type        = string
  default     = ""
}
