//! Main WinCC Unified GraphQL client implementation

use crate::error::{WinCCError, WinCCResult};
use crate::graphql::{mutations, queries, subscriptions};
use crate::graphql_ws::{GraphQLWSClient, SubscriptionCallbacks, Subscription};
use crate::types::*;
use reqwest::blocking::Client;
use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION, CONTENT_TYPE};
use serde_json::{json, Value};
use std::collections::HashMap;

/// Main WinCC Unified GraphQL client
/// 
/// This client provides synchronous access to the WinCC Unified GraphQL API,
/// supporting queries and mutations.
pub struct WinCCUnifiedClient {
    http_client: Client,
    http_url: String,
    ws_url: Option<String>,
    token: Option<String>,
    ws_client: Option<GraphQLWSClient>,
}

impl WinCCUnifiedClient {
    /// Create a new WinCC Unified client
    /// 
    /// # Arguments
    /// * `http_url` - The HTTP URL for GraphQL queries and mutations
    /// 
    /// # Example
    /// ```
    /// use winccua_graphql_client::WinCCUnifiedClient;
    /// 
    /// let client = WinCCUnifiedClient::new("https://your-server/graphql");
    /// ```
    pub fn new(http_url: &str) -> Self {
        Self {
            http_client: Client::new(),
            http_url: http_url.to_string(),
            ws_url: None,
            token: None,
            ws_client: None,
        }
    }

    /// Create a new WinCC Unified client with WebSocket support
    /// 
    /// # Arguments
    /// * `http_url` - The HTTP URL for GraphQL queries and mutations
    /// * `ws_url` - The WebSocket URL for GraphQL subscriptions
    pub fn new_with_ws(http_url: &str, ws_url: &str) -> Self {
        Self {
            http_client: Client::new(),
            http_url: http_url.to_string(),
            ws_url: Some(ws_url.to_string()),
            token: None,
            ws_client: None,
        }
    }
    
    /// Set the authentication token
    /// 
    /// # Arguments
    /// * `token` - The bearer token for authentication
    pub fn set_token(&mut self, token: &str) {
        self.token = Some(token.to_string());
        
        // Update WebSocket client token if it exists
        if let Some(ws_client) = &self.ws_client {
            ws_client.update_token(token.to_string());
        }
    }
    
    /// Clear the authentication token
    pub fn clear_token(&mut self) {
        self.token = None;
    }
    
    /// Make a GraphQL HTTP request
    fn request(&self, query: &str, variables: Option<Value>) -> WinCCResult<Value> {
        let mut headers = HeaderMap::new();
        headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
        
        if let Some(token) = &self.token {
            let auth_header = format!("Bearer {}", token);
            headers.insert(AUTHORIZATION, HeaderValue::from_str(&auth_header).unwrap());
        }
        
        let payload = json!({
            "query": query,
            "variables": variables.unwrap_or(json!({}))
        });
        
        let response = self.http_client
            .post(&self.http_url)
            .headers(headers)
            .json(&payload)
            .send()?;
        
        if !response.status().is_success() {
            return Err(WinCCError::HttpError(reqwest::Error::from(
                response.error_for_status().unwrap_err()
            )));
        }
        
        let result: Value = response.json()?;
        
        if let Some(errors) = result.get("errors") {
            if let Some(error_array) = errors.as_array() {
                if !error_array.is_empty() {
                    return Err(WinCCError::from_graphql_errors(error_array));
                }
            }
        }
        
        Ok(result.get("data").unwrap_or(&json!({})).clone())
    }
    
