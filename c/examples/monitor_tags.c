#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include "../include/wincc_unified.h"

static volatile int keep_running = 1;

void signal_handler(int signum) {
    keep_running = 0;
}

int main(int argc, char* argv[]) {
    signal(SIGINT, signal_handler);
    
    const char* base_url = getenv("WINCCUA_URL");
    const char* username = getenv("WINCCUA_USERNAME");
    const char* password = getenv("WINCCUA_PASSWORD");
    
    if (!base_url || !username || !password) {
        fprintf(stderr, "Please set WINCCUA_URL, WINCCUA_USERNAME, and WINCCUA_PASSWORD environment variables\n");
        return 1;
    }
    
    wincc_client_t* client = wincc_client_new(base_url, username, password);
    if (!client) {
        fprintf(stderr, "Failed to create client\n");
        return 1;
    }
    
    wincc_error_t* error = wincc_connect(client);
    if (error) {
        fprintf(stderr, "Connection failed: %s\n", error->description);
        wincc_error_free(error);
        wincc_client_free(client);
        return 1;
    }
    
    printf("Connected! Monitoring tags (press Ctrl+C to stop)...\n\n");
    
    const char* tags[] = {
        "Silo1_Temperature",
        "Silo1_Pressure",
        "Silo1_Level",
        "Silo2_Temperature",
        "Silo2_Pressure",
        "Silo2_Level"
    };
    const size_t tag_count = sizeof(tags) / sizeof(tags[0]);
    
    while (keep_running) {
        printf("\033[H\033[J");
        printf("=== Tag Monitor ===\n");
        printf("Time: %ld\n\n", time(NULL));
        
        wincc_tag_results_t* results = wincc_read_tags(client, tags, tag_count);
        if (results) {
            for (size_t i = 0; i < results->count; i++) {
                wincc_tag_result_t* tag = &results->items[i];
                if (tag->error) {
                    printf("%-20s: ERROR - %s\n", tag->name, tag->error->description);
                } else {
                    printf("%-20s: %-10s (Quality: %s)\n", 
                           tag->name, tag->value, tag->quality);
                }
            }
            wincc_tag_results_free(results);
        }
        
        printf("\n=== Active Alarms ===\n");
        wincc_alarms_t* alarms = wincc_get_active_alarms(client);
        if (alarms) {
            if (alarms->count == 0) {
                printf("No active alarms\n");
            } else {
                for (size_t i = 0; i < alarms->count && i < 5; i++) {
                    wincc_alarm_t* alarm = &alarms->items[i];
                    if (!alarm->error) {
                        printf("[%s] %s: %s\n", alarm->state, alarm->name, alarm->text);
                    }
                }
                if (alarms->count > 5) {
                    printf("... and %zu more alarms\n", alarms->count - 5);
                }
            }
            wincc_alarms_free(alarms);
        }
        
        sleep(1);
    }
    
    printf("\n\nShutting down...\n");
    wincc_disconnect(client);
    wincc_client_free(client);
    
    return 0;
}