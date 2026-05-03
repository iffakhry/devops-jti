# Kubernetes: PV, PVC & Deployment Laravel 12 dengan Minikube

---

## 🧰 Alat dan Prasyarat

### Software yang harus terinstall:

- **Docker Desktop** (v25+) — [docker.com/get-started](https://www.docker.com/get-started)
- **Minikube** (v1.33+) — [minikube.sigs.k8s.io](https://minikube.sigs.k8s.io/docs/start/)
- **kubectl** (v1.30+) — [kubernetes.io/docs/tasks/tools](https://kubernetes.io/docs/tasks/tools/)
- **Git**

### Verifikasi instalasi:

```bash
docker --version
minikube version
kubectl version --client
```

---

## 📚 BAGIAN A — Teori: PersistentVolume (PV) & PersistentVolumeClaim (PVC)

### A.1 Mengapa Butuh PV dan PVC?

Container bersifat **ephemeral (sementara)** — ketika container dihapus atau restart, semua data di dalamnya hilang. Kubernetes menyelesaikan masalah ini dengan sistem penyimpanan persisten yang terpisah dari Pod.

```
┌─────────────────────────────────────────────────────┐
│                  KUBERNETES CLUSTER                  │
│                                                      │
│  ┌─────────────┐    ┌──────────────┐                │
│  │     Pod     │───▶│     PVC      │ ◀── Request    │
│  │  (App)      │    │  (Klaim)     │     Storage    │
│  └─────────────┘    └──────┬───────┘                │
│                             │ Binding                │
│                      ┌──────▼───────┐                │
│                      │      PV      │ ◀── Disediakan │
│                      │  (Storage)   │     Admin      │
│                      └──────────────┘                │
└─────────────────────────────────────────────────────┘
```

### A.2 PersistentVolume (PV)

**PV** adalah representasi dari storage fisik yang tersedia di cluster. PV dikelola oleh **administrator cluster**, bukan developer aplikasi.

**Analogi:** PV seperti ruangan di kos-kosan yang sudah tersedia dan siap disewa.

```yaml
# Contoh definisi PV
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-contoh
spec:
  capacity:
    storage: 1Gi # Kapasitas storage
  accessModes:
    - ReadWriteOnce # Mode akses
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/pv-contoh # Path di node (hanya untuk dev/minikube)
```

**Mode Akses PV:**

| Mode                  | Keterangan                                                    |
| --------------------- | ------------------------------------------------------------- |
| `ReadWriteOnce (RWO)` | Hanya bisa di-mount oleh 1 node, bisa baca & tulis            |
| `ReadOnlyMany (ROX)`  | Bisa di-mount banyak node, tapi read-only                     |
| `ReadWriteMany (RWX)` | Bisa di-mount banyak node, baca & tulis (butuh NFS/GlusterFS) |

**Reclaim Policy:**

| Policy    | Perilaku setelah PVC dihapus                  |
| --------- | --------------------------------------------- |
| `Retain`  | PV tetap ada, data aman, perlu manual cleanup |
| `Delete`  | PV dan data dihapus otomatis (umum di cloud)  |
| `Recycle` | ⚠️ _Deprecated_ — tidak direkomendasikan      |

### A.3 PersistentVolumeClaim (PVC)

**PVC** adalah **permintaan storage** dari sisi developer/pengguna. PVC tidak perlu tahu detail implementasi storage fisik yang ada.

**Analogi:** PVC seperti formulir pengajuan sewa kamar — Anda cukup tulis berapa besar kamar yang dibutuhkan dan fasilitasnya. Pihak kos (administrator) yang mencarikan kamar yang cocok.

```yaml
# Contoh definisi PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-contoh
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi # Minta 500MB storage
```

### A.4 Siklus Hidup PV dan PVC

```
Provisioning ──▶ Binding ──▶ Using ──▶ Releasing ──▶ Reclaiming
    │                                                      │
  [Admin buat PV]  [PVC cocok   [Pod pakai    [PVC         [Retain/Delete/
  atau dynamic     dengan PV]   PVC sebagai    dihapus]     Recycle]
  provisioning]                 volume]
```

**Status PV:**

- `Available` — belum terikat ke PVC manapun
- `Bound` — sudah terikat ke sebuah PVC
- `Released` — PVC sudah dihapus, PV belum direclai
- `Failed` — reclaim otomatis gagal

### A.5 Dynamic Provisioning

Di lingkungan cloud modern (GKE, EKS, AKS) dan di Minikube, kita bisa menggunakan **StorageClass** untuk provisi PV secara otomatis tanpa admin perlu membuat PV manual.

```yaml
# StorageClass default Minikube
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: k8s.io/minikube-hostpath
```

Dengan dynamic provisioning: PVC dibuat → StorageClass otomatis buat PV yang cocok → Langsung Bound.

---

## 🛠️ BAGIAN B — Demo Implementasi PV & PVC

Sebelum deploy Laravel, kita praktikkan PV/PVC secara sederhana.

### B.1 Mulai Minikube

```bash
# Mulai cluster Minikube dengan resource yang cukup
minikube start --cpus=2 --memory=4096 --driver=docker

# Verifikasi cluster berjalan
kubectl cluster-info
kubectl get nodes
```

Output yang diharapkan:

```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   1m    v1.30.x
```

### B.2 Demo Static Provisioning

**Langkah 1:** Buat PV

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: demo-pv
  labels:
    type: local
spec:
  capacity:
    storage: 256Mi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/demo-data
EOF
```

**Langkah 2:** Verifikasi PV tersedia

```bash
kubectl get pv
# STATUS harus: Available
```

**Langkah 3:** Buat PVC yang meminta storage tersebut

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: demo-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
EOF
```

**Langkah 4:** Verifikasi binding

```bash
kubectl get pv,pvc
# PV STATUS: Bound
# PVC STATUS: Bound
```

**Langkah 5:** Gunakan PVC di dalam Pod

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo-pod-pvc
spec:
  containers:
  - name: busybox
    image: busybox:stable
    command: ["sh", "-c", "echo 'Data tersimpan!' > /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: demo-pvc   # Referensikan PVC yang dibuat
EOF
```

**Langkah 6:** Verifikasi data persisten

```bash
# Baca file yang dibuat pod
kubectl exec demo-pod-pvc -- cat /data/test.txt
# Output: Data tersimpan!

# Hapus pod
kubectl delete pod demo-pod-pvc

# Buat pod baru yang pakai PVC yang sama
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo-pod-pvc-2
spec:
  containers:
  - name: busybox
    image: busybox:stable
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: demo-pvc
EOF

# Data tetap ada meski pod pertama sudah dihapus!
kubectl exec demo-pod-pvc-2 -- cat /data/test.txt
# Output: Data tersimpan!
```

**Kesimpulan Demo:** Data bertahan meskipun Pod dihapus karena tersimpan di PV, bukan di dalam container.

**Bersihkan demo:**

```bash
kubectl delete pod demo-pod-pvc-2
kubectl delete pvc demo-pvc
kubectl delete pv demo-pv
```

---

## 🚀 BAGIAN C — Deploy Laravel 12 di Minikube

### C.1 Persiapan: Clone & Setup Aplikasi Laravel 12

```bash
# Clone atau buat aplikasi Laravel 12 baru
composer create-project laravel/laravel laravel-k8s-demo
cd laravel-k8s-demo

# Atau clone contoh yang sudah ada
# git clone https://github.com/learnk8s/laravel-kubernetes-demo
```

### C.2 Buat Dockerfile untuk Laravel 12

Buat file `Dockerfile` di root proyek Laravel:

```dockerfile
# ---- Stage 1: Build dependencies ----
FROM composer:2.7 AS vendor

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist \
    --optimize-autoloader

# ---- Stage 2: Production image ----
FROM php:8.3-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    curl \
    libpng-dev \
    libzip-dev \
    zip \
    unzip

# Install PHP extensions
RUN docker-php-ext-install \
    pdo_mysql \
    gd \
    zip \
    opcache

# Copy Nginx config
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Copy Supervisor config
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

WORKDIR /var/www/html

# Copy application files
COPY --from=vendor /app/vendor ./vendor
COPY . .

# Set permissions
RUN chown -R www-data:www-data storage bootstrap/cache && \
    chmod -R 775 storage bootstrap/cache

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
```

Buat file `docker/nginx.conf`:

```nginx
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    server {
        listen 80;
        server_name _;
        root /var/www/html/public;
        index index.php;

        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }

        location ~ \.php$ {
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME /var/www/html/public$fastcgi_script_name;
            include fastcgi_params;
        }
    }
}
```

Buat file `docker/supervisord.conf`:

```ini
[supervisord]
nodaemon=true
logfile=/dev/null
logfile_maxbytes=0

[program:php-fpm]
command=php-fpm -F
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:nginx]
command=nginx -g 'daemon off;'
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
```

### C.3 Build & Push Docker Image

```bash
# Gunakan Docker daemon minikube agar tidak perlu push ke registry
eval $(minikube docker-env)

# Build image langsung ke registry minikube
docker build -t laravel-k8s-demo:latest .

# Verifikasi image tersedia
docker images | grep laravel-k8s-demo
```

> 💡 **Tips:** Dengan `eval $(minikube docker-env)`, Docker CLI Anda terhubung ke daemon Docker di dalam Minikube, sehingga image langsung tersedia untuk dipakai Kubernetes tanpa perlu push ke Docker Hub.

### C.4 Generate APP_KEY dan Simpan sebagai Secret

```bash
# Generate APP_KEY dari Laravel
php artisan key:generate --show
# Output: base64:xxxxxxxxxxxxxxxxxxxxxxxxxxxxx=

# Simpan APP_KEY sebagai Kubernetes Secret (BUKAN di YAML deployment!)
kubectl create secret generic laravel-secret \
  --from-literal=APP_KEY='base64:xxxxxxxxxxxxxxxxxxxxxxxxxxxxx='

# Verifikasi secret
kubectl get secrets
kubectl describe secret laravel-secret
```

> ⚠️ **Best Practice Industri:** Jangan pernah menyimpan secret langsung di file YAML Deployment. Gunakan Kubernetes Secret agar tidak ter-commit ke Git.

### C.5 Buat Manifest Deployment

Buat file `k8s/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: laravel-k8s-demo
  labels:
    app: laravel-k8s-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: laravel-k8s-demo
  template:
    metadata:
      labels:
        app: laravel-k8s-demo
    spec:
      containers:
        - name: laravel
          image: laravel-k8s-demo:latest
          imagePullPolicy: Never # Gunakan image lokal minikube
          ports:
            - containerPort: 80
          env:
            - name: APP_ENV
              value: "production"
            - name: APP_DEBUG
              value: "false"
            - name: APP_KEY
              valueFrom:
                secretKeyRef:
                  name: laravel-secret # Ambil dari Secret
                  key: APP_KEY
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "500m"
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 30
            periodSeconds: 10
```

Buat file `k8s/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: laravel-k8s-demo
  labels:
    app: laravel-k8s-demo
spec:
  type: NodePort
  selector:
    app: laravel-k8s-demo # Cocokkan dengan label di Deployment
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

### C.6 Deploy ke Kubernetes

```bash
# Terapkan semua manifest
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Pantau status Pod (tunggu STATUS = Running)
kubectl get pods -w
# Tekan Ctrl+C setelah Running

# Cek detail deployment
kubectl get deployment,pod,service
```

Output yang diharapkan:

```
NAME                                       READY   UP-TO-DATE   AVAILABLE
deployment.apps/laravel-k8s-demo           1/1     1            1

NAME                                    READY   STATUS    RESTARTS
pod/laravel-k8s-demo-xxxxxxxxx-xxxxx    1/1     Running   0

NAME                       TYPE       CLUSTER-IP      PORT(S)
service/laravel-k8s-demo   NodePort   10.96.xxx.xxx   80:3xxxx/TCP
```

### C.7 Akses Aplikasi

```bash
# Buka aplikasi di browser
minikube service laravel-k8s-demo

# Atau dapatkan URL-nya saja
minikube service laravel-k8s-demo --url

# Tampilkan Minikube dashboard (GUI opsional)
minikube dashboard
```

---

## ⚖️ BAGIAN D — Scaling Aplikasi

### D.1 Scaling Manual (Horizontal)

```bash
# Skalakan ke 3 replika
kubectl scale deployment laravel-k8s-demo --replicas=3

# Pantau pods baru muncul
kubectl get pods -w

# Verifikasi 3 replika berjalan
kubectl get deployment laravel-k8s-demo
```

### D.2 Update Replicas via Manifest (Cara yang Direkomendasikan)

Edit `k8s/deployment.yaml`:

```yaml
spec:
  replicas: 3 # Ubah dari 1 menjadi 3
```

```bash
# Terapkan perubahan
kubectl apply -f k8s/deployment.yaml

# Verifikasi
kubectl get pods
```

### D.3 Simulasi Ketahanan (Self-Healing)

```bash
# Ambil nama salah satu pod
kubectl get pods

# Hapus pod secara paksa
kubectl delete pod <nama-pod>

# Perhatikan Kubernetes otomatis membuat pod baru!
kubectl get pods -w
```

Kubernetes Deployment memastikan jumlah replika selalu sesuai konfigurasi — jika satu Pod mati, Pod baru akan dibuat otomatis.

### D.4 Kembali ke 1 Replika

```bash
kubectl scale deployment laravel-k8s-demo --replicas=1
```

---

## 🌐 BAGIAN E — Nginx Ingress untuk Ekspos Aplikasi

### E.1 Aktifkan Ingress Addon di Minikube

```bash
# Aktifkan Nginx Ingress Controller
minikube addons enable ingress

# Tunggu hingga Ingress Controller siap (bisa 2-3 menit)
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Verifikasi
kubectl get pods -n ingress-nginx
```

### E.2 Ubah Service Type ke ClusterIP

Ketika menggunakan Ingress, Service tidak perlu bertipe `NodePort` lagi. Edit `k8s/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: laravel-k8s-demo
  labels:
    app: laravel-k8s-demo
spec:
  type: ClusterIP # Ubah dari NodePort ke ClusterIP
  selector:
    app: laravel-k8s-demo
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

```bash
kubectl apply -f k8s/service.yaml
```

### E.3 Buat Ingress Resource

Buat file `k8s/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: laravel-k8s-demo-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: laravel-demo.local # Custom hostname
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: laravel-k8s-demo
                port:
                  number: 80
```

```bash
# Terapkan Ingress
kubectl apply -f k8s/ingress.yaml

# Verifikasi Ingress (tunggu ADDRESS terisi)
kubectl get ingress
```

Output yang diharapkan:

```
NAME                          CLASS   HOSTS                ADDRESS        PORTS   AGE
laravel-k8s-demo-ingress      nginx   laravel-demo.local   192.168.x.x    80      1m
```

### E.4 Tambahkan DNS Lokal

```bash
# Dapatkan IP Minikube
minikube ip
# Contoh output: 192.168.49.2

# Tambahkan ke /etc/hosts (Linux/Mac)
echo "$(minikube ip) laravel-demo.local" | sudo tee -a /etc/hosts

# Windows (PowerShell sebagai Administrator):
# Add-Content C:\Windows\System32\drivers\etc\hosts "$(minikube ip) laravel-demo.local"
```

### E.5 Akses via Hostname

```bash
# Test menggunakan curl
curl http://laravel-demo.local

# Atau buka di browser
# http://laravel-demo.local
```

---

## 🗄️ BAGIAN F — Bonus: PVC untuk Storage Laravel

Pada deployment nyata, file upload Laravel perlu disimpan secara persisten menggunakan PVC.

### F.1 Buat PVC untuk Storage Laravel

Buat file `k8s/pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: laravel-storage-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  # Tidak perlu storageClassName di Minikube — pakai default (dynamic)
```

```bash
kubectl apply -f k8s/pvc.yaml

# Verifikasi PVC (STATUS harus Bound dengan dynamic provisioning)
kubectl get pvc
```

### F.2 Mount PVC ke Deployment

Update `k8s/deployment.yaml` dengan menambahkan volume:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: laravel-k8s-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: laravel-k8s-demo
  template:
    metadata:
      labels:
        app: laravel-k8s-demo
    spec:
      containers:
        - name: laravel
          image: laravel-k8s-demo:latest
          imagePullPolicy: Never
          ports:
            - containerPort: 80
          env:
            - name: APP_ENV
              value: "production"
            - name: APP_DEBUG
              value: "false"
            - name: APP_KEY
              valueFrom:
                secretKeyRef:
                  name: laravel-secret
                  key: APP_KEY
          volumeMounts:
            - name: laravel-storage # Nama volume (referensi ke bawah)
              mountPath: /var/www/html/storage # Mount ke folder storage Laravel
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "500m"
      volumes:
        - name: laravel-storage
          persistentVolumeClaim:
            claimName: laravel-storage-pvc # Nama PVC yang dibuat
```

```bash
kubectl apply -f k8s/deployment.yaml
kubectl get pods -w
```

---

## 📁 Struktur File Lengkap Proyek

```
laravel-k8s-demo/
├── app/
├── ...file Laravel lainnya...
├── docker/
│   ├── nginx.conf
│   └── supervisord.conf
├── Dockerfile
└── k8s/
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    └── pvc.yaml
```

---

## 🔁 Ringkasan Perintah Penting

| Tujuan                  | Perintah                                       |
| ----------------------- | ---------------------------------------------- |
| Mulai Minikube          | `minikube start --cpus=2 --memory=4096`        |
| Gunakan Docker minikube | `eval $(minikube docker-env)`                  |
| Terapkan manifest       | `kubectl apply -f <file.yaml>`                 |
| Lihat semua resource    | `kubectl get all`                              |
| Lihat pods              | `kubectl get pods`                             |
| Lihat log pod           | `kubectl logs <nama-pod>`                      |
| Masuk ke pod            | `kubectl exec -it <nama-pod> -- sh`            |
| Scale deployment        | `kubectl scale deployment <nama> --replicas=N` |
| Lihat IP minikube       | `minikube ip`                                  |
| Buka service di browser | `minikube service <nama-service>`              |
| Hapus semua resource    | `kubectl delete -f k8s/`                       |
| Stop minikube           | `minikube stop`                                |

---

## 🐛 Troubleshooting Umum

**Pod status `ImagePullBackOff`:**

```bash
# Pastikan menggunakan Docker daemon minikube
eval $(minikube docker-env)
# Lalu build ulang image
docker build -t laravel-k8s-demo:latest .
# Pastikan imagePullPolicy: Never di deployment.yaml
```

**Pod status `CrashLoopBackOff`:**

```bash
# Lihat log pod
kubectl logs <nama-pod>
# Atau lihat log pod sebelumnya yang crash
kubectl logs <nama-pod> --previous
```

**PVC status `Pending`:**

```bash
# Cek apakah ada PV yang cocok
kubectl get pv
# Cek detail PVC
kubectl describe pvc <nama-pvc>
```

**Ingress ADDRESS kosong:**

```bash
# Pastikan addon ingress aktif
minikube addons list | grep ingress
# Tunggu ingress controller siap
kubectl get pods -n ingress-nginx
```

**Tidak bisa akses lewat hostname:**

```bash
# Verifikasi /etc/hosts
cat /etc/hosts | grep laravel-demo
# Pastikan IP sesuai dengan minikube ip
minikube ip
```

---

## ✅ Checklist Penilaian Uji Coba

- [ ] Minikube berhasil dijalankan dan cluster aktif
- [ ] Demo PV/PVC berhasil — data persisten setelah pod dihapus
- [ ] Docker image Laravel 12 berhasil di-build
- [ ] Deployment berjalan dengan minimal 1 Pod status `Running`
- [ ] Aplikasi dapat diakses via `minikube service`
- [ ] Scaling ke 3 replika berhasil
- [ ] Nginx Ingress aktif dan aplikasi dapat diakses via hostname `laravel-demo.local`
- [ ] PVC berhasil di-mount ke Deployment (Bagian Bonus)

---

## 📖 Referensi

- [Kubernetes Docs: Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Kubernetes Docs: Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Minikube Docs](https://minikube.sigs.k8s.io/docs/)
- [Laravel 12 Documentation](https://laravel.com/docs/12.x)
- [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
