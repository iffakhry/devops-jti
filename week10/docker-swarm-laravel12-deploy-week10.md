# Deploy Laravel 12 dengan Docker Swarm

## Panduan Step-by-Step: 1 Manager + 1 Worker (Multipass)

> **Stack:** Laravel 12 · PHP 8.3 · Nginx · MySQL 8.0 · Docker Swarm · Multipass  
> **Topologi:** 2 VM Multipass (1 Manager + 1 Worker)

---

## Daftar Isi

1. [Gambaran Arsitektur](#1-gambaran-arsitektur)
2. [Persiapan VM dengan Multipass](#2-persiapan-vm-dengan-multipass)
3. [Install Docker di Semua Node](#3-install-docker-di-semua-node)
4. [Inisialisasi Docker Swarm](#4-inisialisasi-docker-swarm)
5. [Membuat Project Laravel 12](#5-membuat-project-laravel-12)
6. [Menulis Dockerfile](#6-menulis-dockerfile)
7. [Menulis docker-stack.yml](#7-menulis-docker-stackyml)
8. [Build dan Push Image ke Docker Hub](#8-build-dan-push-image-ke-docker-hub)
9. [Deploy Stack ke Swarm](#9-deploy-stack-ke-swarm)
10. [Verifikasi dan Akses Aplikasi](#10-verifikasi-dan-akses-aplikasi)
11. [Simulasi Rolling Update](#11-simulasi-rolling-update)
12. [Troubleshooting Umum](#12-troubleshooting-umum)

---

## 1. Gambaran Arsitektur

```
┌─────────────────────────────────────────────────────────┐
│                    HOST MACHINE                         │
│                  (Laptop/PC Anda)                       │
│                                                         │
│  ┌──────────────────────┐  ┌──────────────────────────┐ │
│  │   VM: swarm-manager  │  │    VM: swarm-worker      │ │
│  │   192.168.64.10      │  │    192.168.64.11         │ │
│  │                      │  │                          │ │
│  │  [Swarm Manager]     │  │  [Swarm Worker]          │ │
│  │                      │  │                          │ │
│  │  Service: laravel    │  │  Service: laravel        │ │
│  │  Service: nginx      │  │  (replica dari manager)  │ │
│  │  Service: mysql      │  │                          │ │
│  └──────────────────────┘  └──────────────────────────┘ │
│          │                           │                   │
│          └───────────────────────────┘                   │
│                Overlay Network                           │
│                (laravel_net)                             │
└─────────────────────────────────────────────────────────┘

Ingress: Port 80 → Nginx → PHP-FPM (Laravel 12) → MySQL
Replicas: laravel=2, nginx=2, mysql=1
```

**Penjelasan singkat:**

- **Manager Node** : otak Swarm — menerima perintah `docker stack deploy`, menjadwalkan task ke worker.
- **Worker Node** : menjalankan container sesuai instruksi manager.
- **Overlay Network** : jaringan virtual antar-node agar container di VM berbeda bisa saling berkomunikasi.
- **Docker Stack** : cara deploy multi-service di Swarm menggunakan file `docker-stack.yml` (mirip Compose, tapi untuk cluster).

---

## 2. Persiapan VM dengan Multipass

> Jalankan semua perintah ini di **HOST MACHINE** (laptop Anda).

### 2.1 Install Multipass

```bash
# macOS
brew install multipass

# Ubuntu/Linux
sudo snap install multipass
```

### 2.2 Buat VM Manager dan Worker

```bash
# Buat VM Manager (2 CPU, 2GB RAM, 10GB disk)
multipass launch --name swarm-manager --cpus 2 --memory 2G --disk 10G 22.04

# Buat VM Worker
multipass launch --name swarm-worker --cpus 2 --memory 2G --disk 10G 22.04
```

### 2.3 Cek IP Masing-masing VM

```bash
multipass list
```

Contoh output:

```
Name             State    IPv4             Image
swarm-manager    Running  192.168.64.10    Ubuntu 22.04 LTS
swarm-worker     Running  192.168.64.11    Ubuntu 22.04 LTS
```

> **Catat IP-nya** — akan digunakan di langkah selanjutnya.

---

## 3. Install Docker di Semua Node

> Jalankan langkah ini di **swarm-manager** dan **swarm-worker** (masing-masing).

Masuk ke VM:

```bash
# Masuk ke manager
multipass shell swarm-manager

# Atau masuk ke worker (buka terminal baru)
multipass shell swarm-worker
```

Install Docker menggunakan script resmi:

```bash
# Update package list
sudo apt-get update

# Install dependencies
sudo apt-get install -y ca-certificates curl gnupg

# Tambah Docker GPG key dan repository
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Tambah user ke group docker (agar tidak perlu sudo)
sudo usermod -aG docker $USER

# Aktifkan perubahan group (atau logout dan login ulang)
newgrp docker

# Verifikasi
docker --version
```

---

## 4. Inisialisasi Docker Swarm

### 4.1 Di swarm-manager — Init Swarm

```bash
# Ganti <MANAGER_IP> dengan IP swarm-manager Anda
docker swarm init --advertise-addr 192.168.64.10
```

Output yang muncul akan seperti ini:

```
Swarm initialized: current node (xxxxxxxxxxxx) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-xxxxxxxxxxxxxxxx-xxxxxxxxxxxxxxxx 192.168.64.10:2377
```

> **Salin perintah `docker swarm join ...`** — akan dipakai di worker.

### 4.2 Di swarm-worker — Join Swarm

```bash
# Tempel perintah join yang didapat dari output manager
docker swarm join --token SWMTKN-1-xxxxxxxxxxxxxxxx-xxxxxxxxxxxxxxxx 192.168.64.10:2377
```

Output:

```
This node joined a swarm as a worker.
```

### 4.3 Verifikasi (di swarm-manager)

```bash
docker node ls
```

Output yang diharapkan:

```
ID                            HOSTNAME        STATUS    AVAILABILITY   MANAGER STATUS
xxxxxxxxxxxx *                swarm-manager   Ready     Active         Leader
yyyyyyyyyyyy                  swarm-worker    Ready     Active
```

---

## 5. Membuat Project Laravel 12

> Lakukan di **HOST MACHINE** (laptop Anda), bukan di dalam VM.

### 5.1 Buat Project Laravel 12

```bash
# Pastikan Composer sudah terinstall di host
# Jika belum: https://getcomposer.org/download/

composer create-project laravel/laravel laravel-swarm-demo

cd laravel-swarm-demo
```

### 5.2 Buat Fitur Demo Sederhana

Kita buat satu endpoint sederhana agar ada sesuatu yang bisa didemonstrasikan.

**Buat Migration:**

```bash
php artisan make:migration create_messages_table
```

Edit file migration di `database/migrations/xxxx_create_messages_table.php`:

```php
public function up(): void
{
    Schema::create('messages', function (Blueprint $table) {
        $table->id();
        $table->string('content');
        $table->timestamps();
    });
}
```

**Buat Model dan Controller:**

```bash
php artisan make:model Message
php artisan make:controller MessageController
```

Edit `app/Http/Controllers/MessageController.php`:

```php
<?php

namespace App\Http\Controllers;

use App\Models\Message;
use Illuminate\Http\Request;

class MessageController extends Controller
{
    public function index()
    {
        $messages = Message::latest()->take(10)->get();
        $hostname = gethostname(); // tampilkan container ID untuk demo

        return response()->json([
            'status'    => 'ok',
            'app'       => 'Laravel 12 on Docker Swarm',
            'container' => $hostname,
            'messages'  => $messages,
        ]);
    }

    public function store(Request $request)
    {
        $request->validate(['content' => 'required|string|max:255']);

        $message = Message::create(['content' => $request->content]);

        return response()->json([
            'status'    => 'created',
            'container' => gethostname(),
            'message'   => $message,
        ], 201);
    }
}
```

Edit `app/Models/Message.php`:

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Message extends Model
{
    protected $fillable = ['content'];
}
```

Edit `routes/api.php`:

```php
<?php

use App\Http\Controllers\MessageController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn() => response()->json(['status' => 'ok']));
Route::apiResource('messages', MessageController::class)->only(['index', 'store']);
```

Edit `routes/web.php` — tambahkan route untuk root:

```php
Route::get('/', function () {
    return response()->json([
        'app'       => 'Laravel 12 Demo — Docker Swarm',
        'container' => gethostname(),
        'endpoints' => [
            'GET  /api/health'    => 'Health check',
            'GET  /api/messages'  => 'List messages',
            'POST /api/messages'  => 'Create message',
        ],
    ]);
});
```

### 5.3 Struktur Akhir Project

```
laravel-swarm-demo/
├── app/
│   ├── Http/Controllers/MessageController.php
│   └── Models/Message.php
├── database/migrations/
│   └── xxxx_create_messages_table.php
├── routes/
│   ├── api.php
│   └── web.php
├── docker/
│   ├── nginx/
│   │   └── default.conf       ← (dibuat di langkah 6)
│   └── php/
│       └── php.ini            ← (dibuat di langkah 6)
├── Dockerfile                  ← (dibuat di langkah 6)
└── docker-stack.yml            ← (dibuat di langkah 7)
```

---

## 6. Menulis Dockerfile

Buat file `Dockerfile` di root project:

```dockerfile
# ============================================================
# Stage 1: Composer Dependencies
# ============================================================
FROM composer:2.7 AS composer-stage

WORKDIR /app

# Copy hanya file dependency dulu (manfaatkan layer cache)
COPY composer.json composer.lock ./

RUN composer install \
    --no-dev \
    --no-interaction \
    --no-autoloader \
    --prefer-dist

# Copy source code lalu generate autoload
COPY . .
RUN composer dump-autoload --no-dev --optimize

# ============================================================
# Stage 2: Production Image
# ============================================================
FROM php:8.3-fpm-alpine

# Install ekstensi PHP yang dibutuhkan Laravel
RUN apk add --no-cache \
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    freetype-dev \
    libzip-dev \
    oniguruma-dev \
    icu-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mbstring \
        exif \
        pcntl \
        bcmath \
        gd \
        zip \
        intl \
        opcache

# Konfigurasi OPcache untuk produksi
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.revalidate_freq=0'; \
    echo 'opcache.validate_timestamps=0'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.memory_consumption=192'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.fast_shutdown=1'; \
} > /usr/local/etc/php/conf.d/opcache.ini

WORKDIR /var/www/html

# Copy aplikasi dari stage composer
COPY --from=composer-stage --chown=www-data:www-data /app .

# Buat direktori storage dan set permission
RUN mkdir -p storage/framework/{cache,sessions,views} \
             storage/logs \
             bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Expose port PHP-FPM
EXPOSE 9000

USER www-data

CMD ["php-fpm"]
```

**Buat konfigurasi Nginx** di `docker/nginx/default.conf`:

```nginx
server {
    listen 80;
    server_name _;
    root /var/www/html/public;
    index index.php;

    # Gzip compression
    gzip on;
    gzip_types text/plain application/json application/javascript text/css;

    # Log
    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass   app:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include        fastcgi_params;
        fastcgi_read_timeout 60;
    }

    location ~ /\.ht {
        deny all;
    }

    # Cache aset statis
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff2)$ {
        expires 1d;
        add_header Cache-Control "public";
    }
}
```

Buat file `.dockerignore` di root project:

```
.git
.github
node_modules
vendor
.env
.env.example
storage/logs/*
storage/framework/cache/*
storage/framework/sessions/*
storage/framework/views/*
docker-compose*.yml
*.md
tests/
```

---

## 7. Menulis docker-stack.yml

Buat file `docker-stack.yml` di root project:

```yaml
version: "3.9"

# ============================================================
# Networks
# ============================================================
networks:
  laravel_net:
    driver: overlay
    attachable: true # izinkan container satu-satunya untuk attach (debugging)

# ============================================================
# Volumes
# ============================================================
volumes:
  mysql_data:
    driver: local

# ============================================================
# Services
# ============================================================
services:
  # ----------------------------------------------------------
  # 1. MySQL Database
  # ----------------------------------------------------------
  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: laravel_db
      MYSQL_USER: laravel_user
      MYSQL_PASSWORD: laravel_password
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - laravel_net
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager # DB tetap di manager (demo sederhana)
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      update_config:
        parallelism: 1
        delay: 10s

  # ----------------------------------------------------------
  # 2. Laravel App (PHP-FPM)
  # ----------------------------------------------------------
  app:
    image: ${DOCKER_USERNAME}/laravel-swarm-demo:${APP_VERSION:-latest}
    environment:
      APP_NAME: "Laravel Swarm Demo"
      APP_ENV: production
      APP_DEBUG: "false"
      APP_KEY: ${APP_KEY}
      APP_URL: http://localhost

      DB_CONNECTION: mysql
      DB_HOST: db
      DB_PORT: 3306
      DB_DATABASE: laravel_db
      DB_USERNAME: laravel_user
      DB_PASSWORD: laravel_password

      CACHE_DRIVER: file
      SESSION_DRIVER: file
      QUEUE_CONNECTION: sync
      LOG_CHANNEL: stderr
      LOG_LEVEL: error
    networks:
      - laravel_net
    deploy:
      replicas: 2 # 2 replica tersebar di manager+worker
      update_config:
        parallelism: 1 # update 1 replica dulu
        delay: 15s # tunggu 15 detik sebelum lanjut
        failure_action: rollback # otomatis rollback jika gagal
        order: start-first # jalankan yang baru dulu, baru matikan yang lama
      rollback_config:
        parallelism: 1
        delay: 10s
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
        window: 120s
    depends_on:
      - db

  # ----------------------------------------------------------
  # 3. Nginx Web Server
  # ----------------------------------------------------------
  nginx:
    image: nginx:1.25-alpine
    ports:
      - target: 80
        published: 80
        mode: ingress # Swarm ingress load balancer (routing mesh)
    volumes:
      - type: bind
        source: ./docker/nginx/default.conf
        target: /etc/nginx/conf.d/default.conf
        read_only: true
    networks:
      - laravel_net
    deploy:
      replicas: 2
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
        order: start-first
      restart_policy:
        condition: on-failure
        delay: 3s
        max_attempts: 3
    depends_on:
      - app

  # ----------------------------------------------------------
  # 4. Laravel Migrator (one-shot task)
  # ----------------------------------------------------------
  migrator:
    image: ${DOCKER_USERNAME}/laravel-swarm-demo:${APP_VERSION:-latest}
    command: ["php", "artisan", "migrate", "--force"]
    environment:
      APP_KEY: ${APP_KEY}
      DB_CONNECTION: mysql
      DB_HOST: db
      DB_PORT: 3306
      DB_DATABASE: laravel_db
      DB_USERNAME: laravel_user
      DB_PASSWORD: laravel_password
    networks:
      - laravel_net
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        max_attempts: 5
        delay: 10s
      placement:
        constraints:
          - node.role == manager
    depends_on:
      - db
```

---

## 8. Build dan Push Image ke Docker Hub

> Lakukan di **HOST MACHINE**.

### 8.1 Login Docker Hub

```bash
docker login
# Masukkan username dan password Docker Hub Anda
```

### 8.2 Build Image

```bash
# Ganti YOUR_DOCKERHUB_USERNAME dengan username Docker Hub Anda
export DOCKER_USERNAME=your_dockerhub_username

# Build image
docker build -t ${DOCKER_USERNAME}/laravel-swarm-demo:1.0.0 .

# Tag juga sebagai latest
docker tag ${DOCKER_USERNAME}/laravel-swarm-demo:1.0.0 \
           ${DOCKER_USERNAME}/laravel-swarm-demo:latest
```

### 8.3 Push ke Docker Hub

```bash
docker push ${DOCKER_USERNAME}/laravel-swarm-demo:1.0.0
docker push ${DOCKER_USERNAME}/laravel-swarm-demo:latest
```

> **Mengapa push ke registry?**  
> Swarm worker tidak punya akses ke image yang hanya ada di host Anda. Image harus tersedia di registry publik (Docker Hub) agar semua node bisa pull.

---

## 9. Deploy Stack ke Swarm

### 9.1 Siapkan File .env untuk Stack

Di **swarm-manager**, buat file environment:

```bash
# Masuk ke manager
multipass shell swarm-manager

# Buat direktori project
mkdir -p ~/laravel-swarm-demo
cd ~/laravel-swarm-demo
```

Buat file `.env` di manager:

```bash
cat > .env << 'EOF'
DOCKER_USERNAME=your_dockerhub_username
APP_VERSION=1.0.0
APP_KEY=base64:GENERATE_THIS_KEY_BELOW
EOF
```

Generate APP_KEY:

```bash
# Di HOST MACHINE, di dalam folder project laravel
php artisan key:generate --show
# Salin output-nya, lalu paste ke .env di manager
```

### 9.2 Copy File ke Manager

```bash
# Dari HOST MACHINE, copy file yang dibutuhkan ke manager
multipass transfer docker-stack.yml swarm-manager:/home/ubuntu/laravel-swarm-demo/
multipass transfer -r docker/ swarm-manager:/home/ubuntu/laravel-swarm-demo/
```

### 9.3 Deploy Stack

```bash
# Di swarm-manager
cd ~/laravel-swarm-demo

# Load environment variables
export $(cat .env | xargs)

# Deploy stack dengan nama "laravel"
docker stack deploy \
  --with-registry-auth \
  --compose-file docker-stack.yml \
  laravel
```

Output:

```
Creating network laravel_laravel_net
Creating service laravel_db
Creating service laravel_app
Creating service laravel_nginx
Creating service laravel_migrator
```

### 9.4 Pantau Status Deployment

```bash
# Cek semua service dalam stack
docker stack services laravel

# Cek detail task/container yang berjalan
docker stack ps laravel

# Pantau service app secara real-time (Ctrl+C untuk berhenti)
watch docker service ps laravel_app
```

Tunggu hingga semua service menampilkan status `Running`. Contoh output `docker stack services laravel`:

```
ID             NAME              MODE         REPLICAS   IMAGE                                    PORTS
xxxxxxxxxxxx   laravel_app       replicated   2/2        your_user/laravel-swarm-demo:1.0.0
yyyyyyyyyyyy   laravel_db        replicated   1/1        mysql:8.0
zzzzzzzzzzzz   laravel_migrator  replicated   0/1        your_user/laravel-swarm-demo:1.0.0
wwwwwwwwwwww   laravel_nginx     replicated   2/2        nginx:1.25-alpine                        *:80->80/tcp
```

> Kolom `REPLICAS 2/2` artinya 2 dari 2 replica sudah berjalan.

---

## 10. Verifikasi dan Akses Aplikasi

### 10.1 Akses dari Browser

```bash
# Ambil IP manager
multipass info swarm-manager | grep IPv4
```

Buka browser dan akses:

- `http://192.168.64.10/` → halaman info aplikasi
- `http://192.168.64.10/api/health` → health check
- `http://192.168.64.10/api/messages` → list messages

### 10.2 Test dengan curl

```bash
# Test root endpoint
curl http://192.168.64.10/

# Test health check
curl http://192.168.64.10/api/health

# Tambah message baru
curl -X POST http://192.168.64.10/api/messages \
  -H "Content-Type: application/json" \
  -d '{"content": "Hello from Docker Swarm!"}'

# List messages
curl http://192.168.64.10/api/messages
```

### 10.3 Demonstrasi Load Balancing (Poin Demo Menarik!)

```bash
# Panggil endpoint berulang kali dan perhatikan nilai "container"
# Setiap request bisa dilayani container yang berbeda!
for i in {1..6}; do
  curl -s http://192.168.64.10/api/health | python3 -m json.tool
  echo "---"
  sleep 1
done
```

Perhatikan bahwa nilai `container` (hostname) berganti-ganti — ini membuktikan Swarm mendistribusikan traffic ke replica yang berbeda.

### 10.4 Cek Log Service

```bash
# Log service app (semua replica)
docker service logs laravel_app --follow --tail 50

# Log service migrator
docker service logs laravel_migrator
```

---

## 11. Simulasi Rolling Update

> Ini adalah fitur unggulan Swarm — update tanpa downtime!

### 11.1 Buat Perubahan Kecil pada Aplikasi

Di **HOST MACHINE**, edit `routes/web.php`:

```php
Route::get('/', function () {
    return response()->json([
        'app'       => 'Laravel 12 Demo — Docker Swarm',
        'version'   => '2.0.0',              // ← tambahkan baris ini
        'container' => gethostname(),
        'endpoints' => [
            'GET  /api/health'    => 'Health check',
            'GET  /api/messages'  => 'List messages',
            'POST /api/messages'  => 'Create message',
        ],
    ]);
});
```

### 11.2 Build dan Push Image Versi Baru

```bash
docker build -t ${DOCKER_USERNAME}/laravel-swarm-demo:2.0.0 .
docker push ${DOCKER_USERNAME}/laravel-swarm-demo:2.0.0
```

### 11.3 Update Stack

```bash
# Di swarm-manager, update service app dengan image baru
docker service update \
  --image ${DOCKER_USERNAME}/laravel-swarm-demo:2.0.0 \
  --update-parallelism 1 \
  --update-delay 15s \
  --update-order start-first \
  laravel_app
```

### 11.4 Pantau Rolling Update

Buka **terminal baru** dan jalankan:

```bash
# Pantau status update secara real-time
watch docker service ps laravel_app
```

Di terminal lain, terus test aplikasi:

```bash
# Buktikan tidak ada downtime selama update
while true; do
  curl -s http://192.168.64.10/ | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"version: {d.get('version','1.0.0')} | container: {d['container']}\")"
  sleep 2
done
```

Anda akan melihat versi berganti dari `1.0.0` ke `2.0.0` secara bertahap, tanpa error!

### 11.5 Rollback (jika diperlukan)

```bash
# Rollback ke versi sebelumnya
docker service rollback laravel_app
```

---

## 12. Troubleshooting Umum

### Problem 1: Service stuck di `Preparing` atau `Starting`

```bash
# Cek detail task yang gagal
docker service ps laravel_app --no-trunc

# Cek log node
docker service logs laravel_app 2>&1 | tail -50
```

**Penyebab umum:**

- Image belum selesai di-pull — tunggu beberapa menit
- APP_KEY tidak disetel → set environment variable
- Registry tidak bisa diakses → pastikan jalankan `docker stack deploy --with-registry-auth`

---

### Problem 2: Nginx error "connect() failed" ke PHP-FPM

```bash
# Pastikan service app sudah Running sebelum nginx
docker service ps laravel_app
docker service ps laravel_nginx
```

**Solusi:** Swarm tidak menjamin urutan start, tapi Nginx akan retry otomatis. Tunggu 1-2 menit.

---

### Problem 3: Database migration gagal

```bash
docker service logs laravel_migrator --no-trunc
```

**Penyebab umum:**

- MySQL belum siap → service migrator akan retry otomatis (`max_attempts: 5`)
- Credentials salah → periksa env variable `DB_*` di stack file

---

### Problem 4: Perubahan kode tidak muncul setelah update

```bash
# Paksa update dengan image digest
docker service update --force laravel_app
```

---

### Problem 5: Worker tidak mendapat replica

```bash
# Cek status node
docker node ls

# Cek resource worker
docker node inspect swarm-worker --pretty | grep -A5 Resources
```

**Solusi:** Pastikan worker dalam status `Ready` dan `Active`.

---

### Perintah Manajemen Stack (Referensi Cepat)

```bash
# Lihat semua stack
docker stack ls

# Lihat service dalam stack
docker stack services laravel

# Lihat task/container dalam stack
docker stack ps laravel

# Scale service (tambah/kurangi replica)
docker service scale laravel_app=3

# Hapus seluruh stack
docker stack rm laravel

# Lihat log service
docker service logs laravel_app -f

# Inspect service detail
docker service inspect laravel_app --pretty
```

---

## Ringkasan Alur Deployment

```
[Host Machine]                    [Docker Hub]              [Swarm Cluster]
     │                                 │                          │
     ├─ composer create-project        │                          │
     ├─ Tulis Dockerfile               │                          │
     ├─ Tulis docker-stack.yml         │                          │
     ├─ docker build                   │                          │
     ├─ docker push ─────────────────► │                          │
     │                                 │                          │
     └─ (ssh/multipass ke manager) ────┼──────────────────────────┤
                                       │                          │
                              [Manager Node]                      │
                                       │                          │
                              docker stack deploy                 │
                                       │                          │
                              Swarm Scheduler ────────────────────┤
                                       │              schedule task ke worker
                                       │                          │
                              [Container Running]        [Container Running]
                               (di Manager)               (di Worker)
                                       │                          │
                              ◄────────┴──────────────────────────┘
                                    Overlay Network
                                    (laravel_net)
```

---
