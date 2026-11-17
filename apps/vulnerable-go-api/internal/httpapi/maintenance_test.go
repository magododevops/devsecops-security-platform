package httpapi

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestWorkOrderAuthorization(t *testing.T) {
	cases := []struct {
		name       string
		token      string
		orderID    string
		wantStatus int
	}{
		{
			name:       "Alice accesses own work order",
			token:      "lab-alice",
			orderID:    "WO-1001",
			wantStatus: http.StatusOK,
		},
		{
			name:       "Bob accesses own work order",
			token:      "lab-bob",
			orderID:    "WO-2001",
			wantStatus: http.StatusOK,
		},
		{
			name:       "Alice cannot access Bob work order",
			token:      "lab-alice",
			orderID:    "WO-2001",
			wantStatus: http.StatusNotFound,
		},
		{
			name:       "Bob cannot access Alice work order",
			token:      "lab-bob",
			orderID:    "WO-1001",
			wantStatus: http.StatusNotFound,
		},
		{
			name:       "Invalid token is rejected",
			token:      "invalid-token",
			orderID:    "WO-1001",
			wantStatus: http.StatusUnauthorized,
		},
		{
			name:       "Missing token is rejected",
			token:      "",
			orderID:    "WO-1001",
			wantStatus: http.StatusUnauthorized,
		},
	}

	handler := NewHandler()

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(
				http.MethodGet,
				"/v1/work-orders/"+tc.orderID,
				nil,
			)

			if tc.token != "" {
				req.Header.Set(
					"Authorization",
					"Bearer "+tc.token,
				)
			}

			recorder := httptest.NewRecorder()
			handler.ServeHTTP(recorder, req)

			if recorder.Code != tc.wantStatus {
				t.Fatalf(
					"expected %d, got %d: %s",
					tc.wantStatus,
					recorder.Code,
					recorder.Body.String(),
				)
			}
		})
	}
}

// TestBOLARegression proves the difference between secure and
// intentionally vulnerable object-level authorization.
func TestBOLARegression(t *testing.T) {
	scenarios := []struct {
		name       string
		isolated   string
		scenario   string
		wantStatus int
	}{
		{
			name:       "secure by default",
			isolated:   "0",
			scenario:   "",
			wantStatus: http.StatusNotFound,
		},
		{
			name:       "scenario alone cannot enable vulnerability",
			isolated:   "0",
			scenario:   "bola",
			wantStatus: http.StatusNotFound,
		},
		{
			name:       "isolated vulnerable mode leaks another tenant",
			isolated:   "1",
			scenario:   "bola",
			wantStatus: http.StatusOK,
		},
	}

	for _, tc := range scenarios {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv("LAB_ISOLATED", tc.isolated)
			t.Setenv("LAB_SCENARIO", tc.scenario)

			request := httptest.NewRequest(
				http.MethodGet,
				"/v1/work-orders/WO-2001",
				nil,
			)
			request.Header.Set(
				"Authorization",
				"Bearer lab-alice",
			)

			recorder := httptest.NewRecorder()
			NewHandler().ServeHTTP(recorder, request)

			if recorder.Code != tc.wantStatus {
				t.Fatalf(
					"expected %d, got %d: %s",
					tc.wantStatus,
					recorder.Code,
					recorder.Body.String(),
				)
			}
		})
	}
}
