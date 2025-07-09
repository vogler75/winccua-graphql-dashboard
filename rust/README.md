# WinCC Unified GraphQL Client for Rust

A synchronous Rust client library for interacting with the WinCC Unified GraphQL API. This library provides comprehensive access to WinCC Unified systems including tag operations, alarm management, session handling, and browsing capabilities.

## Features

- **Synchronous GraphQL HTTP client** - No async/await complexity
- **Authentication with session tokens** - Automatic token management
- **Comprehensive error handling** - Detailed error types and messages
- **All WinCC Unified API endpoints** - Complete API coverage
- **Type-safe operations** - Strongly typed data structures
- **Extensive documentation** - JSON return examples for all methods

## Installation

Add this to your `Cargo.toml`:

```toml
[dependencies]
winccua-graphql-client = "1.0.0"
```

## Building and Running

### Prerequisites

- Rust 1.70 or later
- Cargo (comes with Rust)

### Compilation

To build the library:

```bash
cargo build
```

To build with optimizations for release:

```bash
cargo build --release
```

### Running Tests

To run all tests:

```bash
cargo test
```

To run tests with output:

```bash
cargo test -- --nocapture
```

### Running the Example

The library includes a comprehensive example that demonstrates all major features:

```bash
cargo run --example basic_usage
```

**Important:** Before running the example, make sure to:
1. Update the server URL in `examples/basic_usage.rs` to match your WinCC Unified server
2. Update the username and password in the example file
3. Ensure your WinCC Unified server is running and accessible

## Quick Start

```rust
use winccua_graphql_client::WinCCUnifiedClient;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Create client - only HTTP URL needed (no WebSocket subscriptions)
    let mut client = WinCCUnifiedClient::new("http://your-server:4000/graphql");
    
    // Login
    let session = client.login("username", "password")?;
    println!("Login successful! Token: {:?}", session.token);
    
    // Read tag values
    let tag_names = vec!["HMI_Tag_1".to_string(), "HMI_Tag_2".to_string()];
    let tag_values = client.get_tag_values_simple(&tag_names)?;
    
    for tag_value in tag_values {
        println!("Tag: {:?}, Value: {:?}", tag_value.name, tag_value.value);
    }
    
    // Logout
    client.logout_simple()?;
    
    Ok(())
}
```

## API Documentation

### Authentication

#### Login with Username/Password
```rust
let session = client.login("username", "password")?;
```

**Returns:** Session object containing user info, token, and expiry timestamp

```json
{
  "user": {
    "id": "string",
    "name": "string",
    "groups": [{"id": "string", "name": "string"}],
    "fullName": "string",
    "language": "string",
    "autoLogoffSec": 3600
  },
  "token": "string",
  "expires": "2023-12-31T23:59:59.999Z",
  "error": {
    "code": "string",
    "description": "string"
  }
}
```

#### Login with UMC SWAC
```rust
let session = client.login_swac("claim", "signed_claim")?;
```

#### Session Management
```rust
let sessions = client.get_session_single()?;
let extended_session = client.extend_session()?;
let logout_success = client.logout_simple()?;
```

### Tag Operations

#### Read Tag Values
```rust
let tag_names = vec!["HMI_Tag_1".to_string()];
let tag_values = client.get_tag_values_simple(&tag_names)?;

// With direct PLC read
let tag_values = client.get_tag_values(&tag_names, true)?;
```

**Returns:** Array of TagValueResult objects

```json
[{
  "name": "string",
  "value": {
    "value": "variant",
    "timestamp": "2023-12-31T23:59:59.999Z",
    "quality": {
      "quality": "GOOD_CASCADE",
      "subStatus": "NON_SPECIFIC",
      "limit": "OK",
      "extendedSubStatus": "NON_SPECIFIC",
      "sourceQuality": true,
      "sourceTime": true,
      "timeCorrected": false
    }
  },
  "error": {
    "code": "string",
    "description": "string"
  }
}]
```

#### Write Tag Values
```rust
use winccua_graphql_client::TagValueInput;
use serde_json::json;

let inputs = vec![TagValueInput {
    name: "HMI_Tag_1".to_string(),
    value: json!(123),
    timestamp: None,
    quality: None,
}];
let results = client.write_tag_values_simple(&inputs)?;
```

#### Read Logged Tag Values
```rust
let names = vec!["LoggingTag_1".to_string()];
let logged_values = client.get_logged_tag_values_simple(
    &names,
    Some("2023-01-01T00:00:00.000Z"), // start_time
    Some("2023-12-31T23:59:59.999Z"), // end_time
    100 // max_number_of_values
)?;
```

### Alarm Operations

#### Get Active Alarms
```rust
let alarms = client.get_active_alarms_simple()?;

// With filters
let alarms = client.get_active_alarms(
    &["System1".to_string()],     // system_names
    "",                           // filter_string
    "en-US",                      // filter_language
    &["en-US".to_string()]        // languages
)?;
```

