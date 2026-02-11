CREATE USER 'laravel_user'@'%' IDENTIFIED BY 'qwerty';

-- melihat user yang ada di mysql
SELECT Host, User, plugin FROM mysql.user;

-- membuat database laravel_db
CREATE DATABASE laravel_db;

-- melihat database yang ada di mysql
SHOW DATABASES;

-- memberikan hak akses ke user laravel_user di database laravel_db
GRANT ALL PRIVILEGES ON laravel_db.* TO 'laravel_user'@'%';