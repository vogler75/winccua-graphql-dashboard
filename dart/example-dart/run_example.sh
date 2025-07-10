#!/bin/bash

# WinCC Unified Dart Example Runner
# This script sets up the environment and runs the Dart example

echo "WinCC Unified Dart Example Runner"
echo "=================================="
echo

# Check if Dart is installed
if ! command -v dart &> /dev/null; then
    echo "Error: Dart is not installed or not in PATH"
    echo "Please install Dart SDK from https://dart.dev/get-dart"
    exit 1
fi

# Check if environment variables are set
if [ -z "$GRAPHQL_HTTP_URL" ] || [ -z "$GRAPHQL_WS_URL" ] || [ -z "$GRAPHQL_USERNAME" ] || [ -z "$GRAPHQL_PASSWORD" ]; then
    echo "Warning: Environment variables not fully set"
    echo "Please set the following environment variables:"
    echo "  GRAPHQL_HTTP_URL=https://your-wincc-server/graphql"
    echo "  GRAPHQL_WS_URL=wss://your-wincc-server/graphql"
    echo "  GRAPHQL_USERNAME=your-username"
    echo "  GRAPHQL_PASSWORD=your-password"
    echo
    echo "Example usage:"
    echo "  export GRAPHQL_HTTP_URL=\"https://your-wincc-server/graphql\""
    echo "  export GRAPHQL_WS_URL=\"wss://your-wincc-server/graphql\""
    echo "  export GRAPHQL_USERNAME=\"your-username\""
    echo "  export GRAPHQL_PASSWORD=\"your-password\""
    echo "  ./run_example.sh"
    echo
fi

# Install dependencies if needed
if [ ! -d ".dart_tool" ]; then
    echo "Installing dependencies..."
    dart pub get
    echo
fi

# Run the example
echo "Running WinCC Unified Dart example..."
echo "Current configuration:"
echo "  HTTP URL: ${GRAPHQL_HTTP_URL:-https://your-wincc-server/graphql}"
echo "  WS URL: ${GRAPHQL_WS_URL:-wss://your-wincc-server/graphql}"
echo "  Username: ${GRAPHQL_USERNAME:-username}"
echo
dart run example.dart
