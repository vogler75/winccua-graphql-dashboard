package com.siemens.wincc.unified;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * WebSocket client for GraphQL subscriptions
 */
public class GraphQLWSClient {
    private static final Logger logger = LoggerFactory.getLogger(GraphQLWSClient.class);
    
    private final String url;
    private final OkHttpClient httpClient;
    private final ObjectMapper objectMapper;
    private final Map<String, SubscriptionCallbacks> subscriptions = new ConcurrentHashMap<>();
    private final AtomicInteger subscriptionIdCounter = new AtomicInteger(0);
    
    private String token;
    private WebSocket webSocket;
    private CompletableFuture<Void> connectionFuture;
    private volatile ConnectionState connectionState = ConnectionState.DISCONNECTED;
    
    private enum ConnectionState {
        DISCONNECTED, CONNECTING, CONNECTED
    }
    
    public GraphQLWSClient(String url, String token) {
        this.url = url;
        this.token = token;
        this.httpClient = new OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(0, TimeUnit.SECONDS) // No timeout for WebSocket
            .writeTimeout(10, TimeUnit.SECONDS)
            .build();
        this.objectMapper = new ObjectMapper();
    }
    
    public void updateToken(String token) {
        this.token = token;
        if (connectionState == ConnectionState.CONNECTED) {
            logger.info("[GraphQL-WS] Token updated, reconnecting...");
            disconnect();
        }
    }
    
    public CompletableFuture<Void> connect() {
        if (connectionState == ConnectionState.CONNECTED) {
            return CompletableFuture.completedFuture(null);
        }
        
        if (connectionState == ConnectionState.CONNECTING) {
            return connectionFuture;
        }
        
        connectionState = ConnectionState.CONNECTING;
        connectionFuture = new CompletableFuture<>();
        
        // Build WebSocket request
        Request.Builder requestBuilder = new Request.Builder()
            .url(url)
            .addHeader("Sec-WebSocket-Protocol", "graphql-transport-ws");
            
        if (token != null) {
            requestBuilder.addHeader("Authorization", "Bearer " + token);
        }
        
        Request request = requestBuilder.build();
        
        // Create WebSocket listener
        WebSocketListener listener = new WebSocketListener() {
            @Override
            public void onOpen(WebSocket webSocket, Response response) {
                logger.info("[GraphQL-WS] WebSocket connected to {}", url);
                
                // Send connection init message
                Map<String, Object> initMessage = new HashMap<>();
                initMessage.put("type", "connection_init");
                
                Map<String, Object> payload = new HashMap<>();
                if (token != null) {
                    payload.put("Authorization", "Bearer " + token);
                }
                payload.put("Content-Type", "application/json");
                initMessage.put("payload", payload);
                
                try {
                    String json = objectMapper.writeValueAsString(initMessage);
                    webSocket.send(json);
                } catch (Exception e) {
                    logger.error("[GraphQL-WS] Failed to send connection init", e);
                    connectionFuture.completeExceptionally(e);
                }
            }
            
            @Override
            public void onMessage(WebSocket webSocket, String text) {
                try {
                    JsonNode message = objectMapper.readTree(text);
                    String type = message.get("type").asText();
                    
                    switch (type) {
                        case "connection_ack":
                            logger.info("[GraphQL-WS] Connection acknowledged");
                            connectionState = ConnectionState.CONNECTED;
                            connectionFuture.complete(null);
                            break;
                            
                        case "connection_error":
                            logger.error("[GraphQL-WS] Connection error: {}", message.get("payload"));
                            connectionState = ConnectionState.DISCONNECTED;
                            connectionFuture.completeExceptionally(new IOException("Connection error: " + message.get("payload")));
                            break;
                            
                        case "next":
                            handleDataMessage(message);
                            break;
                            
                        case "error":
                            handleErrorMessage(message);
                            break;
                            
                        case "complete":
                            handleCompleteMessage(message);
                            break;
                            
                        case "pong":
                            logger.debug("[GraphQL-WS] Keep alive received");
                            break;
                            
                        default:
                            logger.warn("[GraphQL-WS] Unknown message type: {}", type);
                    }
                } catch (Exception e) {
                    logger.error("[GraphQL-WS] Error processing message", e);
                }
            }
            
            @Override
            public void onFailure(WebSocket webSocket, Throwable t, Response response) {
                logger.error("[GraphQL-WS] WebSocket error", t);
                connectionState = ConnectionState.DISCONNECTED;
                
                if (connectionFuture != null && !connectionFuture.isDone()) {
                    connectionFuture.completeExceptionally(t);
                }
                
                // Notify all subscriptions of disconnection
                notifySubscriptionsDisconnected();
            }
            
            @Override
            public void onClosed(WebSocket webSocket, int code, String reason) {
                logger.info("[GraphQL-WS] WebSocket closed: {} {}", code, reason);
                connectionState = ConnectionState.DISCONNECTED;
                
                if (connectionFuture != null && !connectionFuture.isDone()) {
                    connectionFuture.completeExceptionally(new IOException("WebSocket closed: " + reason));
                }
                
                // Notify all subscriptions of disconnection
                notifySubscriptionsDisconnected();
            }
        };
        
        // Connect WebSocket
        webSocket = httpClient.newWebSocket(request, listener);
        
        return connectionFuture;
    }
    
