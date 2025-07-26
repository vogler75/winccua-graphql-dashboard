package com.siemens.wincc.unified.example;

import com.siemens.wincc.unified.Subscription;
import com.siemens.wincc.unified.SubscriptionCallbacks;
import com.siemens.wincc.unified.WinCCUnifiedClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * Example usage of WinCC Unified Java Client Library
 * Demonstrates basic functionality similar to the Python examples
 */
public class Example {
    private static final Logger logger = LoggerFactory.getLogger(Example.class);
    
    public static void main(String[] args) {
        // Configuration - get URLs and credentials from environment variables or use defaults
        String HTTP_URL = System.getenv().getOrDefault("GRAPHQL_HTTP_URL", "https://your-wincc-server/graphql");
        String WS_URL = System.getenv().getOrDefault("GRAPHQL_WS_URL", "wss://your-wincc-server/graphql");
        String USERNAME = System.getenv().getOrDefault("GRAPHQL_USERNAME", "username");
        String PASSWORD = System.getenv().getOrDefault("GRAPHQL_PASSWORD", "password");
        
        System.out.println("WinCC Unified Java Client Example");
        System.out.println("=" + "=".repeat(39));
        System.out.println();
        System.out.println("Note: Please set GRAPHQL_HTTP_URL, GRAPHQL_WS_URL, GRAPHQL_USERNAME, and GRAPHQL_PASSWORD environment variables or update values in the code before running");
        System.out.println();
        
        // Initialize client
        try (WinCCUnifiedClient client = new WinCCUnifiedClient(HTTP_URL, WS_URL)) {
            
            // Login
            System.out.println("Logging in...");
            Map<String, Object> session = client.login(USERNAME, PASSWORD);
            
            @SuppressWarnings("unchecked")
            Map<String, Object> user = (Map<String, Object>) session.get("user");
            System.out.println("Logged in as: " + user.get("name"));
            System.out.println("Token expires: " + session.get("expires"));
            
            // Get session info
            System.out.println("\nGetting session info...");
            List<Map<String, Object>> sessionInfo = client.getSession();
            
            if (sessionInfo == null || sessionInfo.isEmpty()) {
                System.out.println("No session info found");
            } else {
                System.out.println("Session info:");
                for (Map<String, Object> sInfo : sessionInfo) {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> sessionUser = (Map<String, Object>) sInfo.get("user");
                    System.out.println("  - User: " + sessionUser.get("fullName") + ", Expires: " + sInfo.get("expires"));
                }
            }
            
            // Browse available objects
            System.out.println("\nBrowsing available objects...");
            List<Map<String, Object>> objects = client.browse();
            System.out.println("Found " + objects.size() + " objects");
            objects.stream().limit(5).forEach(obj -> {
                System.out.println("  - " + obj.get("name") + " (" + obj.get("objectType") + ")");
            });
            
            // Get tag values
            System.out.println("\nGetting tag values...");
            List<String> tagNames = List.of("HMI_Tag_1", "HMI_Tag_2"); // Replace with actual tag names
            try {
                List<Map<String, Object>> tags = client.getTagValues(tagNames);
                for (Map<String, Object> tag : tags) {
                    if (tag.get("error") != null) {
                        @SuppressWarnings("unchecked")
                        Map<String, Object> error = (Map<String, Object>) tag.get("error");
                        System.out.println("  - " + tag.get("name") + ": ERROR - " + error.get("description"));
                    } else {
                        @SuppressWarnings("unchecked")
                        Map<String, Object> value = (Map<String, Object>) tag.get("value");
                        @SuppressWarnings("unchecked")
                        Map<String, Object> quality = (Map<String, Object>) value.get("quality");
                        System.out.println("  - " + tag.get("name") + ": " + value.get("value") + 
                                         " (Quality: " + quality.get("quality") + ", Time: " + value.get("timestamp") + ")");
                    }
                }
            } catch (Exception e) {
                System.out.println("Error getting tag values: " + e.getMessage());
            }
            
            // Get logged tag values
            System.out.println("\nGetting logged tag values...");
            try {
                // Get values from the last 24 hours
                Instant endTime = Instant.now();
                Instant startTime = endTime.minus(24, ChronoUnit.HOURS);
                
                List<Map<String, Object>> loggedValues = client.getLoggedTagValues(
                    List.of("PV-Vogler-PC::Meter_Input_WattAct:LoggingTag_1"),
                    startTime.toString(),
                    endTime.toString(),
                    10
                );
                
                System.out.println("Found " + loggedValues.size() + " logged tag results");
                for (Map<String, Object> result : loggedValues) {
                    if (result.get("error") != null) {
                        @SuppressWarnings("unchecked")
                        Map<String, Object> error = (Map<String, Object>) result.get("error");
                        String errorCode = (String) error.get("code");
                        if (!"0".equals(errorCode)) {
                            System.out.println("  - " + result.get("loggingTagName") + ": ERROR - " + error.get("description"));
                            continue;
                        }
                    }
                    
                    @SuppressWarnings("unchecked")
                    List<Map<String, Object>> values = (List<Map<String, Object>>) result.get("values");
                    System.out.println("  - " + result.get("loggingTagName") + ": " + values.size() + " values");
                    
                    // Show last 5 values
                    values.stream().skip(Math.max(0, values.size() - 5)).forEach(val -> {
                        @SuppressWarnings("unchecked")
                        Map<String, Object> valueData = (Map<String, Object>) val.get("value");
                        @SuppressWarnings("unchecked")
                        Map<String, Object> qualityData = (Map<String, Object>) valueData.get("quality");
                        System.out.println("    " + valueData.get("timestamp") + ": " + 
                                         valueData.get("value") + " (Quality: " + qualityData.get("quality") + ")");
                    });
                }
            } catch (Exception e) {
                System.out.println("Error getting logged tag values: " + e.getMessage());
            }
            
            // Get active alarms
            System.out.println("\nGetting active alarms...");
            try {
                List<Map<String, Object>> alarms = client.getActiveAlarms();
                System.out.println("Found " + alarms.size() + " active alarms");
                alarms.stream().limit(3).forEach(alarm -> {
                    @SuppressWarnings("unchecked")
                    List<String> eventTexts = (List<String>) alarm.get("eventText");
                    String eventText = eventTexts != null && !eventTexts.isEmpty() ? eventTexts.get(0) : "No event text";
                    System.out.println("  - " + alarm.get("name") + ": " + eventText + " (Priority: " + alarm.get("priority") + ")");
                });
            } catch (Exception e) {
                System.out.println("Error getting alarms: " + e.getMessage());
            }
            
            // Example of writing tag values
            System.out.println("\nWriting tag values...");
            try {
                List<Map<String, Object>> tagValues = List.of(
                    Map.of("name", "HMI_Tag_1", "value", 100),
                    Map.of("name", "HMI_Tag_2", "value", 200)
                );
                
                List<Map<String, Object>> writeResults = client.writeTagValues(tagValues);
                for (Map<String, Object> result : writeResults) {
                    if (result.get("error") != null) {
                        @SuppressWarnings("unchecked")
                        Map<String, Object> error = (Map<String, Object>) result.get("error");
                        System.out.println("  - " + result.get("name") + ": ERROR - " + error.get("description"));
                    } else {
                        System.out.println("  - " + result.get("name") + ": Written successfully");
                    }
                }
            } catch (Exception e) {
                System.out.println("Error writing tag values: " + e.getMessage());
            }
            
            // Set up subscription for tag values
            System.out.println("\nSetting up tag value subscription...");
            CountDownLatch subscriptionLatch = new CountDownLatch(1);
            
            SubscriptionCallbacks tagCallbacks = SubscriptionCallbacks.of(
                data -> {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> dataMap = (Map<String, Object>) data.get("data");
                    @SuppressWarnings("unchecked")
                    Map<String, Object> tagValues = (Map<String, Object>) dataMap.get("tagValues");
                    if (tagValues != null) {
                        @SuppressWarnings("unchecked")
                        Map<String, Object> value = (Map<String, Object>) tagValues.get("value");
                        String timestamp = (String) value.get("timestamp");
                        String reason = (String) tagValues.getOrDefault("notificationReason", "UPDATE");
                        System.out.println("  [SUBSCRIPTION] " + tagValues.get("name") + ": " + 
                                         value.get("value") + " (" + reason + ") at " + timestamp);
                    }
                },
                error -> {
                    System.out.println("  [SUBSCRIPTION ERROR] " + error.getMessage());
                },
                () -> {
                    System.out.println("  [SUBSCRIPTION] Tag subscription completed");
                    subscriptionLatch.countDown();
                }
            );
            
            try {
                Subscription subscription = client.subscribeToTagValues(tagNames, tagCallbacks);
                
                System.out.println("Tag subscription active. Waiting for updates...");
                
                // Keep subscription active for 30 seconds
                Thread.sleep(1_000);
                
                // Unsubscribe
                System.out.println("Unsubscribing from tag values...");
                subscription.unsubscribe();
                
            } catch (Exception e) {
                System.out.println("Error setting up subscription: " + e.getMessage());
            }
            
            // Set up subscription for active alarms
            System.out.println("\nSetting up alarm subscription...");
            CountDownLatch alarmLatch = new CountDownLatch(1);
            
            SubscriptionCallbacks alarmCallbacks = SubscriptionCallbacks.of(
                data -> {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> dataMap = (Map<String, Object>) data.get("data");
                    @SuppressWarnings("unchecked")
                    Map<String, Object> activeAlarms = (Map<String, Object>) dataMap.get("activeAlarms");
                    if (activeAlarms != null) {
                        logger.info("DATA2");
                        String reason = (String) activeAlarms.getOrDefault("notificationReason", "UPDATE");
                        @SuppressWarnings("unchecked")
                        List<String> eventTexts = (List<String>) activeAlarms.get("eventText");
                        String eventText = eventTexts != null && !eventTexts.isEmpty() ? eventTexts.get(0) : "No event text";
                        System.out.println("  [ALARM] " + activeAlarms.get("name") + ": " + eventText + " (" + reason + ")");
                    }
                },
                error -> {
                    System.out.println("  [ALARM ERROR] " + error.getMessage());
                },
                () -> {
                    System.out.println("  [ALARM] Alarm subscription completed");
                    alarmLatch.countDown();
                }
            );
            
            try {
                Subscription alarmSubscription = client.subscribeToActiveAlarms(alarmCallbacks);
                
                System.out.println("Alarm subscription active. Waiting for updates...");
                
                // Keep subscription active for 30 seconds
                Thread.sleep(30_000);
                
                // Unsubscribe
                System.out.println("Unsubscribing from alarms...");
                alarmSubscription.unsubscribe();
                
            } catch (Exception e) {
                System.out.println("Error setting up alarm subscription: " + e.getMessage());
            }
            
            // Logout
            System.out.println("\nLogging out...");
            client.logout();
            System.out.println("Logged out successfully");
            
        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            logger.error("Application error", e);
        }
    }
}