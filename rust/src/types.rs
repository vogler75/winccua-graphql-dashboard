//! Type definitions for WinCC Unified GraphQL API

use serde::{Deserialize, Serialize};
use serde_json::Value;

/// Session information containing user details and authentication token
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Session {
    pub user: Option<User>,
    pub token: Option<String>,
    pub expires: Option<String>,
    pub error: Option<ErrorInfo>,
}

/// User information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: Option<String>,
    pub name: Option<String>,
    pub groups: Option<Vec<UserGroup>>,
    #[serde(rename = "fullName")]
    pub full_name: Option<String>,
    pub language: Option<String>,
    #[serde(rename = "autoLogoffSec")]
    pub auto_logoff_sec: Option<i32>,
}

/// User group information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserGroup {
    pub id: Option<String>,
    pub name: Option<String>,
}

/// Error information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorInfo {
    pub code: Option<String>,
    pub description: Option<String>,
}

/// Nonce for SWAC authentication
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Nonce {
    pub value: Option<String>,
    #[serde(rename = "validFor")]
    pub valid_for: Option<i32>,
}

/// Tag value result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagValueResult {
    pub name: Option<String>,
    pub value: Option<TagValue>,
    pub error: Option<ErrorInfo>,
}

/// Tag value with timestamp and quality
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagValue {
    pub value: Option<Value>,
    pub timestamp: Option<String>,
    pub quality: Option<Quality>,
}

/// Quality information for tag values
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Quality {
    pub quality: Option<String>,
    #[serde(rename = "subStatus")]
    pub sub_status: Option<String>,
    pub limit: Option<String>,
    #[serde(rename = "extendedSubStatus")]
    pub extended_sub_status: Option<String>,
    #[serde(rename = "sourceQuality")]
    pub source_quality: Option<bool>,
    #[serde(rename = "sourceTime")]
    pub source_time: Option<bool>,
    #[serde(rename = "timeCorrected")]
    pub time_corrected: Option<bool>,
}

/// Input for writing tag values
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagValueInput {
    pub name: String,
    pub value: Value,
    pub timestamp: Option<String>,
    pub quality: Option<QualityInput>,
}

/// Quality input for writing tag values
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityInput {
    pub quality: String,
    #[serde(rename = "subStatus")]
    pub sub_status: Option<String>,
}

/// Result of tag write operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WriteTagValuesResult {
    pub name: Option<String>,
    pub error: Option<ErrorInfo>,
}

/// Browse result for tags, alarms, etc.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BrowseTagsResult {
    pub name: Option<String>,
    #[serde(rename = "displayName")]
    pub display_name: Option<String>,
    #[serde(rename = "objectType")]
    pub object_type: Option<String>,
    #[serde(rename = "dataType")]
    pub data_type: Option<String>,
}

/// Logged tag values result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoggedTagValuesResult {
    #[serde(rename = "loggingTagName")]
    pub logging_tag_name: Option<String>,
    pub error: Option<ErrorInfo>,
    pub values: Option<Vec<LoggedValue>>,
}

/// Individual logged value
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoggedValue {
    pub value: Option<TagValue>,
    pub flags: Option<Vec<String>>,
}

