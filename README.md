# WinCC Unified GraphQL Client Libraries

GraphQL client libraries for WinCC Unified servers, providing comprehensive API access for industrial automation and SCADA systems.

## Overview

This repository contains client libraries for connecting to WinCC Unified GraphQL servers in both JavaScript and Python environments. The libraries provide full API coverage including authentication, tag operations, alarm management, and real-time subscriptions.

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

## Getting Started

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

## License

GPL-3.0 License