    /// Logs a user in based on their username and password.
    /// 
    /// Returns: Session object containing user info, token, and expiry timestamp
    /// 
    /// JSON Structure: 
    /// ```json
    /// {
    ///   "user": {
    ///     "id": "string",
    ///     "name": "string",
    ///     "groups": [{"id": "string", "name": "string"}],
    ///     "fullName": "string",
    ///     "language": "string",
    ///     "autoLogoffSec": 3600
    ///   },
    ///   "token": "string",
    ///   "expires": "2023-12-31T23:59:59.999Z",
    ///   "error": {
    ///     "code": "string",
    ///     "description": "string"
    ///   }
    /// }
    /// ```
    /// 
    /// Errors:
    /// - 101 - Incorrect credentials provided
    /// - 102 - UMC error
    pub fn login(&mut self, username: &str, password: &str) -> WinCCResult<Session> {
        let variables = json!({
            "username": username,
            "password": password
        });
        
        let result = self.request(mutations::LOGIN, Some(variables))?;
        let login_result: Session = serde_json::from_value(result["login"].clone())?;
        
        if let Some(ref token) = login_result.token {
            self.set_token(token);
        }
        
        if login_result.token.is_some() {
            Ok(login_result)
        } else {
            let error_msg = login_result.error
                .as_ref()
                .and_then(|e| e.description.as_ref())
                .map_or("Unknown error", |v| v);
            Err(WinCCError::LoginError(error_msg.to_string()))
        }
    }
    
    /// Returns information about the current session. If all_sessions is true, returns all sessions of the current user.
    /// 
    /// Returns: Array of Session objects with user info, token, and expiry timestamp
    /// 
    /// JSON Structure: 
    /// ```json
    /// [{
    ///   "user": {
    ///     "id": "string",
    ///     "name": "string",
    ///     "groups": [{"id": "string", "name": "string"}],
    ///     "fullName": "string",
    ///     "language": "string",
    ///     "autoLogoffSec": 3600
    ///   },
    ///   "token": "string",
    ///   "expires": "2023-12-31T23:59:59.999Z",
    ///   "error": {
    ///     "code": "string",
    ///     "description": "string"
    ///   }
    /// }]
    /// ```
    pub fn get_session(&self, all_sessions: bool) -> WinCCResult<Vec<Session>> {
        let variables = json!({
            "allSessions": all_sessions
        });
        
        let result = self.request(queries::SESSION, Some(variables))?;
        let sessions: Vec<Session> = serde_json::from_value(result["session"].clone())?;
        Ok(sessions)
    }
    
    /// Returns information about the current session (single session)
    pub fn get_session_single(&self) -> WinCCResult<Vec<Session>> {
        self.get_session(false)
    }
    
    /// Queries tag values based on the provided names list. If direct_read is true, values are taken directly from PLC.
    /// 
    /// Returns: Array of TagValueResult objects with tag name, value, and quality information
    /// 
    /// JSON Structure: 
    /// ```json
    /// [{
    ///   "name": "string",
    ///   "value": {
    ///     "value": "variant",
    ///     "timestamp": "2023-12-31T23:59:59.999Z",
    ///     "quality": {
    ///       "quality": "GOOD_CASCADE",
    ///       "subStatus": "NON_SPECIFIC",
    ///       "limit": "OK",
    ///       "extendedSubStatus": "NON_SPECIFIC",
    ///       "sourceQuality": true,
    ///       "sourceTime": true,
    ///       "timeCorrected": false
    ///     }
    ///   },
    ///   "error": {
    ///     "code": "string",
    ///     "description": "string"
    ///   }
    /// }]
    /// ```
    /// 
    /// Errors:
    /// - 2 - Cannot resolve provided name
    /// - 202 - Only leaf elements of a Structure Tag can be addressed
    pub fn get_tag_values(&self, names: &[String], direct_read: bool) -> WinCCResult<Vec<TagValueResult>> {
        let variables = json!({
            "names": names,
            "directRead": direct_read
        });
        
        let result = self.request(queries::TAG_VALUES, Some(variables))?;
        let tag_values: Vec<TagValueResult> = serde_json::from_value(result["tagValues"].clone())?;
        Ok(tag_values)
    }
    
    /// Queries tag values (without direct read)
    pub fn get_tag_values_simple(&self, names: &[String]) -> WinCCResult<Vec<TagValueResult>> {
        self.get_tag_values(names, false)
    }
    