    public Subscription subscribe(String query, Map<String, Object> variables, SubscriptionCallbacks callbacks) {
        String subscriptionId = generateSubscriptionId();
        
        // Store subscription callbacks
        subscriptions.put(subscriptionId, callbacks);
        
        // Connect first if not connected
        connect().thenRun(() -> {
            // Send subscription message
            Map<String, Object> subscriptionMessage = new HashMap<>();
            subscriptionMessage.put("id", subscriptionId);
            subscriptionMessage.put("type", "subscribe");
            
            Map<String, Object> payload = new HashMap<>();
            payload.put("query", query);
            payload.put("variables", variables != null ? variables : new HashMap<>());
            subscriptionMessage.put("payload", payload);
            
            try {
                String json = objectMapper.writeValueAsString(subscriptionMessage);
                webSocket.send(json);
                logger.info("[GraphQL-WS] Subscription started: {}", subscriptionId);
            } catch (Exception e) {
                logger.error("[GraphQL-WS] Failed to send subscription", e);
                subscriptions.remove(subscriptionId);
                if (callbacks != null && callbacks.onError() != null) {
                    callbacks.onError().accept(e);
                }
            }
        }).exceptionally(throwable -> {
            logger.error("[GraphQL-WS] Failed to connect for subscription", throwable);
            subscriptions.remove(subscriptionId);
            if (callbacks != null && callbacks.onError() != null) {
                callbacks.onError().accept(throwable);
            }
            return null;
        });
        
        return new Subscription(subscriptionId, this);
    }
    
    public void unsubscribe(String subscriptionId) {
        if (subscriptions.containsKey(subscriptionId)) {
            // Send complete message
            if (webSocket != null && connectionState == ConnectionState.CONNECTED) {
                Map<String, Object> completeMessage = new HashMap<>();
                completeMessage.put("id", subscriptionId);
                completeMessage.put("type", "complete");
                
                try {
                    String json = objectMapper.writeValueAsString(completeMessage);
                    webSocket.send(json);
                } catch (Exception e) {
                    logger.error("[GraphQL-WS] Failed to send complete message", e);
                }
            }
            
            // Remove subscription
            subscriptions.remove(subscriptionId);
            logger.info("[GraphQL-WS] Subscription stopped: {}", subscriptionId);
        }
    }
    
    public void disconnect() {
        connectionState = ConnectionState.DISCONNECTED;
        
        // Stop all subscriptions
        for (String subscriptionId : subscriptions.keySet()) {
            unsubscribe(subscriptionId);
        }
        
        // Close WebSocket
        if (webSocket != null) {
            webSocket.close(1000, "Normal closure");
            webSocket = null;
        }
        
        connectionFuture = null;
    }
    
    private String generateSubscriptionId() {
        return "sub_" + subscriptionIdCounter.incrementAndGet();
    }
    
    private void handleDataMessage(JsonNode message) {
        String subscriptionId = message.get("id").asText();
        JsonNode payload = message.get("payload");
        
        SubscriptionCallbacks callbacks = subscriptions.get(subscriptionId);
        if (callbacks != null && callbacks.onData() != null) {
            try {
                Map<String, Object> data = objectMapper.convertValue(payload, new TypeReference<Map<String, Object>>() {});
                callbacks.onData().accept(data);
            } catch (Exception e) {
                logger.error("[GraphQL-WS] Error in subscription callback", e);
            }
        }
    }
    
    private void handleErrorMessage(JsonNode message) {
        String subscriptionId = message.get("id").asText();
        JsonNode payload = message.get("payload");
        
        SubscriptionCallbacks callbacks = subscriptions.get(subscriptionId);
        if (callbacks != null && callbacks.onError() != null) {
            try {
                callbacks.onError().accept(new RuntimeException(payload.toString()));
            } catch (Exception e) {
                logger.error("[GraphQL-WS] Error in subscription error callback", e);
            }
        }
    }
    
    private void handleCompleteMessage(JsonNode message) {
        String subscriptionId = message.get("id").asText();
        
        SubscriptionCallbacks callbacks = subscriptions.get(subscriptionId);
        if (callbacks != null && callbacks.onComplete() != null) {
            try {
                callbacks.onComplete().run();
            } catch (Exception e) {
                logger.error("[GraphQL-WS] Error in subscription complete callback", e);
            }
        }
        
        // Remove subscription
        subscriptions.remove(subscriptionId);
    }
    
    private void notifySubscriptionsDisconnected() {
        for (SubscriptionCallbacks callbacks : subscriptions.values()) {
            if (callbacks != null && callbacks.onError() != null) {
                try {
                    callbacks.onError().accept(new RuntimeException("WebSocket connection closed"));
                } catch (Exception e) {
                    logger.error("[GraphQL-WS] Error in subscription disconnection callback", e);
                }
            }
        }
    }
}