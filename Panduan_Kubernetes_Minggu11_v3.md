# Kubernetes dengan Minikube

---

## 🧠 Bab 1: Dasar Teori Kubernetes

### 1.1 Apa itu Kubernetes?

**Kubernetes** (disingkat **K8s**) adalah platform open-source untuk otomatisasi deployment, scaling, dan manajemen aplikasi yang dikontainerisasi. Dikembangkan oleh Google pada 2014 berdasarkan pengalaman internal mereka menjalankan sistem skala besar (dikenal sebagai "Borg"), dan kini dikelola oleh Cloud Native Computing Foundation (CNCF).

**Analogi sederhana:** Bayangkan Kubernetes seperti seorang **manajer restoran cepat saji**:

- **Container** = juru masak (chef)
- **Pod** = dapur (satu atau beberapa chef bekerja bersama)
- **Node** = gedung restoran (tempat dapur beroperasi)
- **Cluster** = jaringan seluruh cabang restoran
- **Kubernetes** = manajer pusat yang memastikan semua cabang beroperasi, jika satu cabang tutup, manajer otomatis memindahkan operasi ke cabang lain

### 1.2 Mengapa Kubernetes? (Relevansi Industri 2026)

Di industri saat ini, Kubernetes telah menjadi standar de-facto untuk:

- **Microservices Architecture** — mengelola puluhan hingga ratusan layanan kecil yang saling berkomunikasi
- **CI/CD Pipeline** — deployment otomatis dari pipeline GitHub Actions/GitLab CI langsung ke cluster K8s
- **Multi-cloud Strategy** — aplikasi yang sama dapat berjalan di AWS EKS, Google GKE, Azure AKS, atau on-premise
- **Auto-scaling** — traffic naik saat promo? Kubernetes menambah pod otomatis, lalu menurunkannya kembali
- **Sertifikasi industri** — CKA (Certified Kubernetes Administrator) dan CKAD adalah sertifikasi paling dicari di industri cloud

### 1.3 Arsitektur Kubernetes

```
┌─────────────────────────────────────────────────────────────────┐
│                         KUBERNETES CLUSTER                      │
│                                                                 │
│  ┌──────────────────────────────────┐                           │
│  │         CONTROL PLANE            │                           │
│  │  (Master Node)                   │                           │
│  │                                  │                           │
│  │  ┌──────────┐  ┌──────────────┐  │                           │
│  │  │  API     │  │  etcd        │  │   ← Penyimpanan           │
│  │  │  Server  │  │  (Database)  │  │     konfigurasi cluster   │
│  │  └──────────┘  └──────────────┘  │                           │
│  │  ┌──────────┐  ┌──────────────┐  │                           │
│  │  │Scheduler │  │  Controller  │  │                           │
│  │  │          │  │  Manager     │  │                           │
│  │  └──────────┘  └──────────────┘  │                           │
│  └──────────────────────────────────┘                           │
│                       │  kubectl (CLI)                          │
│         ┌─────────────┼─────────────┐                           │
│         ▼             ▼             ▼                           │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐                   │
│  │  WORKER    │ │  WORKER    │ │  WORKER    │                   │
│  │  NODE 1    │ │  NODE 2    │ │  NODE 3    │                   │
│  │            │ │            │ │            │                   │
│  │ ┌────────┐ │ │ ┌────────┐ │ │ ┌────────┐ │                   │
│  │ │ Pod 1  │ │ │ │ Pod 3  │ │ │ │ Pod 5  │ │                   │
│  │ │[app:v1]│ │ │ │[app:v1]│ │ │ │[db]    │ │                   │
│  │ └────────┘ │ │ └────────┘ │ │ └────────┘ │                   │
│  │ ┌────────┐ │ │ ┌────────┐ │ │            │                   │
│  │ │ Pod 2  │ │ │ │ Pod 4  │ │ │            │                   │
│  │ │[app:v1]│ │ │ │[app:v1]│ │ │            │                   │
│  │ └────────┘ │ │ └────────┘ │ │            │                   │
│  │            │ │            │ │            │                   │
│  │  kubelet   │ │  kubelet   │ │  kubelet   │                   │
│  │  kube-proxy│ │  kube-proxy│ │  kube-proxy│                   │
│  └────────────┘ └────────────┘ └────────────┘                   │
└─────────────────────────────────────────────────────────────────┘
```

### 1.4 Komponen Utama

| Komponen               | Lokasi        | Fungsi                                                            |
| ---------------------- | ------------- | ----------------------------------------------------------------- |
| **API Server**         | Control Plane | Pintu masuk semua perintah kubectl; semua komunikasi melalui sini |
| **etcd**               | Control Plane | Database key-value untuk menyimpan seluruh state cluster          |
| **Scheduler**          | Control Plane | Memutuskan Pod harus dijalankan di Node mana                      |
| **Controller Manager** | Control Plane | Memastikan state aktual = state yang diinginkan (desired state)   |
| **kubelet**            | Worker Node   | Agen di setiap node; menjalankan container sesuai instruksi       |
| **kube-proxy**         | Worker Node   | Mengatur networking dan load balancing antar Pod                  |
| **Container Runtime**  | Worker Node   | Mesin yang menjalankan container (containerd, CRI-O)              |

