# WinCC Unified GraphQL Client Library

A comprehensive JavaScript client library for WinCC Unified systems with complete GraphQL API integration. Includes authentication, tag operations, alarm management, and real-time subscriptions with an example power monitoring dashboard.

## Features

- **Complete GraphQL API**: Full WinCC Unified GraphQL schema implementation
- **Authentication**: Login/logout with username/password and SWAC support
- **Tag Operations**: Read current values, historical data, and browse tags
- **Alarm Management**: Query, acknowledge, reset, enable/disable, shelve/unshelve alarms
- **Real-time Subscriptions**: Live updates for tags, alarms, and redundancy state
- **WebSocket Support**: GraphQL subscriptions with automatic reconnection
- **Example Dashboard**: Power monitoring dashboard with gauges and trend charts

## Installation

```bash
npm install
```

## Quick Start

### 1. Start the Dashboard Server

```bash
npm start
```

### 2. Access the Dashboard

Open your browser and navigate to:
```
http://localhost:8080
```

### 3. Login and Monitor

- Enter your WinCC Unified credentials
- View real-time power gauges
- Analyze production vs consumption trends

## Dashboard Features

### Power Monitoring Gauges

The dashboard displays 3 real-time power gauges:

- **Meter Input Watts**: Power consumption from grid
- **Meter Output Watts**: Power output to grid  
- **PV Power Watts**: Solar power production

**Features:**
- Real-time value updates via WebSocket subscriptions
- 0-4000W range with color-coded backgrounds
- Rounded values for clean display
- Connection status indicators
- Quality and timestamp information

### Trend Chart Analytics

Interactive trend chart showing:

- **Green Line**: PV Power Production (`PV-Vogler-PC::PV_Power_WattAct`)
- **Red Line**: Meter Input Consumption (`PV-Vogler-PC::Meter_Input_WattAct`)

**Features:**
- Last 1000 data points per series from logging tags
- Real-time updates as new data arrives
- Production vs consumption comparison
- Manual refresh capability
- Responsive time-series visualization

## WinCC Unified GraphQL Client

### Basic Setup

```javascript
// Browser usage (already included in dashboard)
const client = new WinCCUnified('http://localhost:8080/graphql', 'ws://localhost:8080/graphql');

// Login and get token
try {
  const session = await client.login('username', 'password');
  console.log('Logged in successfully:', session.user.name);
} catch (error) {
  console.error('Login failed:', error.message);
}
```

### Complete API Reference

#### Authentication
```javascript
// Login with username/password
const session = await client.login('username', 'password');

// Login with SWAC (Single Sign-On)
const session = await client.loginSWAC('claim', 'signedClaim');

// Get nonce for SWAC login
const nonce = await client.getNonce();

// Get identity provider URL for SWAC
const url = await client.getIdentityProviderURL();

// Extend current session
const extendedSession = await client.extendSession();

// Set token manually
client.setToken('your-bearer-token');

// Get session information
const sessions = await client.getSession(false); // allSessions = false

// Logout (current or all sessions)
await client.logout(false); // allSessions = false
```

#### Tag Operations
```javascript
// Get current tag values
const tagValues = await client.getTagValues([
  'PV-Vogler-PC::PV_Power_WattAct',
  'PV-Vogler-PC::Meter_Input_WattAct'
], false); // directRead = false for cached values

// Get historical logged tag values
const loggedValues = await client.getLoggedTagValues(
  ['PV-Vogler-PC::PV_Power_WattAct:LoggingTag_1'], // names
  null, // startTime (null = from beginning)
  new Date().toISOString(), // endTime
  1000, // maxNumberOfValues
  'TIME_DESC' // sortingMode
);

// Browse available tags and objects
const browseResults = await client.browse({
  nameFilters: ['*power*', '*watt*'],
  objectTypeFilters: ['TAG', 'LOGGINGTAG', 'ALARM'],
  baseTypeFilters: ['MySystem::MyType'],
  language: 'en-US'
});

// Write tag values
const writeResults = await client.writeTagValues([
  {
    name: 'PV-Vogler-PC::PV_Power_WattAct',
    value: 2500.0,
    timestamp: new Date().toISOString(),
    quality: {
      quality: 'GOOD_CASCADE',
      subStatus: 'NON_SPECIFIC'
    }
  }
]);
```

