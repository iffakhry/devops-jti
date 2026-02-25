package main

import (
	"fmt"
	"net/http"
	"os"
)

func main() {
	// Mengambil Environment Variables
	appName := os.Getenv("APP_NAME")
	if appName == "" {
		appName = "Go-Docker-API" // Default jika kosong
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080" // Default port
	}

	// Handler API
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "GET" {
			http.Error(w, "http method not allowed", http.StatusBadRequest)
			return
		}
		message := fmt.Sprintf("Halo! Anda sedang mengakses API: %s", appName)
		fmt.Fprint(w, message)
	})

	// Health check endpoint (best practice di Docker)
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "OK")
	})

	fmt.Printf("Aplikasi [%s] berjalan di port %s...\n", appName, port)
	
	// Menjalankan server
	err := http.ListenAndServe(":"+port, nil)
	if err != nil {
		fmt.Printf("Gagal menjalankan server: %v\n", err)
	}
}