    /// Queries logged tag values from the database. Names must be LoggingTag names or Tag names (if only one logging tag exists).
    /// 
    /// Returns: Array of LoggedTagValuesResult objects with logging tag name, error info, and array of logged values
    /// 
    /// JSON Structure: 
    /// ```json
    /// [{
    ///   "loggingTagName": "string",
    ///   "error": {
    ///     "code": "string",
    ///     "description": "string"
    ///   },
    ///   "values": [{
    ///     "value": {
    ///       "value": "variant",
    ///       "timestamp": "2023-12-31T23:59:59.999Z",
    ///       "quality": {
    ///         "quality": "GOOD_CASCADE",
    ///         "subStatus": "NON_SPECIFIC",
    ///         "limit": "OK",
    ///         "extendedSubStatus": "NON_SPECIFIC",
    ///         "sourceQuality": true,
    ///         "sourceTime": true,
    ///         "timeCorrected": false
    ///       }
    ///     },
    ///     "flags": ["CALCULATED", "PARTIAL"]
    ///   }]
    /// }]
    /// ```
    /// 
    /// Sorting modes: TIME_ASC, TIME_DESC
    /// Bounding modes: NO_BOUNDING_VALUES, LEFT_BOUNDING_VALUES, RIGHT_BOUNDING_VALUES, LEFTRIGHT_BOUNDING_VALUES
    /// 
    /// Errors:
    /// - 1 - Generic error
    /// - 2 - Cannot resolve provided name
    /// - 3 - Argument error
    pub fn get_logged_tag_values(
        &self,
        names: &[String],
        start_time: Option<&str>,
        end_time: Option<&str>,
        max_number_of_values: i32,
        sorting_mode: &str,
    ) -> WinCCResult<Vec<LoggedTagValuesResult>> {
        let mut variables = json!({
            "names": names,
            "maxNumberOfValues": max_number_of_values,
            "sortingMode": sorting_mode
        });
        
        if let Some(start) = start_time {
            variables["startTime"] = json!(start);
        }
        if let Some(end) = end_time {
            variables["endTime"] = json!(end);
        }
        
        let result = self.request(queries::LOGGED_TAG_VALUES, Some(variables))?;
        let logged_values: Vec<LoggedTagValuesResult> = serde_json::from_value(result["loggedTagValues"].clone())?;
        Ok(logged_values)
    }
    
    /// Queries logged tag values with default sorting (TIME_ASC)
    pub fn get_logged_tag_values_simple(
        &self,
        names: &[String],
        start_time: Option<&str>,
        end_time: Option<&str>,
        max_number_of_values: i32,
    ) -> WinCCResult<Vec<LoggedTagValuesResult>> {
        self.get_logged_tag_values(names, start_time, end_time, max_number_of_values, "TIME_ASC")
    }
    
    /// Returns a nonce that can be used with e.g. the UMC SWAC login method.
    /// 
    /// Returns: Nonce object with value and validity duration
    /// 
    /// JSON Structure: 
    /// ```json
    /// {
    ///   "value": "string",
    ///   "validFor": 300
    /// }
    /// ```
    pub fn get_nonce(&self) -> WinCCResult<Nonce> {
        let result = self.request(queries::NONCE, None)?;
        let nonce: Nonce = serde_json::from_value(result["nonce"].clone())?;
        Ok(nonce)
    }
    
    /// Returns the URL of the identity provider for UMC SWAC authentication.
    /// 
    /// Returns: String URL where user should be redirected for SWAC login
    /// 
    /// JSON Structure: 
    /// ```json
    /// "https://identity-provider.example.com/auth"
    /// ```
    pub fn get_identity_provider_url(&self) -> WinCCResult<String> {
        let result = self.request(queries::IDENTITY_PROVIDER_URL, None)?;
        let url = result["identityProviderURL"].as_str()
            .ok_or_else(|| WinCCError::OperationFailed("Invalid identity provider URL".to_string()))?;
        Ok(url.to_string())
    }
    
