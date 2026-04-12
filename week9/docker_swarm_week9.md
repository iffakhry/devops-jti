# Panduan Praktikum Docker Swarm
**Workshop Developer Operational — Minggu 9**
Program Studi D4 Teknik Informatika · Politeknik Negeri Jember

---

## Daftar Isi

1. [Capaian Pembelajaran](#1-capaian-pembelajaran)
2. [Glosarium Istilah](#2-glosarium-istilah)
3. [Dasar Teori](#3-dasar-teori)
4. [Perbandingan Docker Swarm vs Kubernetes](#4-perbandingan-docker-swarm-vs-kubernetes)
5. [Alat dan Bahan](#5-alat-dan-bahan)
6. [Konfigurasi Docker Swarm (1 Manager + 1 Worker)](#6-konfigurasi-docker-swarm-1-manager--1-worker)
7. [Mengelola Service pada Docker Swarm](#7-mengelola-service-pada-docker-swarm)
8. [High Availability dengan 3 Manager Nodes](#8-high-availability-dengan-3-manager-nodes)
9. [Docker Stack dan Declarative Deployment](#9-docker-stack-dan-declarative-deployment)
10. [Docker Secrets dan Keamanan Service](#10-docker-secrets-dan-keamanan-service)
11. [Rubrik Penilaian](#11-rubrik-penilaian)
12. [Pertanyaan Analisis dan Troubleshooting](#12-pertanyaan-analisis-dan-troubleshooting)

---

## 1. Capaian Pembelajaran

Setelah menyelesaikan praktikum ini, mahasiswa diharapkan mampu:

1. Memahami konsep dan arsitektur Docker Swarm beserta posisinya di ekosistem container orchestration modern.
2. Mengonfigurasi Docker Swarm dengan topologi minimal (1 manager, 1 worker) maupun topologi high availability (3 manager nodes).
3. Membuat, memperbarui, men-scale, dan me-rollback service pada Docker Swarm.
4. Menggunakan Docker Stack dengan file YAML untuk melakukan declarative deployment — pendekatan yang digunakan di industri.
5. Mengelola secrets untuk menyimpan kredensial secara aman.
6. Memahami kapan sebaiknya menggunakan Docker Swarm dan kapan sebaiknya beralih ke Kubernetes.

---

## 2. Glosarium Istilah

Berikut adalah penjelasan istilah-istilah teknis yang akan ditemui dalam praktikum ini:

| Istilah | Penjelasan |
|---|---|
| **Container** | Unit terkecil yang dapat dijalankan, berisi aplikasi beserta semua dependensinya. Terisolasi dari container lain dan dari sistem host. |
| **Container Orchestration** | Proses otomatis untuk mengelola, menjadwalkan, dan menskalakan banyak container di beberapa mesin (node) sekaligus. |
| **Docker Swarm** | Fitur bawaan Docker untuk container orchestration. Beberapa mesin (host) yang menjalankan Docker dapat digabungkan menjadi sebuah cluster yang dikelola secara terpusat. |
| **Cluster** | Kumpulan beberapa mesin (node) yang bekerja bersama dan dikelola sebagai satu kesatuan. |
| **Node** | Sebuah mesin (fisik atau virtual) yang menjadi anggota cluster Docker Swarm. |
| **Manager Node** | Node yang bertanggung jawab mengelola state cluster, menjadwalkan service ke worker, dan menjaga konsistensi konfigurasi. |
| **Worker Node** | Node yang menerima instruksi dari manager dan menjalankan container (task) yang ditugaskan kepadanya. |
| **Service** | Definisi dari task yang ingin dijalankan di dalam Swarm. Berisi informasi image yang digunakan, jumlah replika, port yang dibuka, dll. |
| **Task** | Satu unit pekerjaan dalam Swarm — yaitu satu container yang dijalankan sebagai bagian dari sebuah service. |
| **Replica** | Salinan dari sebuah container yang menjalankan service yang sama. Semakin banyak replika, semakin tinggi ketersediaan dan kapasitas service. |
| **Overlay Network** | Jaringan virtual yang dibuat Swarm agar container yang berjalan di node berbeda dapat saling berkomunikasi seolah berada dalam satu jaringan lokal yang sama. |
| **Ingress Network** | Overlay network khusus yang menangani routing traffic dari luar cluster ke service yang tepat di dalam cluster (routing mesh). |
| **Service Discovery** | Kemampuan container untuk menemukan dan berkomunikasi dengan container/service lain menggunakan nama service (bukan IP address) — dikelola otomatis oleh Swarm. |
| **High Availability (HA)** | Kemampuan sistem untuk tetap berjalan meskipun salah satu atau beberapa komponen mengalami kegagalan. |
| **Raft Consensus** | Algoritma yang digunakan manager nodes untuk sepakat (konsensus) mengenai state cluster. Membutuhkan lebih dari setengah manager aktif (quorum) untuk mengambil keputusan. |
| **Quorum** | Jumlah minimum manager nodes yang harus aktif agar cluster dapat beroperasi. Untuk N manager, quorum = floor(N/2) + 1. |
| **Rolling Update** | Strategi update service di mana container diganti satu per satu (atau sekelompok kecil) secara bertahap, sehingga service tidak pernah sepenuhnya mati selama proses update. |
| **Rollback** | Mengembalikan service ke versi konfigurasi sebelumnya apabila update mengalami masalah. |
| **Docker Stack** | Cara mendefinisikan dan menjalankan sekumpulan service terkait menggunakan file YAML (docker-compose format). Pendekatan ini disebut *declarative deployment*. |
| **Declarative Deployment** | Pendekatan deployment di mana kita mendefinisikan *apa* yang kita inginkan (di dalam file YAML) dan membiarkan sistem mengurus *bagaimana* mencapai kondisi tersebut — berbeda dengan *imperative* yang menulis perintah satu per satu. |
| **Docker Secret** | Fitur Swarm untuk menyimpan data sensitif (password, API key, certificate) secara terenkripsi, sehingga tidak perlu ditulis secara plain-text di kode atau environment variable. |
| **Kubernetes (K8s)** | Platform container orchestration open-source yang dikembangkan oleh Google. Saat ini menjadi standar industri untuk production workload berskala besar. |
| **VPS (Virtual Private Server)** | Mesin virtual yang berjalan di atas server fisik. Pada praktikum ini disimulasikan menggunakan Multipass. |
| **Multipass** | Tool dari Canonical (pembuat Ubuntu) untuk membuat dan mengelola VM Ubuntu secara cepat di atas Windows, macOS, atau Linux. |

---

## 3. Dasar Teori

### 3.1 Apa itu Docker Swarm?

Docker Swarm adalah fitur orkestrasi container yang sudah terintegrasi langsung di dalam Docker Engine. Docker Swarm memungkinkan kita menggabungkan beberapa mesin (host) yang menjalankan Docker ke dalam sebuah **cluster**, kemudian mengelola semua container di cluster tersebut dari satu titik komando.

Dengan Swarm, kita mendefinisikan sebuah **service** (misalnya: "jalankan aplikasi web saya dengan 3 replika"), dan Swarm akan otomatis:
- Memilih node yang tepat untuk menjalankan setiap replika.
- Memastikan jumlah replika selalu sesuai (jika satu container mati, Swarm akan menghidupkan yang baru).
- Mendistribusikan traffic ke semua replika yang berjalan.
- Melakukan rolling update tanpa downtime saat kita memperbarui versi aplikasi.

### 3.2 Arsitektur Docker Swarm

```
                    ┌─────────────────────────────────┐
                    │         Docker Swarm Cluster      │
                    │                                   │
  Pengguna ──────►  │  ┌──────────────────────────┐   │
  (CLI / API)       │  │     Manager Node(s)       │   │
                    │  │  - Menjadwalkan service   │   │
                    │  │  - Menjaga state cluster  │   │
                    │  │  - Raft consensus         │   │
                    │  └──────────┬───────────────-┘   │
                    │             │  instruksi          │
                    │    ┌────────┴────────┐           │
                    │    ▼                 ▼           │
                    │  ┌──────────┐  ┌──────────┐     │
                    │  │ Worker 1 │  │ Worker 2 │     │
                    │  │ [Task A] │  │ [Task A] │     │
                    │  │ [Task B] │  │ [Task C] │     │
                    │  └──────────┘  └──────────┘     │
                    │         Overlay Network           │
                    └─────────────────────────────────┘
```

**Manager Node** bertugas sebagai "otak" cluster. Manager menerima perintah dari pengguna, menjadwalkan di mana service harus dijalankan, dan memastikan kondisi cluster selalu sesuai dengan yang diinginkan.

**Worker Node** adalah "tangan" cluster. Worker menerima instruksi dari manager dan menjalankan container (task) yang ditugaskan.

> **Catatan:** Sebuah Manager Node juga dapat menjalankan task (bertindak sebagai worker sekaligus). Namun di lingkungan production, sering kali manager dikonfigurasi agar tidak menjalankan task supaya resource-nya murni untuk manajemen cluster.

### 3.3 Mengapa High Availability Memerlukan 3 Manager?

Ini adalah salah satu konsep paling penting dalam Swarm. Bayangkan kamu punya satu manager saja — jika mesin itu mati, seluruh cluster tidak bisa dikelola. Untuk mengatasi ini, kita menjalankan beberapa manager.

Docker Swarm menggunakan algoritma **Raft Consensus** untuk menjaga konsistensi di antara semua manager. Raft mengharuskan lebih dari setengah manager aktif (**quorum**) untuk mengambil keputusan.

| Jumlah Manager | Quorum | Toleransi Kegagalan |
|:-:|:-:|:-:|
| 1 | 1 | 0 (tidak ada HA) |
| 2 | 2 | 0 (tetap tidak ada HA) |
| **3** | **2** | **1 node bisa mati** |
| 5 | 3 | 2 node bisa mati |
| 7 | 4 | 3 node bisa mati |

Itulah mengapa **3 manager adalah konfigurasi minimum yang direkomendasikan** untuk production — karena jika 1 manager mati, cluster masih memiliki quorum (2 dari 3) dan tetap dapat beroperasi.

### 3.4 Overlay Network dan Service Discovery

Ketika Docker Swarm membuat cluster, secara otomatis ia membuat sebuah **overlay network** bernama `ingress`. Overlay network ini memungkinkan container yang berjalan di node yang berbeda-beda untuk saling berkomunikasi seolah berada dalam satu jaringan lokal.

Selain itu, Swarm memiliki fitur **service discovery** bawaan: container dapat menjangkau service lain hanya dengan menyebut **nama service**-nya, bukan IP address. Swarm akan secara otomatis mengarahkan request ke salah satu replika yang aktif.

```
Container A ──► "http://backend/" ──► [Swarm DNS] ──► Container B (replika manapun)
```

Ini sangat berguna karena IP address container bisa berubah, tetapi nama service selalu konsisten.

Port-port yang perlu dibuka di firewall untuk Docker Swarm:

| Port | Protokol | Fungsi |
|---|---|---|
| `2377` | TCP | Komunikasi manajemen cluster antar manager |
| `7946` | TCP & UDP | Komunikasi antar node (gossip protocol) |
| `4789` | UDP | Traffic overlay network (VXLAN) |

---

## 4. Perbandingan Docker Swarm vs Kubernetes

Di industri, pertanyaan ini selalu muncul: *"Kapan pakai Swarm, kapan pakai Kubernetes?"* Memahami perbedaan ini akan membantu kamu dalam mengambil keputusan arsitektur yang tepat di pekerjaan.

| Aspek | Docker Swarm | Kubernetes |
|---|---|---|
| **Kompleksitas setup** | Sangat mudah, built-in di Docker | Kompleks, butuh instalasi terpisah |
| **Kurva pembelajaran** | Landai — cocok untuk pemula | Curam — butuh waktu lebih lama |
| **Skalabilitas** | Baik untuk ratusan node | Sangat baik untuk ribuan node |
| **Ekosistem** | Terbatas pada Docker | Sangat luas (CNCF ecosystem) |
| **Auto-scaling** | Manual (perlu scripting) | Otomatis (HPA, VPA) |
| **Monitoring bawaan** | Tidak ada | Tidak ada, tapi ekosistem kaya |
| **Adopsi industri** | Digunakan di perusahaan kecil-menengah | Standar di perusahaan besar dan cloud provider |
| **Managed service** | Tidak ada yang populer | GKE (Google), EKS (AWS), AKS (Azure) |
| **Update cadence** | Lambat | Aktif dikembangkan |

**Kapan pilih Docker Swarm:**
- Tim kecil yang sudah familiar dengan Docker dan butuh orkestrasi sederhana.
- Aplikasi dengan traffic yang relatif stabil dan tidak membutuhkan auto-scaling kompleks.
- Edge computing atau lingkungan dengan resource terbatas.
- Proyek yang butuh waktu setup singkat.

**Kapan pilih Kubernetes:**
- Aplikasi skala besar dengan ratusan hingga ribuan container.
- Butuh auto-scaling yang canggih berdasarkan metrik kustom.
- Tim yang bekerja di perusahaan yang sudah menggunakan cloud provider (GCP, AWS, Azure).
- Butuh ekosistem tooling yang kaya (service mesh, advanced monitoring, dll).

> **Pesan untuk mahasiswa:** Mempelajari Swarm memberikan fondasi konsep yang kuat (node, service, overlay network, rolling update) yang langsung dapat diterapkan saat belajar Kubernetes nantinya. Konsepnya sangat mirip, hanya berbeda dalam skala dan cara konfigurasi.

---

## 5. Alat dan Bahan

- PC/Laptop dengan RAM minimal 8 GB (untuk menjalankan beberapa VM)
- **Multipass** (download di [multipass.run](https://multipass.run)) — untuk membuat VM Ubuntu
- Koneksi internet (untuk mengunduh Docker dan image container)
- Kertas catatan atau text editor untuk mencatat output perintah

---

## 6. Konfigurasi Docker Swarm (1 Manager + 1 Worker)

### 6.1 Membuat Instance VM dengan Multipass

Kita membutuhkan 2 VM: satu sebagai **manager** dan satu sebagai **worker**.

```bash
# Buat VM manager
multipass launch --name manager --cpus 1 --memory 1G --disk 6G

# Buat VM worker
multipass launch --name worker --cpus 1 --memory 1G --disk 6G

# Verifikasi kedua instance berjalan
multipass list
```

Output yang diharapkan:
```
Name                    State             IPv4             Image
manager                 Running           192.168.64.x     Ubuntu 22.04 LTS
worker                  Running           192.168.64.y     Ubuntu 22.04 LTS
```

Catat kedua IP address tersebut — akan sering digunakan sepanjang praktikum.

### 6.2 Persiapan Jaringan dan Firewall

Masuk ke setiap VM dan lakukan pengecekan jaringan:

```bash
# Masuk ke VM manager
multipass shell manager

# Cek IP address
ip a

# Uji konektivitas ke worker (ganti dengan IP worker kamu)
ping -c 4 <IP_WORKER>

# Cek status firewall
sudo ufw status
```

Jika firewall aktif, buka port yang diperlukan Docker Swarm:

```bash
sudo ufw allow 2377/tcp   # Manajemen cluster
sudo ufw allow 7946/tcp   # Komunikasi antar node
sudo ufw allow 7946/udp
sudo ufw allow 4789/udp   # Overlay network (VXLAN)
sudo ufw reload
```

Lakukan hal yang sama di VM worker.

> **Mengapa port ini penting?**
> - Port `2377/tcp` adalah "pintu utama" tempat worker berkomunikasi dengan manager untuk mendapatkan instruksi.
> - Port `7946` digunakan untuk gossip protocol — cara node saling "berbisik" tentang kondisi masing-masing.
> - Port `4789/udp` adalah port untuk protokol VXLAN yang membentuk overlay network. Tanpa port ini, container di node berbeda tidak bisa saling berkomunikasi.

### 6.3 Instalasi Docker

Lakukan instalasi Docker di **kedua** VM (manager dan worker):

```bash
# Update package list
sudo apt-get update

# Install dependensi
sudo apt-get install -y ca-certificates curl

# Tambahkan Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Tambahkan Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Tambahkan user ke grup docker (agar tidak perlu sudo setiap perintah docker)
sudo usermod -aG docker $USER
newgrp docker

# Verifikasi instalasi
docker --version
```

### 6.4 Inisiasi Docker Swarm di Manager

Jalankan perintah berikut **di VM manager**:

```bash
# Ganti <IP_MANAGER> dengan IP address VM manager kamu
docker swarm init --advertise-addr <IP_MANAGER>
```

Output yang diharapkan:
```
Swarm initialized: current node (xxxxxxxxxxxx) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-xxxxxxxx... <IP_MANAGER>:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
```

> **Apa yang terjadi?** Perintah `docker swarm init` mengubah Docker Engine di mesin ini menjadi manager pertama (dan satu-satunya, untuk saat ini) dari sebuah Swarm baru. `--advertise-addr` memberitahu Swarm alamat IP mana yang harus digunakan oleh node lain untuk terhubung ke manager ini.

Salin **seluruh** perintah `docker swarm join ...` dari output tersebut.

### 6.5 Menambahkan Worker ke Swarm

Jalankan perintah join yang tadi disalin **di VM worker**:

```bash
docker swarm join --token SWMTKN-1-<token-kamu> <IP_MANAGER>:2377
```

Output yang diharapkan:
```
This node joined a swarm as a worker.
```

### 6.6 Verifikasi Cluster

Kembali ke **VM manager** dan verifikasi cluster:

```bash
# Lihat semua node dalam cluster
docker node ls
```

Output yang diharapkan:
```
ID                            HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
xxxxxxxxxxxxxxxxxxxx *        manager    Ready     Active         Leader           24.0.x
yyyyyyyyyyyyyyyyyyyy          worker     Ready     Active                          24.0.x
```

Kolom `MANAGER STATUS` menunjukkan `Leader` pada manager — artinya node ini yang aktif memimpin cluster. Tanda bintang (*) menunjukkan node tempat kamu menjalankan perintah.

```bash
# Perintah berguna lainnya
docker info | grep -i swarm           # Cek status swarm (Active/Inactive)
docker swarm join-token worker        # Tampilkan token untuk worker baru
docker swarm join-token manager       # Tampilkan token untuk menambah manager
```

---

## 7. Mengelola Service pada Docker Swarm

### 7.1 Membuat Service

Service adalah cara kita mendefinisikan "apa yang ingin dijalankan" di dalam Swarm. Jalankan perintah berikut **di manager**:

```bash
# Buat service nginx dengan 2 replika, publish port 80
docker service create \
  --name web \
  --replicas 2 \
  --publish published=80,target=80 \
  nginx:latest
```

Penjelasan parameter:
- `--name web` : nama service
- `--replicas 2` : Swarm akan menjalankan 2 container nginx
- `--publish published=80,target=80` : port 80 di host akan diteruskan ke port 80 di container

```bash
# Cek status service
docker service ls

# Lihat di node mana setiap replika berjalan
docker service ps web
```

Output `docker service ps web`:
```
ID             NAME      IMAGE          NODE      DESIRED STATE   CURRENT STATE
aaaaaaaaaa     web.1     nginx:latest   manager   Running         Running 30s ago
bbbbbbbbbb     web.2     nginx:latest   worker    Running         Running 29s ago
```

Perhatikan bahwa Swarm secara otomatis mendistribusikan 2 replika ke 2 node yang berbeda.

Akses service melalui browser dengan URL `http://<IP_MANAGER>` dan `http://<IP_WORKER>` — keduanya akan menampilkan halaman nginx yang sama, berkat **ingress routing mesh**.

> **Apa itu ingress routing mesh?**
> Meski sebuah replika mungkin hanya berjalan di node tertentu, kamu bisa mengakses service dari IP address node **manapun** di dalam cluster. Swarm secara otomatis mengarahkan traffic ke replika yang aktif — inilah yang disebut ingress routing mesh.

### 7.2 Scaling Service

```bash
# Tambah replika menjadi 4
docker service scale web=4

# Verifikasi
docker service ps web
```

### 7.3 Rolling Update

Ini adalah salah satu fitur paling berharga dari Swarm. Kita akan mengupdate image dari `nginx:latest` ke image lain tanpa downtime:

```bash
# Update image service
docker service update \
  --image nginx:1.25 \
  --update-parallelism 1 \
  --update-delay 10s \
  web
```

Penjelasan parameter update:
- `--image nginx:1.25` : image baru yang akan digunakan
- `--update-parallelism 1` : update 1 replika dalam satu waktu (tidak sekaligus)
- `--update-delay 10s` : tunggu 10 detik sebelum update replika berikutnya

```bash
# Monitor proses update secara real-time
docker service ps web
```

Selama proses update berlangsung, service tetap dapat diakses karena replika yang belum diupdate masih melayani traffic.

### 7.4 Rollback Service

Jika update bermasalah, kita dapat dengan mudah kembali ke versi sebelumnya:

```bash
# Rollback ke konfigurasi sebelumnya
docker service rollback web

# Verifikasi
docker service ps web
docker service inspect web --pretty
```

> **Mengapa rollback penting?**
> Di production, tidak jarang sebuah update ternyata menyebabkan bug atau penurunan performa. Kemampuan rollback yang cepat adalah salah satu alasan utama menggunakan container orchestrator — kita tidak perlu mengembalikan kode secara manual di setiap server.

### 7.5 Inspeksi dan Monitoring Service

```bash
# Detail lengkap service (format mudah dibaca)
docker service inspect web --pretty

# Hanya tampilkan replika yang sedang running
docker service ps web --filter "desired-state=running"

# Lihat log dari semua replika sekaligus
docker service logs web

# Ikuti log secara real-time
docker service logs -f web
```

### 7.6 Menghapus Service

```bash
docker service rm web
```

### 7.7 Node Meninggalkan Swarm

```bash
# Di node worker:
docker swarm leave

# Di node manager (membutuhkan --force):
docker swarm leave --force
```

---

## 8. High Availability dengan 3 Manager Nodes

Pada bab ini, kita akan membangun topologi yang mendekati **production-ready**: 3 manager nodes untuk high availability.

### 8.1 Membuat 3 VM Baru

Buat 3 VM baru menggunakan Multipass (atau gunakan kembali yang lama jika resources cukup):

```bash
# Buat 3 instance (di luar Multipass, di terminal host)
multipass launch --name mgr1 --cpus 1 --memory 1G --disk 6G
multipass launch --name mgr2 --cpus 1 --memory 1G --disk 6G
multipass launch --name mgr3 --cpus 1 --memory 1G --disk 6G

multipass list
```

Install Docker di ketiga VM (ulangi langkah-langkah instalasi Docker pada subbab 6.3 di setiap VM).

### 8.2 Inisiasi Swarm di Manager Pertama

```bash
# Di mgr1
docker swarm init --advertise-addr <IP_MGR1>
```

### 8.3 Mendapatkan Token Manager

Berbeda dengan token worker, untuk menambahkan node sebagai **manager** kita membutuhkan token khusus:

```bash
# Di mgr1 — tampilkan token untuk bergabung sebagai manager
docker swarm join-token manager
```

Output:
```
To add a manager to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-XXXXXX-MGRTOKEN <IP_MGR1>:2377
```

### 8.4 Menambahkan mgr2 dan mgr3 sebagai Manager

```bash
# Di mgr2 — jalankan perintah join dengan token manager
docker swarm join --token SWMTKN-1-XXXXXX-MGRTOKEN <IP_MGR1>:2377

# Di mgr3 — sama
docker swarm join --token SWMTKN-1-XXXXXX-MGRTOKEN <IP_MGR1>:2377
```

### 8.5 Verifikasi Cluster 3 Manager

```bash
# Di mgr1
docker node ls
```

Output yang diharapkan:
```
ID                            HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
aaaaaaaaaaaaaaaaaaaaaaaaa *   mgr1       Ready     Active         Leader           24.0.x
bbbbbbbbbbbbbbbbbbbbbbbbb     mgr2       Ready     Active         Reachable        24.0.x
ccccccccccccccccccccccccc     mgr3       Ready     Active         Reachable        24.0.x
```

Kolom `MANAGER STATUS` sekarang menunjukkan:
- `Leader` : manager aktif yang saat ini memimpin
- `Reachable` : manager yang aktif dan dapat menjadi leader jika leader saat ini mati

### 8.6 Simulasi Kegagalan Manager (Fault Tolerance Test)

Ini adalah momen paling penting dalam latihan ini. Kita akan mensimulasikan kegagalan manager Leader dan mengamati apa yang terjadi.

**Langkah 1:** Deploy sebuah service terlebih dahulu:
```bash
# Di mgr1
docker service create --name web --replicas 3 --publish 80:80 nginx
docker service ls
```

**Langkah 2:** "Matikan" mgr1 (simulasi kegagalan):
```bash
# Di terminal host (bukan di dalam VM)
multipass stop mgr1
```

**Langkah 3:** Amati cluster dari mgr2:
```bash
# Di mgr2
docker node ls
```

Output yang diharapkan:
```
ID                            HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
aaaaaaaaaaaaaaaaaaaaaaaaa     mgr1       Down      Active         Unreachable      24.0.x
bbbbbbbbbbbbbbbbbbbbbbbbb *   mgr2       Ready     Active         Leader           24.0.x
ccccccccccccccccccccccccc     mgr3       Ready     Active         Reachable        24.0.x
```

Perhatikan bahwa mgr2 **otomatis terpilih sebagai Leader baru** melalui algoritma Raft. Cluster tetap beroperasi!

```bash
# Cek apakah service masih berjalan
docker service ls
docker service ps web
```

Service tetap berjalan. Inilah arti sebenarnya dari **High Availability**.

**Langkah 4:** Hidupkan kembali mgr1:
```bash
# Di terminal host
multipass start mgr1
```

```bash
# Di mgr2 — mgr1 akan kembali sebagai Reachable (bukan Leader)
docker node ls
```

### 8.7 Memahami Quorum

Coba matikan 2 manager sekaligus (mgr1 dan mgr2) dan amati apa yang terjadi pada mgr3:

```bash
# Di terminal host
multipass stop mgr1
multipass stop mgr2
```

```bash
# Di mgr3 — coba jalankan perintah
docker service ls
```

Output: **Error** — cluster tidak dapat beroperasi karena quorum tidak terpenuhi (hanya 1 dari 3 manager yang aktif, butuh minimal 2).

Ini membuktikan: dengan 3 manager, hanya boleh ada **1 kegagalan** yang ditoleransi. Kembalikan VM setelah observasi:

```bash
multipass start mgr1
multipass start mgr2
```

---

## 9. Docker Stack dan Declarative Deployment

Di industri, tidak ada engineer yang membuat service satu per satu menggunakan perintah `docker service create`. Cara yang digunakan adalah **Docker Stack** — mendefinisikan seluruh aplikasi (yang bisa terdiri dari banyak service) dalam sebuah file YAML.

> **Mengapa declarative lebih baik?**
> - File YAML bisa disimpan di version control (Git) — sehingga ada riwayat setiap perubahan.
> - Mudah direproduksi di lingkungan berbeda (development, staging, production).
> - Seluruh tim bisa melihat konfigurasi aplikasi hanya dengan membaca satu file.
> - Mudah diintegrasikan dengan CI/CD pipeline.

### 9.1 Anatomi File docker-compose.yml untuk Swarm

Buat file bernama `docker-stack.yml`:

```yaml
version: '3.8'

services:

  # Service web: aplikasi frontend
  web:
    image: nginx:1.25
    ports:
      - "80:80"
    deploy:
      replicas: 3
      update_config:
        parallelism: 1        # Update 1 replika per waktu
        delay: 10s            # Tunggu 10 detik antar update
        failure_action: rollback  # Otomatis rollback jika update gagal
      restart_policy:
        condition: on-failure  # Restart container jika crash
        max_attempts: 3
      placement:
        constraints:
          - node.role == worker  # Hanya jalankan di worker node
    networks:
      - webnet

  # Service database
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: admin
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password  # Baca dari secret
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager  # Sematkan di manager (atau node tertentu)
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - webnet
    secrets:
      - db_password

networks:
  webnet:
    driver: overlay  # Overlay network agar semua node bisa saling terhubung

volumes:
  db_data:

secrets:
  db_password:
    external: true  # Secret sudah dibuat terlebih dahulu di luar stack
```

### 9.2 Deploy Stack

```bash
# Deploy stack dengan nama "myapp"
docker stack deploy -c docker-stack.yml myapp

# Lihat semua stack yang berjalan
docker stack ls

# Lihat service-service dalam stack "myapp"
docker stack services myapp

# Lihat detail task dari setiap service
docker stack ps myapp
```

### 9.3 Update Stack

Untuk melakukan update, cukup ubah file YAML (misalnya ganti `replicas: 3` menjadi `replicas: 5`), lalu jalankan ulang perintah deploy:

```bash
# Edit docker-stack.yml (ubah replicas web menjadi 5)
# Kemudian jalankan lagi:
docker stack deploy -c docker-stack.yml myapp
```

Swarm akan **hanya menerapkan perubahan** yang ada — tidak perlu menghapus dan membuat ulang seluruh stack.

### 9.4 Menghapus Stack

```bash
docker stack rm myapp
```

### 9.5 Placement Constraint

Placement constraint adalah cara kita menentukan di node mana sebuah service harus dijalankan. Ini berguna misalnya untuk:
- Memastikan database hanya berjalan di node dengan storage SSD.
- Memastikan service publik hanya berjalan di node yang memiliki IP publik.

```bash
# Tambahkan label pada sebuah node
docker node update --label-add storage=ssd mgr1

# Di docker-stack.yml, gunakan label tersebut:
# placement:
#   constraints:
#     - node.labels.storage == ssd
```

---

## 10. Docker Secrets dan Keamanan Service

### 10.1 Mengapa Secrets Itu Penting?

Perhatikan contoh buruk berikut:

```bash
# ❌ BURUK — jangan pernah lakukan ini di production!
docker service create \
  --env POSTGRES_PASSWORD=rahasia123 \
  postgres
```

Masalahnya:
- Password terlihat jelas di history shell (`history` command).
- Password muncul di output `docker inspect`.
- Siapapun yang bisa menjalankan `docker inspect` bisa melihat password.
- Password tersimpan plain-text di log CI/CD.

**Docker Secrets** menyelesaikan semua masalah ini. Secret dienkripsi saat transit (TLS) dan saat disimpan (encrypted Raft log), dan hanya didekripsi di memory pada container yang membutuhkannya.

### 10.2 Membuat Secret

```bash
# Cara 1: dari input langsung (cocok untuk development)
echo "P@ssw0rdRahasia!" | docker secret create db_password -

# Cara 2: dari file (lebih aman, file bisa dihapus setelahnya)
echo "P@ssw0rdRahasia!" > password.txt
docker secret create db_password password.txt
rm password.txt  # Hapus file setelah secret dibuat!

# Cara 3: dari file .env (untuk multiple secrets)
docker secret create ssl_cert ./certs/server.crt
```

### 10.3 Melihat Daftar Secret

```bash
# Daftar semua secret
docker secret ls

# Detail secret (isi/value tidak akan ditampilkan!)
docker secret inspect db_password
```

### 10.4 Menggunakan Secret dalam Service

```bash
docker service create \
  --name mydb \
  --secret db_password \
  --env POSTGRES_PASSWORD_FILE=/run/secrets/db_password \
  postgres:15
```

Secret akan di-mount sebagai file di `/run/secrets/<nama-secret>` di dalam container. Aplikasi membaca password dari file tersebut, bukan dari environment variable.

```bash
# Verifikasi secret ter-mount di dalam container
docker exec -it <container-id> cat /run/secrets/db_password
```

### 10.5 Secret dalam Docker Stack (YAML)

Cara paling praktis menggunakan secret bersama Stack:

```yaml
version: '3.8'

services:
  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
      POSTGRES_DB: myapp
      POSTGRES_USER: admin
    secrets:
      - db_password
    deploy:
      replicas: 1

secrets:
  db_password:
    external: true  # Secret sudah dibuat dengan "docker secret create"
```

> **Catatan:** Secret hanya bisa dibuat dan digunakan di dalam Swarm (bukan di mode standalone Docker). Secret juga bersifat **immutable** — jika ingin mengganti isi secret, hapus dan buat ulang dengan nama baru, lalu update service.

### 10.6 Menghapus Secret

```bash
# Secret tidak bisa dihapus jika masih digunakan oleh service
docker service update --secret-rm db_password mydb
docker secret rm db_password
```

---

## 11. Rubrik Penilaian

### Penilaian Praktikum (Bobot: 60%)

| No | Indikator | Skor |
|---|---|:-:|
| 1 | Ketepatan waktu dan seluruh langkah kerja dikerjakan dengan benar | 4 |
| 2 | Ketepatan waktu namun ada 1–2 langkah yang kurang tepat | 3 |
| 3 | Terlambat namun langkah kerja sebagian besar benar | 2 |
| 4 | Terlambat dan banyak langkah kerja yang tidak sesuai | 1 |

**Total Skor Praktikum = Skor × 25**

### Penilaian Pemahaman Konsep (Bobot: 40%)

| No | Indikator | Skor |
|---|---|:-:|
| 1 | Mampu menjelaskan konsep dengan tepat dan memberikan analisis tambahan | 4 |
| 2 | Mampu menjelaskan konsep dengan tepat | 3 |
| 3 | Penjelasan konsep sebagian benar | 2 |
| 4 | Tidak mampu menjelaskan konsep | 1 |

**Total Skor Pemahaman = Skor × 25**

---

## 12. Pertanyaan Analisis dan Troubleshooting

Jawab pertanyaan berikut sebagai bagian dari laporan praktikum. Pertanyaan ini dirancang untuk mengasah kemampuan berpikir analitis seperti yang diharapkan di dunia kerja.

### Pertanyaan Konsep

1. Jelaskan dengan kata-kata sendiri perbedaan antara **Manager Node** dan **Worker Node**. Apa yang terjadi jika satu-satunya Manager Node dalam cluster mati?

2. Sebuah perusahaan memiliki 5 server dan ingin menjalankan Docker Swarm. Mereka bertanya: "Berapa banyak server yang harus dijadikan Manager?" Berikan rekomendasi dan jelaskan alasannya menggunakan konsep quorum.

3. Apa perbedaan antara pendekatan **imperative** (menggunakan `docker service create` satu per satu) dengan pendekatan **declarative** (menggunakan `docker stack deploy` dengan file YAML)? Mana yang lebih cocok untuk lingkungan production dan mengapa?

4. Mengapa menyimpan password database di environment variable (`--env POSTGRES_PASSWORD=...`) dianggap praktik yang buruk? Apa solusi yang ditawarkan Docker Swarm?

### Pertanyaan Troubleshooting

5. Kamu menjalankan `docker node ls` di manager dan mendapati salah satu node berstatus `Down`. Apa langkah-langkah yang akan kamu lakukan untuk mendiagnosis dan memperbaiki masalah ini?

6. Setelah melakukan `docker service update`, beberapa replika berstatus `Failed`. Bagaimana cara kamu mendeteksi masalah ini, melihat log error, dan melakukan rollback?

7. Kamu memiliki cluster dengan 3 manager. Dua manager sekaligus mati. Apa yang terjadi pada cluster? Apakah service yang sudah berjalan ikut mati? Bagaimana cara memulihkannya?

### Pertanyaan Pengembangan

8. Bayangkan kamu diminta memilih antara Docker Swarm dan Kubernetes untuk sebuah startup e-commerce dengan 5 developer dan traffic ~10.000 pengunjung/hari. Apa rekomendasimu dan apa alasannya?

9. Dalam file `docker-stack.yml`, apa fungsi dari konfigurasi `update_config.failure_action: rollback`? Kapan konfigurasi ini akan aktif?

10. Buat diagram sederhana (bisa digambar tangan atau teks ASCII) yang menggambarkan arsitektur cluster dengan 3 manager dan 2 worker yang menjalankan sebuah web service dengan 5 replika. Tunjukkan di node mana saja replika kemungkinan besar akan ditempatkan.

---

*Panduan ini merupakan materi tambahan yang mengacu pada praktik Docker Swarm di industri saat ini. Untuk referensi lebih lanjut, kunjungi dokumentasi resmi di [docs.docker.com/engine/swarm](https://docs.docker.com/engine/swarm/).*
