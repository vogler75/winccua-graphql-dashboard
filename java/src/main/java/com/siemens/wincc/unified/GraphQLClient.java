package com.siemens.wincc.unified;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import okhttp3.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

/**
 * HTTP GraphQL client for WinCC Unified
 */
public class GraphQLClient implements AutoCloseable {
    private static final Logger logger = LoggerFactory.getLogger(GraphQLClient.class);
    private static final MediaType JSON = MediaType.get("application/json; charset=utf-8");
    
    private final String httpUrl;
    private final String wsUrl;
    private final OkHttpClient httpClient;
    private final ObjectMapper objectMapper;
    private String token;
    private GraphQLWSClient wsClient;
    
    public GraphQLClient(String httpUrl, String wsUrl) {
        this.httpUrl = httpUrl;
        this.wsUrl = wsUrl;
        this.httpClient = new OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build();
        this.objectMapper = new ObjectMapper();
    }
    
    public void setToken(String token) {
        this.token = token;
        if (wsClient != null) {
            wsClient.updateToken(token);
        }
    }
    
    public GraphQLWSClient getWebSocketClient() {
        if (wsClient == null) {
            wsClient = new GraphQLWSClient(wsUrl, token);
        }
        return wsClient;
    }
    
    /**
     * Make a synchronous GraphQL HTTP request
     * @param query The GraphQL query string
     * @param variables The query variables
     * @return The response data
     * @throws IOException if the request fails
     */
    public Map<String, Object> request(String query, Map<String, Object> variables) throws IOException {
        // Build request body
        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("query", query);
        if (variables != null) {
            requestBody.put("variables", variables);
        }
        
        String jsonBody = objectMapper.writeValueAsString(requestBody);
        
        // Build HTTP request
        Request.Builder requestBuilder = new Request.Builder()
            .url(httpUrl)
            .post(RequestBody.create(jsonBody, JSON))
            .addHeader("Content-Type", "application/json");
            
        if (token != null) {
            requestBuilder.addHeader("Authorization", "Bearer " + token);
        }
        
        Request request = requestBuilder.build();
        
        // Execute request
        try (Response response = httpClient.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("HTTP error! status: " + response.code());
            }
            
            String responseBody = response.body().string();
            JsonNode jsonResponse = objectMapper.readTree(responseBody);
            
            // Check for GraphQL errors
            if (jsonResponse.has("errors")) {
                JsonNode errors = jsonResponse.get("errors");
                StringBuilder errorMsg = new StringBuilder("GraphQL error: ");
                if (errors.isArray()) {
                    for (JsonNode error : errors) {
                        String message = error.has("message") ? error.get("message").asText() : error.toString();
                        errorMsg.append(message).append(", ");
                    }
                }
                throw new IOException(errorMsg.toString());
            }
            
            // Return data
            JsonNode data = jsonResponse.get("data");
            if (data != null) {
                return objectMapper.convertValue(data, new TypeReference<Map<String, Object>>() {});
            }
            
            return new HashMap<>();
        }
    }
    
    /**
     * Make a GraphQL subscription through WebSocket
     * @param query The GraphQL subscription query
     * @param variables The query variables
     * @param callbacks The subscription callbacks
     * @return A subscription object that can be used to unsubscribe
     */
    public Subscription subscribe(String query, Map<String, Object> variables, SubscriptionCallbacks callbacks) {
        GraphQLWSClient wsClient = getWebSocketClient();
        return wsClient.subscribe(query, variables, callbacks);
    }
    
    @Override
    public void close() {
        if (wsClient != null) {
            wsClient.disconnect();
        }
        httpClient.dispatcher().executorService().shutdown();
    }
}