### 1.5 Objek-Objek Kubernetes

#### Pod

Unit terkecil di Kubernetes. Satu Pod biasanya berisi satu container (bisa lebih untuk kasus sidecar).

```
Pod
└── Container (aplikasi utama)
    ├── Shared Network (IP yang sama)
    └── Shared Storage (Volume)
```

> ⚠️ **Catatan penting:** Pod bersifat _ephemeral_ (sementara). Jika Pod mati, data di dalamnya hilang kecuali menggunakan PersistentVolume.

#### Deployment

Mengatur replikasi Pod dan rolling update. Inilah yang dipakai di production, bukan membuat Pod secara langsung.

#### Service

Memberikan IP dan DNS name yang stabil untuk mengakses sekumpulan Pod. Pod bisa mati dan lahir lagi dengan IP berbeda, tapi Service tetap dapat diakses dengan alamat yang sama.

#### Namespace

Pemisah virtual dalam satu cluster. Berguna untuk memisahkan lingkungan development, staging, dan production dalam satu cluster.

---

## 💻 Bab 2: Persiapan dan Instalasi

### 2.1 Kebutuhan Sistem

| Komponen         | Minimum                                 | Rekomendasi |
| ---------------- | --------------------------------------- | ----------- |
| CPU              | 2 core                                  | 4 core      |
| RAM              | 2 GB (untuk Minikube)                   | 8 GB        |
| Disk             | 20 GB                                   | 40 GB       |
| OS               | Windows 10/11, macOS 12+, Ubuntu 20.04+ | —           |
| Docker           | Versi terbaru (CE)                      | —           |
| Koneksi Internet | Diperlukan untuk pull image             | —           |

### 2.2 Instalasi Docker (Prasyarat)

Minikube membutuhkan container runtime. Docker adalah pilihan paling umum.

Verifikasi Docker sudah terinstal:

```bash
docker --version
# Output: Docker version 26.x.x, build ...
docker run hello-world
```

Jika belum terinstal, kunjungi: https://docs.docker.com/get-docker/

### 2.3 Instalasi Minikube

#### Windows (PowerShell — Run as Administrator)

```powershell
# Download Minikube
New-Item -Path 'c:\' -Name 'minikube' -ItemType Directory -Force
Invoke-WebRequest -OutFile 'c:\minikube\minikube.exe' `
  -Uri 'https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe' `
  -UseBasicParsing

# Tambahkan ke PATH
$oldPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine)
if ($oldPath.Split(';') -inotcontains 'C:\minikube') {
  [Environment]::SetEnvironmentVariable('Path', $('{0};C:\minikube' -f $oldPath), [EnvironmentVariableTarget]::Machine)
}
```

#### macOS (Terminal)

```bash
# Intel Mac
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
sudo install minikube-darwin-amd64 /usr/local/bin/minikube

# Apple Silicon (M1/M2/M3/M4)
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-arm64
sudo install minikube-darwin-arm64 /usr/local/bin/minikube

# Atau menggunakan Homebrew (cara termudah)
brew install minikube
```

#### Linux (Ubuntu/Debian)

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

### 2.4 Instalasi kubectl

`kubectl` adalah CLI resmi untuk berkomunikasi dengan cluster Kubernetes.

#### macOS

```bash
brew install kubectl
```

#### Windows (PowerShell — Run as Administrator)

```powershell
winget install -e --id Kubernetes.kubectl
```

#### Linux

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Verifikasi instalasi:

```bash
kubectl version --client
minikube version
```

---

## 🚀 Bab 3: Menjalankan Cluster Minikube

### 3.1 Memulai Cluster

```bash
# Menjalankan cluster dengan driver Docker (DIREKOMENDASIKAN)
minikube start --driver=docker

# Menjalankan dengan resource lebih besar (untuk praktikum yang lebih intensif)
minikube start --driver=docker --cpus=2 --memory=4096

# Menjalankan cluster multi-node (1 control plane + 2 workers)
minikube start --nodes=3 --driver=docker -p lab-cluster
```

Output yang diharapkan:

```
😄  minikube v1.33.x on Darwin/Linux/Windows
✨  Using the docker driver based on user configuration
📌  Using Docker Desktop driver with root privileges
👍  Starting "minikube" primary control-plane node in "minikube" cluster
🚜  Pulling base image v0.0.44 ...
🔥  Creating docker container (CPUs=2, Memory=4096MB) ...
🐳  Preparing Kubernetes v1.30.x on Docker 26.x.x ...
🔗  Configuring bridge CNI (Container Networking Interface) ...
🔎  Verifying Kubernetes components...
🌟  Enabled addons: storage-provisioner, default-storageclass
🏄  Done! kubectl is now configured to use "minikube" cluster
```

### 3.2 Perintah Dasar Manajemen Cluster

