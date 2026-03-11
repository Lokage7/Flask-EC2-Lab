# ============================================================
# VARIABLE DEFINITIONS
# Default values can be overridden in terraform.tfvars
# ============================================================
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"    # &lt;-- Override in terraform.tfvars
}
variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "grc-flask-lab"
}
variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "lab"
}
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"     # Keep for free tier eligibility
}
variable "public_key_path" {
  description = "Path to your SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"  # &lt;-- MUST CHANGE in terraform.tfvars
}
variable "allowed_flask_cidrs" {
  description = "CIDR blocks allowed to access Flask app"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Open to all - restrict in production
}
