package httpapi

import (
	"encoding/json"
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
