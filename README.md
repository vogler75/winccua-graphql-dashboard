# WinCC Unified GraphQL Client Libraries

Multi-language GraphQL client libraries for WinCC Unified servers, providing comprehensive API access for industrial automation and SCADA systems.

## Overview

This repository contains client libraries for connecting to WinCC Unified GraphQL servers in JavaScript/Node.js, Python, Java, Rust, and Dart environments. The libraries provide full API coverage including authentication, tag operations, alarm management, and real-time subscriptions.

## Implementations

### JavaScript/Node.js (`nodejs/`)
- **Web Dashboard**: Interactive power monitoring dashboard with real-time gauges and trend charts
- **Browser Client**: HTML5-compatible client library for web applications
- **Node.js Client**: Server-side JavaScript client for automation scripts
- **Examples**: Automated tag oscillator and scripting framework

**Features:**
- Real-time WebSocket subscriptions
- Interactive dashboard with Chart.js visualization
- Comprehensive GraphQL API coverage
- Authentication and session management
- Tag reading, writing, and browsing
- Alarm management and monitoring

### Python (`python/`)
- **Async Client**: Modern Python async/await GraphQL client
- **HTTP & WebSocket**: Support for both query/mutation and subscription operations
- **Comprehensive API**: Full WinCC Unified GraphQL API coverage

**Features:**
- Async/await support with aiohttp and websockets
- Real-time subscriptions with callback handling
- Complete tag and alarm management
- Session management and authentication
- Error handling and connection management

### Java (`java/`)
- **Synchronous Client**: Thread-safe blocking API for JVM applications
- **Async Client**: Non-blocking async operations for high-performance scenarios
- **WebSocket Support**: Real-time subscriptions via GraphQL WebSocket protocol

**Features:**
- Java 21+ with modern language features
- OkHttp for HTTP transport, Jackson for JSON
- Thread-safe design for concurrent operations
- Comprehensive error handling with WinCC error codes
- Full GraphQL API coverage

### Rust (`rust/`)
- **Synchronous Client**: Simple, safe API with strong type guarantees
- **HTTP-only**: Focused on queries and mutations (no WebSocket)
- **Type Safety**: Leverages Rust's type system for compile-time guarantees

**Features:**
- Zero-unsafe code with memory safety
- Comprehensive error handling with Result types
- Integration tests for reliability
- Minimal dependencies for embedded scenarios

### Dart (`dart/`)
- **Pure Dart Client**: Platform-independent Dart library for console and server applications
- **Cross-Platform**: Works on any platform that supports Dart
- **Flutter Example**: Includes a complete Flutter monitoring app with UI

**Features:**
- Full GraphQL API support with queries, mutations, and subscriptions
- WebSocket support for real-time updates
- Strong type safety with Dart's type system
- Comprehensive error handling
- Example applications for both console (Dart) and mobile/desktop (Flutter)

## Getting Started

### Environment Setup
```bash
source setenv.sh  # Set required environment variables
```

### JavaScript/Node.js
```bash
cd nodejs/
npm install
npm start  # Start dashboard server
```

### Python
```bash
cd python/
pip install -r requirements.txt
python example.py  # Run example client
```

### Java
```bash
cd java/
mvn clean compile
mvn exec:java  # Run example
```

### Rust
```bash
cd rust/
cargo build --release
cargo run --example basic_usage
```

### Dart
```bash
cd dart/example-dart/
dart pub get
dart run example.dart  # Run console example

# For Flutter example:
cd dart/example-flutter/
flutter pub get
flutter run  # Run on connected device/emulator
```

## License

GPL-3.0 License