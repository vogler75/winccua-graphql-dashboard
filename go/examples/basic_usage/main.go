// Basic usage example for WinCC Unified GraphQL client in Go
package main

import (
	"fmt"
	"os"
	"time"

	"winccua-graphql-client/pkg/client"
	"winccua-graphql-client/pkg/types"
)

func main() {
	// Get configuration from environment variables (use setenv.sh)
	username := getEnvOrDefault("GRAPHQL_USERNAME", "username1")
	password := getEnvOrDefault("GRAPHQL_PASSWORD", "password1")
	httpURL := getEnvOrDefault("GRAPHQL_HTTP_URL", "http://localhost:4000/graphql")

	fmt.Printf("Using HTTP URL: %s\n", httpURL)
	fmt.Printf("Using Username: %s\n", username)
	fmt.Println()

	// Create client
	c := client.NewClient(httpURL)

	// Example 1: Login
	fmt.Println("=== Login Example ===")
	session, err := c.Login(username, password)
	if err != nil {
		fmt.Printf("Login failed: %v\n", err)
		return
	}

	fmt.Println("Login successful!")
	if session.User != nil {
		if session.User.Name != nil {
			fmt.Printf("User: %s\n", *session.User.Name)
		}
		if session.User.FullName != nil {
			fmt.Printf("Full Name: %s\n", *session.User.FullName)
		}
	}
	if session.Token != nil {
		fmt.Printf("Token: %s\n", *session.Token)
	}
	if session.Expires != nil {
		fmt.Printf("Expires: %s\n", *session.Expires)
	}

	// Example 2: Get session info
	fmt.Println("\n=== Session Info Example ===")
	sessionInfo, err := c.GetSessionSimple()
	if err != nil {
		fmt.Printf("Failed to get session: %v\n", err)
	} else {
		fmt.Println("Current session info:")
		if sessionInfo.User != nil {
			if sessionInfo.User.Name != nil {
				fmt.Printf("  User: %s\n", *sessionInfo.User.Name)
			}
			if sessionInfo.User.ID != nil {
				fmt.Printf("  User ID: %s\n", *sessionInfo.User.ID)
			}
			if sessionInfo.User.FullName != nil {
				fmt.Printf("  Full Name: %s\n", *sessionInfo.User.FullName)
			}
			if len(sessionInfo.User.Groups) > 0 {
				fmt.Printf("  Groups: ")
				for i, group := range sessionInfo.User.Groups {
					if group.Name != nil {
						if i > 0 {
							fmt.Printf(", ")
						}
						fmt.Printf("%s", *group.Name)
					}
				}
				fmt.Println()
			}
		}
		if sessionInfo.Token != nil {
			fmt.Printf("  Token: %s\n", *sessionInfo.Token)
		}
		if sessionInfo.Expires != nil {
			fmt.Printf("  Expires: %s\n", *sessionInfo.Expires)
		}
	}

	// Example 3: Read tag values
	fmt.Println("\n=== Tag Values Example ===")
	tagNames := []string{
		"HMI_Tag_1",
		"HMI_Tag_2",
	}

	tagValues, err := c.GetTagValuesSimple(tagNames)
	if err != nil {
		fmt.Printf("Failed to get tag values: %v\n", err)
	} else {
		fmt.Println("Tag values:")
		for _, tagValue := range tagValues {
			if tagValue.Name != nil {
				fmt.Printf("  Name: %s\n", *tagValue.Name)
			}
			if tagValue.Value != nil {
				fmt.Printf("  Value: %v\n", tagValue.Value.Value)
				if tagValue.Value.Timestamp != nil {
					fmt.Printf("  Timestamp: %s\n", *tagValue.Value.Timestamp)
				}
				if tagValue.Value.Quality != nil && tagValue.Value.Quality.Quality != nil {
					fmt.Printf("  Quality: %s\n", *tagValue.Value.Quality.Quality)
				}
			}
			if tagValue.Error != nil {
				if tagValue.Error.Code != nil && *tagValue.Error.Code != "0" {
					fmt.Printf("  Error: %v\n", tagValue.Error)
				}
			}
		}
	}

	// Example 4: Write tag values
	fmt.Println("\n=== Write Tag Values Example ===")
	tagInputs := []*types.TagValueInput{
		{
			Name:  "HMI_Tag_1",
			Value: 123,
		},
		{
			Name:  "HMI_Tag_2",
			Value: true,
		},
	}

	writeResults, err := c.WriteTagValuesSimple(tagInputs)
	if err != nil {
		fmt.Printf("Failed to write tag values: %v\n", err)
	} else {
		fmt.Println("Write results:")
		for _, result := range writeResults {
			if result.Name != nil {
				fmt.Printf("  Name: %s\n", *result.Name)
			}
			if result.Error != nil {
				if result.Error.Code != nil && *result.Error.Code != "0" {
					fmt.Printf("  Error: %v\n", result.Error)
				}
			}
		}
	}

	// Example 5: Browse tags
	fmt.Println("\n=== Browse Tags Example ===")
	browseResults, err := c.BrowseSimple()
	if err != nil {
		fmt.Printf("Failed to browse: %v\n", err)
	} else {
		fmt.Println("Browse results (first 10):")
		for i, result := range browseResults {
			if i >= 10 {
				break
			}
			name := "unknown"
			displayName := ""
			objectType := "unknown"
			dataType := ""
			if result.Name != nil {
				name = *result.Name
			}
			if result.DisplayName != nil {
				displayName = *result.DisplayName
			}
			if result.ObjectType != nil {
				objectType = *result.ObjectType
			}
			if result.DataType != nil {
				dataType = *result.DataType
			}
			fmt.Printf("  %d: Name: %s", i+1, name)
			if displayName != "" {
				fmt.Printf(" (%s)", displayName)
			}
			fmt.Printf(", Type: %s", objectType)
			if dataType != "" {
				fmt.Printf(", DataType: %s", dataType)
			}
			fmt.Println()
		}
	}

	// Example 6: Get active alarms
	fmt.Println("\n=== Active Alarms Example ===")
	alarms, err := c.GetActiveAlarmsSimple()
	if err != nil {
		fmt.Printf("Failed to get active alarms: %v\n", err)
	} else {
		fmt.Println("Active alarms (first 5):")
		for i, alarm := range alarms {
			if i >= 5 {
				break
			}
			name := "unknown"
			priority := 0
			state := "unknown"
			if alarm.Name != nil {
				name = *alarm.Name
			}
			if alarm.Priority != nil {
				priority = *alarm.Priority
			}
			if alarm.State != nil {
				state = *alarm.State
			}
			fmt.Printf("  %d: Name: %s, Priority: %d, State: %s\n", i+1, name, priority, state)
		}
	}

	// Example 7: Acknowledge alarms
	fmt.Println("\n=== Acknowledge Alarms Example ===")
	alarmIdentifiers := []*types.AlarmIdentifierInput{
		{
			Name:       "System::Alarm1",
			InstanceID: intPtr(1),
		},
	}

	ackResults, err := c.AcknowledgeAlarms(alarmIdentifiers)
	if err != nil {
		fmt.Printf("Failed to acknowledge alarms: %v\n", err)
	} else {
		fmt.Println("Acknowledge results:")
		for _, result := range ackResults {
			alarmName := "unknown"
			instanceID := 0
			if result.AlarmName != nil {
				alarmName = *result.AlarmName
			}
			if result.AlarmInstanceID != nil {
				instanceID = *result.AlarmInstanceID
			}
			fmt.Printf("  Name: %s, Instance ID: %d", alarmName, instanceID)
			if result.Error != nil {
				if result.Error.Code != nil && *result.Error.Code != "0" {
					fmt.Printf(", Error: %v\n", result.Error)
				} else {
					fmt.Println()
				}
			} else {
				fmt.Println()
			}
		}
	}

	// Example 8: Logged tag values
	fmt.Println("\n=== Logged Tag Values Example ===")
	loggingTagNames := []string{
		"PV-Vogler-PC::Meter_Input_WattAct:LoggingTag_1",
	}

	endTime := time.Now().Format(time.RFC3339)
	startTime := time.Now().Add(-6 * time.Hour).Format(time.RFC3339)

	fmt.Printf("Start time: %s\n", startTime)
	fmt.Printf("End time: %s\n", endTime)

	loggedValues, err := c.GetLoggedTagValuesSimple(
		loggingTagNames,
		&startTime,
		&endTime,
		100,
	)
	if err != nil {
		fmt.Printf("Failed to get logged tag values: %v\n", err)
	} else {
		fmt.Println("Logged tag values:")
		for _, loggedValue := range loggedValues {
			if loggedValue.LoggingTagName != nil {
				fmt.Printf("  Tag: %s\n", *loggedValue.LoggingTagName)
			}
			if loggedValue.Values != nil {
				fmt.Printf("  Values count: %d\n", len(loggedValue.Values))
				if len(loggedValue.Values) > 0 {
					fmt.Printf("  Sample values (first 3):\n")
					for i, value := range loggedValue.Values {
						if i >= 3 {
							break
						}
						fmt.Printf("    Value: %v", value.Value)
						if value.Timestamp != nil {
							fmt.Printf(", Time: %s", *value.Timestamp)
						}
						fmt.Println()
					}
				}
			}
			if loggedValue.Error != nil {
				if loggedValue.Error.Code != nil && *loggedValue.Error.Code != "0" {
					fmt.Printf("  Error: %v\n", loggedValue.Error)
				}
			}
		}
	}

	// Example 9: Logout
	fmt.Println("\n=== Logout Example ===")
	err = c.LogoutSimple()
	if err != nil {
		fmt.Printf("Logout failed: %v\n", err)
	} else {
		fmt.Println("Logout successful")
	}
}

// Helper functions
func intPtr(i int) *int {
	return &i
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}