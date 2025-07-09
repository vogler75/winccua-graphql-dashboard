//! # WinCC Unified GraphQL Client for Rust
//!
//! This library provides a synchronous client for the WinCC Unified GraphQL API.
//! It supports queries and mutations for interacting with WinCC Unified systems.
//!
//! ## Features
//!
//! - Synchronous GraphQL HTTP client
//! - Authentication with session tokens
//! - Comprehensive error handling
//! - All WinCC Unified API endpoints

pub mod client;
pub mod error;
pub mod graphql;
pub mod types;

pub use client::WinCCUnifiedClient;
pub use error::{WinCCError, WinCCResult};
pub use types::*;

// Re-export common types for convenience
pub use serde_json::Value;