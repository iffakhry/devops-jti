# Monitoring dengan Prometheus & Grafana

---

## 📚 Dasar Teori

### 1. Observability — Konsep Kunci di Industri

Di industri modern, sistem tidak cukup hanya "berjalan" — harus bisa **diobservasi**. Observability (kemampuan untuk memahami kondisi internal sistem dari data eksternalnya) bertumpu pada tiga pilar:

```
┌─────────────────────────────────────────────────────┐
│                   OBSERVABILITY                     │
│                                                     │
│   📊 METRICS      📝 LOGS       🔍 TRACES           │
│   (Prometheus)  (Loki/ELK)   (Jaeger/Tempo)        │
│                                                     │
│   "Apa yang      "Apa yang     "Di mana             │
│    terjadi?"      terjadi?"    bottleneck-nya?"     │
└─────────────────────────────────────────────────────┘
```

Praktikum ini fokus pada **pilar pertama: Metrics**, menggunakan Prometheus sebagai pengumpul data dan Grafana sebagai visualisasi.

### 2. Prometheus

**Prometheus** adalah sistem monitoring dan alerting open-source yang dikembangkan oleh SoundCloud (2012) dan kini menjadi proyek CNCF (Cloud Native Computing Foundation). Digunakan oleh perusahaan seperti GitLab, Shopify, DigitalOcean, dan ribuan perusahaan lainnya.

**Komponen utama:**

```
┌──────────────────────────────────────────────────────────────┐
│                    ARSITEKTUR PROMETHEUS                     │
│                                                              │
│  ┌─────────────┐     PULL (scrape)    ┌──────────────────┐  │
│  │ Node        │◄────────────────────│                  │  │
│  │ Exporter    │     tiap 15s         │  Prometheus      │  │
│  │ :9100       │                      │  Server :9090    │  │
│  └─────────────┘                      │                  │  │
│                                       │  [Time Series DB]│  │
│  ┌─────────────┐     PULL (scrape)    │                  │  │
│  │ App Metrics │◄────────────────────│                  │  │
│  │ /metrics    │                      └──────────────────┘  │
│  └─────────────┘                              │              │
│                                               │ PromQL       │
│  ┌─────────────┐     PUSH alerts      ┌──────▼───────────┐  │
│  │Alert        │◄────────────────────│                  │  │
│  │Manager      │                      │    Grafana       │  │
│  │:9093        │                      │    :3000         │  │
│  └─────────────┘                      └──────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

**Model Pull vs Push:**

- Prometheus menggunakan **pull model** — Prometheus yang aktif mengambil data dari target
- Berbeda dengan push model (InfluxDB, Graphite) di mana aplikasi yang mengirimkan data
- Keuntungan pull: Prometheus tahu persis apakah target sedang down atau tidak

### 3. Grafana

**Grafana** adalah platform visualisasi dan analisis data open-source yang bisa terhubung ke berbagai sumber data (Prometheus, MySQL, PostgreSQL, Loki, InfluxDB, dll.). Grafana Labs juga menyediakan layanan cloud (Grafana Cloud) yang banyak digunakan di industri.

**Fitur utama:**

- **Dashboards** yang dapat dikustomisasi dengan berbagai tipe panel
- **Alerting** yang terintegrasi dengan berbagai channel notifikasi (Slack, Email, PagerDuty, dll.)
- **Explore** untuk analisis ad-hoc menggunakan PromQL
- **Provisioning** untuk menyimpan konfigurasi dashboard sebagai kode (GitOps-friendly)

### 4. PromQL — Bahasa Query Prometheus

PromQL (Prometheus Query Language) adalah bahasa query untuk mengambil dan menganalisis time series data. Contoh sederhana:

```promql
# CPU usage dalam persen (rate 5 menit terakhir)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory yang terpakai
node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes

