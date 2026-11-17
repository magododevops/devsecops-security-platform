package httpapi

import (
	"encoding/json"
	"github.com/magododevops/devsecops-security-platform/apps/vulnerable-go-api/internal/maintenance"
	"net/http"
	"os"
	"strings"
)

type response struct {
	Status  string `json:"status,omitempty"`
	Message string `json:"message,omitempty"`
	ID      string `json:"id,omitempty"`
}

func NewHandler() http.Handler {
	mux := http.NewServeMux()
	service := maintenance.NewService()

	mux.HandleFunc(
		"GET /v1/work-orders/{id}",
		workOrderHandler(service),
	)

	mux.HandleFunc(
		"PATCH /v1/work-orders/{id}",
		updateWorkOrderHandler(service),
	)

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
	if os.Getenv("LAB_INSECURE_HEADERS") == "1" {
		w.Header().Set("X-Powered-By", "DevSecOpsLab/0.1")
	}

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
		ID:     id,
		Status: "found",
	})
}
