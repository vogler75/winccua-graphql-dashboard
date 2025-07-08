# WinCC Unified Python Client Library

A Python client library for connecting to WinCC Unified GraphQL API, providing both HTTP and WebSocket support for queries, mutations, and subscriptions.

## Features

- **HTTP GraphQL Client**: Execute queries and mutations
- **WebSocket GraphQL Client**: Real-time subscriptions for tag values, alarms, and system state
- **Comprehensive API Coverage**: Support for all WinCC Unified GraphQL operations
- **Async/Await Support**: Built with modern Python async programming
- **Authentication**: Token-based authentication with session management

## Installation

```bash
pip install -r requirements.txt
```

## Quick Start

```python
import asyncio
from winccunified_client import WinCCUnifiedClient

async def main():
    # Initialize client
    client = WinCCUnifiedClient(
        http_url="https://your-wincc-server/graphql",
        ws_url="wss://your-wincc-server/graphql"
    )
    
    async with client:
        # Login
        session = await client.login("username", "password")
        print(f"Logged in as: {session['user']['name']}")
        
        # Get tag values
        tags = await client.get_tag_values(["Tag1", "Tag2"])
        print(f"Tag values: {tags}")
        
        # Subscribe to tag value changes
        def on_tag_update(data):
            print(f"Tag update: {data}")
        
        subscription = await client.subscribe_to_tag_values(
            ["Tag1", "Tag2"],
            on_data=on_tag_update
        )
        
        # Keep subscription active
        await asyncio.sleep(60)
        
        # Unsubscribe
        subscription['unsubscribe']()

# Run the example
asyncio.run(main())
```

## API Reference

### WinCCUnifiedClient

Main client class for interacting with WinCC Unified GraphQL API.

#### Authentication Methods

- `login(username, password)` - Login with username/password
- `login_swac(claim, signed_claim)` - Login with SWAC authentication
- `set_token(token)` - Set authentication token directly
- `extend_session()` - Extend current session
- `logout(all_sessions=False)` - Logout from current or all sessions

#### Data Access Methods

- `get_tag_values(names, direct_read=False)` - Get current tag values
- `get_logged_tag_values(names, start_time=None, end_time=None, max_number_of_values=1000, sorting_mode='TIME_ASC')` - Get historical tag values
- `browse(name_filters=None, object_type_filters=None, base_type_filters=None, language='en-US')` - Browse available objects
- `get_active_alarms(system_names=None, filter_string='', filter_language='en-US', languages=None)` - Get active alarms
- `get_logged_alarms(system_names=None, filter_string='', filter_language='en-US', languages=None, start_time=None, end_time=None, max_number_of_results=0)` - Get alarm history

#### Tag Writing Methods

- `write_tag_values(tag_values, timestamp=None, quality=None)` - Write values to tags

#### Alarm Management Methods

- `acknowledge_alarms(alarm_identifiers)` - Acknowledge alarms
- `reset_alarms(alarm_identifiers)` - Reset alarms
- `disable_alarms(names)` - Disable alarms
- `enable_alarms(names)` - Enable alarms
- `shelve_alarms(names, shelve_timeout=None)` - Shelve alarms
- `unshelve_alarms(names)` - Unshelve alarms

#### Subscription Methods

- `subscribe_to_tag_values(names, on_data=None, on_error=None, on_complete=None)` - Subscribe to tag value changes
- `subscribe_to_active_alarms(system_names=None, filter_string='', filter_language='en-US', languages=None, on_data=None, on_error=None, on_complete=None)` - Subscribe to alarm changes
- `subscribe_to_redu_state(on_data=None, on_error=None, on_complete=None)` - Subscribe to redundancy state changes

## Data Structures

### Tag Value Input
```python
tag_value = {
    "name": "TagName",
    "value": "TagValue"
}
```

### Alarm Identifier Input
```python
alarm_identifier = {
    "alarmName": "AlarmName",
    "alarmInstanceID": "InstanceID"
}
```

### Quality Input
```python
quality = {
    "quality": "GOOD",
    "subStatus": 0,
    "limit": "NONE"
}
```

## Error Handling

The library raises Python exceptions for GraphQL errors and connection issues:

```python
try:
    await client.login("invalid_user", "invalid_password")
except Exception as e:
    print(f"Login failed: {e}")
```

## WebSocket Subscriptions

Subscriptions use callbacks for handling real-time data:

```python
async def on_data(data):
    print(f"Received: {data}")

async def on_error(error):
    print(f"Error: {error}")

async def on_complete():
    print("Subscription completed")

subscription = await client.subscribe_to_tag_values(
    ["Tag1", "Tag2"],
    on_data=on_data,
    on_error=on_error,
    on_complete=on_complete
)
```

## Requirements

- Python 3.8+
- websockets>=11.0.0
- aiohttp>=3.8.0

## License

ISC License - see LICENSE file for details.