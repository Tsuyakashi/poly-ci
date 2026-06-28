package main

import (
	"log/slog"
	"net/http"
	"os"
	"time"
)

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/health" {
			next.ServeHTTP(w, r)
			return
		}

		start := time.Now()
		next.ServeHTTP(w, r)

		slog.Info("Request handled",
			"method", r.Method,
			"path", r.URL.Path,
			"remote_addr", r.RemoteAddr,
			"duration", time.Since(start).String(),
		)
	})
}

func handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Write([]byte("Hello, 世界\n"))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status": "UP"}`))
}

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	mux := http.NewServeMux()
	mux.HandleFunc("/", handler)
	mux.HandleFunc("/health", healthHandler)

	wrappedMux := loggingMiddleware(mux)

	slog.Info("Starting production server", "port", "8080")
	
	server := &http.Server{
		Addr:         ":8080",
		Handler:      wrappedMux,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	if err := server.ListenAndServe(); err != nil {
		slog.Error("Server failed to start", "error", err)
		os.Exit(1)
	}
}