```bash
# Cek status cluster
minikube status

# Lihat info cluster
kubectl cluster-info

# Lihat semua node
kubectl get nodes

# Lihat node dengan detail lebih
kubectl get nodes -o wide

# Pause cluster (hemat resource saat tidak dipakai)
minikube pause

# Resume cluster
minikube unpause

# Stop cluster
minikube stop

# Hapus cluster (reset total)
minikube delete

# Hapus cluster dengan nama spesifik
minikube delete -p lab-cluster

# Lihat semua profil cluster Minikube yang ada di mesin ini
minikube profile list

# Stop cluster dengan nama spesifik (tanpa menghapusnya)
minikube stop -p lab-cluster

# Jalankan kembali cluster yang sebelumnya di-stop
minikube start -p lab-cluster
```

> 💡 **Glossary — Profile Minikube:**
> Setiap cluster Minikube yang dibuat dengan `-p <nama>` disebut **profil**. Satu mesin bisa memiliki beberapa profil sekaligus (misalnya `minikube` untuk cluster default dan `lab-cluster` untuk cluster multi-node). Perintah `minikube profile list` menampilkan semua profil beserta statusnya (Running/Stopped), driver, versi Kubernetes, dan jumlah node.

```bash
# Contoh output minikube profile list:
# |-------------|-----------|---------|--------------|------|---------|---------|-------|--------|
# |   Profile   |  VM Driver| Runtime |      IP      | Port | Version | Status  | Nodes | Active |
# |-------------|-----------|---------|--------------|------|---------|---------|-------|--------|
# | lab-cluster | docker    | docker  | 192.168.49.2 | 8443 | v1.30.0 | Running |     3 |        |
# | minikube    | docker    | docker  | 192.168.49.3 | 8443 | v1.30.0 | Stopped |     1 | *      |
# |-------------|-----------|---------|--------------|------|---------|---------|-------|--------|

# Lihat detail lengkap sebuah Node (resource, kondisi, Pod yang berjalan di sana)
kubectl describe node <nama-node>

# Contoh untuk cluster default Minikube:
kubectl describe node minikube

# Contoh untuk cluster multi-node:
kubectl describe node lab-cluster        # node control plane
kubectl describe node lab-cluster-m02   # worker node pertama
kubectl describe node lab-cluster-m03   # worker node kedua
```

> 💡 **Kapan menggunakan `kubectl describe node`?**
> Perintah ini sangat berguna untuk melihat:
>
> - **Conditions** — apakah node dalam kondisi `Ready`, `MemoryPressure`, atau `DiskPressure`
> - **Allocatable resources** — berapa CPU dan RAM yang tersedia untuk Pod
> - **Non-terminated Pods** — Pod apa saja yang sedang berjalan di node tersebut
> - **Events** — jika ada masalah pada node, akan muncul di bagian bawah output

### 3.3 Dashboard Kubernetes

Minikube menyertakan dashboard web yang memudahkan visualisasi cluster:

```bash
# Buka dashboard di browser
minikube dashboard

# Jika ingin URL saja (tanpa buka browser otomatis)
minikube dashboard --url
```

---

## 📦 Bab 4: Pod dan Deployment

### 4.1 Namespace

Sebelum membuat resource, pahami Namespace:

```bash
# Lihat semua namespace
kubectl get namespaces

# Output default:
# NAME              STATUS   AGE
# default           Active   5m
# kube-node-lease   Active   5m
# kube-public       Active   5m
# kube-system       Active   5m

# Buat namespace baru untuk praktikum ini
kubectl create namespace praktikum

# Set namespace default untuk sesi ini
kubectl config set-context --current --namespace=praktikum
```

### 4.2 Membuat Pod (Cara Imperatif — untuk belajar cepat)

```bash
# Buat Pod sederhana dengan nginx
kubectl run nginx-pod --image=nginx:alpine --restart=Never

# Lihat Pod yang berjalan
kubectl get pods

# Lihat detail Pod
kubectl describe pod nginx-pod

# Lihat log Pod
kubectl logs nginx-pod

# Masuk ke dalam container (seperti docker exec)
kubectl exec -it nginx-pod -- /bin/sh

# Hapus Pod
kubectl delete pod nginx-pod
```

### 4.3 Membuat Pod via Manifest YAML (Cara Deklaratif — standar industri)

Buat file `pod-nginx.yaml`:

```yaml
# pod-nginx.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  namespace: praktikum
  labels:
    app: nginx
    environment: development
spec:
  containers:
    - name: nginx
      image: nginx:1.25-alpine
      ports:
        - containerPort: 80
      resources:
        requests:
          memory: "64Mi"
          cpu: "250m"
        limits:
          memory: "128Mi"
          cpu: "500m"
```

```bash
# Terapkan manifest
kubectl apply -f pod-nginx.yaml

# Verifikasi
kubectl get pod nginx-pod -n praktikum

# Lihat dalam format YAML (untuk memahami state aktual)
kubectl get pod nginx-pod -n praktikum -o yaml

# Lihat dalam format wide (tampilkan IP dan Node)
kubectl get pod nginx-pod -n praktikum -o wide
```

> 💡 **Glossary:**
>
> - `apiVersion` — versi API Kubernetes yang digunakan
> - `kind` — jenis resource (Pod, Deployment, Service, dll.)
> - `metadata` — informasi identitas resource
> - `spec` — spesifikasi/konfigurasi yang diinginkan
> - `resources.requests` — resource minimum yang dibutuhkan container
> - `resources.limits` — batas maksimum resource yang boleh digunakan

