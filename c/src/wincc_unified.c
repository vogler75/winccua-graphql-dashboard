#include "wincc_unified.h"
#include "graphql_client.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <cjson/cJSON.h>

struct wincc_client {
    graphql_client_t* graphql_client;
    char* base_url;
    char* username;
    char* password;
    char* token;
    char* session_id;
};

static char* escape_json_string(const char* str) {
    if (!str) return strdup("");
    
    size_t len = strlen(str);
    char* escaped = malloc(len * 2 + 1);
    size_t j = 0;
    
    for (size_t i = 0; i < len; i++) {
        switch (str[i]) {
            case '"': escaped[j++] = '\\'; escaped[j++] = '"'; break;
            case '\\': escaped[j++] = '\\'; escaped[j++] = '\\'; break;
            case '\n': escaped[j++] = '\\'; escaped[j++] = 'n'; break;
            case '\r': escaped[j++] = '\\'; escaped[j++] = 'r'; break;
            case '\t': escaped[j++] = '\\'; escaped[j++] = 't'; break;
            default: escaped[j++] = str[i]; break;
        }
    }
    escaped[j] = '\0';
    
    return escaped;
}

wincc_client_t* wincc_client_new(const char* base_url, const char* username, const char* password) {
    wincc_client_t* client = calloc(1, sizeof(wincc_client_t));
    if (!client) return NULL;
    
    client->base_url = strdup(base_url);
    client->username = strdup(username);
    client->password = strdup(password);
    
    char graphql_url[1024];
    snprintf(graphql_url, sizeof(graphql_url), "%s/graphql", base_url);
    
    client->graphql_client = graphql_client_new(graphql_url);
    if (!client->graphql_client) {
        wincc_client_free(client);
        return NULL;
    }
    
    return client;
}

void wincc_client_free(wincc_client_t* client) {
    if (!client) return;
    
    wincc_disconnect(client);
    
    if (client->graphql_client) {
        graphql_client_free(client->graphql_client);
    }
    
    free(client->base_url);
    free(client->username);
    free(client->password);
    free(client->token);
    free(client->session_id);
    free(client);
}

wincc_error_t* wincc_connect(wincc_client_t* client) {
    if (!client) return NULL;
    
    const char* login_query = "mutation Login($username: String!, $password: String!) { "
                             "Login(user: $username, password: $password) { "
                             "token sessionId error { code description } } }";
    
    char variables[512];
    char* escaped_user = escape_json_string(client->username);
    char* escaped_pass = escape_json_string(client->password);
    
    snprintf(variables, sizeof(variables), 
             "{\"username\":\"%s\",\"password\":\"%s\"}", 
             escaped_user, escaped_pass);
    
    free(escaped_user);
    free(escaped_pass);
    
    graphql_response_t* response = graphql_execute(client->graphql_client, login_query, variables);
    if (!response) {
        wincc_error_t* error = malloc(sizeof(wincc_error_t));
        error->error_code = strdup("CONNECTION_ERROR");
        error->description = strdup("Failed to connect to server");
        return error;
    }
    
    cJSON* json = cJSON_Parse(response->json_string);
    graphql_response_free(response);
    
    if (!json) {
        wincc_error_t* error = malloc(sizeof(wincc_error_t));
        error->error_code = strdup("PARSE_ERROR");
        error->description = strdup("Invalid JSON response");
        return error;
    }
    
    cJSON* data = cJSON_GetObjectItem(json, "data");
    cJSON* login = cJSON_GetObjectItem(data, "Login");
    cJSON* error_obj = cJSON_GetObjectItem(login, "error");
    
    if (error_obj) {
        wincc_error_t* error = malloc(sizeof(wincc_error_t));
        cJSON* code = cJSON_GetObjectItem(error_obj, "code");
        cJSON* desc = cJSON_GetObjectItem(error_obj, "description");
        
        error->error_code = strdup(code ? code->valuestring : "UNKNOWN_ERROR");
        error->description = strdup(desc ? desc->valuestring : "Unknown error");
        
        cJSON_Delete(json);
        return error;
    }
    
    cJSON* token = cJSON_GetObjectItem(login, "token");
    cJSON* session_id = cJSON_GetObjectItem(login, "sessionId");
    
    if (token && session_id) {
        client->token = strdup(token->valuestring);
        client->session_id = strdup(session_id->valuestring);
        
        char auth_header[1024];
        snprintf(auth_header, sizeof(auth_header), "Bearer %s", client->token);
        graphql_client_set_header(client->graphql_client, "Authorization", auth_header);
    }
    
    cJSON_Delete(json);
    return NULL;
}

