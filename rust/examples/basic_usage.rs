//! Basic usage example for WinCC Unified GraphQL client

use winccua_graphql_client::{WinCCUnifiedClient, TagValueInput, AlarmIdentifierInput};
use serde_json::json;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Create client
    let mut client = WinCCUnifiedClient::new(
        "http://DESKTOP-KHLB071:4000/graphql"
    );
    
    // Example 1: Login
    println!("=== Login Example ===");
    match client.login("username1", "password1") {
        Ok(session) => {
            println!("Login successful!");
            println!("User: {:?}", session.user);
            println!("Token: {:?}", session.token);
            println!("Expires: {:?}", session.expires);
        }
        Err(e) => {
            println!("Login failed: {}", e);
            return Ok(());
        }
    }
    
    // Example 2: Get session info
    println!("\n=== Session Info Example ===");
    match client.get_session_single() {
        Ok(sessions) => {
            println!("Current sessions: {:?}", sessions);
        }
        Err(e) => {
            println!("Failed to get session: {}", e);
        }
    }
    
    // Example 3: Read tag values
    println!("\n=== Tag Values Example ===");
    let tag_names = vec![
        "HMI_Tag_1".to_string(),
        "HMI_Tag_2".to_string(),
    ];
    
    match client.get_tag_values_simple(&tag_names) {
        Ok(tag_values) => {
            println!("Tag values:");
            for tag_value in tag_values {
                println!("  Name: {:?}", tag_value.name);
                println!("  Value: {:?}", tag_value.value);
                println!("  Error: {:?}", tag_value.error);
            }
        }
        Err(e) => {
            println!("Failed to get tag values: {}", e);
        }
    }
    
    // Example 4: Write tag values
    println!("\n=== Write Tag Values Example ===");
    let tag_inputs = vec![
        TagValueInput {
            name: "HMI_Tag_1".to_string(),
            value: json!(123),
            timestamp: None,
            quality: None,
        },
        TagValueInput {
            name: "HMI_Tag_2".to_string(),
            value: json!(true),
            timestamp: None,
            quality: None,
        },
    ];
    
    match client.write_tag_values_simple(&tag_inputs) {
        Ok(results) => {
            println!("Write results:");
            for result in results {
                println!("  Name: {:?}", result.name);
                println!("  Error: {:?}", result.error);
            }
        }
        Err(e) => {
            println!("Failed to write tag values: {}", e);
        }
    }
    
    // Example 5: Browse tags
    println!("\n=== Browse Tags Example ===");
    match client.browse_simple() {
        Ok(browse_results) => {
            println!("Browse results (first 10):");
            for (i, result) in browse_results.iter().take(10).enumerate() {
                println!("  {}: Name: {:?}, Type: {:?}", i + 1, result.name, result.object_type);
            }
        }
        Err(e) => {
            println!("Failed to browse: {}", e);
        }
    }
    
    // Example 6: Get active alarms
    println!("\n=== Active Alarms Example ===");
    match client.get_active_alarms_simple() {
        Ok(alarms) => {
            println!("Active alarms (first 5):");
            for (i, alarm) in alarms.iter().take(5).enumerate() {
                println!("  {}: Name: {:?}, Priority: {:?}, State: {:?}", 
                    i + 1, alarm.name, alarm.priority, alarm.state);
            }
        }
        Err(e) => {
            println!("Failed to get active alarms: {}", e);
        }
    }
    
    // Example 7: Acknowledge alarms
    println!("\n=== Acknowledge Alarms Example ===");
    let alarm_identifiers = vec![
        AlarmIdentifierInput {
            name: "System::Alarm1".to_string(),
            instance_id: Some(1),
        },
    ];
    
    match client.acknowledge_alarms(&alarm_identifiers) {
        Ok(results) => {
            println!("Acknowledge results:");
            for result in results {
                println!("  Name: {:?}, Instance ID: {:?}, Error: {:?}", 
                    result.alarm_name, result.alarm_instance_id, result.error);
            }
        }
        Err(e) => {
            println!("Failed to acknowledge alarms: {}", e);
        }
    }
    
    // Example 8: Logged tag values
    println!("\n=== Logged Tag Values Example ===");
    let logging_tag_names = vec![
        "PV-Vogler-PC::Meter_Input_WattAct:LoggingTag_1".to_string(),
    ];
    
    let end_time = chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true);
    let start_time = (chrono::Utc::now() - chrono::Duration::hours(6)).to_rfc3339_opts(chrono::SecondsFormat::Millis, true);
    
    // print start and end time
    println!("Start time: {}", start_time);
    println!("End time: {}", end_time);

    match client.get_logged_tag_values_simple(
        &logging_tag_names,
        Some(&start_time),
        Some(&end_time),
        100,
    ) {
        Ok(logged_values) => {
            println!("Logged tag values:");
            for logged_value in logged_values {
                println!("  Tag: {:?}", logged_value.logging_tag_name);
                println!("  Values count: {:?}", logged_value.values.as_ref().map(|v| v.len()));
                println!("  Error: {:?}", logged_value.error);
            }
        }
        Err(e) => {
            println!("Failed to get logged tag values: {}", e);
        }
    }
    
    // Example 9: Logout
    println!("\n=== Logout Example ===");
    match client.logout_simple() {
        Ok(success) => {
            println!("Logout successful: {}", success);
        }
        Err(e) => {
            println!("Logout failed: {}", e);
        }
    }
    
    Ok(())
}