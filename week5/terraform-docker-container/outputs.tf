output "container_id" {
  description = "ID dari container yang dibuat"
  value       = docker_container.nginx.id
}

output "web_url" {
  description = "URL untuk mengakses Nginx"
  value       = "http://localhost:${var.external_port}"
}