void wincc_disconnect(wincc_client_t* client) {
    if (!client || !client->session_id) return;
    
    const char* logout_query = "mutation Logout($sessionId: ID!) { "
                              "Logout(sessionId: $sessionId) { "
                              "error { code description } } }";
    
    char variables[256];
    snprintf(variables, sizeof(variables), "{\"sessionId\":\"%s\"}", client->session_id);
    
    graphql_response_t* response = graphql_execute(client->graphql_client, logout_query, variables);
    if (response) {
        graphql_response_free(response);
    }
    
    free(client->token);
    free(client->session_id);
    client->token = NULL;
    client->session_id = NULL;
}

wincc_tag_results_t* wincc_read_tags(wincc_client_t* client, const char** tag_names, size_t count) {
    if (!client || !tag_names || count == 0) return NULL;
    
    char* tags_array = malloc(count * 256);
    strcpy(tags_array, "[");
    
    for (size_t i = 0; i < count; i++) {
        char* escaped = escape_json_string(tag_names[i]);
        strcat(tags_array, "\\\"");
        strcat(tags_array, escaped);
        strcat(tags_array, "\\\"");
        if (i < count - 1) strcat(tags_array, ",");
        free(escaped);
    }
    strcat(tags_array, "]");
    
    const char* query = "query ReadTags($tags: [String!]!) { "
                       "ReadTags(tags: $tags) { "
                       "name value quality timestamp error { code description } } }";
    
    char* variables = malloc(strlen(tags_array) + 32);
    sprintf(variables, "{\"tags\":%s}", tags_array);
    
    graphql_response_t* response = graphql_execute(client->graphql_client, query, variables);
    
    free(tags_array);
    free(variables);
    
    if (!response) return NULL;
    
    cJSON* json = cJSON_Parse(response->json_string);
    graphql_response_free(response);
    
    if (!json) return NULL;
    
    wincc_tag_results_t* results = calloc(1, sizeof(wincc_tag_results_t));
    
    cJSON* data = cJSON_GetObjectItem(json, "data");
    cJSON* read_tags = cJSON_GetObjectItem(data, "ReadTags");
    
    if (read_tags) {
        results->count = cJSON_GetArraySize(read_tags);
        results->items = calloc(results->count, sizeof(wincc_tag_result_t));
        
        for (size_t i = 0; i < results->count; i++) {
            cJSON* item = cJSON_GetArrayItem(read_tags, i);
            wincc_tag_result_t* result = &results->items[i];
            
            cJSON* name = cJSON_GetObjectItem(item, "name");
            cJSON* value = cJSON_GetObjectItem(item, "value");
            cJSON* quality = cJSON_GetObjectItem(item, "quality");
            cJSON* timestamp = cJSON_GetObjectItem(item, "timestamp");
            cJSON* error = cJSON_GetObjectItem(item, "error");
            
            if (name) result->name = strdup(name->valuestring);
            if (value) result->value = strdup(value->valuestring);
            if (quality) result->quality = strdup(quality->valuestring);
            if (timestamp) result->timestamp = strdup(timestamp->valuestring);
            
            if (error) {
                result->error = malloc(sizeof(wincc_error_t));
                cJSON* code = cJSON_GetObjectItem(error, "code");
                cJSON* desc = cJSON_GetObjectItem(error, "description");
                
                result->error->error_code = strdup(code ? code->valuestring : "");
                result->error->description = strdup(desc ? desc->valuestring : "");
            }
        }
    }
    
    cJSON_Delete(json);
    return results;
}

