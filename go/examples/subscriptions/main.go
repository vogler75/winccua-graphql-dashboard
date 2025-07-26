// Complete example of WebSocket subscriptions including login
// This example demonstrates the full workflow: login -> subscribe -> logout
//
// To run this example:
// 1. Source the environment: source setenv.sh
// 2. Run: go run examples/subscriptions.go
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"winccua-graphql-client/pkg/client"
	"winccua-graphql-client/pkg/graphql"
)

func loginAndGetToken(httpURL, username, password string) (string, error) {
	fmt.Println("Getting authentication token...")

	// Create HTTP client for login
	httpClient := client.NewClient(httpURL)

	// Use our library's login function
	session, err := httpClient.Login(username, password)
	if err != nil {
		return "", fmt.Errorf("login failed: %w", err)
	}

	if session.Token == nil {
		return "", fmt.Errorf("no token received from login")
	}

	fmt.Println("Login successful!")
	return *session.Token, nil
}

func main() {
	// Get configuration from environment variables (use setenv.sh)
	username := getEnvOrDefault("GRAPHQL_USERNAME", "username1")
	password := getEnvOrDefault("GRAPHQL_PASSWORD", "password1")
	httpURL := getEnvOrDefault("GRAPHQL_HTTP_URL", "http://localhost:4000/graphql")
	wsURL := getEnvOrDefault("GRAPHQL_WS_URL", "ws://localhost:4000/graphql")

	fmt.Println("WinCC Unified WebSocket Subscription Example (Full Workflow)")
	fmt.Println("===========================================================")
	fmt.Printf("HTTP URL: %s\n", httpURL)
	fmt.Printf("WS URL: %s\n", wsURL)
	fmt.Printf("Username: %s\n", username)
	fmt.Println()

	// Get authentication token using our library
	token, err := loginAndGetToken(httpURL, username, password)
	if err != nil {
		log.Fatalf("Authentication failed: %v\nMake sure to run 'source setenv.sh' and check your credentials", err)
	}

	// Create client with WebSocket support
	c := client.NewClientWithWebSocket(httpURL, wsURL)

	// Connect WebSocket
	fmt.Println("Connecting WebSocket...")
	if err := c.ConnectWebSocket(token); err != nil {
		log.Fatalf("Failed to connect WebSocket: %v", err)
	}
	fmt.Println("WebSocket connected!")
	fmt.Println()

	// Create context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle Ctrl+C
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigChan
		fmt.Println("\nReceived interrupt signal, shutting down...")
		cancel()
	}()

	// Example 1: Subscribe to tag values
	fmt.Println("Example 1: Tag Value Subscription")
	fmt.Println("---------------------------------")

	tagNames := []string{"HMI_Tag_1", "HMI_Tag_2"}
	fmt.Printf("Subscribing to tags: %v\n", tagNames)

	tagCallbacks := graphql.SubscriptionCallbacks{
		OnData: func(data json.RawMessage) {
			var payload map[string]interface{}
			if err := json.Unmarshal(data, &payload); err != nil {
				log.Printf("Failed to parse tag data: %v", err)
				return
			}

			if dataField, ok := payload["data"].(map[string]interface{}); ok {
				if tagData, ok := dataField["tagValues"].(map[string]interface{}); ok {
					name := getString(tagData, "name", "unknown")
					reason := getString(tagData, "notificationReason", "unknown")

					if valueObj, ok := tagData["value"].(map[string]interface{}); ok {
						value := valueObj["value"]
						timestamp := getString(valueObj, "timestamp", "")
						fmt.Printf("[TAG] %s = %v at %s (%s)\n", name, value, timestamp, reason)
					} else if errorField, ok := tagData["error"].(map[string]interface{}); ok {
						code := getString(errorField, "code", "")
						desc := getString(errorField, "description", "")
						fmt.Printf("[TAG ERROR] %s: %s - %s\n", name, code, desc)
					}
				}
			}
		},
		OnError: func(err error) {
			log.Printf("[TAG SUBSCRIPTION ERROR] %v", err)
		},
		OnComplete: func() {
			fmt.Println("[TAG SUBSCRIPTION] Completed")
		},
	}

	tagSub, err := c.SubscribeToTagValues(tagNames, tagCallbacks)
	if err != nil {
		log.Fatalf("Failed to start tag subscription: %v", err)
	}
	fmt.Println("Tag subscription started!")
	fmt.Println()

	// Example 2: Subscribe to active alarms
	fmt.Println("Example 2: Active Alarms Subscription")
	fmt.Println("------------------------------------")

	alarmCallbacks := graphql.SubscriptionCallbacks{
		OnData: func(data json.RawMessage) {
			var payload map[string]interface{}
			if err := json.Unmarshal(data, &payload); err != nil {
				log.Printf("Failed to parse alarm data: %v", err)
				return
			}

			if dataField, ok := payload["data"].(map[string]interface{}); ok {
				if alarmData, ok := dataField["activeAlarms"].(map[string]interface{}); ok {
					name := getString(alarmData, "name", "unknown")
					reason := getString(alarmData, "notificationReason", "unknown")
					state := getString(alarmData, "state", "unknown")
					priority := getInt(alarmData, "priority", 0)

					eventText := "No event text"
					if eventTexts, ok := alarmData["eventText"].([]interface{}); ok && len(eventTexts) > 0 {
						if text, ok := eventTexts[0].(string); ok {
							eventText = text
						}
					}

					fmt.Printf("[ALARM] %s - %s (Priority: %d, State: %s, Reason: %s)\n",
						name, eventText, priority, state, reason)
				}
			}
		},
		OnError: func(err error) {
			log.Printf("[ALARM SUBSCRIPTION ERROR] %v", err)
		},
		OnComplete: func() {
			fmt.Println("[ALARM SUBSCRIPTION] Completed")
		},
	}

	alarmSub, err := c.SubscribeToActiveAlarms(alarmCallbacks)
	if err != nil {
		log.Fatalf("Failed to start alarm subscription: %v", err)
	}
	fmt.Println("Alarm subscription started!")
	fmt.Println()

	// Example 3: Subscribe to redundancy state
	fmt.Println("Example 3: Redundancy State Subscription")
	fmt.Println("----------------------------------------")

	reduCallbacks := graphql.SubscriptionCallbacks{
		OnData: func(data json.RawMessage) {
			var payload map[string]interface{}
			if err := json.Unmarshal(data, &payload); err != nil {
				log.Printf("Failed to parse redundancy data: %v", err)
				return
			}

			if dataField, ok := payload["data"].(map[string]interface{}); ok {
				if reduData, ok := dataField["reduState"].(map[string]interface{}); ok {
					reason := getString(reduData, "notificationReason", "unknown")

					if valueObj, ok := reduData["value"].(map[string]interface{}); ok {
						state := getString(valueObj, "value", "unknown")
						timestamp := getString(valueObj, "timestamp", "")
						fmt.Printf("[REDU STATE] %s at %s (%s)\n", state, timestamp, reason)
					}
				}
			}
		},
		OnError: func(err error) {
			log.Printf("[REDU SUBSCRIPTION ERROR] %v", err)
		},
	}

	reduSub, err := c.SubscribeToRedundancyState(reduCallbacks)
	if err != nil {
		log.Fatalf("Failed to start redundancy subscription: %v", err)
	}
	fmt.Println("Redundancy state subscription started!")
	fmt.Println()

	// Give the connection some time to stabilize
	fmt.Println("Waiting for connection to stabilize...")
	time.Sleep(2 * time.Second)

	// Listen for notifications
	fmt.Println("Listening for notifications for 30 seconds...")
	fmt.Println("(You should see tag value updates, alarm notifications, and redundancy state changes)")
	fmt.Println("Press Ctrl+C to stop early")
	fmt.Println()

	// Wait for either timeout or interrupt
	select {
	case <-ctx.Done():
		fmt.Println("\nShutdown signal received!")
	case <-time.After(30 * time.Second):
		fmt.Println("\n30 seconds elapsed, shutting down...")
	}

	// Cleanup subscriptions
	fmt.Println("Stopping subscriptions...")
	if err := tagSub.Stop(); err != nil {
		log.Printf("Error stopping tag subscription: %v", err)
	}
	if err := alarmSub.Stop(); err != nil {
		log.Printf("Error stopping alarm subscription: %v", err)
	}
	if err := reduSub.Stop(); err != nil {
		log.Printf("Error stopping redundancy subscription: %v", err)
	}

	// Disconnect WebSocket
	fmt.Println("Disconnecting WebSocket...")
	if err := c.DisconnectWebSocket(); err != nil {
		log.Printf("Error disconnecting WebSocket: %v", err)
	} else {
		fmt.Println("WebSocket disconnected!")
	}

	// Logout using our library
	fmt.Println("\nLogging out...")
	httpClient := client.NewClient(httpURL)
	httpClient.SetAuthToken(token) // Set the token for logout
	
	if err := httpClient.LogoutSimple(); err != nil {
		fmt.Printf("Logout failed (but continuing...): %v\n", err)
	} else {
		fmt.Println("Logged out successfully!")
	}

	fmt.Println("\nExample completed!")
}

// Helper functions
func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getString(m map[string]interface{}, key, defaultValue string) string {
	if value, ok := m[key].(string); ok {
		return value
	}
	return defaultValue
}

func getInt(m map[string]interface{}, key string, defaultValue int) int {
	if value, ok := m[key].(float64); ok {
		return int(value)
	}
	return defaultValue
}