output "instance_public_ip" {
  description = "The public IP address of the EC2 instance for the .NET app."
  value       = aws_instance.app_server.public_ip
}