# Disk usage dalam persen
100 - ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes)
```

---

## 🛠️ Persiapan Alat dan Bahan

| No  | Kebutuhan      | Spesifikasi Minimum      | Keterangan                          |
| --- | -------------- | ------------------------ | ----------------------------------- |
| 1   | VPS / Laptop   | RAM 2GB, CPU 2 core      | Bisa pakai local machine            |
| 2   | Docker Engine  | v24.x ke atas            | Install dari docs.docker.com        |
| 3   | Docker Compose | v2.x (plugin)            | Sudah bundled dengan Docker Desktop |
| 4   | Browser        | Chrome / Firefox terbaru | Untuk mengakses Grafana UI          |
| 5   | Terminal       | Bash/Zsh atau PuTTY      | Untuk mengeksekusi perintah         |

**Verifikasi instalasi Docker:**

```bash
docker --version
# Output: Docker version 27.x.x

docker compose version
# Output: Docker Compose version v2.x.x
```

> ⚠️ **Catatan:** `docker-compose` (dengan tanda hubung, v1 — sudah EOL). Gunakan `docker compose` (tanpa tanda hubung, v2 plugin)

---

## 🚀 Praktikum 1: Setup Stack Monitoring Dasar

### Struktur Direktori Proyek

```
monitoring-stack/
├── docker-compose.yml
├── prometheus/
│   └── prometheus.yml
└── grafana/
    └── provisioning/       ← (opsional, untuk konfigurasi otomatis)
```

Buat struktur direktori:

```bash
mkdir -p ~/monitoring-stack/prometheus
mkdir -p ~/monitoring-stack/grafana/provisioning
cd ~/monitoring-stack
```

### Langkah 1: Buat File `docker-compose.yml`

```yaml
# ~/monitoring-stack/docker-compose.yml
# Catatan: Key 'version' tidak lagi diperlukan di Docker Compose v2

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
      - "--storage.tsdb.retention.time=15d"
      - "--web.enable-lifecycle"
    networks:
      - monitoring

  node_exporter:
    image: prom/node-exporter:latest
    container_name: node_exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - "--path.procfs=/host/proc"
      - "--path.sysfs=/host/sys"
      - "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=praktikum2026 # Ganti di produksi!
      - GF_USERS_ALLOW_SIGN_UP=false
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - prometheus
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus-data:
    driver: local
  grafana-data:
    driver: local
```

**Penjelasan:**

- Ditambahkan `restart: unless-stopped` agar container otomatis restart jika crash
- Ditambahkan `prometheus-data` volume agar data metrik persisten
- Ditambahkan flag `--storage.tsdb.retention.time=15d` untuk retensi data 15 hari
- Ditambahkan `--web.enable-lifecycle` untuk hot-reload konfigurasi
- Mount `/proc` dan `/sys` ke node_exporter agar bisa baca metrik host OS secara akurat

### Langkah 2: Buat File `prometheus/prometheus.yml`

```yaml
# ~/monitoring-stack/prometheus/prometheus.yml

global:
  scrape_interval: 15s # Seberapa sering Prometheus mengambil data
  evaluation_interval: 15s # Seberapa sering Prometheus mengevaluasi rules

scrape_configs:
  # Prometheus memonitor dirinya sendiri
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  # Monitor metrik sistem host (CPU, RAM, Disk, Network)
  - job_name: "node"
    static_configs:
      - targets: ["node_exporter:9100"]
        labels:
          environment: "development"
          team: "infra"
```

### Langkah 3: Jalankan Stack

```bash
cd ~/monitoring-stack

# Jalankan semua container di background
docker compose up -d

# Pantau log saat startup
docker compose logs -f

# Tekan Ctrl+C untuk keluar dari log (container tetap berjalan)
```

**Expected output:**

```
✔ Network monitoring-stack_monitoring   Created
✔ Volume "monitoring-stack_prometheus-data"  Created
✔ Volume "monitoring-stack_grafana-data"     Created
✔ Container prometheus    Started
✔ Container node_exporter Started
✔ Container grafana       Started
```

**Verifikasi container berjalan:**

```bash
docker compose ps
```

```
NAME            IMAGE                        STATUS          PORTS
grafana         grafana/grafana:latest       Up 30 seconds   0.0.0.0:3000->3000/tcp
node_exporter   prom/node-exporter:latest    Up 30 seconds   0.0.0.0:9100->9100/tcp
prometheus      prom/prometheus:latest       Up 30 seconds   0.0.0.0:9090->9090/tcp
```

### Langkah 4: Verifikasi Prometheus

Buka browser ke `http://localhost:9090`

1. Klik menu **Status → Targets**
2. Pastikan semua target berstatus **UP** (hijau)

