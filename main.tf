terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~&gt; 5.0"
    }
  }
  required_version = "&gt;= 1.0"
}
provider "aws" {
  region = var.aws_region
}
# Fetch the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
# Fetch your current public IP address
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}
# Security Group
resource "aws_security_group" "flask_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for Flask application"
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }
  ingress {
    description = "Flask app"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = var.allowed_flask_cidrs
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
    cidr_blocks = ["0.0.0.0/0"]
  tags = {
    Name        = "${var.project_name}-sg"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
# Key Pair
resource "aws_key_pair" "flask_key" {
  key_name   = "${var.project_name}-key"
  public_key = file(var.public_key_path)
  tags = {
    Name      = "${var.project_name}-key"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}
# EC2 Instance
resource "aws_instance" "flask_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.flask_key.key_name
  vpc_security_group_ids = [aws_security_group.flask_sg.id]
  user_data              = file("userdata.sh")
  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }
  tags = {
    Name        = "${var.project_name}-server"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
