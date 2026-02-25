# menggunakan image Node.js
FROM node:24-alpine3.22
# set folder kerja di dalam container
WORKDIR /app
# copy semua file project ke container folder app
COPY . /app
# install dependency yang diperlukan
RUN npm install
# expose port yang digunakan oleh aplikasi
EXPOSE 3000
# perintah untuk menjalankan aplikasi
CMD [ "node", "/app/server.js" ]