### 4.4 Deployment (Cara yang Benar di Production)

> ⚠️ **Penting:** Di production, kita **tidak** membuat Pod secara langsung. Kita menggunakan Deployment agar Kubernetes dapat mengelola replika, rolling update, dan self-healing secara otomatis.

Buat file `deployment-nginx.yaml`:

```yaml
# deployment-nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: praktikum
  labels:
    app: nginx
spec:
  replicas: 3 # Jalankan 3 Pod sekaligus
  selector:
    matchLabels:
      app: nginx
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1 # Boleh tambah 1 Pod extra saat update
      maxUnavailable: 0 # Tidak boleh ada Pod yang down saat update
  template: # Template untuk setiap Pod yang dibuat
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.25-alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "200m"
          readinessProbe: # Kubernetes cek apakah Pod siap menerima traffic
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
```

```bash
# Terapkan Deployment
kubectl apply -f deployment-nginx.yaml

# Lihat status Deployment
kubectl get deployment -n praktikum

# Lihat Pod yang dibuat oleh Deployment
kubectl get pods -n praktikum

# Lihat detail rollout
kubectl rollout status deployment/nginx-deployment -n praktikum
```

### 4.5 Scaling Deployment

```bash
# Scale secara imperatif (untuk eksperimen cepat)
kubectl scale deployment/nginx-deployment --replicas=5 -n praktikum

# Verifikasi
kubectl get pods -n praktikum

# Scale kembali ke 3
kubectl scale deployment/nginx-deployment --replicas=3 -n praktikum
```

Atau edit manifest YAML, ubah `replicas: 5` lalu:

```bash
kubectl apply -f deployment-nginx.yaml
```

---

## 🔄 Bab 5: Rolling Update dan Rollback

### 5.1 Rolling Update

Update image ke versi baru:

```bash
# Update image deployment (cara imperatif)
kubectl set image deployment/nginx-deployment nginx=nginx:1.26-alpine -n praktikum

# Pantau proses rolling update
kubectl rollout status deployment/nginx-deployment -n praktikum

# Lihat Pod baru menggantikan Pod lama
kubectl get pods -n praktikum --watch
```

Atau update manifest YAML, ubah `image: nginx:1.26-alpine` lalu:

```bash
kubectl apply -f deployment-nginx.yaml
```

> 💡 **Catatan penting:** Flag `--record` sudah **deprecated** sejak K8s v1.25. Jangan gunakan flag tersebut di cluster modern.

### 5.2 Melihat History Deployment

```bash
# Lihat riwayat rollout
kubectl rollout history deployment/nginx-deployment -n praktikum

# Lihat detail revisi tertentu
kubectl rollout history deployment/nginx-deployment --revision=2 -n praktikum
```

> 💡 **Tip:** Untuk menyimpan alasan perubahan di history, gunakan annotation di manifest YAML:
>
> ```yaml
> metadata:
>   annotations:
>     kubernetes.io/change-cause: "Update nginx dari 1.25 ke 1.26"
> ```
>
> Lalu `kubectl apply -f deployment-nginx.yaml`

### 5.3 Rollback

```bash
# Rollback ke versi sebelumnya (revisi -1)
kubectl rollout undo deployment/nginx-deployment -n praktikum

# Rollback ke revisi spesifik
kubectl rollout undo deployment/nginx-deployment --to-revision=1 -n praktikum

# Verifikasi
kubectl rollout status deployment/nginx-deployment -n praktikum
kubectl get pods -n praktikum
```

---

## 🌐 Bab 6: Service dan Networking

### 6.1 Jenis-jenis Service

| Tipe             | Deskripsi                                    | Kapan Digunakan                        |
| ---------------- | -------------------------------------------- | -------------------------------------- |
| **ClusterIP**    | IP internal cluster saja (default)           | Komunikasi antar service dalam cluster |
| **NodePort**     | Expose via port di setiap Node (30000-32767) | Development/testing, akses dari luar   |
| **LoadBalancer** | Buat load balancer eksternal (cloud)         | Production di cloud provider           |

### 6.2 Membuat Service

Buat file `service-nginx.yaml`:

```yaml
# service-nginx.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: praktikum
spec:
  type: NodePort
  selector:
    app: nginx # Cocokkan dengan label Pod/Deployment
  ports:
    - protocol: TCP
      port: 80 # Port di dalam cluster
      targetPort: 80 # Port di dalam container
      nodePort: 30080 # Port yang dapat diakses dari luar (opsional, auto-assign jika tidak diisi)
```

```bash
# Terapkan Service
kubectl apply -f service-nginx.yaml

# Lihat Service
kubectl get services -n praktikum

# Lihat detail
kubectl describe service nginx-service -n praktikum

# Akses service melalui Minikube
minikube service nginx-service -n praktikum --url
# Buka URL yang muncul di browser
```

### 6.3 Port Forwarding (Cara Cepat untuk Testing)

