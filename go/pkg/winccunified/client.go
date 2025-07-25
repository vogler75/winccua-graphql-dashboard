package winccunified

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/siemens/winccua-graphql-libs/go/internal/graphql"
)

// Client represents a WinCC Unified client
type Client struct {
	baseURL       string
	username      string
	password      string
	graphqlClient *graphql.Client
	wsClient      *graphql.WebSocketClient
	
	token     string
	sessionID string
	mu        sync.RWMutex
	
	autoExtendSession bool
	stopExtend        chan struct{}
}

// NewClient creates a new WinCC Unified client
func NewClient(baseURL, username, password string) *Client {
	graphqlURL := strings.TrimRight(baseURL, "/") + "/graphql"
	
	return &Client{
		baseURL:       baseURL,
		username:      username,
		password:      password,
		graphqlClient: graphql.NewClient(graphqlURL),
		autoExtendSession: true,
		stopExtend:    make(chan struct{}),
	}
}

// Connect authenticates and establishes a session
func (c *Client) Connect(ctx context.Context) error {
	variables := map[string]interface{}{
		"username": c.username,
		"password": c.password,
	}

	var result struct {
		Login LoginResult `json:"Login"`
	}

	if err := c.graphqlClient.Execute(ctx, loginMutation, variables, &result); err != nil {
		return fmt.Errorf("login failed: %w", err)
	}

	if result.Login.Error != nil {
		return fmt.Errorf("login error: %s - %s", result.Login.Error.Code, result.Login.Error.Description)
	}

	c.mu.Lock()
	c.token = result.Login.Token
	c.sessionID = result.Login.SessionID
	c.mu.Unlock()

	// Set authorization header
	c.graphqlClient.SetHeader("Authorization", "Bearer "+result.Login.Token)

	// Start session extension if enabled
	if c.autoExtendSession {
		go c.sessionExtender()
	}

	return nil
}

// Disconnect terminates the session
func (c *Client) Disconnect(ctx context.Context) error {
	c.mu.RLock()
	sessionID := c.sessionID
	c.mu.RUnlock()

	if sessionID == "" {
		return nil
	}

	// Stop session extension
	if c.autoExtendSession {
		close(c.stopExtend)
	}

	// Close WebSocket if connected
	if c.wsClient != nil {
		c.wsClient.Close()
	}

	variables := map[string]interface{}{
		"sessionId": sessionID,
	}

	var result struct {
		Logout struct {
			Error *Error `json:"error"`
		} `json:"Logout"`
	}

	if err := c.graphqlClient.Execute(ctx, logoutMutation, variables, &result); err != nil {
		return fmt.Errorf("logout failed: %w", err)
	}

	if result.Logout.Error != nil {
		return fmt.Errorf("logout error: %s - %s", result.Logout.Error.Code, result.Logout.Error.Description)
	}

	c.mu.Lock()
	c.token = ""
	c.sessionID = ""
	c.mu.Unlock()

	return nil
}

// ReadTags reads the current values of the specified tags
func (c *Client) ReadTags(ctx context.Context, tagNames []string) ([]TagResult, error) {
	variables := map[string]interface{}{
		"tags": tagNames,
	}

	var result struct {
		ReadTags []TagResult `json:"ReadTags"`
	}

	if err := c.graphqlClient.Execute(ctx, readTagsQuery, variables, &result); err != nil {
		return nil, fmt.Errorf("read tags failed: %w", err)
	}

	return result.ReadTags, nil
}

// WriteTags writes values to the specified tags
func (c *Client) WriteTags(ctx context.Context, tags []TagWrite) ([]WriteResult, error) {
	variables := map[string]interface{}{
		"tags": tags,
	}

	var result struct {
		WriteTags []WriteResult `json:"WriteTags"`
	}

	if err := c.graphqlClient.Execute(ctx, writeTagsMutation, variables, &result); err != nil {
		return nil, fmt.Errorf("write tags failed: %w", err)
	}

	return result.WriteTags, nil
}

// Browse returns the items at the specified path
func (c *Client) Browse(ctx context.Context, path string) (*BrowseResult, error) {
	variables := make(map[string]interface{})
	if path != "" {
		variables["path"] = path
	}

	var result struct {
		Browse BrowseResult `json:"Browse"`
	}

	if err := c.graphqlClient.Execute(ctx, browseQuery, variables, &result); err != nil {
		return nil, fmt.Errorf("browse failed: %w", err)
	}

	return &result.Browse, nil
}