Untuk mengetes PromQL, klik **Graph** dan coba query:

```promql
up
```

Output: nilai `1` berarti target aktif, `0` berarti down.

### Langkah 5: Akses dan Konfigurasi Grafana

1. Buka `http://localhost:3000`
2. Login dengan:
   - Username: `admin`
   - Password: `praktikum2026`
3. Grafana akan meminta ganti password — bisa dilewati untuk praktikum

> 🔔 **Catatan versi:** Langkah berikut menggunakan UI **Grafana v10/v11** (2024–2026). Tampilan sidebar telah berubah signifikan dari versi sebelumnya — menu "Configuration" dan ikon gear sudah dihapus.

**Menambahkan Prometheus sebagai Data Source:**

1. Di sidebar kiri, klik menu **Connections** → **Data sources**
2. Klik tombol **Add new data source** (pojok kanan atas)
3. Ketik `Prometheus` di kolom pencarian, lalu klik **Prometheus**
4. Di bagian **Connection**, isi kolom **Prometheus server URL**: `http://prometheus:9090`
   > ⚠️ Gunakan nama container (`prometheus`), bukan `localhost`, karena Grafana mengakses Prometheus melalui Docker internal network — bukan dari host
5. Scroll ke bawah, klik **Save & test**
6. Pastikan muncul banner hijau: ✅ _"Successfully queried the Prometheus API"_

### Langkah 6: Import Dashboard Node Exporter (Cara Cepat Industri)

Di industri, jarang membuat dashboard dari nol. Grafana memiliki marketplace dashboard yang bisa langsung diimpor:

1. Di sidebar kiri, klik ikon **Dashboards** (ikon kotak-kotak / grid)
2. Klik tombol **New** (pojok kanan atas) → pilih **Import**
3. Di kolom **"Find and import dashboards..."**, masukkan ID: **`1860`**
4. Klik **Load**
5. Di bagian bawah, pada dropdown **Prometheus**, pilih data source Prometheus yang sudah dikonfigurasi
6. Klik **Import**

Hasilnya: dashboard lengkap dengan ratusan metrik sistem langsung tersedia!

### Langkah 7: Membuat Panel Manual

Untuk memahami cara kerja Grafana secara mendalam, buat panel manual dari awal:

1. Di sidebar kiri, klik ikon **Dashboards** → klik **New** → pilih **New dashboard**
2. Klik tombol **Add visualization** (di beberapa versi Grafana tombol ini berlabel **Add panel** — keduanya sama)
3. Pada dialog **"Select data source"**, pilih **Prometheus**
4. Di bagian bawah layar (panel editor), pastikan tab **Queries** aktif
5. Perhatikan dua tombol di pojok kanan area query: **Builder** dan **Code**. Secara default aktif di mode **Builder** (visual/dropdown). Klik tombol **Code** untuk beralih ke mode teks PromQL
6. Kolom teks PromQL akan muncul — masukkan query berikut:
   ```promql
   100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
   ```
7. Klik tombol **Run queries** untuk melihat preview data di panel atas
8. Di panel kanan atas, ubah judul panel: klik **Panel options** → isi **Title**: `CPU Usage (%)`
9. Di panel kanan, cari **Standard options → Unit** → ketik `percent` → pilih **Percent (0-100)**
10. Klik **Apply** (pojok kanan atas)
11. Klik ikon 💾 (Save dashboard) → beri nama dashboard, misal: `Monitoring Praktikum` → klik **Save**

---

## 📊 Referensi Query PromQL Penting

### Metrik CPU

```promql
# CPU Usage per core
rate(node_cpu_seconds_total{mode!="idle"}[5m])

# Total CPU Usage (persen)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Load Average 1 menit
node_load1
```

### Metrik Memory

```promql
# Memory terpakai (bytes)
node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes

# Memory usage (persen)
100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)

# Swap usage
node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes
```

### Metrik Disk

