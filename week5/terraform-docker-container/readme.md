## Workflow Terraform

1. Write: Menulis konfigurasi dalam file .tf (contoh: main.tf).
2. Init (terraform init): Menyiapkan direktori kerja dan mengunduh provider (misal: provider Docker atau AWS).
3. Plan (terraform plan): Melihat simulasi perubahan sebelum benar-benar dieksekusi. Ini adalah tahap krusial di industri untuk review keamanan.
4. Apply (terraform apply): Mengeksekusi kode menjadi infrastruktur nyata.
5. Destroy (terraform destroy): Menghapus seluruh infrastruktur yang telah dibuat agar tidak memakan biaya (sangat penting untuk efisiensi cloud).

## Check Terraform Providers

[Terraform Registry](https://registry.terraform.io)
registry.terraform.io

## notes

- pada main.tf, kita bisa set langsung values dari masing-masing komponen. semua values ditulis di main.tf. namun ini akan membuat code konfigurasi kita statis.
- direkomendasikan menggunakan pendekatan dinamisasi kode (Terraform Variables & Outputs), dengan membuat file variables.tf dan outputs.tf

* variables.tf digunakan untuk membuat variabel dan menyimpan values dari variabel tsb, untuk nanti dipanggil di main.tf, sehingga nanti bisa dipakai berulang kali.
* outputs.tf Digunakan untuk menampilkan informasi penting setelah apply selesai, seperti IP address server atau ID instance, tanpa harus mengecek manual di Docker/Console.

## cara running dengan pendekatan dinamisasi kode

1. langsung `terraform apply`
2. override `terraform apply -var="external_port=9000" -var="container_name=Nginx-Custom"`

### keuntungan

1. Reusability: Dengan variabel, satu kode yang sama bisa dipakai untuk membuat 100 server dengan nama berbeda hanya dengan mengganti file inputnya saja.
2. Abstraksi: Pengguna kode (user) tidak perlu tahu isi main.tf yang rumit, mereka cukup melihat variables.tf untuk tahu apa yang bisa mereka setting.
3. Output: outputs.tf membantu otomasi. Jika nanti mereka belajar CI/CD, output ini bisa diambil oleh sistem lain untuk pengujian otomatis.
