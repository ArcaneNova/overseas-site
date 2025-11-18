variable "aws_region" {
  default = "eu-north-1"
}

variable "ssh_public_key_path" {
  default = "~/.ssh/deploy-key.pub"
}

variable "my_ip_cidr" {
  default = "0.0.0.0/0"
  description = "Restrict SSH to your IP (e.g., 1.2.3.4/32)"
}

variable "app_instance_type" {
  default = "t3.medium"
}

variable "nagios_instance_type" {
  default = "t3.small"
}
