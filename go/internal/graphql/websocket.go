package graphql

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

type WebSocketClient struct {
	url     string
	headers http.Header
	conn    *websocket.Conn
	mu      sync.Mutex

	subscriptions map[string]chan<- json.RawMessage
	subMu         sync.RWMutex
	
	done    chan struct{}
	errChan chan error
}

type WSMessage struct {
	ID      string          `json:"id,omitempty"`
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

func NewWebSocketClient(url string) *WebSocketClient {
	return &WebSocketClient{
		url:           url,
		headers:       make(http.Header),
		subscriptions: make(map[string]chan<- json.RawMessage),
		done:          make(chan struct{}),
		errChan:       make(chan error, 1),
	}
}

func (c *WebSocketClient) SetHeader(key, value string) {
	c.headers.Set(key, value)
}

func (c *WebSocketClient) Connect(ctx context.Context) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	dialer := websocket.Dialer{
		HandshakeTimeout: 10 * time.Second,
	}

	conn, _, err := dialer.DialContext(ctx, c.url, c.headers)
	if err != nil {
		return fmt.Errorf("failed to connect: %w", err)
	}

	c.conn = conn

	// Send connection init
	initMsg := WSMessage{
		Type: "connection_init",
	}
	if err := c.conn.WriteJSON(initMsg); err != nil {
		c.conn.Close()
		return fmt.Errorf("failed to send connection_init: %w", err)
	}

	// Wait for connection_ack
	var ackMsg WSMessage
	if err := c.conn.ReadJSON(&ackMsg); err != nil {
		c.conn.Close()
		return fmt.Errorf("failed to read connection_ack: %w", err)
	}

	if ackMsg.Type != "connection_ack" {
		c.conn.Close()
		return fmt.Errorf("expected connection_ack, got %s", ackMsg.Type)
	}

	// Start read loop
	go c.readLoop()

	return nil
}

func (c *WebSocketClient) Subscribe(ctx context.Context, id string, query string, variables map[string]interface{}) (<-chan json.RawMessage, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.conn == nil {
		return nil, fmt.Errorf("not connected")
	}

	ch := make(chan json.RawMessage, 10)

	c.subMu.Lock()
	c.subscriptions[id] = ch
	c.subMu.Unlock()

	payload := map[string]interface{}{
		"query":     query,
		"variables": variables,
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		c.subMu.Lock()
		delete(c.subscriptions, id)
		c.subMu.Unlock()
		return nil, fmt.Errorf("failed to marshal payload: %w", err)
	}

	msg := WSMessage{
		ID:      id,
		Type:    "subscribe",
		Payload: payloadBytes,
	}

	if err := c.conn.WriteJSON(msg); err != nil {
		c.subMu.Lock()
		delete(c.subscriptions, id)
		c.subMu.Unlock()
		return nil, fmt.Errorf("failed to send subscription: %w", err)
	}

	return ch, nil
}

func (c *WebSocketClient) Unsubscribe(id string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.conn == nil {
		return fmt.Errorf("not connected")
	}

	c.subMu.Lock()
	if ch, ok := c.subscriptions[id]; ok {
		close(ch)
		delete(c.subscriptions, id)
	}
	c.subMu.Unlock()

	msg := WSMessage{
		ID:   id,
		Type: "complete",
	}

	return c.conn.WriteJSON(msg)
}

func (c *WebSocketClient) Close() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.conn == nil {
		return nil
	}

	close(c.done)

	// Close all subscription channels
	c.subMu.Lock()
	for _, ch := range c.subscriptions {
		close(ch)
	}
	c.subscriptions = make(map[string]chan<- json.RawMessage)
	c.subMu.Unlock()

	// Send connection_terminate
	msg := WSMessage{
		Type: "connection_terminate",
	}
	c.conn.WriteJSON(msg)

	return c.conn.Close()
}

func (c *WebSocketClient) readLoop() {
	defer func() {
		c.mu.Lock()
		c.conn.Close()
		c.conn = nil
		c.mu.Unlock()
	}()

	for {
		select {
		case <-c.done:
			return
		default:
			var msg WSMessage
			if err := c.conn.ReadJSON(&msg); err != nil {
				select {
				case c.errChan <- err:
				default:
				}
				return
			}

			switch msg.Type {
			case "next":
				c.subMu.RLock()
				if ch, ok := c.subscriptions[msg.ID]; ok {
					select {
					case ch <- msg.Payload:
					default:
						// Channel full, drop message
					}
				}
				c.subMu.RUnlock()

			case "error":
				c.subMu.RLock()
				if ch, ok := c.subscriptions[msg.ID]; ok {
					close(ch)
				}
				c.subMu.RUnlock()

				c.subMu.Lock()
				delete(c.subscriptions, msg.ID)
				c.subMu.Unlock()

			case "complete":
				c.subMu.RLock()
				if ch, ok := c.subscriptions[msg.ID]; ok {
					close(ch)
				}
				c.subMu.RUnlock()

				c.subMu.Lock()
				delete(c.subscriptions, msg.ID)
				c.subMu.Unlock()
			}
		}
	}
}