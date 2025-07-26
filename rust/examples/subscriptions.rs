//! Complete example of WebSocket subscriptions including login
//! This example demonstrates the full workflow: login -> subscribe -> logout
//! 
//! To run this example:
//! 1. Source the environment: source setenv.sh
//! 2. Run: cargo run --example full_subscriptions

use std::env;
use std::time::Duration;
use std::process::Command;
use tokio;
use winccua_graphql_client::{GraphQLWSClient, SubscriptionCallbacks, subscriptions};
use serde_json::Value;

async fn get_token_from_login(http_url: &str, username: &str, password: &str) -> Result<String, Box<dyn std::error::Error>> {
    println!("Getting authentication token...");
    
    // Use curl to get token to avoid runtime conflicts
    let output = Command::new("curl")
        .arg("-s")
        .arg("-X")
        .arg("POST")
        .arg("-H")
        .arg("Content-Type: application/json")
        .arg("-d")
        .arg(&format!(r#"{{"query":"mutation Login($username: String!, $password: String!) {{ login(username: $username, password: $password) {{ token error {{ code description }} }} }}","variables":{{"username":"{}","password":"{}"}}}}"#, username, password))
        .arg(http_url)
        .output()?;

    if !output.status.success() {
        return Err("Failed to execute curl command".into());
    }

    let response_text = String::from_utf8(output.stdout)?;
    let response: Value = serde_json::from_str(&response_text)?;
    
    if let Some(errors) = response.get("errors") {
        return Err(format!("GraphQL errors: {}", errors).into());
    }
    
    if let Some(data) = response.get("data") {
        if let Some(login) = data.get("login") {
            // Check if there's an error field and it's not null
            if let Some(error) = login.get("error") {
                if !error.is_null() {
                    let code = error.get("code").and_then(|c| c.as_str()).unwrap_or("Unknown");
                    let desc = error.get("description").and_then(|d| d.as_str()).unwrap_or("No description");
                    // Only return error if code is not "0" (success)
                    if code != "0" {
                        return Err(format!("Login failed: {} - {}", code, desc).into());
                    }
                }
            }
            
            if let Some(token) = login.get("token").and_then(|t| t.as_str()) {
                println!("Login successful!");
                return Ok(token.to_string());
            }
        }
    }
    
    Err("No token found in response".into())
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Get configuration from environment variables (use setenv.sh)
    let username = env::var("GRAPHQL_USERNAME").unwrap_or_else(|_| "username1".to_string());
    let password = env::var("GRAPHQL_PASSWORD").unwrap_or_else(|_| "password1".to_string());
    let http_url = env::var("GRAPHQL_HTTP_URL")
        .unwrap_or_else(|_| "http://localhost:4000/graphql".to_string());
    let ws_url = env::var("GRAPHQL_WS_URL")
        .unwrap_or_else(|_| "ws://localhost:4000/graphql".to_string());

    println!("WinCC Unified WebSocket Subscription Example (Full Workflow)");
    println!("===========================================================");
    println!("HTTP URL: {}", http_url);
    println!("WS URL: {}", ws_url);
    println!("Username: {}", username);
    println!();

    // Get authentication token
    let token = match get_token_from_login(&http_url, &username, &password).await {
        Ok(token) => token,
        Err(e) => {
            eprintln!("Authentication failed: {}", e);
            eprintln!("Make sure to run 'source setenv.sh' and check your credentials");
            return Ok(());
        }
    };

    // Create WebSocket client
    let mut ws_client = GraphQLWSClient::new(ws_url.clone(), token.clone());
    
    // Connect WebSocket
    println!("Connecting WebSocket...");
    match ws_client.connect().await {
        Ok(_) => println!("WebSocket connected!"),
        Err(e) => {
            eprintln!("Failed to connect WebSocket: {}", e);
            return Ok(());
        }
    }
    println!();

    // Example 1: Subscribe to tag values
    println!("Example 1: Tag Value Subscription");
    println!("---------------------------------");
    
    let tag_names = vec!["HMI_Tag_1".to_string(), "HMI_Tag_2".to_string()];
    println!("Subscribing to tags: {:?}", tag_names);
    
    let tag_callbacks = SubscriptionCallbacks::new(|data: Value| {
        if let Some(tag_data) = data.get("data").and_then(|d| d.get("tagValues")) {
            let name = tag_data.get("name").and_then(|n| n.as_str()).unwrap_or("unknown");
            let reason = tag_data.get("notificationReason").and_then(|r| r.as_str()).unwrap_or("unknown");
            
            if let Some(value_obj) = tag_data.get("value") {
                let value = value_obj.get("value");
                let timestamp = value_obj.get("timestamp").and_then(|t| t.as_str()).unwrap_or("");
                println!("[TAG] {} = {:?} at {} ({})", name, value, timestamp, reason);
            } else if let Some(error) = tag_data.get("error") {
                let code = error.get("code").and_then(|c| c.as_str()).unwrap_or("");
                let desc = error.get("description").and_then(|d| d.as_str()).unwrap_or("");
                println!("[TAG ERROR] {}: {} - {}", name, code, desc);
            }
        }
    })
    .with_error(|err| {
        eprintln!("[TAG SUBSCRIPTION ERROR] {}", err);
    })
    .with_complete(|| {
        println!("[TAG SUBSCRIPTION] Completed");
    });

    let mut variables = std::collections::HashMap::new();
    variables.insert("names".to_string(), serde_json::json!(tag_names));
    
    let _tag_subscription = match ws_client.subscribe(
        subscriptions::TAG_VALUES.to_string(),
        variables,
        tag_callbacks
    ).await {
        Ok(sub) => {
            println!("Tag subscription started!");
            sub
        }
        Err(e) => {
            eprintln!("Failed to start tag subscription: {}", e);
            return Ok(());
        }
    };
    println!();

    // Example 2: Subscribe to active alarms
    println!("Example 2: Active Alarms Subscription");
    println!("------------------------------------");
    
    let alarm_callbacks = SubscriptionCallbacks::new(|data: Value| {
        if let Some(alarm_data) = data.get("data").and_then(|d| d.get("activeAlarms")) {
            let name = alarm_data.get("name").and_then(|n| n.as_str()).unwrap_or("unknown");
            let reason = alarm_data.get("notificationReason").and_then(|r| r.as_str()).unwrap_or("unknown");
            let state = alarm_data.get("state").and_then(|s| s.as_str()).unwrap_or("unknown");
            let priority = alarm_data.get("priority").and_then(|p| p.as_i64()).unwrap_or(0);
            let event_text = alarm_data.get("eventText")
                .and_then(|t| t.as_array())
                .and_then(|arr| arr.get(0))
                .and_then(|t| t.as_str())
                .unwrap_or("No event text");
            
            println!("[ALARM] {} - {} (Priority: {}, State: {}, Reason: {})", 
                name, event_text, priority, state, reason);
        }
    })
    .with_error(|err| {
        eprintln!("[ALARM SUBSCRIPTION ERROR] {}", err);
    })
    .with_complete(|| {
        println!("[ALARM SUBSCRIPTION] Completed");
    });

    let alarm_variables = std::collections::HashMap::new();
    let _alarm_subscription = match ws_client.subscribe(
        subscriptions::ACTIVE_ALARMS.to_string(),
        alarm_variables,
        alarm_callbacks
    ).await {
        Ok(sub) => {
            println!("Alarm subscription started!");
            sub
        }
        Err(e) => {
            eprintln!("Failed to start alarm subscription: {}", e);
            return Ok(());
        }
    };
    println!();

    // Example 3: Subscribe to redundancy state
    println!("Example 3: Redundancy State Subscription");
    println!("----------------------------------------");
    
    let redu_callbacks = SubscriptionCallbacks::new(|data: Value| {
        if let Some(redu_data) = data.get("data").and_then(|d| d.get("reduState")) {
            let reason = redu_data.get("notificationReason").and_then(|r| r.as_str()).unwrap_or("unknown");
            
            if let Some(value_obj) = redu_data.get("value") {
                let state = value_obj.get("value").and_then(|v| v.as_str()).unwrap_or("unknown");
                let timestamp = value_obj.get("timestamp").and_then(|t| t.as_str()).unwrap_or("");
                println!("[REDU STATE] {} at {} ({})", state, timestamp, reason);
            }
        }
    })
    .with_error(|err| {
        eprintln!("[REDU SUBSCRIPTION ERROR] {}", err);
    });

    let redu_variables = std::collections::HashMap::new();
    let _redu_subscription = match ws_client.subscribe(
        subscriptions::REDU_STATE.to_string(),
        redu_variables,
        redu_callbacks
    ).await {
        Ok(sub) => {
            println!("Redundancy state subscription started!");
            sub
        }
        Err(e) => {
            eprintln!("Failed to start redundancy subscription: {}", e);
            return Ok(());
        }
    };
    println!();

    // Give the connection some time to stabilize and wait for connection_ack
    println!("Waiting for connection to stabilize...");
    tokio::time::sleep(Duration::from_secs(2)).await;
    
    // Listen for notifications
    println!("Listening for notifications for 30 seconds...");
    println!("(You should see tag value updates, alarm notifications, and redundancy state changes)");
    println!("Press Ctrl+C to stop early");
    println!();
    
    tokio::time::sleep(Duration::from_secs(30)).await;

    // Cleanup
    println!("\nUnsubscribing and disconnecting...");
    ws_client.disconnect().await;
    println!("WebSocket disconnected!");

    // Logout using curl
    println!("\nLogging out...");
    let logout_output = Command::new("curl")
        .arg("-s")
        .arg("-X")
        .arg("POST")
        .arg("-H")
        .arg("Content-Type: application/json")
        .arg("-H")
        .arg(&format!("Authorization: Bearer {}", token))
        .arg("-d")
        .arg(r#"{"query":"mutation Logout($allSessions: Boolean) { logout(allSessions: $allSessions) }","variables":{"allSessions":false}}"#)
        .arg(&http_url)
        .output();

    match logout_output {
        Ok(output) if output.status.success() => println!("Logged out successfully!"),
        _ => println!("Logout failed (but continuing...)"),
    }

    println!("\nExample completed!");
    Ok(())
}