```bash
# Forward port lokal ke Pod
kubectl port-forward pod/nginx-pod 8080:80 -n praktikum

# Forward ke Service
kubectl port-forward service/nginx-service 8080:80 -n praktikum

# Akses via: http://localhost:8080
```

---

## ⚙️ Bab 7: ConfigMap dan Secret

### 7.1 ConfigMap (Konfigurasi Non-Rahasia)

ConfigMap memisahkan konfigurasi dari image container — prinsip **12-Factor App**.

```bash
# Buat ConfigMap dari literal
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=APP_PORT=8080 \
  -n praktikum

# Lihat ConfigMap
kubectl get configmap -n praktikum
kubectl describe configmap app-config -n praktikum
```

Atau via YAML (`configmap.yaml`):

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: praktikum
data:
  APP_ENV: "production"
  APP_PORT: "8080"
  nginx.conf: |
    server {
      listen 80;
      server_name localhost;
      location / {
        root /usr/share/nginx/html;
        index index.html;
      }
    }
```

```bash
kubectl apply -f configmap.yaml
kubectl get configmap app-config -n praktikum -o yaml
```

### 7.2 Secret (Data Sensitif)

> ⚠️ **Penting:** Secret di Kubernetes secara default hanya di-encode base64, **bukan dienkripsi**. Untuk production, gunakan solusi seperti Sealed Secrets, Vault, atau External Secrets Operator.

```bash
# Buat Secret
kubectl create secret generic db-secret \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASSWORD=supersecret123 \
  -n praktikum

# Lihat Secret (nilai akan ter-encode base64)
kubectl get secrets -n praktikum
kubectl get secret db-secret -n praktikum -o yaml
```

Via YAML (`secret.yaml`):

```yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: praktikum
type: Opaque
stringData: # Gunakan stringData agar nilai tidak perlu di-encode manual
  DB_USER: admin
  DB_PASSWORD: supersecret123
```

### 7.3 Menggunakan ConfigMap dan Secret dalam Deployment

```yaml
# deployment-dengan-config.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-deployment
  namespace: praktikum
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: nginx:alpine
          env:
            - name: APP_ENV # Dari ConfigMap
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: APP_ENV
            - name: DB_PASSWORD # Dari Secret
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: DB_PASSWORD
```

---

## 📊 Bab 8: Horizontal Pod Autoscaler (HPA)

> ⚠️ **CATATAN:** Heapster sudah EOL sejak 2018. Saat ini gunakan **Metrics Server**.

### 8.1 Aktifkan Metrics Server di Minikube

```bash
# Aktifkan addon metrics-server
minikube addons enable metrics-server

# Verifikasi (tunggu 1-2 menit)
kubectl top nodes
kubectl top pods -n praktikum
```

### 8.2 Membuat HPA

```bash
# Buat HPA untuk nginx-deployment
kubectl autoscale deployment nginx-deployment \
  --cpu-percent=50 \
  --min=2 \
  --max=10 \
  -n praktikum

# Lihat status HPA
kubectl get hpa -n praktikum
```

Via YAML (`hpa.yaml`):

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-hpa
  namespace: praktikum
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-deployment
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

```bash
kubectl apply -f hpa.yaml
kubectl get hpa -n praktikum --watch
```

### 8.3 Persiapan: Deployment yang Tepat untuk Uji HPA

> ⚠️ **Catatan penting:** nginx biasa tidak cocok untuk menguji HPA berbasis CPU karena hampir tidak mengonsumsi CPU saat idle. Gunakan image `php-apache` dari dokumentasi resmi K8s yang dirancang khusus untuk simulasi beban CPU.
> Referensi: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/

Buat file `deployment-php-apache.yaml`:

```yaml
# deployment-php-apache.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
  namespace: praktikum
spec:
  replicas: 1
  selector:
    matchLabels:
      app: php-apache
  template:
    metadata:
      labels:
        app: php-apache
    spec:
      containers:
        - name: php-apache
          image: registry.k8s.io/hpa-example # Image resmi K8s untuk test HPA
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "200m" # WAJIB diisi agar HPA bisa menghitung persentase
            limits:
              cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: php-apache
  namespace: praktikum
spec:
  selector:
    app: php-apache
  ports:
    - port: 80
      targetPort: 80
```

```bash
kubectl apply -f deployment-php-apache.yaml

# Verifikasi Pod dan Service berjalan
kubectl get pods,svc -n praktikum
```

Buat HPA untuk deployment ini:

```bash
kubectl autoscale deployment php-apache \
  --cpu-percent=50 \
  --min=1 \
  --max=10 \
  -n praktikum

# Cek status awal HPA
kubectl get hpa php-apache -n praktikum
```

Output awal (sebelum ada beban):

```
NAME         REFERENCE               TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   0%/50%    1         10        1          30s
```

> Kolom `TARGETS` menunjukkan `<CPU saat ini>/<threshold>`. Saat idle, CPU akan sangat rendah (0-5%).

---

### 8.4 Pengujian HPA — Simulasi CPU Naik (Scale Out)

Buka **dua terminal** secara bersamaan.

**Terminal 1 — Pantau HPA secara realtime:**

```bash
# Watch HPA setiap 15 detik
kubectl get hpa php-apache -n praktikum --watch

