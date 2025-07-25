package winccunified

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"sync"

	"github.com/siemens/winccua-graphql-libs/go/internal/graphql"
)

// Subscription represents an active subscription
type Subscription struct {
	ID     string
	client *graphql.WebSocketClient
	cancel context.CancelFunc
}

// Close closes the subscription
func (s *Subscription) Close() error {
	if s.cancel != nil {
		s.cancel()
	}
	return s.client.Unsubscribe(s.ID)
}

// ConnectWebSocket establishes a WebSocket connection for subscriptions
func (c *Client) ConnectWebSocket(ctx context.Context) error {
	if c.wsClient != nil {
		return nil // Already connected
	}

	wsURL := strings.Replace(c.baseURL, "http", "ws", 1) + "/graphql"
	c.wsClient = graphql.NewWebSocketClient(wsURL)

	c.mu.RLock()
	token := c.token
	c.mu.RUnlock()

	if token != "" {
		c.wsClient.SetHeader("Authorization", "Bearer "+token)
	}

	return c.wsClient.Connect(ctx)
}

// SubscribeToTags subscribes to tag value changes
func (c *Client) SubscribeToTags(ctx context.Context, tagNames []string) (<-chan TagResult, *Subscription, error) {
	if c.wsClient == nil {
		if err := c.ConnectWebSocket(ctx); err != nil {
			return nil, nil, fmt.Errorf("failed to connect websocket: %w", err)
		}
	}

	variables := map[string]interface{}{
		"tags": tagNames,
	}

	subID := fmt.Sprintf("tags_%d", len(tagNames))
	rawCh, err := c.wsClient.Subscribe(ctx, subID, subscribeToTagsSubscription, variables)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to subscribe to tags: %w", err)
	}

	resultCh := make(chan TagResult, 10)
	
	ctxWithCancel, cancel := context.WithCancel(ctx)
	subscription := &Subscription{
		ID:     subID,
		client: c.wsClient,
		cancel: cancel,
	}

	go func() {
		defer close(resultCh)
		for {
			select {
			case <-ctxWithCancel.Done():
				return
			case rawData, ok := <-rawCh:
				if !ok {
					return
				}

				var result struct {
					SubscribeToTags TagResult `json:"SubscribeToTags"`
				}

				if err := json.Unmarshal(rawData, &result); err != nil {
					continue
				}

				select {
				case resultCh <- result.SubscribeToTags:
				case <-ctxWithCancel.Done():
					return
				}
			}
		}
	}()

	return resultCh, subscription, nil
}

// SubscribeToAlarms subscribes to alarm state changes
func (c *Client) SubscribeToAlarms(ctx context.Context) (<-chan Alarm, *Subscription, error) {
	if c.wsClient == nil {
		if err := c.ConnectWebSocket(ctx); err != nil {
			return nil, nil, fmt.Errorf("failed to connect websocket: %w", err)
		}
	}

	subID := "alarms"
	rawCh, err := c.wsClient.Subscribe(ctx, subID, subscribeToAlarmsSubscription, nil)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to subscribe to alarms: %w", err)
	}

	resultCh := make(chan Alarm, 10)
	
	ctxWithCancel, cancel := context.WithCancel(ctx)
	subscription := &Subscription{
		ID:     subID,
		client: c.wsClient,
		cancel: cancel,
	}

	go func() {
		defer close(resultCh)
		for {
			select {
			case <-ctxWithCancel.Done():
				return
			case rawData, ok := <-rawCh:
				if !ok {
					return
				}

				var result struct {
					SubscribeToAlarms Alarm `json:"SubscribeToAlarms"`
				}

				if err := json.Unmarshal(rawData, &result); err != nil {
					continue
				}

				select {
				case resultCh <- result.SubscribeToAlarms:
				case <-ctxWithCancel.Done():
					return
				}
			}
		}
	}()

	return resultCh, subscription, nil
}

// SubscribeToRedundancyState subscribes to redundancy state changes
func (c *Client) SubscribeToRedundancyState(ctx context.Context) (<-chan RedundancyState, *Subscription, error) {
	if c.wsClient == nil {
		if err := c.ConnectWebSocket(ctx); err != nil {
			return nil, nil, fmt.Errorf("failed to connect websocket: %w", err)
		}
	}

	subID := "redundancy"
	rawCh, err := c.wsClient.Subscribe(ctx, subID, subscribeToRedundancyStateSubscription, nil)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to subscribe to redundancy state: %w", err)
	}

	resultCh := make(chan RedundancyState, 10)
	
	ctxWithCancel, cancel := context.WithCancel(ctx)
	subscription := &Subscription{
		ID:     subID,
		client: c.wsClient,
		cancel: cancel,
	}

	go func() {
		defer close(resultCh)
		for {
			select {
			case <-ctxWithCancel.Done():
				return
			case rawData, ok := <-rawCh:
				if !ok {
					return
				}

				var result struct {
					SubscribeToRedundancyState RedundancyState `json:"SubscribeToRedundancyState"`
				}

				if err := json.Unmarshal(rawData, &result); err != nil {
					continue
				}

				select {
				case resultCh <- result.SubscribeToRedundancyState:
				case <-ctxWithCancel.Done():
					return
				}
			}
		}
	}()

	return resultCh, subscription, nil
}

// DisconnectWebSocket closes the WebSocket connection
func (c *Client) DisconnectWebSocket() error {
	if c.wsClient == nil {
		return nil
	}

	err := c.wsClient.Close()
	c.wsClient = nil
	return err
}