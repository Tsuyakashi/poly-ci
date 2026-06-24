package main

import (
	"fmt"
	"log"
	"net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintln(w, "Hello, 世界")
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, `{"status": "UP"}`)
}

func main() {
	http.HandleFunc("/", handler)
	http.HandleFunc("/health", healthHandler)
	
	fmt.Println("Running demo app. Press Ctrl+C to exit...")
	log.Fatal(http.ListenAndServe(":80", nil))
}
