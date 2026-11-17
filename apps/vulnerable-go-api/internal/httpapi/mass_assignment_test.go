package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/magododevops/devsecops-security-platform/apps/vulnerable-go-api/internal/maintenance"
)

func TestMassAssignmentRegression(t *testing.T) {
	cases := []struct {
		name       string
		isolated   string
		scenario   string
		token      string
		payload    string
		wantStatus int
		wantTenant string
	}{
		{
			name:       "allowed status update",
			token:      "lab-alice",
			payload:    `{"status":"closed"}`,
			wantStatus: http.StatusOK,
			wantTenant: "tenant-alpha",
		},
		{
			name:       "protected tenant field rejected",
			token:      "lab-alice",
			payload:    `{"status":"closed","tenant_id":"tenant-beta"}`,
			wantStatus: http.StatusBadRequest,
		},
		{
			name:       "scenario alone remains safe",
			scenario:   "mass-assignment",
			token:      "lab-alice",
			payload:    `{"tenant_id":"tenant-beta"}`,
			wantStatus: http.StatusBadRequest,
		},
		{
			name:       "vulnerable mode changes tenant",
			isolated:   "1",
			scenario:   "mass-assignment",
			token:      "lab-alice",
			payload:    `{"tenant_id":"tenant-beta"}`,
			wantStatus: http.StatusOK,
			wantTenant: "tenant-beta",
		},
		{
			name:       "other tenant cannot update order",
			token:      "lab-bob",
			payload:    `{"status":"closed"}`,
			wantStatus: http.StatusNotFound,
		},
		{
			name:       "missing authentication rejected",
			payload:    `{"status":"closed"}`,
			wantStatus: http.StatusUnauthorized,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv("LAB_ISOLATED", tc.isolated)
			t.Setenv("LAB_SCENARIO", tc.scenario)

			// A new handler provides fresh in-memory data per test.
			handler := NewHandler()

			request := httptest.NewRequest(
				http.MethodPatch,
				"/v1/work-orders/WO-1001",
				strings.NewReader(tc.payload),
			)
			if tc.token != "" {
				request.Header.Set(
					"Authorization", "Bearer "+tc.token,
				)
			}

			recorder := httptest.NewRecorder()
			handler.ServeHTTP(recorder, request)

			if recorder.Code != tc.wantStatus {
				t.Fatalf(
					"expected %d, got %d: %s",
					tc.wantStatus,
					recorder.Code,
					recorder.Body.String(),
				)
			}

			if tc.wantStatus != http.StatusOK {
				return
			}

			var order maintenance.WorkOrder
			if err := json.Unmarshal(
				recorder.Body.Bytes(), &order,
			); err != nil {
				t.Fatal(err)
			}

			if order.TenantID != tc.wantTenant {
				t.Fatalf(
					"expected tenant %q, got %q",
					tc.wantTenant,
					order.TenantID,
				)
			}
		})
	}
}