```promql
# Disk usage semua filesystem yang terdeteksi (persen)
100 - ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes)

# Spesifik ke mountpoint tertentu — sesuaikan dengan hasil query node_filesystem_avail_bytes
# di environment Anda (umumnya /var atau /tmp di setup Docker)
100 - ((node_filesystem_avail_bytes{mountpoint="/var"} * 100) / node_filesystem_size_bytes{mountpoint="/var"})

# Catatan: node_exporter di dalam Docker hanya melaporkan filesystem yang
# dapat diaksesnya di dalam container, bukan seluruh filesystem host.

# Disk I/O read rate
rate(node_disk_read_bytes_total[5m])

# Disk I/O write rate
rate(node_disk_written_bytes_total[5m])
```

### Metrik Network

```promql
# Network traffic masuk (bytes/sec)
rate(node_network_receive_bytes_total{device!="lo"}[5m])

# Network traffic keluar (bytes/sec)
rate(node_network_transmit_bytes_total{device!="lo"}[5m])
```

---

## 🔔 Praktikum 2: Konfigurasi Alerting

Alerting adalah fitur kritis di industri. Tanpa alerting, tim harus terus-menerus memantau dashboard secara manual (tidak realistis).

### Membuat Alerting Rule di Grafana (UI Grafana v11)

> 🔔 **Referensi UI:** Panduan ini menggunakan **Grafana v11** sebagai standar, dengan 6 section pada halaman New Alert Rule sebagaimana tampil di UI aktual.

1. Di sidebar kiri, klik menu **Alerting** (ikon lonceng)
2. Klik **Alert rules** di submenu
3. Klik tombol **New alert rule** (pojok kanan atas)

---

4. **Section 1 — Enter alert rule name**
   - Isi kolom **Name**: `High CPU Usage`

---

5. **Section 2 — Define query and alert condition**
   - Pastikan data source sudah terpilih: **Prometheus**
   - Di pojok kanan area query, klik tombol **Code** untuk beralih dari mode Builder ke mode teks PromQL
   - Di kolom teks yang muncul (berlabel **Metrics browser**), masukkan:
     ```promql
     100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
     ```
   - Klik **Run queries** — di bawahnya akan muncul tabel hasil dengan nilai CPU usage saat ini (misal: `2.83`)
   - Di bagian **Alert condition**, atur kondisi:
     - **WHEN QUERY** → **IS ABOVE** → isi nilai: `80`
   - Klik tombol **Preview alert rule condition** untuk melihat status saat ini
   - Status akan tampil: **Normal** (hijau, CPU masih di bawah 80%) atau **Firing** (merah, CPU di atas 80%)

---

6. **Section 3 — Add folder and labels**
   - **Folder:** klik dropdown → pilih folder yang sudah ada, atau klik **+ New folder** → beri nama `praktikum-alerts`
   - **Labels** _(opsional)_: klik **Edit labels** → tambahkan key `severity`, value `warning` → klik **Save**

---

7. **Section 4 — Set evaluation behavior**
   - **Evaluation group and interval:** pilih dari dropdown atau klik **+ New evaluation group** → beri nama `node-alerts` (interval evaluasi otomatis `1m`)
   - **Pending period:** klik tombol **5m** — artinya alert baru benar-benar aktif (_Firing_) setelah kondisi terpenuhi selama 5 menit terus-menerus, untuk menghindari false alarm sesaat
   - **Keep firing for:** biarkan **None** (0s) — alert langsung kembali Normal begitu kondisi tidak lagi terpenuhi
   - **Configure no data and error handling:** biarkan default untuk praktikum

---

8. **Section 5 — Configure notifications** _(wajib diisi, tidak bisa disimpan jika kosong)_
   - Di bagian **Recipient**, terdapat baris **Alertmanager: grafana**
   - Klik dropdown **Contact point** → pilih **grafana-default-email**
     > Jika tidak ada pilihan, klik **View or create contact points** untuk membuat contact point baru terlebih dahulu (lihat catatan di bawah)
   - > 💡 **Catatan:** Di production, Contact point dikonfigurasi ke Slack, Email, atau PagerDuty. Untuk praktikum, pilih contact point apapun yang tersedia — tujuannya hanya agar form bisa disimpan.

   > ⚠️ **Jika Contact point masih kosong dan tidak ada pilihan:**
   >
   > 1. Buka tab baru → Grafana → **Alerting** → **Contact points**
   > 2. Klik **+ Add contact point**
   > 3. Isi **Name**: `praktikum-contact`
   > 4. **Integration**: pilih **Email**
   > 5. **Addresses**: isi email Anda (misal: `mahasiswa@example.com`)
   > 6. Klik **Save contact point**
   > 7. Kembali ke halaman New Alert Rule, refresh, lalu pilih `praktikum-contact` di dropdown Contact point