#### Alarm Management
```javascript
// Get active alarms
const activeAlarms = await client.getActiveAlarms({
  systemNames: ['PV-Vogler-PC'],
  filterString: 'priority >= 8', // High priority alarms
  filterLanguage: 'en-US',
  languages: ['en-US', 'de-DE']
});

// Get logged/historical alarms
const loggedAlarms = await client.getLoggedAlarms({
  systemNames: ['PV-Vogler-PC'],
  filterString: 'state = "RAISED"',
  startTime: '2024-01-01T00:00:00.000Z',
  endTime: new Date().toISOString(),
  maxNumberOfResults: 100
});

// Acknowledge alarms
const ackResults = await client.acknowledgeAlarms([
  { name: 'MySystem::MyAlarm', instanceID: 1 },
  { name: 'MySystem::MyAlarm2' } // instanceID omitted = all instances
]);

// Reset alarms
const resetResults = await client.resetAlarms([
  { name: 'MySystem::MyAlarm', instanceID: 1 }
]);

// Enable/disable alarms
await client.enableAlarms(['MySystem::MyAlarm1', 'MySystem::MyAlarm2']);
await client.disableAlarms(['MySystem::MyAlarm1']);

// Shelve/unshelve alarms (temporarily suppress)
await client.shelveAlarms(['MySystem::MyAlarm1'], 3600); // 1 hour timeout
await client.unshelveAlarms(['MySystem::MyAlarm1']);
```

#### Real-time Subscriptions
```javascript
// Subscribe to tag value changes
const tagSubscription = await client.subscribeToTagValues([
  'PV-Vogler-PC::PV_Power_WattAct',
  'PV-Vogler-PC::Meter_Input_WattAct'
], (data, error) => {
  if (error) {
    console.error('Subscription error:', error);
    return;
  }
  console.log('Tag update:', data.name, data.value.value);
});

// Subscribe to active alarm changes
const alarmSubscription = await client.subscribeToActiveAlarms({
  systemNames: ['PV-Vogler-PC'],
  filterString: 'priority >= 8',
  languages: ['en-US']
}, (data, error) => {
  if (error) {
    console.error('Alarm subscription error:', error);
    return;
  }
  console.log('Alarm update:', data.notificationReason, data.name);
});

// Subscribe to redundancy state changes
const reduSubscription = await client.subscribeToReduState((data, error) => {
  if (error) {
    console.error('Redu state error:', error);
    return;
  }
  console.log('Redundancy state:', data.value.value); // ACTIVE or PASSIVE
});

// Unsubscribe from all
tagSubscription.unsubscribe();
alarmSubscription.unsubscribe();
reduSubscription.unsubscribe();
```

## Configuration

### Server Configuration
The dashboard proxies requests to your WinCC Unified server:
- Default target: `http://DESKTOP-KHLB071:4000`
- Update in `server.js` line 8 for your server

### Chart Configuration
- **Data Points**: Last 1000 points per series
- **Value Range**: 0-4000W for gauges
- **Update Rate**: Real-time via WebSocket subscriptions
- **Chart Library**: Chart.js v3.9.1

## Cleanup

```javascript
// Dispose client and close WebSocket connections
client.dispose();
```

## Complete GraphQL API Reference

### Queries

#### Authentication & Session Management
- **`session(allSessions: Boolean)`** - Get current session information
- **`nonce`** - Get nonce for SWAC authentication
- **`identityProviderURL`** - Get identity provider URL for SWAC login

#### Tag Operations
- **`tagValues(names: [String!]!, directRead: Boolean)`** - Query current tag values
- **`loggedTagValues(names: [String]!, startTime: Timestamp, endTime: Timestamp, maxNumberOfValues: Int, sortingMode: LoggedTagValuesSortingModeEnum, boundingValuesMode: LoggedTagValuesBoundingModeEnum)`** - Query historical logged tag data
- **`browse(nameFilters: [String], objectTypeFilters: [ObjectTypesEnum], baseTypeFilters: [String], language: String)`** - Browse available tags, elements, types, alarms and objects

#### Alarm Management
- **`activeAlarms(systemNames: [String], filterString: String, filterLanguage: String, languages: [String])`** - Query active alarms
- **`loggedAlarms(systemNames: [String], filterString: String, filterLanguage: String, languages: [String], startTime: Timestamp, endTime: Timestamp, maxNumberOfResults: Int)`** - Query historical alarm data

### Mutations

#### Authentication
- **`login(username: String!, password: String!)`** - Login with username/password
- **`loginSWAC(claim: String!, signedClaim: String!)`** - Login with SWAC (Single Sign-On)
- **`extendSession`** - Extend current session expiry
- **`logout(allSessions: Boolean)`** - Logout current or all sessions