    /// Queries tags, elements, types, alarms, logging tags based on filter criteria. 
    /// Each filter parameter supports arrays with OR relation, while parameters have AND relation.
    /// 
    /// Returns: Array of BrowseTagsResult objects with name, display name, object type, and data type
    /// 
    /// JSON Structure: 
    /// ```json
    /// [{
    ///   "name": "string",
    ///   "displayName": "string",
    ///   "objectType": "TAG",
    ///   "dataType": "Int32"
    /// }]
    /// ```
    /// 
    /// ObjectTypes: TAG, SIMPLETAG, STRUCTURETAG, TAGTYPE, STRUCTURETAGTYPE, SIMPLETAGTYPE, ALARM, ALARMCLASS, LOGGINGTAG
    /// 
    /// Errors:
    /// - 1 - Generic error
    /// - 2 - Cannot resolve provided name
    /// - 3 - Argument error
    pub fn browse(
        &self,
        name_filters: &[String],
        object_type_filters: &[String],
        base_type_filters: &[String],
        language: &str,
    ) -> WinCCResult<Vec<BrowseTagsResult>> {
        let variables = json!({
            "nameFilters": name_filters,
            "objectTypeFilters": object_type_filters,
            "baseTypeFilters": base_type_filters,
            "language": language
        });
        
        let result = self.request(queries::BROWSE, Some(variables))?;
        let browse_results: Vec<BrowseTagsResult> = serde_json::from_value(result["browse"].clone())?;
        Ok(browse_results)
    }
    
    /// Browse with default parameters
    pub fn browse_simple(&self) -> WinCCResult<Vec<BrowseTagsResult>> {
        self.browse(&[], &[], &[], "en-US")
    }
    
    /// Query active alarms from the provided systems using ChromQueryLanguage filter.
    /// 
    /// Returns: Array of ActiveAlarm objects with comprehensive alarm information
    /// 
    /// JSON Structure: (truncated for brevity, see ActiveAlarm struct for full definition)
    /// ```json
    /// [{
    ///   "name": "string",
    ///   "instanceID": 123,
    ///   "alarmGroupID": 456,
    ///   "raiseTime": "2023-12-31T23:59:59.999Z",
    ///   "acknowledgmentTime": "2023-12-31T23:59:59.999Z",
    ///   "state": "RAISED",
    ///   "priority": 10,
    ///   "eventText": ["Alarm message"],
    ///   "...": "... (see ActiveAlarm struct for complete structure)"
    /// }]
    /// ```
    /// 
    /// Errors:
    /// - 301 - Syntax error in query string
    /// - 302 - Invalid language
    /// - 303 - Invalid filter language
    pub fn get_active_alarms(
        &self,
        system_names: &[String],
        filter_string: &str,
        filter_language: &str,
        languages: &[String],
    ) -> WinCCResult<Vec<ActiveAlarm>> {
        let variables = json!({
            "systemNames": system_names,
            "filterString": filter_string,
            "filterLanguage": filter_language,
            "languages": languages
        });
        
        let result = self.request(queries::ACTIVE_ALARMS, Some(variables))?;
        let active_alarms: Vec<ActiveAlarm> = serde_json::from_value(result["activeAlarms"].clone())?;
        Ok(active_alarms)
    }
    
    /// Get active alarms with default parameters
    pub fn get_active_alarms_simple(&self) -> WinCCResult<Vec<ActiveAlarm>> {
        self.get_active_alarms(&[], "", "en-US", &["en-US".to_string()])
    }
    