---

9. **Section 6 — Configure notification message** _(opsional)_
   - **Summary**: isi pesan singkat, misal:
     `CPU usage tinggi di instance {{ $labels.instance }}`
   - Kolom ini opsional — boleh dikosongkan untuk praktikum

---

10. Klik **Save rule and exit** (pojok kanan atas) untuk menyimpan alert rule

### Contoh Alert Rules Industri (untuk `prometheus.yml`)

Untuk deployment production, alert rules biasanya dipisahkan ke file tersendiri:

```yaml
# prometheus/alert.rules.yml
groups:
  - name: node-alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "CPU usage tinggi di {{ $labels.instance }}"
          description: 'CPU usage: {{ $value | printf "%.1f" }}%'

      - alert: CriticalCPUUsage
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 95
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "CPU KRITIS di {{ $labels.instance }}"
          description: 'CPU usage: {{ $value | printf "%.1f" }}% — segera tindaklanjuti!'

      - alert: HighMemoryUsage
        expr: 100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Memory usage tinggi di {{ $labels.instance }}"
          description: 'Memory terpakai: {{ $value | printf "%.1f" }}%'

      - alert: DiskSpaceLow
        expr: 100 - ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes) > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Disk hampir penuh di {{ $labels.instance }}"
          description: 'Partisi {{ $labels.mountpoint }} terpakai {{ $value | printf "%.1f" }}%'

      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} DOWN"
          description: "Target {{ $labels.job }} tidak dapat dijangkau lebih dari 1 menit"
```

Tambahkan referensi ke `prometheus.yml`:

```yaml
rule_files:
  - "alert.rules.yml"
```

---

## 🏭 Studi Kasus 1: Monitoring Infrastruktur VPS untuk Aplikasi Laravel

### Latar Belakang

Bayangkan skenario nyata: sebuah startup e-commerce menggunakan Laravel yang di-deploy di VPS. Tim DevOps perlu memantau kesehatan server dan mendapatkan notifikasi ketika ada anomali **sebelum** pelanggan mengeluh.

### Arsitektur

```
┌─────────────────────────────────────────────────────────────────┐
│                        VPS SERVER                               │
│                                                                 │
│  ┌──────────────────┐   ┌──────────────┐   ┌───────────────┐  │
│  │   Laravel App    │   │    Nginx     │   │    MySQL      │  │
│  │   :8000          │   │    :80/:443  │   │    :3306      │  │
│  └──────────────────┘   └──────────────┘   └───────────────┘  │
│                                                                 │
│  ┌──────────────────┐   ┌──────────────┐   ┌───────────────┐  │
│  │  Node Exporter   │   │mysqld_export │   │nginx_exporter │  │
│  │  :9100           │   │:9104         │   │:9113          │  │
│  └──────────────────┘   └──────────────┘   └───────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ scrape metrics
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│               MONITORING SERVER (terpisah)                      │
│                                                                 │
│   Prometheus :9090   →   Grafana :3000                         │
└─────────────────────────────────────────────────────────────────┘
```

### Percobaan: Monitoring Laravel di Docker (Stack Lengkap)

**Struktur direktori:**

```
laravel-monitoring/
├── docker-compose.yml
├── prometheus/
│   ├── prometheus.yml
│   └── alert.rules.yml
└── app/                    ← kode Laravel (bisa berupa volume mount)
```

**docker-compose.yml untuk stack lengkap:**

