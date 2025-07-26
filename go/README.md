# WinCC Unified GraphQL Client for Go

A comprehensive Go client library for the WinCC Unified GraphQL API, providing seamless access to industrial automation systems with full WebSocket subscription support.

## Features

- **HTTP GraphQL Client** - Synchronous queries and mutations
- **WebSocket GraphQL Client** - Real-time subscriptions with concurrent callbacks
- **Authentication Management** - Bearer token-based session handling
- **Comprehensive API Coverage** - All WinCC Unified operations supported
- **Strong Type Safety** - Complete type definitions for all API responses
- **Industrial-Grade Error Handling** - Proper error propagation and quality indicators

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

### WebSocket Subscriptions

```go
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "time"
    "winccua-graphql-client/pkg/client"
    "winccua-graphql-client/pkg/graphql"
)

func main() {
    // Create client with WebSocket support
    c := client.NewClientWithWebSocket(
        "http://your-wincc-server:4000/graphql",
        "ws://your-wincc-server:4000/graphql",
    )
    
    // Login and get token
    session, err := c.Login("username", "password")
    if err != nil {
        log.Fatal(err)
    }
    
    // Connect WebSocket
    err = c.ConnectWebSocket(*session.Token)
    if err != nil {
        log.Fatal(err)
    }
    defer c.DisconnectWebSocket()
    
    // Subscribe to tag values
    callbacks := graphql.SubscriptionCallbacks{
        OnData: func(data json.RawMessage) {
            // Handle tag value updates
            fmt.Printf("Tag update: %s\n", string(data))
        },
        OnError: func(err error) {
            log.Printf("Subscription error: %v", err)
        },
    }
    
    sub, err := c.SubscribeToTagValues([]string{"HMI_Tag_1"}, callbacks)
    if err != nil {
        log.Fatal(err)
    }
    
    // Listen for updates
    time.Sleep(30 * time.Second)
    
    // Stop subscription
    sub.Stop()
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