    /// Query logged alarms from the storage system using ChromQueryLanguage filter and time boundaries.
    /// 
    /// Returns: Array of LoggedAlarm objects with comprehensive historical alarm information
    /// 
    /// JSON Structure: (truncated for brevity, see LoggedAlarm struct for full definition)
    /// ```json
    /// [{
    ///   "name": "string",
    ///   "instanceID": 123,
    ///   "alarmGroupID": 456,
    ///   "raiseTime": "2023-12-31T23:59:59.999Z",
    ///   "acknowledgmentTime": "2023-12-31T23:59:59.999Z",
    ///   "state": "RAISED",
    ///   "priority": 10,
    ///   "eventText": ["Alarm message"],
    ///   "hasComments": true,
    ///   "...": "... (see LoggedAlarm struct for complete structure)"
    /// }]
    /// ```
    /// 
    /// Errors:
    /// - 301 - Syntax error in query string
    /// - 302 - Invalid language (or not logged)
    /// - 303 - Invalid filter language (or not logged)
    pub fn get_logged_alarms(
        &self,
        system_names: &[String],
        filter_string: &str,
        filter_language: &str,
        languages: &[String],
        start_time: Option<&str>,
        end_time: Option<&str>,
        max_number_of_results: i32,
    ) -> WinCCResult<Vec<LoggedAlarm>> {
        let mut variables = json!({
            "systemNames": system_names,
            "filterString": filter_string,
            "filterLanguage": filter_language,
            "languages": languages,
            "maxNumberOfResults": max_number_of_results
        });
        
        if let Some(start) = start_time {
            variables["startTime"] = json!(start);
        }
        if let Some(end) = end_time {
            variables["endTime"] = json!(end);
        }
        
        let result = self.request(queries::LOGGED_ALARMS, Some(variables))?;
        let logged_alarms: Vec<LoggedAlarm> = serde_json::from_value(result["loggedAlarms"].clone())?;
        Ok(logged_alarms)
    }
    
    /// Get logged alarms with default parameters
    pub fn get_logged_alarms_simple(&self) -> WinCCResult<Vec<LoggedAlarm>> {
        self.get_logged_alarms(&[], "", "en-US", &["en-US".to_string()], None, None, 0)
    }
    
    /// Logs a user in based on the claim and signed claim from UMC SWAC authentication.
    /// 
    /// Returns: Session object containing user info, token, and expiry timestamp
    /// 
    /// JSON Structure: Same as login() method
    /// 
    /// Errors:
    /// - 101 - Incorrect credentials provided
    /// - 103 - Nonce expired
    pub fn login_swac(&mut self, claim: &str, signed_claim: &str) -> WinCCResult<Session> {
        let variables = json!({
            "claim": claim,
            "signedClaim": signed_claim
        });
        
        let result = self.request(mutations::LOGIN_SWAC, Some(variables))?;
        let login_result: Session = serde_json::from_value(result["loginSWAC"].clone())?;
        
        if let Some(ref token) = login_result.token {
            self.set_token(token);
        }
        
        if login_result.token.is_some() {
            Ok(login_result)
        } else {
            let error_msg = login_result.error
                .as_ref()
                .and_then(|e| e.description.as_ref())
                .map_or("Unknown error", |v| v);
            Err(WinCCError::LoginError(format!("SWAC login failed: {}", error_msg)))
        }
    }
    
    /// Extends the user's current session expiry by the 'session expires' value from the identity provider (UMC).
    /// 
    /// Returns: Session object with updated expiry timestamp
    /// 
    /// JSON Structure: Same as login() method
    pub fn extend_session(&mut self) -> WinCCResult<Session> {
        let result = self.request(mutations::EXTEND_SESSION, None)?;
        let extend_result: Session = serde_json::from_value(result["extendSession"].clone())?;
        
        if let Some(ref token) = extend_result.token {
            self.set_token(token);
        }
        
        if extend_result.token.is_some() {
            Ok(extend_result)
        } else {
            let error_msg = extend_result.error
                .as_ref()
                .and_then(|e| e.description.as_ref())
                .map_or("Unknown error", |v| v);
            Err(WinCCError::SessionError(format!("Session extension failed: {}", error_msg)))
        }
    }
    
    /// Logs out the current user. If all_sessions is true, all sessions of the current user will be terminated.
    /// 
    /// Returns: Boolean indicating success
    /// 
    /// JSON Structure: 
    /// ```json
    /// true
    /// ```
    pub fn logout(&mut self, all_sessions: bool) -> WinCCResult<bool> {
        let variables = json!({
            "allSessions": all_sessions
        });
        
        let result = self.request(mutations::LOGOUT, Some(variables))?;
        
        self.clear_token();
        
        let logout_result = result["logout"].as_bool().unwrap_or(false);
        Ok(logout_result)
    }
    
