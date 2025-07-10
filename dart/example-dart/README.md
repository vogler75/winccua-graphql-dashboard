# WinCC Unified Dart Example

This is a standalone Dart command-line example that demonstrates the usage of the WinCC Unified GraphQL API. It performs the same operations as the Java example, including authentication, browsing objects, reading/writing tags, handling alarms, and managing subscriptions.

## Features

- **Authentication**: Login with username/password authentication
- **Session Management**: Get and display session information
- **Object Browsing**: Browse available objects in the WinCC Unified system
- **Tag Operations**: Read and write tag values with quality information
- **Historical Data**: Query logged/historical tag values with time filtering
- **Alarm Management**: Get active alarms and their details
- **Real-time Subscriptions**: Subscribe to tag value changes and alarm updates
- **Error Handling**: Comprehensive error handling for all operations
- **Environment Configuration**: Uses environment variables for server settings

## Prerequisites

- **Dart SDK**: 3.0.0 or higher
- **WinCC Unified Server**: Access to a WinCC Unified system with GraphQL API enabled
- **Network Access**: Connectivity to the WinCC Unified server (HTTP/WebSocket)

## Installation

1. **Navigate to the example directory**:
   ```bash
   cd dart/example-dart
   ```

2. **Install dependencies**:
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

### Using a .env file (optional)

Create a `.env` file in the example directory:
```env
GRAPHQL_HTTP_URL=https://your-wincc-server/graphql
GRAPHQL_WS_URL=wss://your-wincc-server/graphql
GRAPHQL_USERNAME=your-username
GRAPHQL_PASSWORD=your-password
```

## Running the Example

### Method 1: Using Dart directly
```bash
dart run example.dart
```

### Method 2: Using the provided script
```bash
./run_example.sh
```

The script will:
- Check if Dart is installed
- Verify environment variables are set
- Install dependencies if needed
- Run the example

## What the Example Does

The example performs the following operations in sequence:

1. **Authentication**
   - Logs in using the provided credentials
   - Displays session information including user details and token expiration

2. **Session Information**
   - Retrieves and displays current session details
   - Shows user information and session expiration times

3. **Object Browsing**
   - Lists available objects in the WinCC Unified system
   - Displays first 5 objects with their names and types

4. **Tag Reading**
   - Reads current values of specified tags (`HMI_Tag_1`, `HMI_Tag_2`)
   - Shows tag values, quality information, and timestamps
   - Handles and displays any errors for individual tags

5. **Historical Data Query**
   - Queries logged tag values from the last 24 hours
   - Displays up to 10 historical values per tag
   - Shows timestamps, values, and quality information

6. **Active Alarms**
   - Retrieves currently active alarms
   - Displays alarm names, event texts, and priorities
   - Shows first 3 alarms as examples

7. **Tag Writing**
   - Writes new values to specified tags
   - Reports success or failure for each write operation

8. **Real-time Subscriptions**
   - **Tag Value Subscription**: Subscribes to tag value changes for 30 seconds
   - **Alarm Subscription**: Subscribes to active alarm updates for 30 seconds
   - Displays real-time updates as they occur

9. **Cleanup**
   - Properly logs out from the server
   - Closes all WebSocket connections
   - Cleans up resources

## Customization

To use with your specific WinCC Unified system:

### Update Tag Names
Modify these lines in `example.dart`:
```dart
final tagNames = ['HMI_Tag_1', 'HMI_Tag_2']; // Replace with your tag names
```

### Update Logged Tag Names
Change the logged tag query:
```dart
final loggedValues = await client.getLoggedTagValues(
  ['PV-Vogler-PC::Meter_Input_WattAct:LoggingTag_1'], // Your logged tag name
  startTime.toIso8601String(),
  endTime.toIso8601String(),
  10,
);
```

### Adjust Time Ranges
Modify the historical data time range:
```dart
final endTime = DateTime.now();
final startTime = endTime.subtract(const Duration(hours: 24)); // Change duration
```

### Change Subscription Duration
Adjust how long subscriptions stay active:
```dart
await Future.delayed(const Duration(seconds: 30)); // Change duration
```

## Output Example

```
WinCC Unified Dart Client Example
========================================

Note: Please set GRAPHQL_HTTP_URL, GRAPHQL_WS_URL, GRAPHQL_USERNAME, and GRAPHQL_PASSWORD environment variables...

Logging in...
Logged in as: AdminUser
Token expires: 2024-01-15T10:30:00.000Z

Getting session info...
Session info:
  - User: Administrator User, Expires: 2024-01-15T10:30:00.000Z

Browsing available objects...
Found 25 objects
  - System1::Tank1 (Tank)
  - System1::Pump1 (Pump)
  - System1::Valve1 (Valve)
  - System1::Sensor1 (Sensor)
  - System1::Motor1 (Motor)

Getting tag values...
  - HMI_Tag_1: 42.5 (Quality: GOOD, Time: 2024-01-15T09:45:23.123Z)
  - HMI_Tag_2: ERROR - Tag not found

[... continues with all operations ...]

Logging out...
Logged out successfully
```

## Error Handling

The example includes comprehensive error handling for:

- **Network Issues**: Connection timeouts, DNS resolution failures
- **Authentication Failures**: Invalid credentials, expired tokens
- **Invalid Tag Names**: Non-existent tags, permission issues
- **GraphQL Errors**: Malformed queries, server-side errors
- **WebSocket Issues**: Connection drops, subscription failures

All errors are caught and displayed with descriptive messages.

## Dependencies

The example uses these Dart packages:

- **`http`**: For making HTTP requests to the GraphQL endpoint
- **`graphql`**: For GraphQL query formatting and parsing (optional, used by the simple client)
- **`web_socket_channel`**: For WebSocket subscriptions

## Development and Testing

### Running with Debug Output
To see more detailed logging, you can modify the example to include debug prints:

```dart
// Add this for more verbose output
print('Making request to: $httpUrl');
print('Request payload: $body');
```

### Testing Connection
Test basic connectivity before running the full example:

```bash
# Test HTTP endpoint
curl -X POST https://your-server/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"query { __schema { types { name } } }"}'

# Test WebSocket (using websocat if available)
websocat wss://your-server/graphql
```

### Modifying for Production
For production use, consider:

- Adding proper SSL certificate validation
- Implementing connection retry logic
- Adding more robust error handling
- Using proper logging instead of print statements
- Implementing graceful shutdown handling

## Troubleshooting

### Common Issues

1. **"Connection refused" errors**:
   - Check if the WinCC Unified server is running
   - Verify the URLs are correct
   - Check firewall settings

2. **"Certificate verification failed"**:
   - Ensure SSL certificates are properly configured
   - For development, you may need to disable certificate validation

3. **"Authentication failed"**:
   - Verify username and password are correct
   - Check if the user account is enabled
   - Ensure the user has GraphQL API access permissions

4. **"Tag not found" errors**:
   - Verify tag names exist in your WinCC Unified project
   - Check tag name syntax (system::tagname format)
   - Ensure proper read/write permissions

5. **WebSocket connection issues**:
   - Check if WebSocket protocol (ws/wss) matches server configuration
   - Verify proxy settings if behind a corporate firewall
   - Ensure WebSocket port is accessible

### Getting Help

If you encounter issues:

1. Check the console output for detailed error messages
2. Verify your WinCC Unified server configuration
3. Test with the Flutter example to isolate issues
4. Review the main library documentation in `../README.md`

## License

GPL-3.0 License
