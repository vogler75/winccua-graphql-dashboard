package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/siemens/winccua-graphql-libs/go/pkg/winccunified"
)

func main() {
	baseURL := os.Getenv("WINCCUA_URL")
	username := os.Getenv("WINCCUA_USERNAME")
	password := os.Getenv("WINCCUA_PASSWORD")

	if baseURL == "" || username == "" || password == "" {
		log.Fatal("Please set WINCCUA_URL, WINCCUA_USERNAME, and WINCCUA_PASSWORD environment variables")
	}

	client := winccunified.NewClient(baseURL, username, password)
	ctx := context.Background()

	fmt.Println("Connecting to WinCC Unified server...")
	if err := client.Connect(ctx); err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}
	defer client.Disconnect(ctx)

	fmt.Println("Connected successfully!")

	// Connect WebSocket for subscriptions
	fmt.Println("Connecting WebSocket for subscriptions...")
	if err := client.ConnectWebSocket(ctx); err != nil {
		log.Fatalf("Failed to connect WebSocket: %v", err)
	}
	defer client.DisconnectWebSocket()

	fmt.Println("WebSocket connected!")

	// Subscribe to tag changes
	tagNames := []string{
		"Silo1_Temperature",
		"Silo1_Pressure",
		"Silo1_Level",
		"Silo2_Temperature",
		"Silo2_Pressure",
		"Silo2_Level",
	}

	tagCh, tagSub, err := client.SubscribeToTags(ctx, tagNames)
	if err != nil {
		log.Fatalf("Failed to subscribe to tags: %v", err)
	}
	defer tagSub.Close()

	fmt.Printf("Subscribed to %d tags\n", len(tagNames))

	// Subscribe to alarm changes
	alarmCh, alarmSub, err := client.SubscribeToAlarms(ctx)
	if err != nil {
		log.Printf("Failed to subscribe to alarms: %v", err)
	} else {
		defer alarmSub.Close()
		fmt.Println("Subscribed to alarm changes")
	}

	// Subscribe to redundancy state changes
	redundancyCh, redundancySub, err := client.SubscribeToRedundancyState(ctx)
	if err != nil {
		log.Printf("Failed to subscribe to redundancy state: %v", err)
	} else {
		defer redundancySub.Close()
		fmt.Println("Subscribed to redundancy state changes")
	}

	// Set up signal handling for graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	fmt.Println("\nListening for updates (press Ctrl+C to stop)...")
	fmt.Println("===========================================")

	// Process subscription messages
	for {
		select {
		case tag, ok := <-tagCh:
			if !ok {
				fmt.Println("Tag subscription closed")
				return
			}
			if tag.Error != nil {
				fmt.Printf("[ERROR] Tag %s: %s\n", tag.Name, tag.Error.Description)
			} else {
				fmt.Printf("[TAG] %s = %s (Quality: %s) at %s\n", 
					tag.Name, tag.Value, tag.Quality, 
					tag.Timestamp.Format("15:04:05"))
			}

		case alarm, ok := <-alarmCh:
			if !ok {
				fmt.Println("Alarm subscription closed")
				alarmCh = nil
				continue
			}
			if alarm.Error != nil {
				fmt.Printf("[ERROR] Alarm: %s\n", alarm.Error.Description)
			} else {
				var timeStr string
				if alarm.State == "ACTIVE" {
					timeStr = alarm.ComeTime.Format("15:04:05")
				} else if alarm.GoTime != nil {
					timeStr = alarm.GoTime.Format("15:04:05")
				}
				fmt.Printf("[ALARM] %s: %s (State: %s) at %s\n", 
					alarm.Name, alarm.Text, alarm.State, timeStr)
			}

		case redundancy, ok := <-redundancyCh:
			if !ok {
				fmt.Println("Redundancy subscription closed")
				redundancyCh = nil
				continue
			}
			if redundancy.Error != nil {
				fmt.Printf("[ERROR] Redundancy: %s\n", redundancy.Error.Description)
			} else {
				fmt.Printf("[REDUNDANCY] Master: %t, State: %s\n", 
					redundancy.IsMaster, redundancy.State)
			}

		case <-sigCh:
			fmt.Println("\nShutting down...")
			return

		case <-time.After(30 * time.Second):
			fmt.Printf("[INFO] Still listening... (%s)\n", time.Now().Format("15:04:05"))
		}
	}
}