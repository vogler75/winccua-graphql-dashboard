# WinCC Unified GraphQL Client for Go

A comprehensive Go client library for the WinCC Unified GraphQL API, providing seamless access to industrial automation systems with full WebSocket subscription support.

## Features

- **HTTP GraphQL Client** - Synchronous queries and mutations ✅
- **WebSocket GraphQL Client** - Real-time subscriptions ⚠️ (Known Issues - See Below)
- **Authentication Management** - Bearer token-based session handling ✅
- **Comprehensive API Coverage** - All WinCC Unified operations supported ✅
- **Strong Type Safety** - Complete type definitions for all API responses ✅
- **Industrial-Grade Error Handling** - Proper error propagation and quality indicators ✅

## Known Issues

### WebSocket Subscriptions
⚠️ **WebSocket subscriptions are currently not working properly** due to frame corruption issues with the gorilla/websocket library when connecting to WinCC Unified servers. 

**Symptoms:**
- `websocket: RSV2 set, RSV3 set, bad opcode` errors
- Connection failures during subscription setup

**Status:** Under investigation. The HTTP GraphQL client works perfectly for all queries, mutations, and polling-based solutions.

**Workaround:** Use HTTP GraphQL polling instead of WebSocket subscriptions for real-time data until this issue is resolved.

## Installation

```bash
go mod init your-project
go get winccua-graphql-client
```

## Quick Start

### Basic Usage

```go
package main

import (
    "fmt"
    "log"
    "winccua-graphql-client/pkg/client"
    "winccua-graphql-client/pkg/types"
)

func main() {
    // Create client
    c := client.NewClient("http://your-wincc-server:4000/graphql")
    
    // Login
    session, err := c.Login("username", "password")
    if err != nil {
        log.Fatal(err)
    }
    fmt.Printf("Logged in as: %s\n", *session.User)
    
    // Read tag values
    tagValues, err := c.GetTagValuesSimple([]string{"HMI_Tag_1", "HMI_Tag_2"})
    if err != nil {
        log.Fatal(err)
    }
    
    for _, tag := range tagValues {
        fmt.Printf("Tag %s = %v\n", *tag.Name, tag.Value)
    }
    
    // Logout
    c.LogoutSimple()
}
```

### WebSocket Subscriptions (⚠️ Currently Not Working)

**Note: WebSocket subscriptions are currently experiencing issues. Use HTTP polling as a workaround.**

```go
// Example of HTTP polling as workaround for real-time data
package main

import (
    "fmt"
    "log"
    "time"
    "winccua-graphql-client/pkg/client"
)

func main() {
    // Create HTTP client
    c := client.NewClient("http://your-wincc-server:4000/graphql")
    
    // Login
    _, err := c.Login("username", "password")
    if err != nil {
        log.Fatal(err)
    }
    
    // Poll tag values every 2 seconds (workaround for subscriptions)
    ticker := time.NewTicker(2 * time.Second)
    defer ticker.Stop()
    
    tagNames := []string{"HMI_Tag_1", "HMI_Tag_2"}
    
    for range ticker.C {
        tagValues, err := c.GetTagValuesSimple(tagNames)
        if err != nil {
            log.Printf("Error reading tags: %v", err)
            continue
        }
        
        for _, tag := range tagValues {
            if tag.Value != nil {
                fmt.Printf("Tag %s = %v at %s\n", 
                    *tag.Name, tag.Value.Value, *tag.Value.Timestamp)
            }
        }
    }
}
```

## Project Structure

```
go/
├── pkg/
│   ├── client/           # Main WinCC Unified client
│   │   └── client.go
│   ├── graphql/          # GraphQL transport layer
│   │   ├── client.go     # HTTP GraphQL client
│   │   ├── websocket.go  # WebSocket GraphQL client
│   │   └── queries.go    # GraphQL query definitions
│   └── types/            # Type definitions
│       └── types.go
├── examples/
│   ├── basic_usage/      # Basic operations example
│   │   └── main.go
│   └── subscriptions/    # WebSocket subscriptions example
│       └── main.go
├── go.mod
└── README.md
```

## API Operations

### Authentication
- `Login(username, password)` - Authenticate and get session token
- `Logout(allSessions)` - End session(s)
- `GetSession()` - Get current session information

### Tag Operations
- `GetTagValues(tagNames)` - Read current tag values
- `WriteTagValues(values)` - Write values to tags
- `Browse(path, maxResults)` - Browse tag namespace
- `GetLoggedTagValues(tagNames, startTime, endTime, maxResults)` - Historical data

### Alarm Management
- `GetActiveAlarms()` - Query active alarms
- `AcknowledgeAlarms(alarms)` - Acknowledge alarms

### Real-time Subscriptions
- `SubscribeToTagValues(tagNames, callbacks)` - Tag value updates
- `SubscribeToActiveAlarms(callbacks)` - Alarm notifications
- `SubscribeToRedundancyState(callbacks)` - Redundancy state changes

## Environment Configuration

Use the provided `setenv.sh` script to configure connection parameters:

```bash
source setenv.sh
```

This sets the following environment variables:
- `GRAPHQL_HTTP_URL` - HTTP GraphQL endpoint
- `GRAPHQL_WS_URL` - WebSocket GraphQL endpoint  
- `GRAPHQL_USERNAME` - Authentication username
- `GRAPHQL_PASSWORD` - Authentication password

## Error Handling

All operations return structured errors following the WinCC Unified pattern:

```go
type WinCCError struct {
    Code        *string `json:"code,omitempty"`
    Description *string `json:"description,omitempty"`
}
```

Success is indicated by error code "0" or nil error fields.

## Industrial Data Quality

Tag values include comprehensive quality information:

```go
type TagValue struct {
    Name      *string     `json:"name,omitempty"`
    Value     interface{} `json:"value,omitempty"`
    Timestamp *string     `json:"timestamp,omitempty"`
    Quality   *string     `json:"quality,omitempty"`
    Error     *WinCCError `json:"error,omitempty"`
}
```

## Building and Running

```bash
# Install dependencies
go mod tidy

# Build all packages
go build ./...

# Run basic usage example
go run examples/basic_usage/main.go

# Run subscription example  
go run examples/subscriptions/main.go
```

## Dependencies

- `github.com/gorilla/websocket` - WebSocket client implementation
- `github.com/valyala/fastjson` - Fast JSON parsing

## License

GPL-3.0 - Same as other implementations in this repository.