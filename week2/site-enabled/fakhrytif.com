server {
    listen 82;
    listen [::]:82;

    root /var/www/html/fakhry_tif;
    index index.html;

    server_name fakhrytif.com;

    location / {
        try_files $uri $uri/ =404;
    }
}