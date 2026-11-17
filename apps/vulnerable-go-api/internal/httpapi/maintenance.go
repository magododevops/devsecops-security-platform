package httpapi

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"strings"

	"github.com/magododevops/devsecops-security-platform/apps/vulnerable-go-api/internal/maintenance"
)

var demoIdentities = map[string]maintenance.Identity{
	"lab-alice": {
		UserID:   "alice",
		TenantID: "tenant-alpha",
		Role:     "technician",
	},
	"lab-bob": {
		UserID:   "bob",
		TenantID: "tenant-beta",
		Role:     "technician",
	},
}

func workOrderHandler(
	service *maintenance.Service,
) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authorization := r.Header.Get("Authorization")

		token, ok := strings.CutPrefix(
			authorization, "Bearer ",
		)

		if !ok {
			http.Error(
				w, "Unauthorized", http.StatusUnauthorized,
			)
			return
		}

		identity, found := demoIdentities[token]

		if !found {
			http.Error(
				w, "Unauthorized", http.StatusUnauthorized,
			)
			return
		}

		var order maintenance.WorkOrder
		var exists bool

		if os.Getenv("LAB_ISOLATED") == "1" &&
			os.Getenv("LAB_SCENARIO") == "bola" {
			// Intentionally vulnerable scenario for isolated testing.
			order, exists = service.GetWorkOrderWithoutTenantCheck(
				r.Context(),
				r.PathValue("id"),
			)
		} else {
			order, exists = service.GetWorkOrder(
				r.Context(),
				identity,
				r.PathValue("id"),
			)
		}

		if !exists {
			http.Error(
				w, "Not found", http.StatusNotFound,
			)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.WriteHeader(http.StatusOK)

		_ = json.NewEncoder(w).Encode(order)
	}
}

// updateWorkOrderHandler demonstrates property-level authorization.
func updateWorkOrderHandler(
	service *maintenance.Service,
) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token, ok := strings.CutPrefix(
			r.Header.Get("Authorization"), "Bearer ",
		)
		if !ok {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		identity, found := demoIdentities[token]
		if !found {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		id := r.PathValue("id")
		order, exists := service.GetWorkOrder(
			r.Context(), identity, id,
		)
		if !exists {
			http.Error(w, "Not found", http.StatusNotFound)
			return
		}

		decoder := json.NewDecoder(
			http.MaxBytesReader(w, r.Body, 4096),
		)

		vulnerable := os.Getenv("LAB_ISOLATED") == "1" &&
			os.Getenv("LAB_SCENARIO") == "mass-assignment"

		if vulnerable {
			// LAB ONLY: binds arbitrary client fields into a domain object.
			if err := decoder.Decode(&order); err != nil {
				http.Error(w, "Invalid JSON", http.StatusBadRequest)
				return
			}

			if err := decoder.Decode(new(any)); err != io.EOF {
				http.Error(w, "Invalid JSON", http.StatusBadRequest)
				return
			}

			order = service.SaveUnrestricted(id, order)
		} else {
			var patch struct {
				Status string `json:"status"`
			}

			decoder.DisallowUnknownFields()

			if err := decoder.Decode(&patch); err != nil {
				http.Error(w, "Invalid JSON", http.StatusBadRequest)
				return
			}

			if err := decoder.Decode(new(any)); err != io.EOF {
				http.Error(w, "Invalid JSON", http.StatusBadRequest)
				return
			}

			switch patch.Status {
			case "open", "in_progress", "closed":
			default:
				http.Error(w, "Invalid status", http.StatusBadRequest)
				return
			}

			order, _ = service.UpdateStatus(
				r.Context(), identity, id, patch.Status,
			)
		}

		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Cache-Control", "no-store")
		_ = json.NewEncoder(w).Encode(order)
	}
}
