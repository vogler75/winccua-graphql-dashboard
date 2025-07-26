// Package client provides the main WinCC Unified GraphQL client
package client

import (
	"encoding/json"
	"fmt"

	"winccua-graphql-client/pkg/graphql"
	"winccua-graphql-client/pkg/types"
)

// WinCCUnifiedClient provides high-level access to WinCC Unified GraphQL API
type WinCCUnifiedClient struct {
	httpClient *graphql.Client
	wsClient   *graphql.WebSocketClient
	httpURL    string
	wsURL      string
}

// NewClient creates a new WinCC Unified client
func NewClient(httpURL string) *WinCCUnifiedClient {
	return &WinCCUnifiedClient{
		httpClient: graphql.NewClient(httpURL),
		httpURL:    httpURL,
	}
}

// NewClientWithWebSocket creates a new WinCC Unified client with WebSocket support
func NewClientWithWebSocket(httpURL, wsURL string) *WinCCUnifiedClient {
	return &WinCCUnifiedClient{
		httpClient: graphql.NewClient(httpURL),
		httpURL:    httpURL,
		wsURL:      wsURL,
	}
}

// SetAuthToken sets the authentication token for HTTP requests
func (c *WinCCUnifiedClient) SetAuthToken(token string) {
	c.httpClient.SetAuthToken(token)
}

// Login authenticates the user and stores the session token
func (c *WinCCUnifiedClient) Login(username, password string) (*types.Session, error) {
	variables := map[string]interface{}{
		"username": username,
		"password": password,
	}

	resp, err := c.httpClient.Mutation(graphql.LoginMutation, variables)
	if err != nil {
		return nil, fmt.Errorf("login request failed: %w", err)
	}

	var result struct {
		Login types.Session `json:"login"`
	}

	if err := json.Unmarshal(resp.Data, &result); err != nil {
		return nil, fmt.Errorf("failed to parse login response: %w", err)
	}

	session := &result.Login

	// Check for errors in the response
	if session.Error != nil && session.Error.Code != nil && *session.Error.Code != "0" {
		return nil, fmt.Errorf("login failed: %w", *session.Error)
	}

	// Set auth token for subsequent requests
	if session.Token != nil {
		c.httpClient.SetAuthToken(*session.Token)
	}

	return session, nil
}

// Logout logs out the current session
func (c *WinCCUnifiedClient) Logout(allSessions bool) (bool, error) {
	variables := map[string]interface{}{
		"allSessions": allSessions,
	}

	resp, err := c.httpClient.Mutation(graphql.LogoutMutation, variables)
	if err != nil {
		return false, fmt.Errorf("logout request failed: %w", err)
	}

	var result struct {
		Logout bool `json:"logout"`
	}

	if err := json.Unmarshal(resp.Data, &result); err != nil {
		return false, fmt.Errorf("failed to parse logout response: %w", err)
	}

	// Clear auth token
	c.httpClient.SetAuthToken("")

	return result.Logout, nil
}

// GetSession gets the current session information
func (c *WinCCUnifiedClient) GetSession() (*types.Session, error) {
	variables := map[string]interface{}{
		"allSessions": false,
	}

	resp, err := c.httpClient.Query(graphql.GetSessionQuery, variables)
	if err != nil {
		return nil, fmt.Errorf("get session request failed: %w", err)
	}

	// Parse as array (session field always returns an array)
	var result struct {
		Session []*types.Session `json:"session"`
	}

	if err := json.Unmarshal(resp.Data, &result); err != nil {
		return nil, fmt.Errorf("failed to parse session response: %w", err)
	}

	if len(result.Session) == 0 {
		return nil, fmt.Errorf("no sessions found in response")
	}

	session := result.Session[0]

	// Check for errors in the response
	if session.Error != nil && session.Error.Code != nil && *session.Error.Code != "0" {
		return nil, fmt.Errorf("get session failed: %w", *session.Error)
	}

	return session, nil
}

// GetTagValues retrieves values for the specified tags
func (c *WinCCUnifiedClient) GetTagValues(tagNames []string) ([]*types.TagValue, error) {
	variables := map[string]interface{}{
		"names":      tagNames,
		"directRead": false,
	}

	resp, err := c.httpClient.Query(graphql.GetTagValuesQuery, variables)
	if err != nil {
		return nil, fmt.Errorf("get tag values request failed: %w", err)
	}

	var result struct {
		TagValues []*types.TagValue `json:"tagValues"`
	}

	if err := json.Unmarshal(resp.Data, &result); err != nil {
		return nil, fmt.Errorf("failed to parse tag values response: %w", err)
	}

	return result.TagValues, nil
}

