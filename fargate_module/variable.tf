variable "aws_region" {}

variable "project_name" {}

variable "ecr_repository_url" {}

variable "container_desired_count" {}

variable "container_port" {}

variable "health_check_path" {
  default = "/"
}

