terraform {
    required_providers {
        docker = {
            source = "kreuzwerker/docker"
            version = "~> 3.6.2"
        }
    }
}

provider "docker" {
    # Aktifkan baris bawah jika menggunakan Windows
    # host = "npipe:////.//pipe//docker_engine"
  
    # Aktifkan baris bawah jika menggunakan Mac/Linux
    # host = "unix:///var/run/docker.sock"
}

resource "docker_image" "nginx" {
    # name = "nginx"
    # Memanggil variabel nginx_version
    name = var.nginx_version
    keep_locally = false
}

resource "docker_container" "nginx" {
    image = docker_image.nginx.image_id
    # name = "tutorial"
    # Memanggil variabel container_name
    name  = var.container_name

    ports {
        internal = 80
        # external = 8000
        # Memanggil variabel external_port
        external = var.external_port
    }
}