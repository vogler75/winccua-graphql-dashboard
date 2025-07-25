# WinCC Unified GraphQL Client for Go

A Go library for accessing WinCC Unified systems via GraphQL API with full support for subscriptions and real-time data streaming.

## Features

- Complete GraphQL client implementation with HTTP and WebSocket support
- High-level API for WinCC Unified operations
- Tag reading and writing with quality information
- Browse system hierarchy
- Active alarm management and alarm history
- Real-time subscriptions for tags, alarms, and redundancy state
- Authentication and automatic session management
- Historical data access
- Redundancy state monitoring
- Context-aware operations with proper cancellation
- Comprehensive error handling
- Thread-safe design

## Installation

```bash
go get github.com/siemens/winccua-graphql-libs/go
```

## Dependencies

- Go 1.21 or later
- github.com/gorilla/websocket (for WebSocket subscriptions)

## Quick Start

### Environment Setup
Set the required environment variables:
```bash
export WINCCUA_URL="https://your-server:4043"
export WINCCUA_USERNAME="your-username"
export WINCCUA_PASSWORD="your-password"
```

Or source the provided environment script:
```bash
source ../setenv.sh
```

### Basic Usage

```go
package main

import (
    "context"
    "fmt"
    "log"
    "os"

    "github.com/siemens/winccua-graphql-libs/go/pkg/winccunified"
)

func main() {
    client := winccunified.NewClient(
        os.Getenv("WINCCUA_URL"),
        os.Getenv("WINCCUA_USERNAME"),
        os.Getenv("WINCCUA_PASSWORD"),
    )

    ctx := context.Background()

    // Connect
    if err := client.Connect(ctx); err != nil {
        log.Fatal(err)
    }
    defer client.Disconnect(ctx)

    // Read tags
    tags, err := client.ReadTags(ctx, []string{"Silo1_Temperature", "Silo1_Pressure"})
    if err != nil {
        log.Fatal(err)
    }

    for _, tag := range tags {
        if tag.Error != nil {
            fmt.Printf("Error reading %s: %s\n", tag.Name, tag.Error.Description)
        } else {
            fmt.Printf("%s = %s (Quality: %s)\n", tag.Name, tag.Value, tag.Quality)
        }
    }

    // Write tags
    writeResults, err := client.WriteTags(ctx, []winccunified.TagWrite{
        {Name: "Silo1_Temperature", Value: "25.5"},
        {Name: "Silo1_Pressure", Value: "1.2"},
    })
    if err != nil {
        log.Fatal(err)
    }

    for _, result := range writeResults {
        if result.Error != nil {
            fmt.Printf("Write failed for %s: %s\n", result.Name, result.Error.Description)
        } else {
            fmt.Printf("Successfully wrote to %s\n", result.Name)
        }
    }
}
```

### Real-time Subscriptions

```go
package main

import (
    "context"
    "fmt"
    "log"
    "os"

    "github.com/siemens/winccua-graphql-libs/go/pkg/winccunified"
)

func main() {
    client := winccunified.NewClient(
        os.Getenv("WINCCUA_URL"),
        os.Getenv("WINCCUA_USERNAME"),
        os.Getenv("WINCCUA_PASSWORD"),
    )

    ctx := context.Background()

    // Connect
    if err := client.Connect(ctx); err != nil {
        log.Fatal(err)
    }
    defer client.Disconnect(ctx)

    // Connect WebSocket for subscriptions
    if err := client.ConnectWebSocket(ctx); err != nil {
        log.Fatal(err)
    }
    defer client.DisconnectWebSocket()

    // Subscribe to tag changes
    tagCh, tagSub, err := client.SubscribeToTags(ctx, []string{"Silo1_Temperature", "Silo1_Pressure"})
    if err != nil {
        log.Fatal(err)
    }
    defer tagSub.Close()

    // Subscribe to alarm changes
    alarmCh, alarmSub, err := client.SubscribeToAlarms(ctx)
    if err != nil {
        log.Fatal(err)
    }
    defer alarmSub.Close()

    // Process subscription messages
    for {
        select {
        case tag := <-tagCh:
            if tag.Error != nil {
                fmt.Printf("Tag error: %s\n", tag.Error.Description)
            } else {
                fmt.Printf("Tag update: %s = %s\n", tag.Name, tag.Value)
            }

        case alarm := <-alarmCh:
            if alarm.Error != nil {
                fmt.Printf("Alarm error: %s\n", alarm.Error.Description)
            } else {
                fmt.Printf("Alarm update: %s - %s\n", alarm.Name, alarm.State)
            }

        case <-ctx.Done():
            return
        }
    }
}
```

