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
    
    client->graphql_client = graphql_client_new(base_url);
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
    
    printf("[DEBUG] wincc_connect: Starting connection to %s\n", client->base_url);
    printf("[DEBUG] wincc_connect: Username: %s\n", client->username);
    
    const char* login_query = "mutation Login($username: String!, $password: String!) { "
                             "login(username: $username, password: $password) { "
                             "token expires user { name } error { code description } } }";
    
    char variables[512];
    char* escaped_user = escape_json_string(client->username);
    char* escaped_pass = escape_json_string(client->password);
    
    snprintf(variables, sizeof(variables), 
             "{\"username\":\"%s\",\"password\":\"%s\"}", 
             escaped_user, escaped_pass);
    
    printf("[DEBUG] wincc_connect: Query: %s\n", login_query);
    printf("[DEBUG] wincc_connect: Variables: %s\n", variables);
    
    free(escaped_user);
    free(escaped_pass);
    
    printf("[DEBUG] wincc_connect: Executing GraphQL query...\n");
    graphql_response_t* response = graphql_execute(client->graphql_client, login_query, variables);
    if (!response) {
        printf("[DEBUG] wincc_connect: No response received from server\n");
        wincc_error_t* error = malloc(sizeof(wincc_error_t));
        error->error_code = strdup("CONNECTION_ERROR");
        error->description = strdup("Failed to connect to server");
        return error;
    }
    
    printf("[DEBUG] wincc_connect: Response received, length: %zu\n", strlen(response->json_string));
    printf("[DEBUG] wincc_connect: Response: %s\n", response->json_string);
    
    cJSON* json = cJSON_Parse(response->json_string);
    graphql_response_free(response);
    
    if (!json) {
        printf("[DEBUG] wincc_connect: Failed to parse JSON response\n");
        wincc_error_t* error = malloc(sizeof(wincc_error_t));
        error->error_code = strdup("PARSE_ERROR");
        error->description = strdup("Invalid JSON response");
        return error;
    }
    
    printf("[DEBUG] wincc_connect: JSON parsed successfully\n");
    
    cJSON* data = cJSON_GetObjectItem(json, "data");
    if (!data) {
        printf("[DEBUG] wincc_connect: No 'data' field in response\n");
    }
    
    cJSON* login = cJSON_GetObjectItem(data, "login");
    if (!login) {
        printf("[DEBUG] wincc_connect: No 'login' field in data\n");
    }
    
    cJSON* error_obj = cJSON_GetObjectItem(login, "error");
    
    if (error_obj) {
        printf("[DEBUG] wincc_connect: Login error detected\n");
        wincc_error_t* error = malloc(sizeof(wincc_error_t));
        cJSON* code = cJSON_GetObjectItem(error_obj, "code");
        cJSON* desc = cJSON_GetObjectItem(error_obj, "description");
        
        error->error_code = strdup(code ? code->valuestring : "UNKNOWN_ERROR");
        error->description = strdup(desc ? desc->valuestring : "Unknown error");
        
        printf("[DEBUG] wincc_connect: Error code: %s, description: %s\n", error->error_code, error->description);
        
        cJSON_Delete(json);
        return error;
    }
    
    cJSON* token = cJSON_GetObjectItem(login, "token");
    
    if (token) {
        printf("[DEBUG] wincc_connect: Token received: %s\n", token->valuestring);
        client->token = strdup(token->valuestring);
        // Session ID is not returned in the new API, use token as session identifier
        client->session_id = strdup(client->token);
        
        char auth_header[1024];
        snprintf(auth_header, sizeof(auth_header), "Bearer %s", client->token);
        printf("[DEBUG] wincc_connect: Setting authorization header\n");
        graphql_client_set_header(client->graphql_client, "Authorization", auth_header);
    } else {
        printf("[DEBUG] wincc_connect: No token in login response\n");
    }
    
    cJSON_Delete(json);
    printf("[DEBUG] wincc_connect: Connection successful\n");
    return NULL;
}

