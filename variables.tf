variable "aws_region" {
  description = "The AWS region to create resources in."
  default     = "us-east-1" # Or your preferred region
}

variable "my_ip" {
  description = "Your public IP address for SSH access to the app server."
  type        = string
}

variable "key_pair_name" {
  description = "The name of your AWS EC2 Key Pair for SSH access to the app server."
  type        = string
}