    /// Logout current session only
    pub fn logout_simple(&mut self) -> WinCCResult<bool> {
        self.logout(false)
    }
    
    /// Updates tags based on the provided TagValueInput list. Uses fallback timestamp and quality if not specified per tag.
    /// 
    /// Returns: Array of WriteTagValuesResult objects with tag name and error information
    /// 
    /// JSON Structure: 
    /// ```json
    /// [{
    ///   "name": "string",
    ///   "error": {
    ///     "code": "string",
    ///     "description": "string"
    ///   }
    /// }]
    /// ```
    /// 
    /// Errors:
    /// - 2 - Cannot resolve provided name
    /// - 201 - Cannot convert provided value to data type
    /// - 202 - Only leaf elements of a Structure Tag can be addressed
    pub fn write_tag_values(
        &self,
        input: &[TagValueInput],
        timestamp: Option<&str>,
        quality: Option<&QualityInput>,
    ) -> WinCCResult<Vec<WriteTagValuesResult>> {
        let mut variables = json!({
            "input": input
        });
        
        if let Some(ts) = timestamp {
            variables["timestamp"] = json!(ts);
        }
        if let Some(q) = quality {
            variables["quality"] = json!(q);
        }
        
        let result = self.request(mutations::WRITE_TAG_VALUES, Some(variables))?;
        let write_results: Vec<WriteTagValuesResult> = serde_json::from_value(result["writeTagValues"].clone())?;
        Ok(write_results)
    }
    
    /// Write tag values without timestamp and quality
    pub fn write_tag_values_simple(&self, input: &[TagValueInput]) -> WinCCResult<Vec<WriteTagValuesResult>> {
        self.write_tag_values(input, None, None)
    }
    
    /// Acknowledge one or more alarms. Each alarm identifier must have the alarm name and optionally an instanceID.
    /// 
    /// Returns: Array of ActiveAlarmMutationResult objects with alarm name, instance ID, and error information
    /// 
    /// JSON Structure: 
    /// ```json
    /// [{
    ///   "alarmName": "string",
    ///   "alarmInstanceID": 123,
    ///   "error": {
    ///     "code": "string",
    ///     "description": "string"
    ///   }
    /// }]
    /// ```
    /// 
    /// Errors:
    /// - 2 - Cannot resolve provided name
    /// - 304 - Invalid object state
    /// - 305 - Alarm cannot be acknowledged in current state
    pub fn acknowledge_alarms(&self, input: &[AlarmIdentifierInput]) -> WinCCResult<Vec<ActiveAlarmMutationResult>> {
        let variables = json!({
            "input": input
        });
        
        let result = self.request(mutations::ACKNOWLEDGE_ALARMS, Some(variables))?;
        let ack_results: Vec<ActiveAlarmMutationResult> = serde_json::from_value(result["acknowledgeAlarms"].clone())?;
        Ok(ack_results)
    }
    
    /// Reset one or more alarms. Each alarm identifier must have the alarm name and optionally an instanceID.
    /// 
    /// Returns: Array of ActiveAlarmMutationResult objects with alarm name, instance ID, and error information
    /// 
    /// JSON Structure: Same as acknowledge_alarms()
    /// 
    /// Errors:
    /// - 2 - Cannot resolve provided name
    /// - 304 - Invalid object state
    /// - 305 - Alarm cannot be reset in current state
    pub fn reset_alarms(&self, input: &[AlarmIdentifierInput]) -> WinCCResult<Vec<ActiveAlarmMutationResult>> {
        let variables = json!({
            "input": input
        });
        
        let result = self.request(mutations::RESET_ALARMS, Some(variables))?;
        let reset_results: Vec<ActiveAlarmMutationResult> = serde_json::from_value(result["resetAlarms"].clone())?;
        Ok(reset_results)
    }
    
