// Package types defines data structures for WinCC Unified GraphQL API
package types

import (
	"encoding/json"
)

// WinCCError represents an error response from WinCC Unified
type WinCCError struct {
	Code        *string `json:"code,omitempty"`
	Description *string `json:"description,omitempty"`
}

func (e WinCCError) Error() string {
	code := "Unknown"
	desc := "No description"
	if e.Code != nil {
		code = *e.Code
	}
	if e.Description != nil {
		desc = *e.Description
	}
	return code + ": " + desc
}

// User represents a user
type User struct {
	ID           *string  `json:"id,omitempty"`
	Name         *string  `json:"name,omitempty"`
	Groups       []*Group `json:"groups,omitempty"`
	FullName     *string  `json:"fullName,omitempty"`
	Language     *string  `json:"language,omitempty"`
	AutoLogoffSec *int    `json:"autoLogoffSec,omitempty"`
}

// Group represents a user group
type Group struct {
	ID   *string `json:"id,omitempty"`
	Name *string `json:"name,omitempty"`
}

// Session represents a user session
type Session struct {
	Token   *string     `json:"token,omitempty"`
	User    *User       `json:"user,omitempty"`
	Expires *string     `json:"expires,omitempty"`
	Error   *WinCCError `json:"error,omitempty"`
}

// Quality represents tag quality information
type Quality struct {
	Quality             *string `json:"quality,omitempty"`
	SubStatus           *string `json:"subStatus,omitempty"`
	Limit               *string `json:"limit,omitempty"`
	ExtendedSubStatus   *string `json:"extendedSubStatus,omitempty"`
	SourceQuality       *bool   `json:"sourceQuality,omitempty"`
	SourceTime          *bool   `json:"sourceTime,omitempty"`
	TimeCorrected       *bool   `json:"timeCorrected,omitempty"`
}

// TagValueData represents the value part of a tag
type TagValueData struct {
	Value     interface{} `json:"value,omitempty"`
	Timestamp *string     `json:"timestamp,omitempty"`
	Quality   *Quality    `json:"quality,omitempty"`
}

// TagValue represents a tag's value and metadata
type TagValue struct {
	Name  *string       `json:"name,omitempty"`
	Value *TagValueData `json:"value,omitempty"`
	Error *WinCCError   `json:"error,omitempty"`
}

// TagValueInput represents input for writing tag values
type TagValueInput struct {
	Name      string      `json:"name"`
	Value     interface{} `json:"value"`
	Timestamp *string     `json:"timestamp,omitempty"`
	Quality   *string     `json:"quality,omitempty"`
}

// WriteTagResult represents the result of a tag write operation
type WriteTagResult struct {
	Name  *string     `json:"name,omitempty"`
	Error *WinCCError `json:"error,omitempty"`
}

// BrowseResult represents a browsing result
type BrowseResult struct {
	Name        *string `json:"name,omitempty"`
	DisplayName *string `json:"displayName,omitempty"`
	ObjectType  *string `json:"objectType,omitempty"`
	DataType    *string `json:"dataType,omitempty"`
}

// Alarm represents an alarm
type Alarm struct {
	Name      *string `json:"name,omitempty"`
	Priority  *int    `json:"priority,omitempty"`
	State     *string `json:"state,omitempty"`
	EventText []string `json:"eventText,omitempty"`
}

// AlarmIdentifierInput represents input for alarm operations
type AlarmIdentifierInput struct {
	Name       string `json:"name"`
	InstanceID *int   `json:"instanceId,omitempty"`
}

// AlarmOperationResult represents the result of alarm operations
type AlarmOperationResult struct {
	AlarmName       *string     `json:"alarmName,omitempty"`
	AlarmInstanceID *int        `json:"alarmInstanceID,omitempty"`
	Error           *WinCCError `json:"error,omitempty"`
}

// LoggedTagValue represents logged tag values
type LoggedTagValue struct {
	LoggingTagName *string           `json:"loggingTagName,omitempty"`
	Values         []*TagValueData   `json:"values,omitempty"`
	Error          *WinCCError       `json:"error,omitempty"`
}

// NotificationReason represents the reason for a subscription notification
type NotificationReason string

const (
	NotificationInitial NotificationReason = "Initial"
	NotificationUpdate  NotificationReason = "Update"
)

// SubscriptionData represents data received from subscriptions
type SubscriptionData struct {
	Type    string          `json:"type"`
	ID      string          `json:"id,omitempty"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

// GraphQLRequest represents a GraphQL request
type GraphQLRequest struct {
	Query     string                 `json:"query"`
	Variables map[string]interface{} `json:"variables,omitempty"`
}

// GraphQLResponse represents a GraphQL response
type GraphQLResponse struct {
	Data   json.RawMessage   `json:"data,omitempty"`
	Errors []GraphQLError    `json:"errors,omitempty"`
}

// GraphQLError represents a GraphQL error
type GraphQLError struct {
	Message   string                 `json:"message"`
	Path      []interface{}          `json:"path,omitempty"`
	Locations []GraphQLErrorLocation `json:"locations,omitempty"`
}

// GraphQLErrorLocation represents the location of a GraphQL error
type GraphQLErrorLocation struct {
	Line   int `json:"line"`
	Column int `json:"column"`
}