# Atau pantau Pod sekaligus
watch -n 5 kubectl get pods -n praktikum
```

**Terminal 2 — Generate beban CPU:**

```bash
# Jalankan Pod load generator
kubectl run load-generator \
  --image=busybox:1.28 \
  --restart=Never \
  -n praktikum \
  -- /bin/sh -c "while true; do wget -q -O- http://php-apache.praktikum.svc.cluster.local; done"
```

> 💡 **Penjelasan:** Pod `load-generator` akan terus-menerus mengirim request HTTP ke service `php-apache`, menyebabkan CPU naik melampaui threshold 50%.

**Amati perubahan di Terminal 1** (proses scale-up membutuhkan ±1-3 menit):

```
# Tahap 1: CPU mulai naik
NAME         REFERENCE               TARGETS    MINPODS   MAXPODS   REPLICAS
php-apache   Deployment/php-apache   12%/50%    1         10        1

# Tahap 2: CPU melampaui threshold, HPA mulai menambah Pod
php-apache   Deployment/php-apache   68%/50%    1         10        1
php-apache   Deployment/php-apache   68%/50%    1         10        4

# Tahap 3: Pod bertambah, CPU terdistribusi dan mulai turun
php-apache   Deployment/php-apache   51%/50%    1         10        7

# Tahap 4: Stabil di jumlah Pod yang cukup
php-apache   Deployment/php-apache   48%/50%    1         10        7
```

Verifikasi Pod yang bertambah:

```bash
kubectl get pods -n praktikum

# Output yang diharapkan:
# NAME                          READY   STATUS    RESTARTS
# php-apache-xxxxxxxxx-aaaaa    1/1     Running   0
# php-apache-xxxxxxxxx-bbbbb    1/1     Running   0
# php-apache-xxxxxxxxx-ccccc    1/1     Running   0
# ...dst (jumlah Pod bertambah otomatis)
# load-generator                1/1     Running   0
```

---

### 8.5 Pengujian HPA — Simulasi CPU Turun (Scale In)

Hentikan load generator untuk melihat proses scale-down:

```bash
# Hapus Pod load generator
kubectl delete pod load-generator -n praktikum
```

Amati kembali di Terminal 1. Scale-down lebih lambat dari scale-up — K8s menunggu **5 menit** secara default sebelum menurunkan replika (untuk menghindari flapping/scale-in terlalu agresif):

```
# CPU mulai turun setelah load-generator dihapus
NAME         REFERENCE               TARGETS   MINPODS   MAXPODS   REPLICAS
php-apache   Deployment/php-apache   48%/50%   1         10        7
php-apache   Deployment/php-apache   21%/50%   1         10        7
php-apache   Deployment/php-apache   5%/50%    1         10        7

# Setelah ~5 menit, HPA mulai mengurangi Pod (scale-in)
php-apache   Deployment/php-apache   2%/50%    1         10        4
php-apache   Deployment/php-apache   0%/50%    1         10        1   ← kembali ke minimum
```

> 💡 **Mengapa scale-down lambat?** Ini adalah perilaku yang disengaja (disebut _cooldown period_). Kubernetes tidak ingin langsung mengurangi Pod karena bisa jadi traffic hanya turun sesaat. Default cooldown scale-down adalah **5 menit**.

---

### 8.6 Memantau HPA secara Detail

```bash
# Lihat detail lengkap HPA termasuk event scale-up/scale-down
kubectl describe hpa php-apache -n praktikum
```

Perhatikan bagian `Events` di output `describe`:

```
Events:
  Type    Reason             Age    Message
  ----    ------             ----   -------
  Normal  SuccessfulRescale  3m     New size: 4; reason: cpu resource utilization (percentage of request) above target
  Normal  SuccessfulRescale  8m     New size: 7; reason: cpu resource utilization (percentage of request) above target
  Normal  SuccessfulRescale  2m     New size: 1; reason: All metrics below target
```

```bash
# Lihat penggunaan resource semua Pod secara realtime
kubectl top pods -n praktikum

# Lihat penggunaan resource Node
kubectl top nodes
```

---

### 8.7 Ringkasan Alur Pengujian HPA

```
[MULAI]
   │
   ▼
kubectl apply deployment + service
   │
   ▼
kubectl autoscale → HPA dibuat (TARGETS: 0%/50%, REPLICAS: 1)
   │
   ▼
Jalankan load-generator (Terminal 2)
   │
   ▼
CPU naik > 50% → HPA scale OUT (tambah Pod otomatis)
   │              (±1-3 menit untuk bereaksi)
   ▼
kubectl delete load-generator
   │
   ▼
CPU turun < 50% → HPA scale IN (kurangi Pod)
   │              (±5 menit cooldown sebelum scale-in)
   ▼
Replika kembali ke minimum (minReplicas: 1)
   │
   ▼