wincc_write_results_t* wincc_write_tags(wincc_client_t* client, const wincc_tag_write_t* tags, size_t count) {
    if (!client || !tags || count == 0) return NULL;
    
    char* tags_array = malloc(count * 512);
    strcpy(tags_array, "[");
    
    for (size_t i = 0; i < count; i++) {
        char* escaped_name = escape_json_string(tags[i].name);
        char* escaped_value = escape_json_string(tags[i].value);
        
        char tag_obj[512];
        snprintf(tag_obj, sizeof(tag_obj), "{\\\"name\\\":\\\"%s\\\",\\\"value\\\":\\\"%s\\\"}",
                 escaped_name, escaped_value);
        
        strcat(tags_array, tag_obj);
        if (i < count - 1) strcat(tags_array, ",");
        
        free(escaped_name);
        free(escaped_value);
    }
    strcat(tags_array, "]");
    
    const char* query = "mutation WriteTags($tags: [TagInput!]!) { "
                       "WriteTags(tags: $tags) { "
                       "name error { code description } } }";
    
    char* variables = malloc(strlen(tags_array) + 32);
    sprintf(variables, "{\"tags\":%s}", tags_array);
    
    graphql_response_t* response = graphql_execute(client->graphql_client, query, variables);
    
    free(tags_array);
    free(variables);
    
    if (!response) return NULL;
    
    cJSON* json = cJSON_Parse(response->json_string);
    graphql_response_free(response);
    
    if (!json) return NULL;
    
    wincc_write_results_t* results = calloc(1, sizeof(wincc_write_results_t));
    
    cJSON* data = cJSON_GetObjectItem(json, "data");
    cJSON* write_tags = cJSON_GetObjectItem(data, "WriteTags");
    
    if (write_tags) {
        results->count = cJSON_GetArraySize(write_tags);
        results->items = calloc(results->count, sizeof(wincc_write_result_t));
        
        for (size_t i = 0; i < results->count; i++) {
            cJSON* item = cJSON_GetArrayItem(write_tags, i);
            wincc_write_result_t* result = &results->items[i];
            
            cJSON* name = cJSON_GetObjectItem(item, "name");
            cJSON* error = cJSON_GetObjectItem(item, "error");
            
            if (name) result->name = strdup(name->valuestring);
            
            if (error) {
                result->error = malloc(sizeof(wincc_error_t));
                cJSON* code = cJSON_GetObjectItem(error, "code");
                cJSON* desc = cJSON_GetObjectItem(error, "description");
                
                result->error->error_code = strdup(code ? code->valuestring : "");
                result->error->description = strdup(desc ? desc->valuestring : "");
            }
        }
    }
    
    cJSON_Delete(json);
    return results;
}

