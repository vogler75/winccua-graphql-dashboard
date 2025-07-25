package test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/siemens/winccua-graphql-libs/go/pkg/winccunified"
)

func TestNewClient(t *testing.T) {
	client := winccunified.NewClient("https://example.com", "user", "pass")
	if client == nil {
		t.Fatal("NewClient returned nil")
	}
}

func TestConnect(t *testing.T) {
	// Mock server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			t.Errorf("Expected POST request, got %s", r.Method)
		}

		if r.Header.Get("Content-Type") != "application/json" {
			t.Errorf("Expected Content-Type application/json, got %s", r.Header.Get("Content-Type"))
		}

		// Check request body contains login mutation
		body := make([]byte, r.ContentLength)
		r.Body.Read(body)
		if !strings.Contains(string(body), "Login") {
			t.Errorf("Expected Login mutation in request body")
		}

		// Mock successful login response
		response := map[string]interface{}{
			"data": map[string]interface{}{
				"Login": map[string]interface{}{
					"token":     "test-token",
					"sessionId": "test-session",
					"error":     nil,
				},
			},
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}))
	defer server.Close()

	client := winccunified.NewClient(server.URL, "testuser", "testpass")
	ctx := context.Background()

	err := client.Connect(ctx)
	if err != nil {
		t.Fatalf("Connect failed: %v", err)
	}
}

func TestConnectWithError(t *testing.T) {
	// Mock server that returns login error
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		response := map[string]interface{}{
			"data": map[string]interface{}{
				"Login": map[string]interface{}{
					"token":     nil,
					"sessionId": nil,
					"error": map[string]interface{}{
						"code":        "INVALID_CREDENTIALS",
						"description": "Invalid username or password",
					},
				},
			},
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}))
	defer server.Close()

	client := winccunified.NewClient(server.URL, "baduser", "badpass")
	ctx := context.Background()

	err := client.Connect(ctx)
	if err == nil {
		t.Fatal("Expected Connect to fail with invalid credentials")
	}

	if !strings.Contains(err.Error(), "INVALID_CREDENTIALS") {
		t.Errorf("Expected error to contain INVALID_CREDENTIALS, got: %v", err)
	}
}

func TestReadTags(t *testing.T) {
	// Mock server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var response map[string]interface{}

		// Check if this is a login request or read tags request
		body := make([]byte, r.ContentLength)
		r.Body.Read(body)
		
		if strings.Contains(string(body), "Login") {
			// Mock login response
			response = map[string]interface{}{
				"data": map[string]interface{}{
					"Login": map[string]interface{}{
						"token":     "test-token",
						"sessionId": "test-session",
						"error":     nil,
					},
				},
			}
		} else if strings.Contains(string(body), "ReadTags") {
			// Mock read tags response
			response = map[string]interface{}{
				"data": map[string]interface{}{
					"ReadTags": []interface{}{
						map[string]interface{}{
							"name":      "TestTag1",
							"value":     "123.45",
							"quality":   "GOOD",
							"timestamp": time.Now().Format(time.RFC3339),
							"error":     nil,
						},
						map[string]interface{}{
							"name":  "TestTag2",
							"value": nil,
							"error": map[string]interface{}{
								"code":        "TAG_NOT_FOUND",
								"description": "Tag not found",
							},
						},
					},
				},
			}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}))
	defer server.Close()

	client := winccunified.NewClient(server.URL, "testuser", "testpass")
	ctx := context.Background()

	// Connect first
	err := client.Connect(ctx)
	if err != nil {
		t.Fatalf("Connect failed: %v", err)
	}

	// Read tags
	tagNames := []string{"TestTag1", "TestTag2"}
	results, err := client.ReadTags(ctx, tagNames)
	if err != nil {
		t.Fatalf("ReadTags failed: %v", err)
	}

	if len(results) != 2 {
		t.Fatalf("Expected 2 results, got %d", len(results))
	}

	// Check first tag (successful)
	if results[0].Name != "TestTag1" {
		t.Errorf("Expected tag name TestTag1, got %s", results[0].Name)
	}
	if results[0].Value != "123.45" {
		t.Errorf("Expected tag value 123.45, got %s", results[0].Value)
	}
	if results[0].Error != nil {
		t.Errorf("Expected no error for TestTag1, got %v", results[0].Error)
	}

	// Check second tag (error)
	if results[1].Name != "TestTag2" {
		t.Errorf("Expected tag name TestTag2, got %s", results[1].Name)
	}
	if results[1].Error == nil {
		t.Error("Expected error for TestTag2, got nil")
	}
	if results[1].Error.Code != "TAG_NOT_FOUND" {
		t.Errorf("Expected error code TAG_NOT_FOUND, got %s", results[1].Error.Code)
	}
}