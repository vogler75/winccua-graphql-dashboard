package com.siemens.wincc.unified;

import java.util.Map;
import java.util.function.Consumer;

/**
 * Callbacks for GraphQL subscriptions
 */
public record SubscriptionCallbacks(
    Consumer<Map<String, Object>> onData,
    Consumer<Throwable> onError,
    Runnable onComplete
) {
    public static SubscriptionCallbacks of(
        Consumer<Map<String, Object>> onData,
        Consumer<Throwable> onError,
        Runnable onComplete
    ) {
        return new SubscriptionCallbacks(onData, onError, onComplete);
    }
    
    public static SubscriptionCallbacks of(Consumer<Map<String, Object>> onData) {
        return new SubscriptionCallbacks(onData, null, null);
    }
    
    public static SubscriptionCallbacks of(
        Consumer<Map<String, Object>> onData,
        Consumer<Throwable> onError
    ) {
        return new SubscriptionCallbacks(onData, onError, null);
    }
}