wincc_browse_results_t* wincc_browse(wincc_client_t* client, const char* path) {
    if (!client) return NULL;
    
    const char* query = "query Browse($path: String) { "
                       "Browse(path: $path) { "
                       "items { name type address childrenCount } "
                       "error { code description } } }";
    
    char variables[512] = "";
    if (path) {
        char* escaped_path = escape_json_string(path);
        snprintf(variables, sizeof(variables), "{\"path\":\"%s\"}", escaped_path);
        free(escaped_path);
    }
    
    graphql_response_t* response = graphql_execute(client->graphql_client, query, 
                                                   strlen(variables) > 0 ? variables : NULL);
    
    if (!response) return NULL;
    
    cJSON* json = cJSON_Parse(response->json_string);
    graphql_response_free(response);
    
    if (!json) return NULL;
    
    wincc_browse_results_t* results = calloc(1, sizeof(wincc_browse_results_t));
    
    cJSON* data = cJSON_GetObjectItem(json, "data");
    cJSON* browse = cJSON_GetObjectItem(data, "Browse");
    
    if (browse) {
        cJSON* error = cJSON_GetObjectItem(browse, "error");
        if (error) {
            results->error = malloc(sizeof(wincc_error_t));
            cJSON* code = cJSON_GetObjectItem(error, "code");
            cJSON* desc = cJSON_GetObjectItem(error, "description");
            
            results->error->error_code = strdup(code ? code->valuestring : "");
            results->error->description = strdup(desc ? desc->valuestring : "");
        }
        
        cJSON* items = cJSON_GetObjectItem(browse, "items");
        if (items) {
            results->count = cJSON_GetArraySize(items);
            results->items = calloc(results->count, sizeof(wincc_browse_item_t));
            
            for (size_t i = 0; i < results->count; i++) {
                cJSON* item = cJSON_GetArrayItem(items, i);
                wincc_browse_item_t* browse_item = &results->items[i];
                
                cJSON* name = cJSON_GetObjectItem(item, "name");
                cJSON* type = cJSON_GetObjectItem(item, "type");
                cJSON* address = cJSON_GetObjectItem(item, "address");
                cJSON* children = cJSON_GetObjectItem(item, "childrenCount");
                
                if (name) browse_item->name = strdup(name->valuestring);
                if (type) browse_item->type = strdup(type->valuestring);
                if (address) browse_item->address = strdup(address->valuestring);
                if (children) browse_item->children_count = children->valueint;
            }
        }
    }
    
    cJSON_Delete(json);
    return results;
}

wincc_alarms_t* wincc_get_active_alarms(wincc_client_t* client) {
    if (!client) return NULL;
    
    const char* query = "query GetActiveAlarms { "
                       "GetActiveAlarms { "
                       "id state name text className comeTime goTime ackTime "
                       "error { code description } } }";
    
    graphql_response_t* response = graphql_execute(client->graphql_client, query, NULL);
    
    if (!response) return NULL;
    
    cJSON* json = cJSON_Parse(response->json_string);
    graphql_response_free(response);
    
    if (!json) return NULL;
    
    wincc_alarms_t* results = calloc(1, sizeof(wincc_alarms_t));
    
    cJSON* data = cJSON_GetObjectItem(json, "data");
    cJSON* alarms = cJSON_GetObjectItem(data, "GetActiveAlarms");
    
    if (alarms) {
        results->count = cJSON_GetArraySize(alarms);
        results->items = calloc(results->count, sizeof(wincc_alarm_t));
        
        for (size_t i = 0; i < results->count; i++) {
            cJSON* item = cJSON_GetArrayItem(alarms, i);
            wincc_alarm_t* alarm = &results->items[i];
            
            cJSON* id = cJSON_GetObjectItem(item, "id");
            cJSON* state = cJSON_GetObjectItem(item, "state");
            cJSON* name = cJSON_GetObjectItem(item, "name");
            cJSON* text = cJSON_GetObjectItem(item, "text");
            cJSON* class_name = cJSON_GetObjectItem(item, "className");
            cJSON* come_time = cJSON_GetObjectItem(item, "comeTime");
            cJSON* go_time = cJSON_GetObjectItem(item, "goTime");
            cJSON* ack_time = cJSON_GetObjectItem(item, "ackTime");
            cJSON* error = cJSON_GetObjectItem(item, "error");
            
            if (id) alarm->id = strdup(id->valuestring);
            if (state) alarm->state = strdup(state->valuestring);
            if (name) alarm->name = strdup(name->valuestring);
            if (text) alarm->text = strdup(text->valuestring);
            if (class_name) alarm->class_name = strdup(class_name->valuestring);
            
            if (error) {
                alarm->error = malloc(sizeof(wincc_error_t));
                cJSON* code = cJSON_GetObjectItem(error, "code");
                cJSON* desc = cJSON_GetObjectItem(error, "description");
                
                alarm->error->error_code = strdup(code ? code->valuestring : "");
                alarm->error->description = strdup(desc ? desc->valuestring : "");
            }
        }
    }
    
    cJSON_Delete(json);
    return results;
}

