package main

import (
    "log"
    "net/http"
    "time"

    "github.com/magododevops/devsecops-security-platform/apps/vulnerable-go-api/internal/httpapi"
)

func main() {
    server := &http.Server{
        Addr:              ":8080",
        Handler:           httpapi.NewHandler(),
        ReadHeaderTimeout: 5 * time.Second,
        ReadTimeout:       10 * time.Second,
        WriteTimeout:      10 * time.Second,
        IdleTimeout:       60 * time.Second,
    }

    log.Println("Go Security Lab listening on :8080")
    log.Fatal(server.ListenAndServe())
}
