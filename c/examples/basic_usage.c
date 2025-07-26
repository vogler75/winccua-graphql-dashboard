#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include "../include/wincc_unified.h"

int main(int argc, char* argv[]) {
    const char* base_url = getenv("GRAPHQL_HTTP_URL");
    const char* username = getenv("GRAPHQL_USERNAME");
    const char* password = getenv("GRAPHQL_PASSWORD");
    
    if (!base_url || !username || !password) {
        fprintf(stderr, "Please set GRAPHQL_HTTP_URL, GRAPHQL_USERNAME, and GRAPHQL_PASSWORD environment variables\n");
        fprintf(stderr, "You can source the setenv.sh script to set these variables\n");
        return 1;
    }
    
    printf("Creating WinCC Unified client...\n");
    wincc_client_t* client = wincc_client_new(base_url, username, password);
    if (!client) {
        fprintf(stderr, "Failed to create client\n");
        return 1;
    }
    
    printf("Connecting to server...\n");
    wincc_error_t* error = wincc_connect(client);
    if (error && error->error_code && strcmp(error->error_code, "0") != 0) {
        fprintf(stderr, "Connection failed: %s - %s\n", error->error_code, error->description);
        wincc_error_free(error);
        wincc_client_free(client);
        return 1;
    }
    
    printf("Connected successfully!\n\n");
    
    printf("=== Reading Tags ===\n");
    const char* tag_names[] = {"Meter_Input_Value", "Meter_Output_Value", "HMI_Tag_1"};
    wincc_tag_results_t* tag_results = wincc_read_tags(client, tag_names, 3);
    
    if (tag_results) {
        for (size_t i = 0; i < tag_results->count; i++) {
            wincc_tag_result_t* tag = &tag_results->items[i];
            if (tag->error) {
                printf("Tag: %s - Error: %s\n", tag->name, tag->error->description);
            } else {
                printf("Tag: %s = %s (Quality: %s)\n", tag->name, tag->value, tag->quality);
            }
        }
        wincc_tag_results_free(tag_results);
    }
    
    printf("\n=== Writing Tags ===\n");
    wincc_tag_write_t tags_to_write[] = {
        {"HMI_Tag_1", "25.5"},
        {"HMI_Tag_2", "1.2"}
    };
    
    wincc_write_results_t* write_results = wincc_write_tags(client, tags_to_write, 2);
    if (write_results) {
        for (size_t i = 0; i < write_results->count; i++) {
            wincc_write_result_t* result = &write_results->items[i];
            if (result->error) {
                printf("Write failed for %s: %s\n", result->name, result->error->description);
            } else {
                printf("Successfully wrote to %s\n", result->name);
            }
        }
        wincc_write_results_free(write_results);
    }
    
    printf("\n=== Browsing Tags ===\n");
    wincc_browse_results_t* browse_results = wincc_browse(client, NULL);
    if (browse_results) {
        if (browse_results->error) {
            printf("Browse error: %s\n", browse_results->error->description);
        } else {
            printf("Found %zu items:\n", browse_results->count);
            for (size_t i = 0; i < browse_results->count && i < 5; i++) {
                wincc_browse_item_t* item = &browse_results->items[i];
                printf("  - %s (Type: %s, Children: %zu)\n", 
                       item->name, item->type, item->children_count);
            }
            if (browse_results->count > 5) {
                printf("  ... and %zu more items\n", browse_results->count - 5);
            }
        }
        wincc_browse_results_free(browse_results);
    }
    
    printf("\n=== Active Alarms ===\n");
    wincc_alarms_t* alarms = wincc_get_active_alarms(client);
    if (alarms) {
        if (alarms->count == 0) {
            printf("No active alarms\n");
        } else {
            printf("Found %zu active alarms:\n", alarms->count);
            for (size_t i = 0; i < alarms->count && i < 3; i++) {
                wincc_alarm_t* alarm = &alarms->items[i];
                if (alarm->error) {
                    printf("  - Error getting alarm: %s\n", alarm->error->description);
                } else {
                    printf("  - %s: %s (State: %s)\n", 
                           alarm->name, alarm->text, alarm->state);
                }
            }
            if (alarms->count > 3) {
                printf("  ... and %zu more alarms\n", alarms->count - 3);
            }
        }
        wincc_alarms_free(alarms);
    }
    
    printf("\nDisconnecting...\n");
    wincc_disconnect(client);
    wincc_client_free(client);
    
    printf("Done!\n");
    return 0;
}