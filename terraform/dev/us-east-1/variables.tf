variable "aws_region" {
  type    = string
  default = "us-east-1"
  validation {
    condition     = contains(["us-east-1", "us-west-2"], var.aws_region)
    error_message = "The AWS region value must be one of: us-east-1, us-west-2."
  }
}

variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["DEV", "STG", "PRD"], var.environment)
    error_message = "The environment value must be one of: DEV, STG, or PRD."
  }
}

variable "project_name" {
  type    = string
  default = "devops-code-challenge"
}
