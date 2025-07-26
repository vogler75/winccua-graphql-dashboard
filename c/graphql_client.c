#include "graphql_client.h"
#include <curl/curl.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

struct graphql_client {
    CURL* curl;
    struct curl_slist* headers;
    char* url;
    graphql_error_t last_error;
};

typedef struct {
    char* data;
    size_t size;
    size_t capacity;
} buffer_t;

static size_t write_callback(void* contents, size_t size, size_t nmemb, void* userp) {
    size_t real_size = size * nmemb;
    buffer_t* buf = (buffer_t*)userp;
    
    size_t new_size = buf->size + real_size;
    if (new_size >= buf->capacity) {
        buf->capacity = new_size * 2;
        buf->data = realloc(buf->data, buf->capacity);
        if (!buf->data) {
            return 0;
        }
    }
    
    memcpy(&(buf->data[buf->size]), contents, real_size);
    buf->size += real_size;
    buf->data[buf->size] = '\0';
    
    return real_size;
}

graphql_client_t* graphql_client_new(const char* url) {
    graphql_client_t* client = calloc(1, sizeof(graphql_client_t));
    if (!client) return NULL;
    
    client->url = strdup(url);
    client->curl = curl_easy_init();
    
    if (!client->curl) {
        free(client->url);
        free(client);
        return NULL;
    }
    
    client->headers = curl_slist_append(NULL, "Content-Type: application/json");
    
    return client;
}

void graphql_client_free(graphql_client_t* client) {
    if (!client) return;
    
    if (client->curl) {
        curl_easy_cleanup(client->curl);
    }
    
    if (client->headers) {
        curl_slist_free_all(client->headers);
    }
    
    free(client->url);
    free(client->last_error.message);
    free(client);
}

void graphql_client_set_header(graphql_client_t* client, const char* name, const char* value) {
    if (!client || !name || !value) return;
    
    char header[1024];
    snprintf(header, sizeof(header), "%s: %s", name, value);
    printf("[DEBUG] graphql_client_set_header: Adding header: %s\n", header);
    client->headers = curl_slist_append(client->headers, header);
}

graphql_response_t* graphql_execute(graphql_client_t* client, const char* query, const char* variables) {
    if (!client || !query) return NULL;
    
    printf("[DEBUG] graphql_execute: URL: %s\n", client->url);
    
    buffer_t response_buffer = {0};
    response_buffer.data = malloc(1024);
    response_buffer.capacity = 1024;
    response_buffer.size = 0;
    
    char* json_body = NULL;
    if (variables && strlen(variables) > 0) {
        size_t len = strlen(query) + strlen(variables) + 64;
        json_body = malloc(len);
        snprintf(json_body, len, "{\"query\":\"%s\",\"variables\":%s}", query, variables);
    } else {
        size_t len = strlen(query) + 32;
        json_body = malloc(len);
        snprintf(json_body, len, "{\"query\":\"%s\"}", query);
    }
    
    printf("[DEBUG] graphql_execute: Request body: %s\n", json_body);
    
    curl_easy_setopt(client->curl, CURLOPT_URL, client->url);
    curl_easy_setopt(client->curl, CURLOPT_HTTPHEADER, client->headers);
    curl_easy_setopt(client->curl, CURLOPT_POSTFIELDS, json_body);
    curl_easy_setopt(client->curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(client->curl, CURLOPT_WRITEDATA, &response_buffer);
    
    printf("[DEBUG] graphql_execute: Performing CURL request...\n");
    CURLcode res = curl_easy_perform(client->curl);
    
    free(json_body);
    
    if (res != CURLE_OK) {
        printf("[DEBUG] graphql_execute: CURL error: %s (code: %d)\n", curl_easy_strerror(res), res);
        free(client->last_error.message);
        client->last_error.message = strdup(curl_easy_strerror(res));
        client->last_error.code = res;
        free(response_buffer.data);
        return NULL;
    }
    
    printf("[DEBUG] graphql_execute: Response received, size: %zu\n", response_buffer.size);
    printf("[DEBUG] graphql_execute: Response content: %s\n", response_buffer.data);
    
    graphql_response_t* response = malloc(sizeof(graphql_response_t));
    response->json_string = response_buffer.data;
    response->length = response_buffer.size;
    
    return response;
}

void graphql_response_free(graphql_response_t* response) {
    if (!response) return;
    free(response->json_string);
    free(response);
}

graphql_error_t* graphql_client_get_last_error(graphql_client_t* client) {
    if (!client || !client->last_error.message) return NULL;
    return &client->last_error;
}