// WriteTagValues writes values to the specified tags
func (c *WinCCUnifiedClient) WriteTagValues(values []*types.TagValueInput) ([]*types.WriteTagResult, error) {
	variables := map[string]interface{}{
		"input":     values,
		"timestamp": nil,
		"quality":   nil,
	}

	resp, err := c.httpClient.Mutation(graphql.WriteTagValuesMutation, variables)
	if err != nil {
		return nil, fmt.Errorf("write tag values request failed: %w", err)
	}

	var result struct {
		WriteTagValues []*types.WriteTagResult `json:"writeTagValues"`
	}

	if err := json.Unmarshal(resp.Data, &result); err != nil {
		return nil, fmt.Errorf("failed to parse write tag values response: %w", err)
	}

	return result.WriteTagValues, nil
}

// Browse browses the tag namespace
func (c *WinCCUnifiedClient) Browse(nameFilters []string, objectTypeFilters []string, baseTypeFilters []string, language *string) ([]*types.BrowseResult, error) {
	variables := map[string]interface{}{
		"nameFilters":       nameFilters,
		"objectTypeFilters": objectTypeFilters,
		"baseTypeFilters":   baseTypeFilters,
		"language":          "en-US",
	}
	if language != nil {
		variables["language"] = *language
	}

	resp, err := c.httpClient.Query(graphql.BrowseQuery, variables)
	if err != nil {
		return nil, fmt.Errorf("browse request failed: %w", err)
	}

	var result struct {
		Browse []*types.BrowseResult `json:"browse"`
	}

	if err := json.Unmarshal(resp.Data, &result); err != nil {
		return nil, fmt.Errorf("failed to parse browse response: %w", err)
	}

	return result.Browse, nil
}

// GetActiveAlarms retrieves active alarms
func (c *WinCCUnifiedClient) GetActiveAlarms() ([]*types.Alarm, error) {
	resp, err := c.httpClient.Query(graphql.GetActiveAlarmsQuery, nil)
	if err != nil {
		return nil, fmt.Errorf("get active alarms request failed: %w", err)
	}

	var result struct {
		ActiveAlarms []*types.Alarm `json:"activeAlarms"`
	}

	if err := json.Unmarshal(resp.Data, &result); err != nil {
		return nil, fmt.Errorf("failed to parse active alarms response: %w", err)
	}

	return result.ActiveAlarms, nil
}

// AcknowledgeAlarms acknowledges the specified alarms
func (c *WinCCUnifiedClient) AcknowledgeAlarms(alarms []*types.AlarmIdentifierInput) ([]*types.AlarmOperationResult, error) {
	variables := map[string]interface{}{
		"input": alarms,
	}

	resp, err := c.httpClient.Mutation(graphql.AcknowledgeAlarmsMutation, variables)
	if err != nil {
		return nil, fmt.Errorf("acknowledge alarms request failed: %w", err)
	}

	var result struct {
		AcknowledgeAlarms []*types.AlarmOperationResult `json:"acknowledgeAlarms"`
	}

	if err := json.Unmarshal(resp.Data, &result); err != nil {
		return nil, fmt.Errorf("failed to parse acknowledge alarms response: %w", err)
	}

	return result.AcknowledgeAlarms, nil
}

// GetLoggedTagValues retrieves logged tag values for the specified time range
func (c *WinCCUnifiedClient) GetLoggedTagValues(tagNames []string, startTime, endTime *string, maxResults *int) ([]*types.LoggedTagValue, error) {
	variables := map[string]interface{}{
		"names":               tagNames,
		"maxNumberOfValues":   0,
		"sortingMode":         "TIME_ASC",
		"boundingValuesMode":  "NO_BOUNDING_VALUES",
	}
	if startTime != nil {
		variables["startTime"] = *startTime
	}
	if endTime != nil {
		variables["endTime"] = *endTime
	}
	if maxResults != nil {
		variables["maxNumberOfValues"] = *maxResults
	}

	resp, err := c.httpClient.Query(graphql.GetLoggedTagValuesQuery, variables)
	if err != nil {
		return nil, fmt.Errorf("get logged tag values request failed: %w", err)
	}

	var result struct {
		LoggedTagValues []*types.LoggedTagValue `json:"loggedTagValues"`
	}

	if err := json.Unmarshal(resp.Data, &result); err != nil {
		return nil, fmt.Errorf("failed to parse logged tag values response: %w", err)
	}

	return result.LoggedTagValues, nil
}

