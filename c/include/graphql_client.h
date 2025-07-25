#ifndef GRAPHQL_CLIENT_H
#define GRAPHQL_CLIENT_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct graphql_client graphql_client_t;

typedef struct {
    char* json_string;
    size_t length;
} graphql_response_t;

typedef struct {
    char* message;
    int code;
} graphql_error_t;

graphql_client_t* graphql_client_new(const char* url);
void graphql_client_free(graphql_client_t* client);

void graphql_client_set_header(graphql_client_t* client, const char* name, const char* value);

graphql_response_t* graphql_execute(graphql_client_t* client, const char* query, const char* variables);
void graphql_response_free(graphql_response_t* response);

graphql_error_t* graphql_client_get_last_error(graphql_client_t* client);

#ifdef __cplusplus
}
#endif

#endif