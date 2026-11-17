package httpapi

import (
    "encoding/json"
    "net/http"
    "strings"
)

type response struct {
    Status  string `json:"status,omitempty"`
    Message string `json:"message,omitempty"`
    ID      string `json:"id,omitempty"`
}

func NewHandler() http.Handler {
    mux := http.NewServeMux()

    mux.HandleFunc("GET /healthz", healthHandler)
    mux.HandleFunc("GET /api/echo", echoHandler)
    mux.HandleFunc("GET /api/items/{id}", itemHandler)

    return mux
}

func writeJSON(
    w http.ResponseWriter,
    status int,
    payload response,
) {
    w.Header().Set("Content-Type", "application/json")
    w.Header().Set("Cache-Control", "no-store")
    w.Header().Set("X-Content-Type-Options", "nosniff")
    w.WriteHeader(status)

    _ = json.NewEncoder(w).Encode(payload)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    writeJSON(w, http.StatusOK, response{
        Status: "healthy",
    })
}

func echoHandler(w http.ResponseWriter, r *http.Request) {
    message := r.URL.Query().Get("message")

    if len(message) > 256 {
        writeJSON(w, http.StatusBadRequest, response{
            Message: "Message too long",
        })
        return
    }

    writeJSON(w, http.StatusOK, response{
        Message: message,
    })
}

func itemHandler(w http.ResponseWriter, r *http.Request) {
    id := r.PathValue("id")

    if len(id) == 0 || len(id) > 64 ||
        strings.ContainsAny(id, `/\`) {
        writeJSON(w, http.StatusBadRequest, response{
            Message: "Invalid item ID",
        })
        return
    }

    writeJSON(w, http.StatusOK, response{
        ID: id,
        Status: "found",
    })
}