```yaml
services:
  # Aplikasi Laravel
  laravel-app:
    image: your-laravel-app:latest # atau build dari Dockerfile
    container_name: laravel_app
    environment:
      APP_ENV: production
      DB_HOST: mysql
    networks:
      - app-network
      - monitoring

  # Database MySQL
  mysql:
    image: mysql:8.4
    container_name: mysql
    environment:
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_DATABASE: laravel_db
    networks:
      - app-network

  # MySQL Exporter — mengekspor metrik database ke Prometheus
  mysqld_exporter:
    image: prom/mysqld-exporter:latest
    container_name: mysqld_exporter
    environment:
      DATA_SOURCE_NAME: "root:secret@(mysql:3306)/"
    ports:
      - "9104:9104"
    depends_on:
      - mysql
    networks:
      - app-network
      - monitoring

  # Nginx sebagai reverse proxy
  nginx:
    image: nginx:alpine
    container_name: nginx
    ports:
      - "80:80"
    networks:
      - app-network
      - monitoring

  # Nginx Prometheus Exporter
  nginx_exporter:
    image: nginx/nginx-prometheus-exporter:latest
    container_name: nginx_exporter
    command:
      - "--nginx.scrape-uri=http://nginx:80/stub_status"
    ports:
      - "9113:9113"
    depends_on:
      - nginx
    networks:
      - app-network
      - monitoring

  # Stack Monitoring
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/alert.rules.yml:/etc/prometheus/alert.rules.yml:ro
      - prometheus-data:/prometheus
    networks:
      - monitoring

  node_exporter:
    image: prom/node-exporter:latest
    container_name: node_exporter
    ports:
      - "9100:9100"
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=praktikum2026
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - prometheus
    networks:
      - monitoring

networks:
  app-network:
    driver: bridge
  monitoring:
    driver: bridge

volumes:
  prometheus-data:
  grafana-data:
```

**prometheus.yml untuk stack Laravel:**

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert.rules.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node"
    static_configs:
      - targets: ["node_exporter:9100"]
        labels:
          application: "laravel-ecommerce"
          environment: "production"

  - job_name: "mysql"
    static_configs:
      - targets: ["mysqld_exporter:9104"]
        labels:
          application: "laravel-ecommerce"

  - job_name: "nginx"
    static_configs:
      - targets: ["nginx_exporter:9113"]
        labels:
          application: "laravel-ecommerce"
