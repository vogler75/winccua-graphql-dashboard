package com.siemens.wincc.unified;

/**
 * Represents a GraphQL subscription that can be unsubscribed
 */
public class Subscription {
    private final String id;
    private final GraphQLWSClient wsClient;
    
    public Subscription(String id, GraphQLWSClient wsClient) {
        this.id = id;
        this.wsClient = wsClient;
    }
    
    public String getId() {
        return id;
    }
    
    public void unsubscribe() {
        wsClient.unsubscribe(id);
    }
}