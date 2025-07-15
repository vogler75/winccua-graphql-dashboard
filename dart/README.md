# WinCC Unified GraphQL Client - Dart

A comprehensive Dart/Flutter GraphQL client library for WinCC Unified industrial automation systems, providing seamless API access for SCADA operations.

## Features

- **Authentication**: Username/password and SWAC (Siemens Web Access Control) login support
- **Tag Operations**: Read current and historical tag values, write tag values
- **Alarm Management**: Query active alarms, acknowledge/reset alarms
- **Real-time Subscriptions**: WebSocket-based subscriptions for tag values and alarms
- **Session Management**: Automatic token handling and session extension
- **Cross-platform**: Pure Dart implementation with Flutter UI examples

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  winccua_graphql_client:
    git:
      url: https://github.com/siemens/winccua-graphql-libs
      path: dart
```

## Basic Usage

### Client Initialization

```dart
import 'package:winccua_graphql_client/winccua_graphql_client.dart';

final client = WinCCUnifiedClient(
  httpUrl: 'https://your-wincc-server/graphql',
  wsUrl: 'wss://your-wincc-server/graphql',
);
```

### Authentication

```dart
// Username/password login
final session = await client.login('username', 'password');
print('Logged in as: ${session.user?.name}');

// SWAC login
final session = await client.loginSWAC(claim, signedClaim);

// Session extension
final extendedSession = await client.extendSession();

// Logout
await client.logout(allSessions: false);
```

### Tag Operations

```dart
// Read current tag values
final tagValues = await client.getTagValues(['HMI_Tag_1', 'HMI_Tag_2']);
for (final tag in tagValues) {
  if (tag.error == null) {
    print('${tag.name}: ${tag.value?.value} (Quality: ${tag.value?.quality?.quality})');
  }
}

// Write tag values
final writeResults = await client.writeTagValues([
  TagValueInput(name: 'HMI_Tag_1', value: 100),
  TagValueInput(name: 'HMI_Tag_2', value: 200),
]);

// Read historical logged values
final loggedValues = await client.getLoggedTagValues(
  names: ['LoggingTag_1'],
  startTime: DateTime.now().subtract(Duration(hours: 24)).toIso8601String(),
  endTime: DateTime.now().toIso8601String(),
  maxNumberOfValues: 100,
  sortingMode: LoggedTagValuesSortingMode.timeDesc,
);
```

### Alarm Management

```dart
// Get active alarms
final activeAlarms = await client.getActiveAlarms(
  systemNames: ['AlarmSystem1'],
  filterString: 'priority > 500',
  languages: ['en-US'],
);

// Acknowledge alarms
final ackResults = await client.acknowledgeAlarms([
  AlarmIdentifierInput(name: 'alarm1', raiseTime: '2023-01-01T10:00:00Z'),
]);

// Reset alarms
final resetResults = await client.resetAlarms([
  AlarmIdentifierInput(name: 'alarm1', raiseTime: '2023-01-01T10:00:00Z'),
]);
```

### Real-time Subscriptions

```dart
// Subscribe to tag value changes
final tagSubscription = client.subscribeToTagValues(['HMI_Tag_1', 'HMI_Tag_2']);
tagSubscription.listen((notification) {
  print('Tag update: ${notification.name} = ${notification.value?.value}');
});

// Subscribe to alarm changes
final alarmSubscription = client.subscribeToActiveAlarms(
  systemNames: ['AlarmSystem1'],
);
alarmSubscription.listen((notification) {
  print('Alarm update: ${notification.name} - ${notification.notificationReason}');
});

// Cancel subscriptions
await tagSubscription.cancel();
await alarmSubscription.cancel();
```

### Resource Cleanup

```dart
// Always dispose the client when done
client.dispose();
```

## Examples

### Dart Console Application

A complete standalone Dart example is available in [`example-dart/`](example-dart/):

```bash
cd example-dart
# Set environment variables
export GRAPHQL_HTTP_URL="https://your-wincc-server/graphql"
export GRAPHQL_WS_URL="wss://your-wincc-server/graphql"
export GRAPHQL_USERNAME="your-username"
export GRAPHQL_PASSWORD="your-password"

# Run the example
dart run example.dart
```

### Flutter Mobile Application

A complete Flutter monitoring app is available in [`example-flutter/`](example-flutter/):

```bash
cd example-flutter
flutter pub get
flutter run
```

Features include:
- Login screen with server URL configuration
- Dashboard with real-time tag monitoring
- Gauge and chart widgets for data visualization
- Active alarms display
- Cross-platform support (iOS, Android, Web, Desktop)

## Development

### Dependencies

The library uses these key dependencies:

- `graphql: ^5.1.3` - GraphQL client with subscription support
- `web_socket_channel: ^2.4.0` - WebSocket communication
- `http: ^1.1.0` - HTTP requests
- `rxdart: ^0.27.7` - Reactive streams
- `json_annotation: ^4.9.0` - JSON serialization

### Build Commands

```bash
# Install dependencies
flutter pub get

# Run code generation (for JSON serialization)
flutter pub run build_runner build

# Run tests
flutter test

# Analyze code
flutter analyze
```

## API Reference

### WinCCUnifiedClient

The main client class provides these methods:

#### Authentication
- `login(username, password)` - Standard login
- `loginSWAC(claim, signedClaim)` - SWAC authentication
- `extendSession()` - Extend current session
- `logout(allSessions)` - Logout from current or all sessions

#### Tag Operations
- `getTagValues(names, directRead)` - Read current tag values
- `writeTagValues(input, timestamp, quality)` - Write tag values
- `getLoggedTagValues(...)` - Read historical logged values

#### Alarm Management
- `getActiveAlarms(...)` - Query active alarms
- `acknowledgeAlarms(input)` - Acknowledge alarms
- `resetAlarms(input)` - Reset alarms

#### Subscriptions
- `subscribeToTagValues(names)` - Subscribe to tag value changes
- `subscribeToActiveAlarms(...)` - Subscribe to alarm changes

#### Lifecycle
- `dispose()` - Clean up resources and close connections

### Data Models

The library includes comprehensive data models for:

- `Session` - Authentication session information
- `TagValueResult` - Tag value with quality and timestamp
- `ActiveAlarm` - Alarm data with state and metadata
- `LoggedTagValuesResult` - Historical tag value data
- `Quality` - Data quality indicators for industrial applications

## Error Handling

All operations return structured error information:

```dart
final tagValues = await client.getTagValues(['InvalidTag']);
for (final tag in tagValues) {
  if (tag.error != null) {
    print('Error ${tag.error!.code}: ${tag.error!.description}');
  }
}
```

## Industrial Automation Context

This library is specifically designed for industrial automation scenarios:

- **Tag-based Data Model**: Reflects process variables and control points
- **Quality Indicators**: Comprehensive quality information essential for industrial applications
- **Alarm State Management**: Full alarm lifecycle support (raise, acknowledge, reset)
- **Historical Data**: Access to logged values for trend analysis and reporting
- **Real-time Updates**: WebSocket subscriptions for live monitoring

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

## Contributing

Contributions are welcome! Please read the [contributing guidelines](../CONTRIBUTING.md) first.

## Support

For issues and questions:
- Check the [GitHub Issues](https://github.com/siemens/winccua-graphql-libs/issues)
- Review the [main documentation](../README.md)
- See the [GraphQL schema](../sdl.gql) for API reference