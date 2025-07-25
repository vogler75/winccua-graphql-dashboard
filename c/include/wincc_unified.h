#ifndef WINCC_UNIFIED_H
#define WINCC_UNIFIED_H

#include <stddef.h>
#include <stdbool.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct wincc_client wincc_client_t;

typedef struct {
    char* error_code;
    char* description;
} wincc_error_t;

typedef struct {
    char* name;
    char* value;
    char* quality;
    char* timestamp;
    wincc_error_t* error;
} wincc_tag_result_t;

typedef struct {
    wincc_tag_result_t* items;
    size_t count;
} wincc_tag_results_t;

typedef struct {
    char* name;
    char* value;
} wincc_tag_write_t;

typedef struct {
    char* name;
    wincc_error_t* error;
} wincc_write_result_t;

typedef struct {
    wincc_write_result_t* items;
    size_t count;
} wincc_write_results_t;

typedef struct {
    char* id;
    char* state;
    char* name;
    char* text;
    char* class_name;
    time_t come_time;
    time_t go_time;
    time_t ack_time;
    wincc_error_t* error;
} wincc_alarm_t;

typedef struct {
    wincc_alarm_t* items;
    size_t count;
} wincc_alarms_t;

typedef struct {
    char* name;
    char* type;
    char* address;
    size_t children_count;
} wincc_browse_item_t;

typedef struct {
    wincc_browse_item_t* items;
    size_t count;
    wincc_error_t* error;
} wincc_browse_results_t;

wincc_client_t* wincc_client_new(const char* base_url, const char* username, const char* password);
void wincc_client_free(wincc_client_t* client);

wincc_error_t* wincc_connect(wincc_client_t* client);
void wincc_disconnect(wincc_client_t* client);

wincc_tag_results_t* wincc_read_tags(wincc_client_t* client, const char** tag_names, size_t count);
wincc_write_results_t* wincc_write_tags(wincc_client_t* client, const wincc_tag_write_t* tags, size_t count);

wincc_browse_results_t* wincc_browse(wincc_client_t* client, const char* path);

wincc_alarms_t* wincc_get_active_alarms(wincc_client_t* client);
wincc_error_t* wincc_acknowledge_alarm(wincc_client_t* client, const char* alarm_id);

void wincc_tag_results_free(wincc_tag_results_t* results);
void wincc_write_results_free(wincc_write_results_t* results);
void wincc_browse_results_free(wincc_browse_results_t* results);
void wincc_alarms_free(wincc_alarms_t* alarms);
void wincc_error_free(wincc_error_t* error);

#ifdef __cplusplus
}
#endif

#endif