/// Active alarm information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActiveAlarm {
    pub name: Option<String>,
    #[serde(rename = "instanceID")]
    pub instance_id: Option<i32>,
    #[serde(rename = "alarmGroupID")]
    pub alarm_group_id: Option<i32>,
    #[serde(rename = "raiseTime")]
    pub raise_time: Option<String>,
    #[serde(rename = "acknowledgmentTime")]
    pub acknowledgment_time: Option<String>,
    #[serde(rename = "clearTime")]
    pub clear_time: Option<String>,
    #[serde(rename = "resetTime")]
    pub reset_time: Option<String>,
    #[serde(rename = "modificationTime")]
    pub modification_time: Option<String>,
    pub state: Option<String>,
    #[serde(rename = "textColor")]
    pub text_color: Option<String>,
    #[serde(rename = "backColor")]
    pub back_color: Option<String>,
    pub flashing: Option<bool>,
    pub languages: Option<Vec<String>>,
    #[serde(rename = "alarmClassName")]
    pub alarm_class_name: Option<String>,
    #[serde(rename = "alarmClassSymbol")]
    pub alarm_class_symbol: Option<Vec<String>>,
    #[serde(rename = "alarmClassID")]
    pub alarm_class_id: Option<i32>,
    #[serde(rename = "stateMachine")]
    pub state_machine: Option<String>,
    pub priority: Option<i32>,
    #[serde(rename = "alarmParameterValues")]
    pub alarm_parameter_values: Option<Vec<Value>>,
    #[serde(rename = "alarmType")]
    pub alarm_type: Option<Vec<String>>,
    #[serde(rename = "eventText")]
    pub event_text: Option<Vec<String>>,
    #[serde(rename = "infoText")]
    pub info_text: Option<Vec<String>>,
    #[serde(rename = "alarmText1")]
    pub alarm_text1: Option<Vec<String>>,
    #[serde(rename = "alarmText2")]
    pub alarm_text2: Option<Vec<String>>,
    #[serde(rename = "alarmText3")]
    pub alarm_text3: Option<Vec<String>>,
    #[serde(rename = "alarmText4")]
    pub alarm_text4: Option<Vec<String>>,
    #[serde(rename = "alarmText5")]
    pub alarm_text5: Option<Vec<String>>,
    #[serde(rename = "alarmText6")]
    pub alarm_text6: Option<Vec<String>>,
    #[serde(rename = "alarmText7")]
    pub alarm_text7: Option<Vec<String>>,
    #[serde(rename = "alarmText8")]
    pub alarm_text8: Option<Vec<String>>,
    #[serde(rename = "alarmText9")]
    pub alarm_text9: Option<Vec<String>>,
    #[serde(rename = "stateText")]
    pub state_text: Option<Vec<String>>,
    pub origin: Option<String>,
    pub area: Option<String>,
    #[serde(rename = "changeReason")]
    pub change_reason: Option<Vec<String>>,
    #[serde(rename = "connectionName")]
    pub connection_name: Option<String>,
    #[serde(rename = "valueLimit")]
    pub value_limit: Option<Value>,
    #[serde(rename = "sourceType")]
    pub source_type: Option<String>,
    #[serde(rename = "suppressionState")]
    pub suppression_state: Option<String>,
    #[serde(rename = "hostName")]
    pub host_name: Option<String>,
    #[serde(rename = "userName")]
    pub user_name: Option<String>,
    pub value: Option<Value>,
    #[serde(rename = "valueQuality")]
    pub value_quality: Option<Quality>,
    pub quality: Option<Quality>,
    #[serde(rename = "invalidFlags")]
    pub invalid_flags: Option<Value>,
    #[serde(rename = "deadBand")]
    pub dead_band: Option<Value>,
    pub producer: Option<String>,
    pub duration: Option<String>,
    #[serde(rename = "durationIso")]
    pub duration_iso: Option<String>,
    #[serde(rename = "sourceID")]
    pub source_id: Option<String>,
    #[serde(rename = "systemSeverity")]
    pub system_severity: Option<i32>,
    #[serde(rename = "loopInAlarm")]
    pub loop_in_alarm: Option<String>,
    #[serde(rename = "loopInAlarmParameterValues")]
    pub loop_in_alarm_parameter_values: Option<Value>,
    pub path: Option<String>,
    #[serde(rename = "userResponse")]
    pub user_response: Option<String>,
}

