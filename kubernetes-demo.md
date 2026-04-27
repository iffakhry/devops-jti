# 📘 Demo Kubernetes untuk Kelas (Step-by-Step)

## 🎯 Tujuan Pembelajaran
Setelah praktikum ini, mahasiswa mampu:
- Menjalankan cluster Kubernetes lokal
- Deploy aplikasi ke Kubernetes
- Melakukan scaling
- Mengakses aplikasi dari luar
- Melakukan update & rollback

---

# 🧱 1. Setup Cluster (Minikube)

## ▶️ Jalankan Minikube
```bash
minikube start --driver=docker
```

## ▶️ Cek Node
```bash
kubectl get nodes
```

---

# 🔍 2. Eksplorasi Awal Kubernetes

## ▶️ Cek semua resource
```bash
kubectl get all
```

---

# 🚀 3. Deploy Aplikasi Sederhana

## ▶️ Buat Deployment
```bash
kubectl create deployment web-app --image=nginx
```

## ▶️ Cek Pod
```bash
kubectl get pods
```

## ▶️ Detail Pod
```bash
kubectl describe pod <NAMA_POD>
```

---

# 🌐 4. Expose Aplikasi

## ▶️ Expose Deployment
```bash
kubectl expose deployment web-app --type=NodePort --port=80
```

## ▶️ Cek Service
```bash
kubectl get svc
```

## ▶️ Akses di Browser
```bash
minikube service web-app
```

---

# 📈 5. Scaling

## ▶️ Scale Pod
```bash
kubectl scale deployment web-app --replicas=3
```

## ▶️ Cek Pod
```bash
kubectl get pods
```

---

# 🔄 6. Update Aplikasi

## ▶️ Update Image
```bash
kubectl set image deployment/web-app nginx=nginx:latest
```

## ▶️ Cek Status Rollout
```bash
kubectl rollout status deployment/web-app
```

---

# ⏪ 7. Rollback

## ▶️ Lihat History
```bash
kubectl rollout history deployment/web-app
```

## ▶️ Rollback
```bash
kubectl rollout undo deployment/web-app
```

---

# 🛠️ 8. Debugging

## ▶️ Lihat Log
```bash
kubectl logs <NAMA_POD>
```

## ▶️ Masuk ke Container
```bash
kubectl exec -it <NAMA_POD> -- /bin/bash
```

---

# ⚙️ 9. ConfigMap

## ▶️ Buat ConfigMap
```bash
kubectl create configmap app-config --from-literal=APP_ENV=production
```

## ▶️ Cek ConfigMap
```bash
kubectl get configmap
```

---

# 🔐 10. Secret

## ▶️ Buat Secret
```bash
kubectl create secret generic db-secret --from-literal=password=123456
```

## ▶️ Cek Secret
```bash
kubectl get secrets
```

---

# 🧹 11. Cleanup

## ▶️ Hapus Deployment
```bash
kubectl delete deployment web-app
```

## ▶️ Hapus Service
```bash
kubectl delete svc web-app
```

## ▶️ Stop Minikube
```bash
minikube stop
```

---

# 🎁 Bonus Challenge

1. Scale sampai 5 pod
2. Update image ke versi berbeda
3. Hapus 1 pod dan lihat apakah Kubernetes recreate