#### Tag Operations
- **`writeTagValues(input: [TagValueInput]!, timestamp: Timestamp, quality: QualityInput)`** - Write values to tags

#### Alarm Operations
- **`acknowledgeAlarms(input: [AlarmIdentifierInput]!)`** - Acknowledge one or more alarms
- **`resetAlarms(input: [AlarmIdentifierInput]!)`** - Reset one or more alarms
- **`disableAlarms(names: [String]!)`** - Disable alarm instance creation
- **`enableAlarms(names: [String]!)`** - Enable alarm instance creation
- **`shelveAlarms(names: [String]!, shelveTimeout: Timespan)`** - Temporarily suppress alarms
- **`unshelveAlarms(names: [String]!)`** - Remove shelving from alarms

### Subscriptions

#### Real-time Data
- **`tagValues(names: [String!]!)`** - Subscribe to tag value changes
- **`activeAlarms(systemNames: [String], filterString: String, filterLanguage: String, languages: [String])`** - Subscribe to active alarm changes
- **`reduState`** - Subscribe to redundancy state changes

### WinCCUnified JavaScript Client API

#### Constructor
```javascript
new WinCCUnified(httpUrl, wsUrl)
```
- `httpUrl` - HTTP endpoint for GraphQL queries/mutations
- `wsUrl` - WebSocket endpoint for GraphQL subscriptions

#### Authentication Methods
- `login(username, password)` - Login with WinCC credentials
- `loginSWAC(claim, signedClaim)` - Login with SWAC
- `setToken(token)` - Set Bearer token manually
- `getSession(allSessions)` - Get session information
- `extendSession()` - Extend current session
- `logout(allSessions)` - Logout current or all sessions
- `getNonce()` - Get nonce for SWAC
- `getIdentityProviderURL()` - Get identity provider URL

#### Tag Methods
- `getTagValues(names, directRead)` - Get current tag values
- `getLoggedTagValues(names, startTime, endTime, maxValues, sortMode)` - Get historical data
- `writeTagValues(input, timestamp, quality)` - Write tag values
- `subscribeToTagValues(names, callback)` - Subscribe to real-time updates

#### Browse Methods
- `browse(options)` - Browse available tags and objects
  - `nameFilters` - Array of name patterns (supports wildcards)
  - `objectTypeFilters` - Filter by object types (TAG, LOGGINGTAG, etc.)
  - `baseTypeFilters` - Filter by base type names
  - `language` - Response language (default: "en-US")

#### Alarm Methods
- `getActiveAlarms(options)` - Get current active alarms
- `getLoggedAlarms(options)` - Get historical alarm data
- `acknowledgeAlarms(input)` - Acknowledge alarms
- `resetAlarms(input)` - Reset alarms
- `enableAlarms(names)` - Enable alarms
- `disableAlarms(names)` - Disable alarms
- `shelveAlarms(names, shelveTimeout)` - Shelve alarms temporarily
- `unshelveAlarms(names)` - Unshelve alarms
- `subscribeToActiveAlarms(options, callback)` - Subscribe to alarm changes

#### System Methods
- `subscribeToReduState(callback)` - Subscribe to redundancy state
- `dispose()` - Clean up resources and close connections

## Architecture

### Dashboard Components
- **Frontend**: HTML5 dashboard with Chart.js visualization
- **Backend**: Express.js proxy server for GraphQL requests
- **WebSocket**: Real-time data streaming via graphql-ws protocol
- **Authentication**: Bearer token-based WinCC Unified authentication

### Data Flow
1. **Login**: Authenticate with WinCC Unified server
2. **Historical**: Load last 1000 points from logging tags
3. **Real-time**: Subscribe to live tag value updates
4. **Display**: Update gauges and charts in real-time

## Dependencies

### Server
- `express` - Web server framework
- `http-proxy` - GraphQL proxy for WinCC Unified
- `graphql` - GraphQL implementation
- `graphql-ws` - WebSocket subscriptions
- `ws` - WebSocket client library

### Frontend
- `Chart.js` - Data visualization library
- `chartjs-adapter-date-fns` - Time series support
- Native browser WebSocket API

## System Requirements

- **Node.js**: v14+ recommended
- **WinCC Unified**: GraphQL API enabled
- **Browser**: Modern browser with WebSocket support
- **Network**: Access to WinCC Unified server on port 4000

## License

GPL-3.0 License