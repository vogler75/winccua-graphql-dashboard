//! Integration tests for WinCC Unified GraphQL client

use winccua_graphql_client::{WinCCUnifiedClient, TagValueInput, AlarmIdentifierInput};
use serde_json::json;

#[test]
fn test_client_creation() {
    let client = WinCCUnifiedClient::new(
        "https://example.com/graphql"
    );
    
    // Just test that the client can be created
    assert!(true);
}

#[test]
fn test_tag_value_input_serialization() {
    let input = TagValueInput {
        name: "System::Tag1".to_string(),
        value: json!(123),
        timestamp: Some("2023-12-31T23:59:59.999Z".to_string()),
        quality: None,
    };
    
    let serialized = serde_json::to_string(&input).unwrap();
    assert!(serialized.contains("System::Tag1"));
    assert!(serialized.contains("123"));
}

#[test]
fn test_alarm_identifier_input_serialization() {
    let input = AlarmIdentifierInput {
        name: "System::Alarm1".to_string(),
        instance_id: Some(1),
    };
    
    let serialized = serde_json::to_string(&input).unwrap();
    assert!(serialized.contains("System::Alarm1"));
    assert!(serialized.contains("1"));
}

#[test]
fn test_error_handling() {
    use winccua_graphql_client::WinCCError;
    
    let error = WinCCError::LoginError("Test error".to_string());
    assert!(error.to_string().contains("Test error"));
}

#[test]
fn test_json_structures() {
    use winccua_graphql_client::{Session, User, ErrorInfo};
    
    let session_json = json!({
        "user": {
            "id": "user123",
            "name": "testuser",
            "fullName": "Test User",
            "language": "en-US",
            "autoLogoffSec": 3600
        },
        "token": "abc123",
        "expires": "2023-12-31T23:59:59.999Z"
    });
    
    let session: Session = serde_json::from_value(session_json).unwrap();
    assert_eq!(session.user.as_ref().unwrap().name.as_ref().unwrap(), "testuser");
    assert_eq!(session.token.as_ref().unwrap(), "abc123");
}