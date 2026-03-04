variable "container_name" {
  description = "Nama container Docker"
  type        = string
  default     = "Nginx-Server-Terraform"
}

variable "external_port" {
  description = "Port luar yang bisa diakses di browser"
  type        = number
  default     = 8080
}

variable "nginx_version" {
  description = "Versi image nginx yang ingin digunakan"
  type        = string
  default     = "nginx:latest"
}