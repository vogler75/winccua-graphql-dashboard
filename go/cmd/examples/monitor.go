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

	// Set up signal handling for graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	// Tag names to monitor
	tagNames := []string{
		"Silo1_Temperature",
		"Silo1_Pressure",
		"Silo1_Level",
		"Silo2_Temperature",
		"Silo2_Pressure",
		"Silo2_Level",
	}

	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	fmt.Println("Monitoring tags (press Ctrl+C to stop)...")
	fmt.Println("=========================================")

	for {
		select {
		case <-ticker.C:
			// Clear screen and show current time
			fmt.Print("\033[H\033[2J")
			fmt.Printf("=== Tag Monitor - %s ===\n\n", time.Now().Format("2006-01-02 15:04:05"))

			// Read current tag values
			tags, err := client.ReadTags(ctx, tagNames)
			if err != nil {
				fmt.Printf("Error reading tags: %v\n", err)
				continue
			}

			fmt.Println("Tag Values:")
			fmt.Println("-----------")
			for _, tag := range tags {
				if tag.Error != nil {
					fmt.Printf("%-20s: ERROR - %s\n", tag.Name, tag.Error.Description)
				} else {
					fmt.Printf("%-20s: %-10s (Quality: %-8s) [%s]\n", 
						tag.Name, tag.Value, tag.Quality, 
						tag.Timestamp.Format("15:04:05"))
				}
			}

			// Get active alarms
			alarms, err := client.GetActiveAlarms(ctx)
			if err != nil {
				fmt.Printf("\nError getting alarms: %v\n", err)
			} else {
				fmt.Printf("\nActive Alarms (%d):\n", len(alarms))
				fmt.Println("------------------")
				if len(alarms) == 0 {
					fmt.Println("No active alarms")
				} else {
					for i, alarm := range alarms {
						if i >= 5 {
							fmt.Printf("... and %d more alarms\n", len(alarms)-5)
							break
						}
						if alarm.Error != nil {
							fmt.Printf("ERROR: %s\n", alarm.Error.Description)
						} else {
							fmt.Printf("[%s] %s: %s\n", alarm.State, alarm.Name, alarm.Text)
						}
					}
				}
			}

			// Get redundancy state
			redundancy, err := client.GetRedundancyState(ctx)
			if err != nil {
				fmt.Printf("\nError getting redundancy state: %v\n", err)
			} else {
				fmt.Printf("\nRedundancy State:\n")
				fmt.Println("----------------")
				if redundancy.Error != nil {
					fmt.Printf("ERROR: %s\n", redundancy.Error.Description)
				} else {
					fmt.Printf("Master: %t, State: %s\n", redundancy.IsMaster, redundancy.State)
				}
			}

			fmt.Println("\nPress Ctrl+C to stop monitoring...")

		case <-sigCh:
			fmt.Println("\nShutting down monitor...")
			return
		}
	}
}