```

### Dashboard Laravel Monitoring — Panel yang Wajib Ada

Buat dashboard Grafana dengan panel-panel berikut:

| Panel                    | Query PromQL                                                                                               | Tipe Visualisasi    |
| ------------------------ | ---------------------------------------------------------------------------------------------------------- | ------------------- |
| CPU Usage                | `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`                                         | Gauge + Time Series |
| Memory Usage             | `100 * (1 - node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes)`                                    | Gauge               |
| Disk Usage               | `100 - ((node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"})` | Gauge               |
| Nginx Active Connections | `nginx_connections_active`                                                                                 | Stat                |
| Nginx Request Rate       | `rate(nginx_http_requests_total[5m])`                                                                      | Time Series         |
| MySQL Queries/sec        | `rate(mysql_global_status_queries[5m])`                                                                    | Time Series         |
| MySQL Connections        | `mysql_global_status_threads_connected`                                                                    | Gauge               |

---

## 🏭 Studi Kasus 2: SLO Monitoring — Praktik DevOps Modern

### Latar Belakang

Di industri 2026, tim DevOps tidak hanya memonitor server — mereka mendefinisikan dan memonitor **SLO (Service Level Objectives)**. Ini adalah standar industri yang digunakan Google, Netflix, Tokopedia, dan lainnya.

**Konsep SLO:**

- **SLI** (Service Level Indicator): Metrik yang diukur, misal: response time, error rate
- **SLO** (Service Level Objective): Target yang ingin dicapai, misal: 99.9% uptime, p95 latency < 200ms
- **SLA** (Service Level Agreement): Perjanjian kontraktual dengan pelanggan

### Contoh SLO untuk API Laravel

```
SLO 1: Availability — "API harus tersedia 99.9% waktu"
SLO 2: Latency — "95% request harus selesai < 500ms"
SLO 3: Error Rate — "Error rate harus < 1%"
```

### Simulasi: Menghasilkan Load dan Melihat Hasilnya

Untuk melihat dashboard berubah secara dinamis, kita bisa membuat beban buatan:

```bash
# Install stress tool (untuk simulasi CPU/Memory load)
docker run --rm -it --network monitoring-stack_monitoring \
  progrium/stress --cpu 2 --timeout 60s

# Atau stress memory
docker run --rm -it --network monitoring-stack_monitoring \
  progrium/stress --vm 1 --vm-bytes 512M --timeout 60s
```

Amati perubahan pada dashboard Grafana secara real-time.

### Query PromQL untuk Monitoring SLO

```promql
# Error Budget — berapa persen "jatah error" yang tersisa
# (Asumsi: SLO = 99.9% availability, error budget = 0.1%)
1 - (
  sum(rate(http_requests_total{status=~"5.."}[30d]))
  /
  sum(rate(http_requests_total[30d]))
) / 0.001

# Availability dalam 24 jam terakhir (persen)
100 * (
  1 - sum(rate(http_requests_total{status=~"5.."}[24h]))
    / sum(rate(http_requests_total[24h]))
)
```

---

## 🔧 Troubleshooting Umum

| Masalah                                  | Gejala                               | Solusi                                                                               |
| ---------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------ |
| Grafana tidak bisa connect ke Prometheus | "Data source connection failed"      | Pastikan URL `http://prometheus:9090` (nama container, bukan localhost)              |
| Target di Prometheus berstatus DOWN      | Status merah di `Status → Targets`   | Cek apakah container node_exporter berjalan: `docker compose ps`                     |
| Dashboard kosong / No Data               | Panel menampilkan "No data"          | Periksa query PromQL, cek rentang waktu di kanan atas Grafana                        |
| Container langsung restart               | `STATUS: Restarting`                 | Lihat log: `docker compose logs prometheus`                                          |
| Port sudah terpakai                      | Error `bind: address already in use` | Ganti port di docker-compose.yml, atau matikan proses yang menggunakan port tersebut |
| Data Prometheus hilang setelah restart   | Metrik historis hilang               | Pastikan volume `prometheus-data` terdefinisi di docker-compose.yml                  |

**Perintah debug yang berguna:**

```bash
# Cek log semua container
docker compose logs

# Cek log container tertentu
docker compose logs prometheus --follow

# Masuk ke dalam container
docker compose exec prometheus sh

# Tes koneksi antar container
docker compose exec grafana wget -qO- http://prometheus:9090/-/healthy

# Reload konfigurasi Prometheus tanpa restart
curl -X POST http://localhost:9090/-/reload

# Cek metrik node_exporter secara langsung
curl http://localhost:9100/metrics | grep node_cpu
```

---

## 💡 Relevansi Industri

### Mengapa Skill Ini Penting?

Berdasarkan survei industri terkini, **Prometheus + Grafana** adalah stack monitoring #1 untuk cloud-native applications:

- **94%** dari DevOps engineer yang menggunakan Kubernetes menggunakan Prometheus
- Grafana Labs dinilai senilai **$6 miliar** (2021) dan terus tumbuh
- Perusahaan teknologi di Indonesia seperti Tokopedia, Gojek, Traveloka, dan Bukalapak semua menggunakan stack observability berbasis Prometheus

### Jalur Karir yang Relevan

| Posisi                          | Relevansi Skill Ini                            |
| ------------------------------- | ---------------------------------------------- |
| DevOps Engineer                 | Core skill — wajib dikuasai                    |
| Site Reliability Engineer (SRE) | Core skill — definisi SLO & monitoring         |
| Platform Engineer               | Core skill — membangun platform observability  |
| Backend Developer               | Penting — instrumentasi aplikasi dengan metrik |
| System Administrator            | Penting — monitoring infrastruktur             |

### Tools Komplementer di Industri

```
Prometheus + Grafana (Metrics)
    +
Loki + Grafana (Logs)          → "PLG Stack" — alternatif ELK yang lebih ringan
    +
Tempo + Grafana (Traces)
    +
Alertmanager (Alerting)
    =
Observability Stack yang lengkap (digunakan oleh ribuan perusahaan)
```

---

## 📚 Referensi

1. Prometheus Documentation — https://prometheus.io/docs/
2. Grafana Documentation — https://grafana.com/docs/
3. PromQL Cheat Sheet — https://promlabs.com/promql-cheat-sheet/
4. Grafana Dashboard Marketplace — https://grafana.com/grafana/dashboards/
5. Node Exporter Full Dashboard (ID: 1860) — https://grafana.com/grafana/dashboards/1860
6. CNCF Landscape (Cloud Native tools) — https://landscape.cncf.io/
7. Google SRE Book (Free) — https://sre.google/books/
