//! Error types for WinCC Unified GraphQL client

use thiserror::Error;

/// Result type for WinCC operations
pub type WinCCResult<T> = Result<T, WinCCError>;

/// Error types for WinCC Unified GraphQL operations
#[derive(Error, Debug)]
pub enum WinCCError {
    #[error("HTTP request failed: {0}")]
    HttpError(#[from] reqwest::Error),
    
    #[error("JSON parsing error: {0}")]
    JsonError(#[from] serde_json::Error),
    
    #[error("GraphQL error: {0}")]
    GraphQLError(String),
    
    #[error("Authentication error: {0}")]
    AuthenticationError(String),
    
    #[error("Login failed: {0}")]
    LoginError(String),
    
    #[error("Session error: {0}")]
    SessionError(String),
    
    #[error("Tag operation error: {0}")]
    TagError(String),
    
    #[error("Alarm operation error: {0}")]
    AlarmError(String),
    
    #[error("Invalid parameter: {0}")]
    InvalidParameter(String),
    
    #[error("Operation failed: {0}")]
    OperationFailed(String),
}

impl WinCCError {
    pub fn from_graphql_errors(errors: &[serde_json::Value]) -> Self {
        let error_messages: Vec<String> = errors
            .iter()
            .map(|e| e["message"].as_str().unwrap_or("Unknown error").to_string())
            .collect();
        WinCCError::GraphQLError(error_messages.join(", "))
    }
}