#### Get Logged Alarms
```rust
let logged_alarms = client.get_logged_alarms_simple()?;

// With time range
let logged_alarms = client.get_logged_alarms(
    &[],                          // system_names
    "",                           // filter_string
    "en-US",                      // filter_language
    &["en-US".to_string()],       // languages
    Some("2023-01-01T00:00:00.000Z"), // start_time
    Some("2023-12-31T23:59:59.999Z"), // end_time
    1000                          // max_number_of_results
)?;
```

#### Acknowledge Alarms
```rust
use winccua_graphql_client::AlarmIdentifierInput;

let alarm_ids = vec![AlarmIdentifierInput {
    name: "System::Alarm1".to_string(),
    instance_id: Some(1),
}];
let results = client.acknowledge_alarms(&alarm_ids)?;
```

#### Reset Alarms
```rust
let results = client.reset_alarms(&alarm_ids)?;
```

#### Enable/Disable Alarms
```rust
let alarm_names = vec!["System::Alarm1".to_string()];
let enable_results = client.enable_alarms(&alarm_names)?;
let disable_results = client.disable_alarms(&alarm_names)?;
```

#### Shelve/Unshelve Alarms
```rust
let shelve_results = client.shelve_alarms_simple(&alarm_names)?;
let unshelve_results = client.unshelve_alarms(&alarm_names)?;

// With custom timeout
let shelve_results = client.shelve_alarms(&alarm_names, Some("PT30M"))?;
```

### Browse Operations

#### Browse Tags and Objects
```rust
let browse_results = client.browse_simple()?;

// Advanced browse with filters
let browse_results = client.browse(
    &["HMI_*".to_string()],       // name_filters
    &["TAG".to_string()],         // object_type_filters
    &[],                          // base_type_filters
    "en-US"                       // language
)?;
```

**Returns:** Array of BrowseTagsResult objects

```json
[{
  "name": "string",
  "displayName": "string",
  "objectType": "TAG",
  "dataType": "Int32"
}]
```

### Utility Operations

#### Get Nonce (for UMC SWAC)
```rust
let nonce = client.get_nonce()?;
```

#### Get Identity Provider URL
```rust
let url = client.get_identity_provider_url()?;
```

## Error Handling

The library provides comprehensive error handling with the `WinCCError` enum:

```rust
use winccua_graphql_client::WinCCError;

match client.login("user", "pass") {
    Ok(session) => println!("Login successful"),
    Err(WinCCError::LoginError(msg)) => println!("Login failed: {}", msg),
    Err(WinCCError::HttpError(e)) => println!("HTTP error: {}", e),
    Err(WinCCError::GraphQLError(msg)) => println!("GraphQL error: {}", msg),
    Err(e) => println!("Other error: {}", e),
}
```

### Common Error Codes

- **101** - Incorrect credentials provided
- **102** - UMC error
- **103** - Nonce expired
- **2** - Cannot resolve provided name
- **201** - Cannot convert provided value to data type
- **202** - Only leaf elements of a Structure Tag can be addressed
- **301** - Syntax error in query string
- **302** - Invalid language
- **303** - Invalid filter language
- **304** - Invalid object state
- **305** - Alarm cannot be acknowledged/reset in current state

## Configuration

The client can be configured for different environments:

```rust
// Development
let client = WinCCUnifiedClient::new("http://localhost:4000/graphql");

// Production with HTTPS
let client = WinCCUnifiedClient::new("https://production-server/graphql");

// Custom port
let client = WinCCUnifiedClient::new("http://192.168.1.100:8080/graphql");
```

## Dependencies

- `serde` - JSON serialization/deserialization
- `serde_json` - JSON handling
- `reqwest` - HTTP client (blocking feature)
- `chrono` - Date/time handling
- `thiserror` - Error handling

## Example Project Structure

```
your-project/
├── Cargo.toml
├── src/
│   └── main.rs
└── examples/
    └── wincc_example.rs
```

Example `Cargo.toml`:
```toml
[package]
name = "my-wincc-app"
version = "0.1.0"
edition = "2021"

[dependencies]
winccua-graphql-client = "1.0.0"
serde_json = "1.0"
chrono = "0.4"
```

## Important Notes

- **No Subscription Support**: This Rust client does not support WebSocket subscriptions (removed as requested). For real-time updates, use polling with the query methods.
- **Synchronous Only**: All operations are synchronous and blocking. This simplifies usage but may not be suitable for high-concurrency applications.
- **Token Management**: The client automatically manages authentication tokens after login.
- **Error Handling**: Always handle errors appropriately as network and authentication issues are common.

## License

GPL-3.0 License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues and questions, please refer to the WinCC Unified documentation or contact your system administrator.