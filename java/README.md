# WinCC Unified GraphQL Java Client

A Java 17+ client library for WinCC Unified GraphQL API with synchronous HTTP requests and WebSocket subscription support.

## Features

- **Synchronous API**: All operations are blocking/synchronous by design
- **WebSocket Subscriptions**: Real-time updates via WebSocket subscriptions
- **Comprehensive Coverage**: Supports all WinCC Unified GraphQL operations
- **Type-Safe**: Uses Maps and Lists for data structures
- **Thread-Safe**: Can be used from multiple threads
- **Auto-Reconnect**: WebSocket automatically reconnects on connection loss
- **Prepared for Async**: Architecture allows easy addition of async layer on top

## Requirements

- Java 17 or higher
- Maven 3.6+
- WinCC Unified server with GraphQL API enabled

## Dependencies

- **OkHttp**: HTTP client and WebSocket support
- **Jackson**: JSON processing
- **SLF4J**: Logging

## Usage

### Basic Example

```java
import com.siemens.wincc.unified.WinCCUnifiedClient;
import com.siemens.wincc.unified.SubscriptionCallbacks;
import java.util.List;
import java.util.Map;

public class Example {
    public static void main(String[] args) {
        try (WinCCUnifiedClient client = new WinCCUnifiedClient(
            "https://your-server/graphql",
            "wss://your-server/graphql"
        )) {
            // Login
            Map<String, Object> session = client.login("username", "password");
            System.out.println("Logged in as: " + session.get("user"));
            
            // Get tag values
            List<String> tagNames = List.of("Tag1", "Tag2");
            List<Map<String, Object>> tags = client.getTagValues(tagNames);
            
            // Subscribe to tag changes
            var subscription = client.subscribeToTagValues(tagNames, 
                SubscriptionCallbacks.of(
                    data -> System.out.println("Tag update: " + data),
                    error -> System.err.println("Error: " + error),
                    () -> System.out.println("Subscription completed")
                )
            );
            
            // Keep subscription active
            Thread.sleep(30_000);
            
            // Cleanup
            subscription.unsubscribe();
            client.logout();
        }
    }
}
```

### Environment Variables

Set these environment variables for the example:

```bash
export GRAPHQL_HTTP_URL="https://your-wincc-server/graphql"
export GRAPHQL_WS_URL="wss://your-wincc-server/graphql"
export GRAPHQL_USERNAME="your-username"
export GRAPHQL_PASSWORD="your-password"
```

## Building

```bash
mvn clean compile
```

## Running the Example

```bash
mvn exec:java
```

## Architecture

The client is designed as a synchronous API that can have an asynchronous layer added on top:

- **WinCCUnifiedClient**: Main client class with synchronous methods
- **GraphQLClient**: HTTP GraphQL client for queries and mutations
- **GraphQLWSClient**: WebSocket client for subscriptions
- **SubscriptionCallbacks**: Callback interface for subscription events

## API Reference

### Session Management

```java
// Login
Map<String, Object> session = client.login("username", "password");

// Get session info
List<Map<String, Object>> sessions = client.getSession();

// Extend session
Map<String, Object> extendedSession = client.extendSession();

// Logout
boolean success = client.logout();
```

### Tag Operations

```java
// Get current tag values
List<Map<String, Object>> tags = client.getTagValues(List.of("Tag1", "Tag2"));

// Get logged tag values
List<Map<String, Object>> history = client.getLoggedTagValues(
    List.of("LoggingTag1"),
    "2023-01-01T00:00:00Z",
    "2023-01-02T00:00:00Z",
    1000
);

// Write tag values
List<Map<String, Object>> writeResults = client.writeTagValues(List.of(
    Map.of("name", "Tag1", "value", 100),
    Map.of("name", "Tag2", "value", 200)
));
```

### Alarm Operations

```java
// Get active alarms
List<Map<String, Object>> alarms = client.getActiveAlarms();

// Get logged alarms
List<Map<String, Object>> history = client.getLoggedAlarms();

// Acknowledge alarms
List<Map<String, Object>> results = client.acknowledgeAlarms(List.of(
    Map.of("name", "AlarmName", "instanceID", 1)
));
```

### Subscriptions

```java
// Subscribe to tag values
Subscription tagSub = client.subscribeToTagValues(
    List.of("Tag1", "Tag2"),
    SubscriptionCallbacks.of(
        data -> processTagUpdate(data),
        error -> handleError(error),
        () -> System.out.println("Completed")
    )
);

// Subscribe to active alarms
Subscription alarmSub = client.subscribeToActiveAlarms(
    SubscriptionCallbacks.of(data -> processAlarmUpdate(data))
);

// Unsubscribe
tagSub.unsubscribe();
alarmSub.unsubscribe();
```

## Error Handling

The client throws `IOException` for network and GraphQL errors:

```java
try {
    List<Map<String, Object>> tags = client.getTagValues(tagNames);
} catch (IOException e) {
    System.err.println("Request failed: " + e.getMessage());
}
```

## Thread Safety

The client is thread-safe and can be used from multiple threads simultaneously. WebSocket subscriptions are handled asynchronously in background threads.

## Adding Async Support

To add async support, you can wrap the client methods in CompletableFuture:

```java
CompletableFuture<List<Map<String, Object>>> future = 
    CompletableFuture.supplyAsync(() -> {
        try {
            return client.getTagValues(tagNames);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    });
```

Or use a thread pool:

```java
ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
executor.submit(() -> {
    try {
        List<Map<String, Object>> tags = client.getTagValues(tagNames);
        // Process tags
    } catch (IOException e) {
        // Handle error
    }
});
```

## License

GPL-3.0 License