    /// Disable the creation of new alarm instances for one or more alarms.
    /// 
    /// Returns: Array of AlarmMutationResult objects with alarm name and error information
    /// 
    /// JSON Structure: 
    /// ```json
    /// [{
    ///   "alarmName": "string",
    ///   "error": {
    ///     "code": "string",
    ///     "description": "string"
    ///   }
    /// }]
    /// ```
    /// 
    /// Errors:
    /// - 2 - Cannot resolve provided name
    pub fn disable_alarms(&self, names: &[String]) -> WinCCResult<Vec<AlarmMutationResult>> {
        let variables = json!({
            "names": names
        });
        
        let result = self.request(mutations::DISABLE_ALARMS, Some(variables))?;
        let disable_results: Vec<AlarmMutationResult> = serde_json::from_value(result["disableAlarms"].clone())?;
        Ok(disable_results)
    }
    
    /// Enable the creation of new alarm instances for one or more alarms.
    /// 
    /// Returns: Array of AlarmMutationResult objects with alarm name and error information
    /// 
    /// JSON Structure: Same as disable_alarms()
    /// 
    /// Errors:
    /// - 2 - Cannot resolve provided name
    pub fn enable_alarms(&self, names: &[String]) -> WinCCResult<Vec<AlarmMutationResult>> {
        let variables = json!({
            "names": names
        });
        
        let result = self.request(mutations::ENABLE_ALARMS, Some(variables))?;
        let enable_results: Vec<AlarmMutationResult> = serde_json::from_value(result["enableAlarms"].clone())?;
        Ok(enable_results)
    }
    
    /// Shelve all active alarm instances of the provided configured alarms. 
    /// Uses runtime's configured shelving timeout if not specified.
    /// 
    /// Returns: Array of AlarmMutationResult objects with alarm name and error information
    /// 
    /// JSON Structure: Same as disable_alarms()
    /// 
    /// Errors:
    /// - 2 - Cannot resolve provided name
    pub fn shelve_alarms(&self, names: &[String], shelve_timeout: Option<&str>) -> WinCCResult<Vec<AlarmMutationResult>> {
        let mut variables = json!({
            "names": names
        });
        
        if let Some(timeout) = shelve_timeout {
            variables["shelveTimeout"] = json!(timeout);
        }
        
        let result = self.request(mutations::SHELVE_ALARMS, Some(variables))?;
        let shelve_results: Vec<AlarmMutationResult> = serde_json::from_value(result["shelveAlarms"].clone())?;
        Ok(shelve_results)
    }
    
    /// Shelve alarms with default timeout
    pub fn shelve_alarms_simple(&self, names: &[String]) -> WinCCResult<Vec<AlarmMutationResult>> {
        self.shelve_alarms(names, None)
    }
    
    /// Revert the Shelve action for the provided configured alarms. 
    /// Unshelving causes a notification for all concerned alarm instances.
    /// 
    /// Returns: Array of AlarmMutationResult objects with alarm name and error information
    /// 
    /// JSON Structure: Same as disable_alarms()
    /// 
    /// Errors:
    /// - 2 - Cannot resolve provided name
    pub fn unshelve_alarms(&self, names: &[String]) -> WinCCResult<Vec<AlarmMutationResult>> {
        let variables = json!({
            "names": names
        });
        
        let result = self.request(mutations::UNSHELVE_ALARMS, Some(variables))?;
        let unshelve_results: Vec<AlarmMutationResult> = serde_json::from_value(result["unshelveAlarms"].clone())?;
        Ok(unshelve_results)
    }

    // WebSocket Subscription Methods

    /// Initialize WebSocket connection for subscriptions
    /// This must be called before using any subscription methods
    pub async fn connect_ws(&mut self) -> WinCCResult<()> {
        if let Some(ws_url) = &self.ws_url {
            let token = self.token.clone().unwrap_or_default();
            let mut ws_client = GraphQLWSClient::new(ws_url.clone(), token);
            ws_client.connect().await?;
            self.ws_client = Some(ws_client);
            Ok(())
        } else {
            Err(WinCCError::InvalidParameter("WebSocket URL not configured".to_string()))
        }
    }

    /// Disconnect WebSocket connection
    pub async fn disconnect_ws(&mut self) {
        if let Some(mut ws_client) = self.ws_client.take() {
            ws_client.disconnect().await;
        }
    }

