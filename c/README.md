# WinCC Unified GraphQL Client for C

A C library for accessing WinCC Unified systems via GraphQL API.

## Features

- Complete GraphQL client implementation using libcurl
- High-level API for WinCC Unified operations
- Tag reading and writing with quality information
- Browse system hierarchy
- Active alarm management
- Authentication and session management
- Thread-safe design
- Minimal dependencies (libcurl and cJSON)

## Dependencies

- libcurl (for HTTP communication)
- cJSON (for JSON parsing)
- C compiler with C11 support

### Installing Dependencies

#### macOS
```bash
brew install curl cjson
```

#### Ubuntu/Debian
```bash
sudo apt-get install libcurl4-openssl-dev libcjson-dev
```

#### RHEL/CentOS
```bash
sudo yum install libcurl-devel cjson-devel
```

## Building

### Using Make
```bash
make
make examples
```

### Using CMake
```bash
mkdir build
cd build
cmake ..
make
```

### Installation
```bash
sudo make install
```

This installs:
- Library to `/usr/local/lib/libwinccunified.a`
- Headers to `/usr/local/include/winccunified/`

## Usage

### Environment Setup
Before running examples, set the required environment variables:
```bash
export WINCCUA_URL="https://your-server:4043"
export WINCCUA_USERNAME="your-username"
export WINCCUA_PASSWORD="your-password"
```

Or source the provided environment script:
```bash
source ../setenv.sh
```

### Basic Example

```c
#include <winccunified/wincc_unified.h>
#include <stdio.h>

int main() {
    // Create client
    wincc_client_t* client = wincc_client_new(
        getenv("WINCCUA_URL"),
        getenv("WINCCUA_USERNAME"),
        getenv("WINCCUA_PASSWORD")
    );
    
    // Connect
    wincc_error_t* error = wincc_connect(client);
    if (error) {
        fprintf(stderr, "Connection failed: %s\n", error->description);
        wincc_error_free(error);
        wincc_client_free(client);
        return 1;
    }
    
    // Read tags
    const char* tags[] = {"Silo1_Temperature", "Silo1_Pressure"};
    wincc_tag_results_t* results = wincc_read_tags(client, tags, 2);
    
    if (results) {
        for (size_t i = 0; i < results->count; i++) {
            wincc_tag_result_t* tag = &results->items[i];
            if (!tag->error) {
                printf("%s = %s\n", tag->name, tag->value);
            }
        }
        wincc_tag_results_free(results);
    }
    
    // Disconnect and cleanup
    wincc_disconnect(client);
    wincc_client_free(client);
    
    return 0;
}
```

## API Reference

### Client Management
```c
wincc_client_t* wincc_client_new(const char* base_url, const char* username, const char* password);
void wincc_client_free(wincc_client_t* client);
wincc_error_t* wincc_connect(wincc_client_t* client);
void wincc_disconnect(wincc_client_t* client);
```

### Tag Operations
```c
wincc_tag_results_t* wincc_read_tags(wincc_client_t* client, const char** tag_names, size_t count);
wincc_write_results_t* wincc_write_tags(wincc_client_t* client, const wincc_tag_write_t* tags, size_t count);
wincc_browse_results_t* wincc_browse(wincc_client_t* client, const char* path);
```

### Alarm Operations
```c
wincc_alarms_t* wincc_get_active_alarms(wincc_client_t* client);
wincc_error_t* wincc_acknowledge_alarm(wincc_client_t* client, const char* alarm_id);
```

### Memory Management
All result structures have corresponding free functions:
```c
void wincc_tag_results_free(wincc_tag_results_t* results);
void wincc_write_results_free(wincc_write_results_t* results);
void wincc_browse_results_free(wincc_browse_results_t* results);
void wincc_alarms_free(wincc_alarms_t* alarms);
void wincc_error_free(wincc_error_t* error);
```

## Examples

- `basic_usage.c` - Demonstrates all major operations
- `monitor_tags.c` - Continuously monitors tag values and alarms

Run examples:
```bash
./bin/basic_usage
./bin/monitor_tags
```

## Error Handling

All operations return error information within result structures:
```c
if (result->error) {
    printf("Error: %s - %s\n", 
           result->error->error_code, 
           result->error->description);
}
```

## Thread Safety

The library is designed to be thread-safe. Each `wincc_client_t` instance should be used by a single thread. For multi-threaded applications, create separate client instances for each thread.

## License

See the main project LICENSE file.