void wincc_disconnect(wincc_client_t* client) {
    if (!client || !client->token) return;
    
    const char* logout_query = "mutation { logout(allSessions: false) }";
    
    graphql_response_t* response = graphql_execute(client->graphql_client, logout_query, NULL);
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
    
    printf("[DEBUG] wincc_read_tags: Reading %zu tags\n", count);
    
    char* tags_array = malloc(count * 256);
    strcpy(tags_array, "[");
    
    for (size_t i = 0; i < count; i++) {
        printf("[DEBUG] wincc_read_tags: Tag[%zu]: %s\n", i, tag_names[i]);
        char* escaped = escape_json_string(tag_names[i]);
        strcat(tags_array, "\\\"");
        strcat(tags_array, escaped);
        strcat(tags_array, "\\\"");
        if (i < count - 1) strcat(tags_array, ",");
        free(escaped);
    }
    strcat(tags_array, "]");
    
    const char* query = "query TagValues($names: [String!]!) { "
                       "tagValues(names: $names) { "
                       "name value { value timestamp quality { quality subStatus } } error { code description } } }";
    
    char* variables = malloc(strlen(tags_array) + 32);
    sprintf(variables, "{\"names\":%s}", tags_array);
    
    printf("[DEBUG] wincc_read_tags: Query: %s\n", query);
    printf("[DEBUG] wincc_read_tags: Variables: %s\n", variables);
    
    graphql_response_t* response = graphql_execute(client->graphql_client, query, variables);
    
    free(tags_array);
    free(variables);
    
    if (!response) {
        printf("[DEBUG] wincc_read_tags: No response received\n");
        return NULL;
    }
    
    printf("[DEBUG] wincc_read_tags: Response: %s\n", response->json_string);
    
    cJSON* json = cJSON_Parse(response->json_string);
    graphql_response_free(response);
    
    if (!json) {
        printf("[DEBUG] wincc_read_tags: Failed to parse JSON\n");
        return NULL;
    }
    
    wincc_tag_results_t* results = calloc(1, sizeof(wincc_tag_results_t));
    
    cJSON* data = cJSON_GetObjectItem(json, "data");
    if (!data) {
        printf("[DEBUG] wincc_read_tags: No 'data' field in response\n");
    }
    
    cJSON* read_tags = cJSON_GetObjectItem(data, "tagValues");
    if (!read_tags) {
        printf("[DEBUG] wincc_read_tags: No 'tagValues' field in data\n");
    }
    
    if (read_tags) {
        results->count = cJSON_GetArraySize(read_tags);
        results->items = calloc(results->count, sizeof(wincc_tag_result_t));
        
        for (size_t i = 0; i < results->count; i++) {
            cJSON* item = cJSON_GetArrayItem(read_tags, i);
            wincc_tag_result_t* result = &results->items[i];
            
            cJSON* name = cJSON_GetObjectItem(item, "name");
            cJSON* value_obj = cJSON_GetObjectItem(item, "value");
            cJSON* error = cJSON_GetObjectItem(item, "error");
            
            if (name) result->name = strdup(name->valuestring);
            
            if (value_obj) {
                cJSON* value = cJSON_GetObjectItem(value_obj, "value");
                cJSON* timestamp = cJSON_GetObjectItem(value_obj, "timestamp");
                cJSON* quality_obj = cJSON_GetObjectItem(value_obj, "quality");
                
                if (value) {
                    if (cJSON_IsString(value)) {
                        result->value = strdup(value->valuestring);
                    } else if (cJSON_IsNumber(value)) {
                        char buffer[64];
                        snprintf(buffer, sizeof(buffer), "%g", value->valuedouble);
                        result->value = strdup(buffer);
                    } else if (cJSON_IsBool(value)) {
                        result->value = strdup(cJSON_IsTrue(value) ? "true" : "false");
                    }
                }
                
                if (timestamp) result->timestamp = strdup(timestamp->valuestring);
                
                if (quality_obj) {
                    cJSON* quality = cJSON_GetObjectItem(quality_obj, "quality");
                    if (quality) result->quality = strdup(quality->valuestring);
                }
            }
            
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
    
    printf("[DEBUG] wincc_write_tags: Writing %zu tags\n", count);
    
    char* tags_array = malloc(count * 512);
    strcpy(tags_array, "[");
    
    for (size_t i = 0; i < count; i++) {
        printf("[DEBUG] wincc_write_tags: Tag[%zu]: %s = %s\n", i, tags[i].name, tags[i].value);
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
    
    const char* query = "mutation WriteTagValues($input: [TagValueInput]!) { "
                       "writeTagValues(input: $input) { "
                       "name error { code description } } }";
    
    char* variables = malloc(strlen(tags_array) + 32);
    sprintf(variables, "{\"input\":%s}", tags_array);
    
    printf("[DEBUG] wincc_write_tags: Query: %s\n", query);
    printf("[DEBUG] wincc_write_tags: Variables: %s\n", variables);
    
    graphql_response_t* response = graphql_execute(client->graphql_client, query, variables);
    
    free(tags_array);
    free(variables);
    
    if (!response) {
        printf("[DEBUG] wincc_write_tags: No response received\n");
        return NULL;
    }
    
    printf("[DEBUG] wincc_write_tags: Response: %s\n", response->json_string);
    
    cJSON* json = cJSON_Parse(response->json_string);
    graphql_response_free(response);
    
    if (!json) return NULL;
    
    wincc_write_results_t* results = calloc(1, sizeof(wincc_write_results_t));
    
    cJSON* data = cJSON_GetObjectItem(json, "data");
    cJSON* write_tags = cJSON_GetObjectItem(data, "writeTagValues");
    
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
    
    printf("[DEBUG] wincc_browse: Browsing path: %s\n", path ? path : "(root)");
    
    const char* query = "query Browse($nameFilters: [String]) { "
                       "browse(nameFilters: $nameFilters) { "
                       "name displayName objectType dataType } }";
    
    char variables[512] = "";
    if (path) {
        char* escaped_path = escape_json_string(path);
        snprintf(variables, sizeof(variables), "{\"nameFilters\":[\"%s\"]}", escaped_path);
        free(escaped_path);
    } else {
        strcpy(variables, "{\"nameFilters\":[]}");
    }
    
    printf("[DEBUG] wincc_browse: Query: %s\n", query);
    printf("[DEBUG] wincc_browse: Variables: %s\n", variables);
    
    graphql_response_t* response = graphql_execute(client->graphql_client, query, variables);
    
    if (!response) {
        printf("[DEBUG] wincc_browse: No response received\n");
        return NULL;
    }
    
    printf("[DEBUG] wincc_browse: Response: %s\n", response->json_string);
    
    cJSON* json = cJSON_Parse(response->json_string);
    graphql_response_free(response);
    
    if (!json) {
        printf("[DEBUG] wincc_browse: Failed to parse JSON\n");
        return NULL;
    }
    
    wincc_browse_results_t* results = calloc(1, sizeof(wincc_browse_results_t));
    
    cJSON* data = cJSON_GetObjectItem(json, "data");
    if (!data) {
        printf("[DEBUG] wincc_browse: No 'data' field in response\n");
    }
    
    cJSON* browse = cJSON_GetObjectItem(data, "browse");
    if (!browse) {
        printf("[DEBUG] wincc_browse: No 'browse' field in data\n");
    }
    
    if (browse) {
        results->count = cJSON_GetArraySize(browse);
        printf("[DEBUG] wincc_browse: Found %zu items\n", results->count);
        results->items = calloc(results->count, sizeof(wincc_browse_item_t));
        
        for (size_t i = 0; i < results->count; i++) {
            cJSON* item = cJSON_GetArrayItem(browse, i);
            wincc_browse_item_t* browse_item = &results->items[i];
            
            cJSON* name = cJSON_GetObjectItem(item, "name");
            cJSON* displayName = cJSON_GetObjectItem(item, "displayName");
            cJSON* objectType = cJSON_GetObjectItem(item, "objectType");
            cJSON* dataType = cJSON_GetObjectItem(item, "dataType");
            
            if (name) browse_item->name = strdup(name->valuestring);
            if (objectType) browse_item->type = strdup(objectType->valuestring);
            if (name) browse_item->address = strdup(name->valuestring); // Use name as address
            browse_item->children_count = 0; // Not available in new API
        }
    }
    
    cJSON_Delete(json);
    return results;
}

wincc_alarms_t* wincc_get_active_alarms(wincc_client_t* client) {
    if (!client) return NULL;
    
    printf("[DEBUG] wincc_get_active_alarms: Getting active alarms\n");
    
    const char* query = "query { "
                       "activeAlarms { "
                       "name instanceID state eventText alarmClassName "
                       "raiseTime clearTime acknowledgmentTime } }";
    
    printf("[DEBUG] wincc_get_active_alarms: Query: %s\n", query);
    
    graphql_response_t* response = graphql_execute(client->graphql_client, query, NULL);
    
    if (!response) {
        printf("[DEBUG] wincc_get_active_alarms: No response received\n");
        return NULL;
    }
    
    printf("[DEBUG] wincc_get_active_alarms: Response: %s\n", response->json_string);
    
    cJSON* json = cJSON_Parse(response->json_string);
    graphql_response_free(response);
    
    if (!json) {
        printf("[DEBUG] wincc_get_active_alarms: Failed to parse JSON\n");
        return NULL;
    }
    
    wincc_alarms_t* results = calloc(1, sizeof(wincc_alarms_t));
    
    cJSON* data = cJSON_GetObjectItem(json, "data");
    if (!data) {
        printf("[DEBUG] wincc_get_active_alarms: No 'data' field in response\n");
    }
    
    cJSON* alarms = cJSON_GetObjectItem(data, "activeAlarms");
    if (!alarms) {
        printf("[DEBUG] wincc_get_active_alarms: No 'activeAlarms' field in data\n");
    }
    
    if (alarms) {
        results->count = cJSON_GetArraySize(alarms);
        printf("[DEBUG] wincc_get_active_alarms: Found %zu alarms\n", results->count);
        results->items = calloc(results->count, sizeof(wincc_alarm_t));
        
        for (size_t i = 0; i < results->count; i++) {
            cJSON* item = cJSON_GetArrayItem(alarms, i);
            wincc_alarm_t* alarm = &results->items[i];
            
            cJSON* name = cJSON_GetObjectItem(item, "name");
            cJSON* instanceID = cJSON_GetObjectItem(item, "instanceID");
            cJSON* state = cJSON_GetObjectItem(item, "state");
            cJSON* eventText = cJSON_GetObjectItem(item, "eventText");
            cJSON* alarmClassName = cJSON_GetObjectItem(item, "alarmClassName");
            
            if (instanceID) {
                char id_str[32];
                snprintf(id_str, sizeof(id_str), "%d", instanceID->valueint);
                alarm->id = strdup(id_str);
            }
            if (state) alarm->state = strdup(state->valuestring);
            if (name) alarm->name = strdup(name->valuestring);
            if (eventText && cJSON_GetArraySize(eventText) > 0) {
                cJSON* first_text = cJSON_GetArrayItem(eventText, 0);
                if (first_text) alarm->text = strdup(first_text->valuestring);
            }
            if (alarmClassName) alarm->class_name = strdup(alarmClassName->valuestring);
        }
    }
    
    cJSON_Delete(json);
    return results;
}

wincc_error_t* wincc_acknowledge_alarm(wincc_client_t* client, const char* alarm_id) {
    if (!client || !alarm_id) return NULL;
    
    const char* query = "mutation AcknowledgeAlarms($input: [AlarmIdentifierInput]!) { "
                       "acknowledgeAlarms(input: $input) { "
                       "alarmName alarmInstanceID error { code description } } }";
    
    char variables[512];
    // Parse alarm_id as instanceID, if not a number use it as alarm name
    char* endptr;
    long instance_id = strtol(alarm_id, &endptr, 10);
    
    if (*endptr == '\0') {
        // It's a number, use as instanceID with empty name
        snprintf(variables, sizeof(variables), 
                 "{\"input\":[{\"name\":\"\",\"instanceID\":%ld}]}", instance_id);
    } else {
        // It's a name
        char* escaped_name = escape_json_string(alarm_id);
        snprintf(variables, sizeof(variables), 
                 "{\"input\":[{\"name\":\"%s\",\"instanceID\":0}]}", escaped_name);
        free(escaped_name);
    }
    
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
    cJSON* ack_results = cJSON_GetObjectItem(data, "acknowledgeAlarms");
    
    wincc_error_t* error = NULL;
    if (ack_results && cJSON_GetArraySize(ack_results) > 0) {
        cJSON* first_result = cJSON_GetArrayItem(ack_results, 0);
        cJSON* error_obj = cJSON_GetObjectItem(first_result, "error");
        
        if (error_obj) {
            error = malloc(sizeof(wincc_error_t));
            cJSON* code = cJSON_GetObjectItem(error_obj, "code");
            cJSON* desc = cJSON_GetObjectItem(error_obj, "description");
            
            error->error_code = strdup(code ? code->valuestring : "UNKNOWN_ERROR");
            error->description = strdup(desc ? desc->valuestring : "Unknown error");
        }
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