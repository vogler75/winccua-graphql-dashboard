# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a multi-language GraphQL client library collection for WinCC Unified industrial automation systems. The project provides comprehensive API access for SCADA operations across JavaScript/Node.js, Python, Java, and Rust implementations.

## Development Commands

### Environment Setup
```bash
source setenv.sh  # Set required environment variables for all examples
```

### JavaScript/Node.js (`nodejs/`)
```bash
npm install                    # Install dependencies
npm start                     # Start dashboard server
npm run script                # Run example script
node examples/counter.js      # Run counter example
```

### Python (`python/`)
```bash
pip install -r requirements.txt  # Install dependencies
pip install -e .                 # Install in development mode
python example.py                # Run example client
```

### Java (`java/`)
```bash
mvn clean compile             # Build project
mvn test                      # Run tests
mvn exec:java                 # Run main example
./runExample.sh               # Run synchronous example
./runExampleAsyncClient.sh    # Run async client example
```

### Rust (`rust/`)
```bash
cargo build                   # Build debug version
cargo build --release         # Build optimized release
cargo test                    # Run tests
cargo run --example basic_usage  # Run basic usage example
```

## Architecture Overview

### Core Design Pattern
All implementations follow a consistent three-layer architecture:
1. **Main Client Layer** (`WinCCUnifiedClient`) - High-level business logic API
2. **GraphQL Transport Layer** (`GraphQLClient`) - HTTP/WebSocket communication
3. **Query/Schema Layer** - Shared GraphQL query definitions

### Key Files
- `sdl.gql` - GraphQL schema definition (authoritative API reference)
- `setenv.sh` - Environment configuration for all examples
- Each language has dedicated query definitions maintaining API consistency

### Authentication & Session Management
- Bearer token-based authentication with automatic token management
- Session extension capabilities for long-running applications
- Multi-session support with optional session termination

### Transport Protocols
- **HTTP GraphQL** for queries and mutations
- **WebSocket GraphQL** for real-time subscriptions
- Dual URL configuration supports different deployment architectures

## Common Operations

### Tag Operations
- Read current tag values with comprehensive quality information
- Write tag values with proper error handling
- Browse available tags and objects in the system hierarchy
- Read historical logged tag values for trend analysis

### Alarm Management
- Query active alarms with filtering capabilities
- Get alarm history with time range support
- Acknowledge/reset alarms with proper state management
- Enable/disable and shelve/unshelve alarm functionality

### Real-time Features
- WebSocket subscriptions for tag value updates
- Active alarm change notifications
- Redundancy state monitoring
- Connection management with automatic reconnection

## Error Handling
All implementations use consistent error structure: `{ code: string, description: string }`
- GraphQL errors are properly propagated with WinCC system error codes
- Operations return errors within result objects for graceful degradation
- Comprehensive quality indicators for industrial data validation

## Testing Status
- **Rust**: Has integration tests in `tests/` directory
- **Java**: Test framework configured but limited test coverage
- **Node.js**: Test framework not implemented (`npm test` fails)
- **Python**: No test framework currently configured

## Language-Specific Notes

### JavaScript/Node.js
- Dual implementation for browser and Node.js environments
- Promise-based async API with event-driven subscription handling
- Express.js dashboard with Chart.js visualization

### Python
- Modern async/await patterns throughout
- aiohttp and websockets dependencies
- Type hints for better IDE support

### Java
- Requires Java 21+
- Synchronous blocking API with thread-safe design
- OkHttp for transport, Jackson for JSON handling

### Rust
- Synchronous-only design for simplicity
- Strong type safety with comprehensive error handling
- No WebSocket subscriptions (intentionally removed)

## Industrial Automation Context
This codebase is specifically designed for industrial automation scenarios with:
- Tag-based data model reflecting process variables
- Comprehensive alarm state machine support
- Data quality indicators essential for industrial applications
- Historical data access for trend analysis and reporting