wincc_error_t* wincc_acknowledge_alarm(wincc_client_t* client, const char* alarm_id) {
    if (!client || !alarm_id) return NULL;
    
    const char* query = "mutation AcknowledgeAlarm($alarmId: ID!) { "
                       "AcknowledgeAlarm(alarmId: $alarmId) { "
                       "error { code description } } }";
    
    char variables[256];
    snprintf(variables, sizeof(variables), "{\"alarmId\":\"%s\"}", alarm_id);
    
    graphql_response_t* response = graphql_execute(client->graphql_client, query, variables);
    
    if (!response) {
        wincc_error_t* error = malloc(sizeof(wincc_error_t));
        error->error_code = strdup("CONNECTION_ERROR");
        error->description = strdup("Failed to execute request");
        return error;
    }
    
    cJSON* json = cJSON_Parse(response->json_string);
    graphql_response_free(response);
    
    if (!json) {
        wincc_error_t* error = malloc(sizeof(wincc_error_t));
        error->error_code = strdup("PARSE_ERROR");
        error->description = strdup("Invalid JSON response");
        return error;
    }
    
    cJSON* data = cJSON_GetObjectItem(json, "data");
    cJSON* ack = cJSON_GetObjectItem(data, "AcknowledgeAlarm");
    cJSON* error_obj = cJSON_GetObjectItem(ack, "error");
    
    wincc_error_t* error = NULL;
    if (error_obj) {
        error = malloc(sizeof(wincc_error_t));
        cJSON* code = cJSON_GetObjectItem(error_obj, "code");
        cJSON* desc = cJSON_GetObjectItem(error_obj, "description");
        
        error->error_code = strdup(code ? code->valuestring : "UNKNOWN_ERROR");
        error->description = strdup(desc ? desc->valuestring : "Unknown error");
    }
    
    cJSON_Delete(json);
    return error;
}

void wincc_tag_results_free(wincc_tag_results_t* results) {
    if (!results) return;
    
    for (size_t i = 0; i < results->count; i++) {
        wincc_tag_result_t* result = &results->items[i];
        free(result->name);
        free(result->value);
        free(result->quality);
        free(result->timestamp);
        if (result->error) {
            wincc_error_free(result->error);
        }
    }
    
    free(results->items);
    free(results);
}

void wincc_write_results_free(wincc_write_results_t* results) {
    if (!results) return;
    
    for (size_t i = 0; i < results->count; i++) {
        wincc_write_result_t* result = &results->items[i];
        free(result->name);
        if (result->error) {
            wincc_error_free(result->error);
        }
    }
    
    free(results->items);
    free(results);
}

void wincc_browse_results_free(wincc_browse_results_t* results) {
    if (!results) return;
    
    for (size_t i = 0; i < results->count; i++) {
        wincc_browse_item_t* item = &results->items[i];
        free(item->name);
        free(item->type);
        free(item->address);
    }
    
    free(results->items);
    if (results->error) {
        wincc_error_free(results->error);
    }
    free(results);
}

void wincc_alarms_free(wincc_alarms_t* alarms) {
    if (!alarms) return;
    
    for (size_t i = 0; i < alarms->count; i++) {
        wincc_alarm_t* alarm = &alarms->items[i];
        free(alarm->id);
        free(alarm->state);
        free(alarm->name);
        free(alarm->text);
        free(alarm->class_name);
        if (alarm->error) {
            wincc_error_free(alarm->error);
        }
    }
    
    free(alarms->items);
    free(alarms);
}

void wincc_error_free(wincc_error_t* error) {
    if (!error) return;
    free(error->error_code);
    free(error->description);
    free(error);
}