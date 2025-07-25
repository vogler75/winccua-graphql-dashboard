package winccunified

import (
	"time"
)

// Error represents a WinCC Unified error
type Error struct {
	Code        string `json:"code"`
	Description string `json:"description"`
}

// TagResult represents the result of reading a tag
type TagResult struct {
	Name      string    `json:"name"`
	Value     string    `json:"value"`
	Quality   string    `json:"quality"`
	Timestamp time.Time `json:"timestamp"`
	Error     *Error    `json:"error,omitempty"`
}

// TagWrite represents a tag to write
type TagWrite struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}

// WriteResult represents the result of writing a tag
type WriteResult struct {
	Name  string `json:"name"`
	Error *Error `json:"error,omitempty"`
}

// BrowseItem represents an item in the browse hierarchy
type BrowseItem struct {
	Name          string `json:"name"`
	Type          string `json:"type"`
	Address       string `json:"address"`
	ChildrenCount int    `json:"childrenCount"`
}

// BrowseResult represents the result of browsing
type BrowseResult struct {
	Items []BrowseItem `json:"items"`
	Error *Error       `json:"error,omitempty"`
}

// Alarm represents an alarm in the system
type Alarm struct {
	ID        string    `json:"id"`
	State     string    `json:"state"`
	Name      string    `json:"name"`
	Text      string    `json:"text"`
	ClassName string    `json:"className"`
	ComeTime  time.Time `json:"comeTime"`
	GoTime    *time.Time `json:"goTime,omitempty"`
	AckTime   *time.Time `json:"ackTime,omitempty"`
	Error     *Error    `json:"error,omitempty"`
}

// LoginResult represents the result of a login operation
type LoginResult struct {
	Token     string `json:"token"`
	SessionID string `json:"sessionId"`
	Error     *Error `json:"error,omitempty"`
}

// HistoricalValue represents a historical tag value
type HistoricalValue struct {
	Value     string    `json:"value"`
	Quality   string    `json:"quality"`
	Timestamp time.Time `json:"timestamp"`
}

// HistoricalResult represents the result of reading historical values
type HistoricalResult struct {
	Name   string            `json:"name"`
	Values []HistoricalValue `json:"values"`
	Error  *Error            `json:"error,omitempty"`
}

// RedundancyState represents the redundancy state of the system
type RedundancyState struct {
	IsMaster bool   `json:"isMaster"`
	State    string `json:"state"`
	Error    *Error `json:"error,omitempty"`
}

// SubscriptionMessage represents a message from a subscription
type SubscriptionMessage struct {
	Type  string      `json:"type"`
	Data  interface{} `json:"data"`
	Error *Error      `json:"error,omitempty"`
}