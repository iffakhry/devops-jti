## instalasi PHP

check versi php yang tersedia ```apt show php```

install php di debian13
```bash
apt install php-fpm
```

install php module
```bash
sudo apt install php-cli php-json php-common php-mysql php-curl php-mbstring php-xml php-zip php-gd php-intl php-bcmath -y

```

check socket php
```bash
ls /run/php/
```
outputnya ```php8.4-fpm.sock```

menambahkan ke konfigurasi site-enabled
```bash
server {
    listen 82;
    listen [::]:82;

    root /var/www/html/fakhry_tif/public;
    index index.php;

    server_name fakhrytif.com;

location / {
    try_files $uri $uri/ /index.php?$query_string;
}
location = /favicon.ico { access_log off; log_not_found off; }
location = /robots.txt { access_log off; log_not_found off; }

error_page 404 /index.php;

location ~ \.php$ {
    fastcgi_pass unix:/var/run/php/php8.4-fpm.sock;
    fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
    include fastcgi_params;
}

location ~ /\.(?!well-known).* {
    deny all;
}
```

### memindahkan folder project laravel dari pc ke server - via scp
karena kita tidak bisa login ssh menggunakan root secara langsung, sedangkan folder /www/html kita ada di root. maka langkah yang bisa kita lakukan adalah:

1. login ke user biasa dulu
2. buat folder temporary di /home/userkamu ```mkdir laravel_temp```
3. check lokasi target foldernya ```pwd```
4. pada terminal pc kamu. lakukan transfer folder dengan perintah scp
```bash
scp -r folder_laravel_pc firdaus@192.168.5.9:/home/firdaus/laravel_temp
```
5. ketika transfer sudah berhasil, cek dengan cara masuk ke terminal server kamu dan jalankan `ls` untuk cek apakah sudah ada file/foldernya
6. proses berikutnya adalah pindah folder project laravel yang ada di ```/home/firdaus/laravel_temp``` ke folder ```/var/www/html/fakhry_tif/public```
7. cara memindahkannya adalah: login ke root user ``` su -```
8. pindahkan dengan perintah mv ```mv /home/firdaus/laravel_temp/fakhry-devops /var/www/html/fakhry_tif/public```
9. cek apakah sudah muncul folder kita di direktori root



### konfigurasi laravelnya
masuk dulu ke folder project laravelnya ```cd fakhry-devops```
1. install composer
```bash
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'c8b085408188070d5f52bcfe4ecfbee5f727afa458b2573b8eaaf77b3419b0bf2768dc67c86944da1544f06fa544fd47') { echo 'Installer verified'.PHP_EOL; } else { echo 'Installer corrupt'.PHP_EOL; unlink('composer-setup.php'); exit(1); }"
php composer-setup.php
php -r "unlink('composer-setup.php');"
```
2. pindahkan composer.phar ```mv composer.phar /usr/local/bin/composer```
3. cek composer version ```composer --version``` yes saja ketika ada pertanyaan continue as root user
4. jalankan ```composer install```
5. jalankan ```php artisan key:generate```
6. setting .env 
7. jalankan ```php artisan migrate```
8. sesuaikan lagi pengaturan yang ada di site-enabled
```bash
server {
    listen 82;
    listen [::]:82;

    root /var/www/html/fakhry_tif/public/fakhry-devops/public;
    index index.php;

    server_name fakhrytif.com;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```
9. cek web di browser
10. jika muncul error permission, maka masuk ke folder project laravel nya dan jalankan ```chmod -R 777 storage/```
