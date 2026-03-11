# ============================================================
# OUTPUTS - These values are AUTO-GENERATED after 'terraform apply'
# Run 'terraform output' to see these values anytime
# NO CHANGES NEEDED in this file
# ============================================================
output "instance_public_ip" {
  description = "Public IP address of the Flask server"
  value       = aws_instance.flask_server.public_ip
  # Auto-populated - use this IP to connect
}
output "instance_public_dns" {
  description = "Public DNS of the Flask server"
}
  value       = aws_instance.flask_server.public_dns
output "flask_url" {
  description = "URL to access the Flask application"
  value       = "http://${aws_instance.flask_server.public_ip}:5000"
  # Copy this URL directly into your browser
}
output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_instance.flask_server.public_ip}"
  # Copy-paste this command to connect (update key path if different)