// GetActiveAlarms returns all currently active alarms
func (c *Client) GetActiveAlarms(ctx context.Context) ([]Alarm, error) {
	var result struct {
		GetActiveAlarms []Alarm `json:"GetActiveAlarms"`
	}

	if err := c.graphqlClient.Execute(ctx, getActiveAlarmsQuery, nil, &result); err != nil {
		return nil, fmt.Errorf("get active alarms failed: %w", err)
	}

	return result.GetActiveAlarms, nil
}

// GetAlarmHistory returns alarms within the specified time range
func (c *Client) GetAlarmHistory(ctx context.Context, startTime, endTime time.Time) ([]Alarm, error) {
	variables := map[string]interface{}{
		"startTime": startTime.Format(time.RFC3339),
		"endTime":   endTime.Format(time.RFC3339),
	}

	var result struct {
		GetAlarmHistory []Alarm `json:"GetAlarmHistory"`
	}

	if err := c.graphqlClient.Execute(ctx, getAlarmHistoryQuery, variables, &result); err != nil {
		return nil, fmt.Errorf("get alarm history failed: %w", err)
	}

	return result.GetAlarmHistory, nil
}

// AcknowledgeAlarm acknowledges the specified alarm
func (c *Client) AcknowledgeAlarm(ctx context.Context, alarmID string) error {
	variables := map[string]interface{}{
		"alarmId": alarmID,
	}

	var result struct {
		AcknowledgeAlarm struct {
			Error *Error `json:"error"`
		} `json:"AcknowledgeAlarm"`
	}

	if err := c.graphqlClient.Execute(ctx, acknowledgeAlarmMutation, variables, &result); err != nil {
		return fmt.Errorf("acknowledge alarm failed: %w", err)
	}

	if result.AcknowledgeAlarm.Error != nil {
		return fmt.Errorf("acknowledge alarm error: %s - %s", 
			result.AcknowledgeAlarm.Error.Code, 
			result.AcknowledgeAlarm.Error.Description)
	}

	return nil
}

// ResetAlarm resets the specified alarm
func (c *Client) ResetAlarm(ctx context.Context, alarmID string) error {
	variables := map[string]interface{}{
		"alarmId": alarmID,
	}

	var result struct {
		ResetAlarm struct {
			Error *Error `json:"error"`
		} `json:"ResetAlarm"`
	}

	if err := c.graphqlClient.Execute(ctx, resetAlarmMutation, variables, &result); err != nil {
		return fmt.Errorf("reset alarm failed: %w", err)
	}

	if result.ResetAlarm.Error != nil {
		return fmt.Errorf("reset alarm error: %s - %s", 
			result.ResetAlarm.Error.Code, 
			result.ResetAlarm.Error.Description)
	}

	return nil
}

// ReadHistoricalValues reads historical values for a tag
func (c *Client) ReadHistoricalValues(ctx context.Context, tagName string, startTime, endTime time.Time, maxValues int) (*HistoricalResult, error) {
	variables := map[string]interface{}{
		"tag":       tagName,
		"startTime": startTime.Format(time.RFC3339),
		"endTime":   endTime.Format(time.RFC3339),
	}

	if maxValues > 0 {
		variables["maxValues"] = maxValues
	}

	var result struct {
		ReadHistoricalValues HistoricalResult `json:"ReadHistoricalValues"`
	}

	if err := c.graphqlClient.Execute(ctx, readHistoricalValuesQuery, variables, &result); err != nil {
		return nil, fmt.Errorf("read historical values failed: %w", err)
	}

	return &result.ReadHistoricalValues, nil
}

// GetRedundancyState returns the current redundancy state
func (c *Client) GetRedundancyState(ctx context.Context) (*RedundancyState, error) {
	var result struct {
		GetRedundancyState RedundancyState `json:"GetRedundancyState"`
	}

	if err := c.graphqlClient.Execute(ctx, getRedundancyStateQuery, nil, &result); err != nil {
		return nil, fmt.Errorf("get redundancy state failed: %w", err)
	}

	return &result.GetRedundancyState, nil
}

// SetAutoExtendSession enables or disables automatic session extension
func (c *Client) SetAutoExtendSession(enabled bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.autoExtendSession = enabled
}

// sessionExtender periodically extends the session
func (c *Client) sessionExtender() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			c.mu.RLock()
			sessionID := c.sessionID
			c.mu.RUnlock()

			if sessionID == "" {
				return
			}

			ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			variables := map[string]interface{}{
				"sessionId": sessionID,
			}

			var result struct {
				ExtendSession struct {
					Error *Error `json:"error"`
				} `json:"ExtendSession"`
			}

			c.graphqlClient.Execute(ctx, extendSessionMutation, variables, &result)
			cancel()

		case <-c.stopExtend:
			return
		}
	}
}