package main

import (
	"context"
	"fmt"
	"log"
	"os"
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

	// Read tags
	fmt.Println("\n=== Reading Tags ===")
	tagNames := []string{"Silo1_Temperature", "Silo1_Pressure", "InvalidTag"}
	tags, err := client.ReadTags(ctx, tagNames)
	if err != nil {
		log.Printf("Failed to read tags: %v", err)
	} else {
		for _, tag := range tags {
			if tag.Error != nil {
				fmt.Printf("Tag: %s - Error: %s\n", tag.Name, tag.Error.Description)
			} else {
				fmt.Printf("Tag: %s = %s (Quality: %s, Time: %v)\n", 
					tag.Name, tag.Value, tag.Quality, tag.Timestamp.Format(time.RFC3339))
			}
		}
	}

	// Write tags
	fmt.Println("\n=== Writing Tags ===")
	tagsToWrite := []winccunified.TagWrite{
		{Name: "Silo1_Temperature", Value: "25.5"},
		{Name: "Silo1_Pressure", Value: "1.2"},
	}

	writeResults, err := client.WriteTags(ctx, tagsToWrite)
	if err != nil {
		log.Printf("Failed to write tags: %v", err)
	} else {
		for _, result := range writeResults {
			if result.Error != nil {
				fmt.Printf("Write failed for %s: %s\n", result.Name, result.Error.Description)
			} else {
				fmt.Printf("Successfully wrote to %s\n", result.Name)
			}
		}
	}

	// Browse hierarchy
	fmt.Println("\n=== Browsing Tags ===")
	browseResult, err := client.Browse(ctx, "")
	if err != nil {
		log.Printf("Failed to browse: %v", err)
	} else {
		if browseResult.Error != nil {
			fmt.Printf("Browse error: %s\n", browseResult.Error.Description)
		} else {
			fmt.Printf("Found %d items:\n", len(browseResult.Items))
			for i, item := range browseResult.Items {
				if i >= 5 {
					fmt.Printf("... and %d more items\n", len(browseResult.Items)-5)
					break
				}
				fmt.Printf("  - %s (Type: %s, Children: %d)\n", 
					item.Name, item.Type, item.ChildrenCount)
			}
		}
	}

	// Get active alarms
	fmt.Println("\n=== Active Alarms ===")
	alarms, err := client.GetActiveAlarms(ctx)
	if err != nil {
		log.Printf("Failed to get active alarms: %v", err)
	} else {
		if len(alarms) == 0 {
			fmt.Println("No active alarms")
		} else {
			fmt.Printf("Found %d active alarms:\n", len(alarms))
			for i, alarm := range alarms {
				if i >= 3 {
					fmt.Printf("... and %d more alarms\n", len(alarms)-3)
					break
				}
				if alarm.Error != nil {
					fmt.Printf("  - Error getting alarm: %s\n", alarm.Error.Description)
				} else {
					fmt.Printf("  - %s: %s (State: %s)\n", 
						alarm.Name, alarm.Text, alarm.State)
				}
			}
		}
	}

	// Get redundancy state
	fmt.Println("\n=== Redundancy State ===")
	redundancyState, err := client.GetRedundancyState(ctx)
	if err != nil {
		log.Printf("Failed to get redundancy state: %v", err)
	} else {
		if redundancyState.Error != nil {
			fmt.Printf("Redundancy state error: %s\n", redundancyState.Error.Description)
		} else {
			fmt.Printf("Master: %t, State: %s\n", redundancyState.IsMaster, redundancyState.State)
		}
	}

	// Read historical values
	fmt.Println("\n=== Historical Values ===")
	endTime := time.Now()
	startTime := endTime.Add(-1 * time.Hour)
	
	historical, err := client.ReadHistoricalValues(ctx, "Silo1_Temperature", startTime, endTime, 10)
	if err != nil {
		log.Printf("Failed to read historical values: %v", err)
	} else {
		if historical.Error != nil {
			fmt.Printf("Historical values error: %s\n", historical.Error.Description)
		} else {
			fmt.Printf("Found %d historical values for %s:\n", len(historical.Values), historical.Name)
			for i, value := range historical.Values {
				if i >= 3 {
					fmt.Printf("... and %d more values\n", len(historical.Values)-3)
					break
				}
				fmt.Printf("  %s: %s (Quality: %s)\n", 
					value.Timestamp.Format(time.RFC3339), value.Value, value.Quality)
			}
		}
	}

	fmt.Println("\nExample completed successfully!")
}