/// Logged alarm information (similar to ActiveAlarm but for historical data)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoggedAlarm {
    pub name: Option<String>,
    #[serde(rename = "instanceID")]
    pub instance_id: Option<i32>,
    #[serde(rename = "alarmGroupID")]
    pub alarm_group_id: Option<i32>,
    #[serde(rename = "raiseTime")]
    pub raise_time: Option<String>,
    #[serde(rename = "acknowledgmentTime")]
    pub acknowledgment_time: Option<String>,
    #[serde(rename = "clearTime")]
    pub clear_time: Option<String>,
    #[serde(rename = "resetTime")]
    pub reset_time: Option<String>,
    #[serde(rename = "modificationTime")]
    pub modification_time: Option<String>,
    pub state: Option<String>,
    #[serde(rename = "textColor")]
    pub text_color: Option<String>,
    #[serde(rename = "backColor")]
    pub back_color: Option<String>,
    pub languages: Option<Vec<String>>,
    #[serde(rename = "alarmClassName")]
    pub alarm_class_name: Option<String>,
    #[serde(rename = "alarmClassSymbol")]
    pub alarm_class_symbol: Option<Vec<String>>,
    #[serde(rename = "alarmClassID")]
    pub alarm_class_id: Option<i32>,
    #[serde(rename = "stateMachine")]
    pub state_machine: Option<String>,
    pub priority: Option<i32>,
    #[serde(rename = "alarmParameterValues")]
    pub alarm_parameter_values: Option<Vec<Value>>,
    #[serde(rename = "alarmType")]
    pub alarm_type: Option<Vec<String>>,
    #[serde(rename = "eventText")]
    pub event_text: Option<Vec<String>>,
    #[serde(rename = "infoText")]
    pub info_text: Option<Vec<String>>,
    #[serde(rename = "alarmText1")]
    pub alarm_text1: Option<Vec<String>>,
    #[serde(rename = "alarmText2")]
    pub alarm_text2: Option<Vec<String>>,
    #[serde(rename = "alarmText3")]
    pub alarm_text3: Option<Vec<String>>,
    #[serde(rename = "alarmText4")]
    pub alarm_text4: Option<Vec<String>>,
    #[serde(rename = "alarmText5")]
    pub alarm_text5: Option<Vec<String>>,
    #[serde(rename = "alarmText6")]
    pub alarm_text6: Option<Vec<String>>,
    #[serde(rename = "alarmText7")]
    pub alarm_text7: Option<Vec<String>>,
    #[serde(rename = "alarmText8")]
    pub alarm_text8: Option<Vec<String>>,
    #[serde(rename = "alarmText9")]
    pub alarm_text9: Option<Vec<String>>,
    #[serde(rename = "stateText")]
    pub state_text: Option<Vec<String>>,
    pub origin: Option<String>,
    pub area: Option<String>,
    #[serde(rename = "changeReason")]
    pub change_reason: Option<Vec<String>>,
    #[serde(rename = "valueLimit")]
    pub value_limit: Option<Value>,
    #[serde(rename = "sourceType")]
    pub source_type: Option<String>,
    #[serde(rename = "suppressionState")]
    pub suppression_state: Option<String>,
    #[serde(rename = "hostName")]
    pub host_name: Option<String>,
    #[serde(rename = "userName")]
    pub user_name: Option<String>,
    pub value: Option<Value>,
    #[serde(rename = "valueQuality")]
    pub value_quality: Option<Quality>,
    pub quality: Option<Quality>,
    #[serde(rename = "invalidFlags")]
    pub invalid_flags: Option<Value>,
    pub deadband: Option<Value>,
    pub producer: Option<String>,
    pub duration: Option<String>,
    #[serde(rename = "durationIso")]
    pub duration_iso: Option<String>,
    #[serde(rename = "hasComments")]
    pub has_comments: Option<bool>,
}

/// Input for alarm identifier operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AlarmIdentifierInput {
    pub name: String,
    #[serde(rename = "instanceID")]
    pub instance_id: Option<i32>,
}

/// Result of alarm mutation operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AlarmMutationResult {
    #[serde(rename = "alarmName")]
    pub alarm_name: Option<String>,
    pub error: Option<ErrorInfo>,
}

/// Result of active alarm mutation operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActiveAlarmMutationResult {
    #[serde(rename = "alarmName")]
    pub alarm_name: Option<String>,
    #[serde(rename = "alarmInstanceID")]
    pub alarm_instance_id: Option<i32>,
    pub error: Option<ErrorInfo>,
}

/// Tag value notification for subscriptions
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagValueNotification {
    pub name: Option<String>,
    pub value: Option<TagValue>,
    pub error: Option<ErrorInfo>,
    #[serde(rename = "notificationReason")]
    pub notification_reason: Option<String>,
}

/// Active alarm notification for subscriptions
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActiveAlarmNotification {
    #[serde(flatten)]
    pub alarm: ActiveAlarm,
    #[serde(rename = "notificationReason")]
    pub notification_reason: Option<String>,
}

/// Redu state notification
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReduStateNotification {
    pub value: Option<ReduStateValue>,
    #[serde(rename = "notificationReason")]
    pub notification_reason: Option<String>,
}

/// Redu state value
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReduStateValue {
    pub value: Option<String>, // "ACTIVE" or "PASSIVE"
    pub timestamp: Option<String>,
}