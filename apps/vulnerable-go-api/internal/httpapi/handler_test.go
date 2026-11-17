package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHealth(t *testing.T) {
	request := httptest.NewRequest(
		http.MethodGet, "/healthz", nil,
	)

	recorder := httptest.NewRecorder()
	NewHandler().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}
}

func TestEcho(t *testing.T) {
	request := httptest.NewRequest(
		http.MethodGet, "/api/echo?message=hello", nil,
	)

	recorder := httptest.NewRecorder()
	NewHandler().ServeHTTP(recorder, request)

	var body response

	if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}

	if body.Message != "hello" {
		t.Fatalf("unexpected message: %s", body.Message)
	}
}

func TestEchoRejectsLongInput(t *testing.T) {
	message := strings.Repeat("a", 257)

	request := httptest.NewRequest(
		http.MethodGet, "/api/echo?message="+message, nil,
	)

	recorder := httptest.NewRecorder()
	NewHandler().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", recorder.Code)
	}
}

func TestItems(t *testing.T) {
	request := httptest.NewRequest(
		http.MethodGet, "/api/items/42", nil,
	)

	recorder := httptest.NewRecorder()
	NewHandler().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}
}