[SELESAI — HPA terbukti berfungsi]
```

---

### 8.8 Troubleshooting HPA

| Gejala                        | Penyebab                                       | Solusi                                                    |
| ----------------------------- | ---------------------------------------------- | --------------------------------------------------------- |
| `TARGETS: <unknown>/50%`      | Metrics Server belum aktif atau Pod belum siap | `minikube addons enable metrics-server`, tunggu 2 menit   |
| CPU tidak naik meski ada load | Container tidak punya `resources.requests.cpu` | Tambahkan `resources.requests.cpu` di manifest Deployment |
| HPA tidak scale-up            | CPU belum melampaui threshold                  | Tambah jumlah load-generator atau turunkan threshold HPA  |
| HPA tidak scale-down          | Cooldown period belum selesai                  | Tunggu 5 menit, ini perilaku normal                       |
| `unable to get metrics`       | Metrics Server tidak dapat mengambil data      | Cek `kubectl get pods -n kube-system \| grep metrics`     |

---

## 🔑 Bab 9: RBAC (Role Based Access Control)

### 9.1 Konsep RBAC

```
User/ServiceAccount → RoleBinding → Role → Permissions (verbs) → Resources
```

### 9.2 Membuat Role dan RoleBinding

```yaml
# rbac.yaml
# Role: izin baca Pod di namespace praktikum
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: praktikum
rules:
  - apiGroups: [""] # "" berarti core API group
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
---
# RoleBinding: ikat role ke user
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: praktikum
subjects:
  - kind: User
    name: mahasiswa-baru # Nama user
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl apply -f rbac.yaml

# Verifikasi
kubectl get role -n praktikum
kubectl get rolebinding -n praktikum

# Test izin (impersonate user)
kubectl auth can-i get pods -n praktikum --as=mahasiswa-baru
kubectl auth can-i delete pods -n praktikum --as=mahasiswa-baru
```

---

## 🐛 Bab 10: Troubleshooting

### 10.1 Alur Debugging Standar

```
Pod tidak berjalan?
    ↓
kubectl get pods → Lihat STATUS dan RESTARTS
    ↓
STATUS = Pending?          → kubectl describe pod <nama> → Lihat bagian Events
STATUS = CrashLoopBackOff? → kubectl logs <nama> --previous → Lihat error
STATUS = ImagePullBackOff? → Image tidak ditemukan/salah nama/credentials
STATUS = OOMKilled?        → Container melebihi memory limit → Naikkan limits
```

### 10.2 Perintah Troubleshooting Lengkap

```bash
# ===== INSPEKSI STATUS =====
kubectl get pods -n praktikum                    # Status semua Pod
kubectl get pods -n praktikum -o wide            # Tambah info IP dan Node
kubectl get events -n praktikum --sort-by=.lastTimestamp  # Event terbaru

# ===== DETAIL DAN LOG =====
kubectl describe pod <nama-pod> -n praktikum     # Detail lengkap + Events
kubectl logs <nama-pod> -n praktikum             # Log container
kubectl logs <nama-pod> -n praktikum --previous  # Log container sebelum restart
kubectl logs <nama-pod> -n praktikum -f          # Follow log secara realtime
kubectl logs <nama-pod> -n praktikum -c <nama-container>  # Multi-container Pod

# ===== EKSEKUSI DALAM CONTAINER =====
kubectl exec -it <nama-pod> -n praktikum -- /bin/sh    # Masuk ke container
kubectl exec <nama-pod> -n praktikum -- env            # Lihat environment variables
kubectl exec <nama-pod> -n praktikum -- curl localhost  # Test koneksi internal

# ===== NODE =====
kubectl get nodes
kubectl describe node minikube
kubectl top nodes                                # Resource usage (butuh metrics-server)
kubectl top pods -n praktikum
```

### 10.3 Skenario Error Umum dan Solusi

| Error               | Penyebab Umum                                                                    | Solusi                                                              |
| ------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `ImagePullBackOff`  | Nama image salah, tidak ada di registry, atau private registry tanpa credentials | Cek nama image, pastikan bisa di-pull manual: `docker pull <image>` |
| `CrashLoopBackOff`  | Aplikasi crash saat start                                                        | `kubectl logs <pod> --previous` untuk lihat error                   |
| `Pending`           | Tidak ada Node yang memenuhi syarat (resource kurang, taint, dll.)               | `kubectl describe pod` → lihat bagian Events                        |
| `OOMKilled`         | Memory limit terlampaui                                                          | Naikkan `resources.limits.memory` di manifest                       |
| `Evicted`           | Node kehabisan disk/memory                                                       | Bersihkan resource atau tambah kapasitas Node                       |
| `ErrImageNeverPull` | `imagePullPolicy: Never` tapi image tidak ada lokal                              | Push image ke registry atau ubah policy                             |

### 10.4 DNS Testing

```bash
# Jalankan Pod busybox untuk debugging network
kubectl run busybox --image=busybox:1.28 --rm -it --restart=Never -- /bin/sh

# Di dalam container:
nslookup nginx-service.praktikum.svc.cluster.local
wget -O- http://nginx-service.praktikum.svc.cluster.local
```

---

## 🌐 Bab 11: Ingress (Opsional — Tingkat Lanjut)

### 11.1 Aktifkan Ingress Controller di Minikube

```bash
minikube addons enable ingress
kubectl get pods -n ingress-nginx
```

### 11.2 Manifest Ingress

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: praktikum
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: nginx.local # Tambahkan ke /etc/hosts → <minikube ip> nginx.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-service
                port:
                  number: 80
```