// ConnectWebSocket establishes a WebSocket connection for subscriptions
func (c *WinCCUnifiedClient) ConnectWebSocket(authToken string) error {
	if c.wsURL == "" {
		return fmt.Errorf("WebSocket URL not configured")
	}

	c.wsClient = graphql.NewWebSocketClient(c.wsURL, authToken)
	return c.wsClient.Connect()
}

// DisconnectWebSocket closes the WebSocket connection
func (c *WinCCUnifiedClient) DisconnectWebSocket() error {
	if c.wsClient == nil {
		return nil
	}
	return c.wsClient.Disconnect()
}

// SubscribeToTagValues subscribes to tag value changes
func (c *WinCCUnifiedClient) SubscribeToTagValues(tagNames []string, callbacks graphql.SubscriptionCallbacks) (*graphql.Subscription, error) {
	if c.wsClient == nil {
		return nil, fmt.Errorf("WebSocket not connected")
	}

	variables := map[string]interface{}{
		"names": tagNames,
	}

	return c.wsClient.Subscribe(graphql.TagValuesSubscription, variables, callbacks)
}

// SubscribeToActiveAlarms subscribes to active alarm changes
func (c *WinCCUnifiedClient) SubscribeToActiveAlarms(callbacks graphql.SubscriptionCallbacks) (*graphql.Subscription, error) {
	if c.wsClient == nil {
		return nil, fmt.Errorf("WebSocket not connected")
	}

	return c.wsClient.Subscribe(graphql.ActiveAlarmsSubscription, nil, callbacks)
}

// SubscribeToRedundancyState subscribes to redundancy state changes
func (c *WinCCUnifiedClient) SubscribeToRedundancyState(callbacks graphql.SubscriptionCallbacks) (*graphql.Subscription, error) {
	if c.wsClient == nil {
		return nil, fmt.Errorf("WebSocket not connected")
	}

	return c.wsClient.Subscribe(graphql.RedundancyStateSubscription, nil, callbacks)
}

// Convenience methods matching the Rust implementation

// LoginSimple performs login and returns just success/failure
func (c *WinCCUnifiedClient) LoginSimple(username, password string) error {
	_, err := c.Login(username, password)
	return err
}

// LogoutSimple performs logout with default parameters
func (c *WinCCUnifiedClient) LogoutSimple() error {
	_, err := c.Logout(false)
	return err
}

// GetSessionSimple gets session info
func (c *WinCCUnifiedClient) GetSessionSimple() (*types.Session, error) {
	return c.GetSession()
}

// GetTagValuesSimple gets tag values with simplified interface
func (c *WinCCUnifiedClient) GetTagValuesSimple(tagNames []string) ([]*types.TagValue, error) {
	return c.GetTagValues(tagNames)
}

// WriteTagValuesSimple writes tag values with simplified interface
func (c *WinCCUnifiedClient) WriteTagValuesSimple(values []*types.TagValueInput) ([]*types.WriteTagResult, error) {
	return c.WriteTagValues(values)
}

// BrowseSimple browses with default parameters
func (c *WinCCUnifiedClient) BrowseSimple() ([]*types.BrowseResult, error) {
	return c.Browse([]string{}, []string{}, []string{}, nil)
}

// GetActiveAlarmsSimple gets active alarms with simplified interface
func (c *WinCCUnifiedClient) GetActiveAlarmsSimple() ([]*types.Alarm, error) {
	return c.GetActiveAlarms()
}

// GetLoggedTagValuesSimple gets logged tag values with simplified interface
func (c *WinCCUnifiedClient) GetLoggedTagValuesSimple(tagNames []string, startTime, endTime *string, maxResults int) ([]*types.LoggedTagValue, error) {
	return c.GetLoggedTagValues(tagNames, startTime, endTime, &maxResults)
}