    /// Subscribe to tag values for the tags based on the provided names list.
    /// Notifications contain reason (Added, Modified, Removed, Removed (Name changed)).
    /// 
    /// Returns: Subscription object with unsubscribe method
    /// 
    /// Callback receives: TagValueNotification object
    /// ```json
    /// {
    ///   "name": "string",
    ///   "value": {
    ///     "value": "variant",
    ///     "timestamp": "timestamp",
    ///     "quality": "Quality"
    ///   },
    ///   "error": {
    ///     "code": "string",
    ///     "description": "string"
    ///   },
    ///   "notificationReason": "string"
    /// }
    /// ```
    /// 
    /// Errors:
    /// - 2 - Cannot resolve provided name
    /// - 202 - Only leaf elements of a Structure Tag can be addressed
    pub async fn subscribe_to_tag_values(
        &self,
        names: Vec<String>,
        callbacks: SubscriptionCallbacks,
    ) -> WinCCResult<Subscription> {
        if let Some(ws_client) = &self.ws_client {
            let mut variables = HashMap::new();
            variables.insert("names".to_string(), json!(names));
            
            ws_client
                .subscribe(subscriptions::TAG_VALUES.to_string(), variables, callbacks)
                .await
        } else {
            Err(WinCCError::OperationFailed("WebSocket not connected".to_string()))
        }
    }

    /// Subscribe for active alarms matching the given filters.
    /// Notifications contain reason (Added, Modified, Removed).
    /// 
    /// Returns: Subscription object with unsubscribe method
    /// 
    /// Callback receives: ActiveAlarmNotification object with all ActiveAlarm fields plus notificationReason
    /// 
    /// Errors:
    /// - 301 - Syntax error in query string
    /// - 302 - Invalid language
    /// - 303 - Invalid filter language
    pub async fn subscribe_to_active_alarms(
        &self,
        system_names: Vec<String>,
        filter_string: String,
        filter_language: String,
        languages: Vec<String>,
        callbacks: SubscriptionCallbacks,
    ) -> WinCCResult<Subscription> {
        if let Some(ws_client) = &self.ws_client {
            let mut variables = HashMap::new();
            variables.insert("systemNames".to_string(), json!(system_names));
            variables.insert("filterString".to_string(), json!(filter_string));
            variables.insert("filterLanguage".to_string(), json!(filter_language));
            variables.insert("languages".to_string(), json!(languages));
            
            ws_client
                .subscribe(subscriptions::ACTIVE_ALARMS.to_string(), variables, callbacks)
                .await
        } else {
            Err(WinCCError::OperationFailed("WebSocket not connected".to_string()))
        }
    }

    /// Subscribe for active alarms with default filters
    pub async fn subscribe_to_active_alarms_simple(
        &self,
        callbacks: SubscriptionCallbacks,
    ) -> WinCCResult<Subscription> {
        self.subscribe_to_active_alarms(
            vec![],
            String::new(),
            "en-US".to_string(),
            vec!["en-US".to_string()],
            callbacks,
        ).await
    }

    /// Subscribe to redundancy state notifications.
    /// Notifications contain information about the active/passive state of the system on state changes.
    /// 
    /// Returns: Subscription object with unsubscribe method
    /// 
    /// Callback receives: ReduStateNotification object
    /// ```json
    /// {
    ///   "value": {
    ///     "value": "ReduState (ACTIVE | PASSIVE)",
    ///     "timestamp": "timestamp"
    ///   },
    ///   "notificationReason": "string"
    /// }
    /// ```
    pub async fn subscribe_to_redu_state(
        &self,
        callbacks: SubscriptionCallbacks,
    ) -> WinCCResult<Subscription> {
        if let Some(ws_client) = &self.ws_client {
            let variables = HashMap::new();
            
            ws_client
                .subscribe(subscriptions::REDU_STATE.to_string(), variables, callbacks)
                .await
        } else {
            Err(WinCCError::OperationFailed("WebSocket not connected".to_string()))
        }
    }
}