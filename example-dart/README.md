# WinCC Unified Dart Example

This is a standalone Dart example that demonstrates the usage of the WinCC Unified GraphQL API. It performs the same operations as the Java example, including authentication, browsing objects, reading/writing tags, handling alarms, and managing subscriptions.

## Features

- Login with username/password authentication
- Browse available objects in the WinCC Unified system
- Read and write tag values
- Query logged/historical tag values
- Get active alarms
- Subscribe to real-time tag value changes
- Subscribe to active alarm updates
- Proper session management and cleanup

## Prerequisites

- Dart SDK 3.0.0 or higher
- Access to a WinCC Unified system with GraphQL API enabled

## Installation

1. Navigate to the example directory:
   ```bash
   cd example-dart
   ```

2. Install dependencies:
   ```bash
   dart pub get
   ```

## Configuration

The example uses environment variables for configuration. Set the following environment variables before running:

- `GRAPHQL_HTTP_URL`: HTTP URL of the WinCC Unified GraphQL endpoint (e.g., `https://your-server/graphql`)
- `GRAPHQL_WS_URL`: WebSocket URL for GraphQL subscriptions (e.g., `wss://your-server/graphql`)  
- `GRAPHQL_USERNAME`: Username for authentication
- `GRAPHQL_PASSWORD`: Password for authentication

### Setting Environment Variables

#### On Windows (Command Prompt):
```cmd
set GRAPHQL_HTTP_URL=https://your-wincc-server/graphql
set GRAPHQL_WS_URL=wss://your-wincc-server/graphql
set GRAPHQL_USERNAME=your-username
set GRAPHQL_PASSWORD=your-password
```

#### On Windows (PowerShell):
```powershell
$env:GRAPHQL_HTTP_URL="https://your-wincc-server/graphql"
$env:GRAPHQL_WS_URL="wss://your-wincc-server/graphql"
$env:GRAPHQL_USERNAME="your-username"
$env:GRAPHQL_PASSWORD="your-password"
```

#### On macOS/Linux:
```bash
export GRAPHQL_HTTP_URL="https://your-wincc-server/graphql"
export GRAPHQL_WS_URL="wss://your-wincc-server/graphql"
export GRAPHQL_USERNAME="your-username"
export GRAPHQL_PASSWORD="your-password"
```

## Running the Example

After setting the environment variables, run the example:

```bash
dart run example.dart
```

## What the Example Does

1. **Authentication**: Logs in using the provided credentials
2. **Session Info**: Retrieves and displays current session information
3. **Browsing**: Lists available objects in the WinCC Unified system
4. **Tag Reading**: Reads current values of specified tags
5. **Historical Data**: Queries logged tag values from the last 24 hours
6. **Alarm Query**: Retrieves active alarms
7. **Tag Writing**: Writes new values to specified tags
8. **Real-time Subscriptions**: 
   - Subscribes to tag value changes for 30 seconds
   - Subscribes to active alarm updates for 30 seconds
9. **Cleanup**: Properly logs out and closes all connections

## Customization

To use with your specific WinCC Unified system:

1. Update the tag names in the example (currently using `HMI_Tag_1`, `HMI_Tag_2`)
2. Modify the logged tag name (`PV-Vogler-PC::Meter_Input_WattAct:LoggingTag_1`)
3. Adjust subscription duration or add custom logic for handling real-time data

## Error Handling

The example includes comprehensive error handling for:
- Network connectivity issues
- Authentication failures
- Invalid tag names
- GraphQL query errors
- WebSocket connection problems

## Dependencies

- `http`: For making HTTP requests to the GraphQL endpoint
- `graphql`: For GraphQL query formatting and parsing
- `web_socket_channel`: For WebSocket subscriptions

## Notes

- The example uses a simplified GraphQL client implementation for educational purposes
- In production, consider using more robust GraphQL libraries like `graphql_flutter` or `ferry`
- WebSocket subscriptions require proper error handling and reconnection logic for production use
- Always ensure proper authentication and authorization for your WinCC Unified system
