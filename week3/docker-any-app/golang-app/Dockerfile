# Stage 1: Build
FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o api-service .

# Stage 2: Runtime
FROM alpine:latest
WORKDIR /root/
COPY --from=builder /app/api-service .

# Menentukan default PORT jika user tidak memberikan saat 'docker run'
ENV PORT=8080

# Port yang dibuka oleh container
EXPOSE ${PORT}

CMD ["./api-service"]