## API Reference

### Client Creation and Connection
```go
client := winccunified.NewClient(baseURL, username, password)
err := client.Connect(ctx)
defer client.Disconnect(ctx)
```

### Tag Operations
```go
// Read tags
tags, err := client.ReadTags(ctx, []string{"tag1", "tag2"})

// Write tags
results, err := client.WriteTags(ctx, []winccunified.TagWrite{
    {Name: "tag1", Value: "value1"},
})

// Browse hierarchy
browseResult, err := client.Browse(ctx, "path")

// Read historical values
historical, err := client.ReadHistoricalValues(ctx, "tag", startTime, endTime, maxValues)
```

### Alarm Operations
```go
// Get active alarms
alarms, err := client.GetActiveAlarms(ctx)

// Get alarm history
alarmHistory, err := client.GetAlarmHistory(ctx, startTime, endTime)

// Acknowledge alarm
err := client.AcknowledgeAlarm(ctx, alarmID)

// Reset alarm
err := client.ResetAlarm(ctx, alarmID)
```

### Subscriptions
```go
// Connect WebSocket
err := client.ConnectWebSocket(ctx)
defer client.DisconnectWebSocket()

// Subscribe to tag changes
tagCh, tagSub, err := client.SubscribeToTags(ctx, tagNames)
defer tagSub.Close()

// Subscribe to alarm changes
alarmCh, alarmSub, err := client.SubscribeToAlarms(ctx)
defer alarmSub.Close()

// Subscribe to redundancy state changes
redundancyCh, redundancySub, err := client.SubscribeToRedundancyState(ctx)
defer redundancySub.Close()
```

### Redundancy Operations
```go
// Get redundancy state
redundancy, err := client.GetRedundancyState(ctx)
```

## Data Types

### TagResult
```go
type TagResult struct {
    Name      string    `json:"name"`
    Value     string    `json:"value"`
    Quality   string    `json:"quality"`
    Timestamp time.Time `json:"timestamp"`
    Error     *Error    `json:"error,omitempty"`
}
```

### Alarm
```go
type Alarm struct {
    ID        string     `json:"id"`
    State     string     `json:"state"`
    Name      string     `json:"name"`
    Text      string     `json:"text"`
    ClassName string     `json:"className"`
    ComeTime  time.Time  `json:"comeTime"`
    GoTime    *time.Time `json:"goTime,omitempty"`
    AckTime   *time.Time `json:"ackTime,omitempty"`
    Error     *Error     `json:"error,omitempty"`
}
```

### Error
```go
type Error struct {
    Code        string `json:"code"`
    Description string `json:"description"`
}
```

## Examples

The repository includes several example programs:

### Basic Usage
```bash
go run cmd/examples/basic_usage.go
```
Demonstrates all major synchronous operations including reading/writing tags, browsing, alarms, and historical data.

### Real-time Subscriptions
```bash
go run cmd/examples/subscriptions.go
```
Shows how to set up WebSocket subscriptions for real-time tag and alarm updates.

### Monitoring Dashboard
```bash
go run cmd/examples/monitor.go
```
Provides a console-based monitoring dashboard that continuously displays tag values and alarm states.

## Building

```bash
# Build all examples
make build

# Run tests
make test

# Format and vet code
make check

# Clean build artifacts
make clean
```

## Error Handling

All operations return detailed error information:

```go
tags, err := client.ReadTags(ctx, tagNames)
if err != nil {
    log.Printf("Operation failed: %v", err)
    return
}

for _, tag := range tags {
    if tag.Error != nil {
        log.Printf("Tag %s error: %s - %s", 
            tag.Name, tag.Error.Code, tag.Error.Description)
    }
}
```

## Session Management

The client automatically manages authentication tokens and provides:
- Automatic session extension (enabled by default)
- Graceful session termination
- Token refresh capabilities

```go
// Disable automatic session extension
client.SetAutoExtendSession(false)
```

## Thread Safety

The client is designed to be thread-safe for concurrent operations. Each client instance can be safely used across multiple goroutines.

## WebSocket Subscriptions

WebSocket subscriptions provide real-time updates with automatic reconnection handling:

- **Tag Subscriptions**: Real-time tag value changes
- **Alarm Subscriptions**: Active alarm state changes  
- **Redundancy Subscriptions**: System redundancy state changes

All subscriptions support proper cleanup and graceful shutdown.

## Testing

```bash
go test ./test/... -v
```

The test suite includes unit tests for core functionality with mock servers.

## License

See the main project LICENSE file.