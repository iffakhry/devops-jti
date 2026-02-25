### menjalankan app manual

1. pastikan node dan npm sudah terinstall

```bash
node -v
npm -v
```

2. inisialisasi project nodejs, akan tergenerate file package.json

```bash
npm init -y
```

3. install express, karena require express

```bash
npm install express
```

4. untuk menjalankan app

```bash
node server.js

#untuk menambahkan env, jalankan ini terlebih dahulu sebelum node server.js
#linux/macos
export APP_NAME=ExpressManual

#windows (powershell)
setx APP_NAME "ExpressManual"
```

### menjalankan via docker

1. build images

```bash
docker build -t express-images .
```

2. check imagenya

```bash
docker images
```

3. buat containernya

```bash
docker run -p 3000:3000 -e APP_NAME=ExpressDocker --name expressContainer express-images
```

notes:

- -p 3000:3000 → port laptop : port container
- --name → nama container
- express-images → nama image
- -e → menambahkan environment variable