```bash
kubectl apply -f ingress.yaml

# Dapatkan IP Minikube
minikube ip

# Tambahkan ke /etc/hosts (Linux/Mac)
echo "$(minikube ip) nginx.local" | sudo tee -a /etc/hosts

# Akses via browser: http://nginx.local
```

---

## 📝 Bab 12: Tugas Praktikum

### Tugas 1 — Instalasi dan Cluster Dasar

1. Install Minikube dan kubectl
2. Jalankan cluster Minikube dengan driver Docker
3. Verifikasi cluster berjalan dengan `kubectl get nodes`
4. Buka dan screenshot Kubernetes Dashboard
5. **Laporan:** Dokumentasikan setiap langkah dengan screenshot

### Tugas 2 — Deployment dan Scaling

1. Buat namespace bernama `<nim>-ns` (contoh: `e3220001-ns`)
2. Buat Deployment `hello-world` menggunakan image `gcr.io/google-samples/hello-app:1.0` dengan 2 replika
3. Buat Service bertipe NodePort untuk mengekspos Deployment tersebut
4. Akses aplikasi dari browser dan screenshot hasilnya
5. Scale Deployment menjadi 4 replika, verifikasi dengan `kubectl get pods`
6. **Laporan:** Sertakan semua manifest YAML yang digunakan

### Tugas 3 — Rolling Update dan Rollback

1. Update image Deployment dari `hello-app:1.0` ke `hello-app:2.0`
2. Pantau proses rolling update dengan `kubectl rollout status`
3. Verifikasi versi baru berjalan dengan mengakses service
4. Lakukan rollback ke versi 1.0
5. **Laporan:** Sertakan output `kubectl rollout history` sebelum dan sesudah rollback

### Tugas 4 — ConfigMap dan Secret (Lanjutan)

1. Buat ConfigMap berisi variabel konfigurasi aplikasi (minimal 3 key-value)
2. Buat Secret berisi username dan password database
3. Buat Deployment yang membaca nilai dari ConfigMap dan Secret sebagai environment variable
4. Verifikasi dengan `kubectl exec` dan perintah `env` di dalam container
5. **Laporan:** Sertakan semua manifest YAML dan bukti verifikasi

---

## 📚 Referensi dan Sumber Belajar

### Dokumentasi Resmi

- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [Minikube Getting Started](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl Cheatsheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

### Sertifikasi Industri (untuk pengembangan karir)

- **CKA** (Certified Kubernetes Administrator) — https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/
- **CKAD** (Certified Kubernetes Application Developer) — https://training.linuxfoundation.org/certification/certified-kubernetes-application-developer-ckad/

### Platform Latihan Online Gratis

- [Killercoda](https://killercoda.com/playgrounds/scenario/kubernetes) — Kubernetes playground di browser
- [Play with Kubernetes](https://labs.play-with-k8s.com/) — Lab K8s gratis 4 jam

---

## 🔖 Glosarium

| Istilah               | Definisi                                                              |
| --------------------- | --------------------------------------------------------------------- |
| **Cluster**           | Sekumpulan mesin (Node) yang menjalankan Kubernetes                   |
| **Control Plane**     | Komponen master yang mengatur seluruh cluster                         |
| **Worker Node**       | Mesin yang menjalankan beban kerja aplikasi (Pod)                     |
| **Pod**               | Unit terkecil di Kubernetes; membungkus satu atau lebih container     |
| **Deployment**        | Objek yang mengelola replika Pod dan rolling update                   |
| **Service**           | Abstraksi jaringan yang memberikan akses stabil ke Pod                |
| **Namespace**         | Pembatas virtual dalam satu cluster                                   |
| **Manifest**          | File YAML/JSON yang mendeskripsikan resource Kubernetes               |
| **kubectl**           | CLI resmi untuk berinteraksi dengan cluster Kubernetes                |
| **etcd**              | Database terdistribusi yang menyimpan state cluster                   |
| **kubelet**           | Agen di setiap Node yang memastikan container berjalan sesuai spec    |
| **ConfigMap**         | Objek untuk menyimpan konfigurasi non-sensitif                        |
| **Secret**            | Objek untuk menyimpan data sensitif (password, token, key)            |
| **Ingress**           | Objek yang mengatur akses HTTP/HTTPS dari luar cluster                |
| **HPA**               | Horizontal Pod Autoscaler — mengatur jumlah replika berdasarkan beban |
| **RBAC**              | Role-Based Access Control — sistem otorisasi berbasis peran           |
| **Rolling Update**    | Strategi update bertahap tanpa downtime                               |
| **Rollback**          | Kembali ke versi deployment sebelumnya                                |
| **Image Pull Policy** | Kebijakan kapan Kubernetes harus menarik image dari registry          |
| **Liveness Probe**    | Kubernetes cek apakah container masih hidup (restart jika gagal)      |
| **Readiness Probe**   | Kubernetes cek apakah container siap menerima traffic                 |

---
