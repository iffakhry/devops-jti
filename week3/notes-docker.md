# DOCKER

## Install Docker on Ubuntu Server
```bash
sudo apt install docker.io
```
Note: pastikan install berhasil dan kita sudah bisa menjalankan perintah `docker -v`

## Jika ada error (Permission Denied) ketika run docker di Ubuntu
```bash
sudo usermod -a -G docker ubuntu

# or

sudo chmod 777 /var/run/docker.sock
```

## Build Docker Image
```bash
docker build -t <nama-image>:<tag> .

# example
docker build -t beapi-images:latest .
```

## Show Image List
```bash
docker images

docker images list
```

## Delete Docker Image
```bash
docker rmi <image-id>
#or
docker rmi <image-name>

# example:
docker rmi beapi-images
```

## Create Docker Container
Note:
* -d digunakan agar app berjalan di background
* host-port : isi dengan port yang akan digunakan di dockernya
* container-port / app port: isi dengan port yang digunakan di app golang (di bagian e.Start())

```bash
docker run -d
-p <host-port>:<container-port>
-e <env-name>=<env-value>
-e <env-name>=<env-value>
-v <host-volume>:<container-volume>
--name <container-name> <image-name>:<tag>

# example:
docker run -p 80:80 --name beapiContainer beapi-images:latest

# example with env
docker run -d -p 80:80 -e JWT_KEY=blabla -e DBUSER=root -e DBPASS=abcdef -e DBHOST=10.10.20.30 -e DBPORT=3306 -e DBNAME=dbapi --name beapiContainer beapi-images:latest
```

## Show Container
```bash
# melihat container yang sedang running
docker ps

# melihat seluruh container, termasuk yang sedang stop
docker ps -a
```

## Start/Stop Container
```bash
docker stop <container-name>

docker start <container-name>
```

## Remove Docker Container
```bash
docker rm <container-name>

docker rm <container-id>

# untuk menghapus paksa container yang sedang berjalan
docker rm <container-name> --force

# example
docker rm beapiContainer
```

## Docker Logs Container
melihat logs dari container. berguna untuk tracing ketika terjadi error di aplikasi/container.
```bash
docker logs <container-name>
```

## Push Image to Docker Hub
```bash
docker login -u <username-dockerhub>

docker build -t <username-dockerhub>/<image-name>:<tag> .

docker push <username-dockerhub>/<image-name>
```

## Pull Image dari Container Registry
```bash
docker pull <image-name>
```

## Menjalankan MySQL diatas Docker
If you are using docker-desktop, the containers can access host os by using `host.docker.internal` name.

Otherwise, you can use default host IP address: `172.17.0.1`

```bash
# How to create and run mysql DB on container docker
docker run -p 3307:3306 \
-e MYSQL_ROOT_PASSWORD=rahasia \
-e MYSQL_DATABASE=altagormdb \
--name mysqldocker \
-d \
mysql
```

# Access/run command in a container
```bash
docker exec -it <container-name> <command>

#example
docker exec -it mysql bash
```

## Check IP Docker Container
referensi: https://stackoverflow.com/questions/17157721/how-to-get-a-docker-containers-ip-address-from-the-host

```bash
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' container_name_or_id
```

## Docker volume / Mounting
Agar supaya data tidak hilang walau container dihapus, kita harus pakai Docker Volume atau Bind Mount (bukan data di dalam container). sehingga ketika container dihapus, data akan tetap ada/tersimpan.

#### Cara 1: Bind Mount (pakai folder langsung)
 1. buat folder di pc. pastikan lokasi folder sudah sesuai 
 ```bash 
# example
~/workspases:> mkdir mysql-data
 ```
 2. buat container dengan menambahkan tag `-v`

 ```bash
# example: membuat container untuk menjalankan mysql.
# /var/lib/mysql adalah data dari mysql containernya (di container)
# /Users/fakhry/workspaces/mysql-data adalah lokasi nyata di pc kita

docker run -d \
  --name mysql-container \
  -e MYSQL_ROOT_PASSWORD=qwerty \
  -v /Users/fakhry/workspaces/mysql-data:/var/lib/mysql \
  -p 3306:3306 \
  mysql:8
 ```

#### Cara 2: Pakai Docker Volume 
1. buat volume dulu
```bash
docker volume create mysql_data

# lalu cek dengan perintah
docker volume ls
```

2. Buat container dengan menambahkan tag volume `-v`
```bash
docker run -d \
  --name mysql-container \
  -e MYSQL_ROOT_PASSWORD=qwerty \
  -v mysql_data:/var/lib/mysql \
  -p 3306:3306 \
  mysql:8

```

#### Cara 3: Pakai Docker Compose dengan menambahkan volume

1. buat file `docker-compose.yml`
```yaml
services:
  db:
    image: mysql:8
    container_name: mysql-container
    environment:
      MYSQL_ROOT_PASSWORD: qwerty
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  mysql_data:
```

2. jalankan docker compose
```bash
docker compose up -d
```

3. Jika ingin menghapus container
```bash
docker compose down
```
4. data tidak akan hilang. karena volume tidak terhapus (hanya containernya saja).

5. Jika ingin menghapus data/volume juga:
```bash
docker compose down -v
```

#### Check Volume
```bash
docker inspect mysql-container
# or
docker volume inspect mysql_data
```

#### notes:
Untuk development:
* Source code → bind mount
* Database → named volume
```bash
#example
volumes:
  - ./src:/var/www/html
  - db_data:/var/lib/mysql
```

## Istilah-istilah di Docker (analogi)
![Docker Architecture](./docker.jpg)