// Package graphql provides WebSocket GraphQL client functionality for subscriptions
package graphql

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// WebSocket message types for GraphQL over WebSocket (graphql-transport-ws protocol)
const (
	TypeConnectionInit      = "connection_init"
	TypeConnectionAck       = "connection_ack"
	TypeConnectionError     = "connection_error"
	TypeConnectionKeepAlive = "ping"
	TypeStart               = "subscribe"
	TypeData                = "next"
	TypeError               = "error"
	TypeComplete            = "complete"
	TypeStop                = "stop"
	TypeConnectionTerminate = "connection_terminate"
)

// WebSocketMessage represents a GraphQL WebSocket message
type WebSocketMessage struct {
	ID      string          `json:"id,omitempty"`
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

// SubscriptionPayload represents the payload for subscription start messages
type SubscriptionPayload struct {
	Query     string                 `json:"query"`
	Variables map[string]interface{} `json:"variables,omitempty"`
}

// SubscriptionCallbacks defines callback functions for subscription events
type SubscriptionCallbacks struct {
	OnData     func(data json.RawMessage)
	OnError    func(err error)
	OnComplete func()
}

// Subscription represents an active subscription
type Subscription struct {
	ID        string
	client    *WebSocketClient
	callbacks SubscriptionCallbacks
	stopCh    chan struct{}
}

// Stop stops the subscription
func (s *Subscription) Stop() error {
	close(s.stopCh)
	
	msg := WebSocketMessage{
		ID:   s.ID,
		Type: TypeStop,
	}
	
	return s.client.sendMessage(msg)
}

// WebSocketClient represents a WebSocket GraphQL client
type WebSocketClient struct {
	URL           string
	AuthToken     string
	conn          *websocket.Conn
	subscriptions map[string]*Subscription
	mu            sync.RWMutex
	ctx           context.Context
	cancel        context.CancelFunc
	connected     bool
}

// NewWebSocketClient creates a new WebSocket GraphQL client
func NewWebSocketClient(url, authToken string) *WebSocketClient {
	ctx, cancel := context.WithCancel(context.Background())
	return &WebSocketClient{
		URL:           url,
		AuthToken:     authToken,
		subscriptions: make(map[string]*Subscription),
		ctx:           ctx,
		cancel:        cancel,
	}
}

// Connect establishes a WebSocket connection and performs GraphQL WebSocket handshake
func (c *WebSocketClient) Connect() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.connected {
		log.Printf("DEBUG: WebSocket already connected")
		return nil
	}

	log.Printf("DEBUG: Attempting to connect to WebSocket URL: %s", c.URL)

	dialer := websocket.Dialer{
		HandshakeTimeout:  10 * time.Second,
		EnableCompression: false, // Disable compression to avoid RSV bit issues
		Proxy:             http.ProxyFromEnvironment,
		// Add more strict checking to avoid frame corruption
		ReadBufferSize:    4096,
		WriteBufferSize:   4096,
		// Skip TLS verification for development/testing
		TLSClientConfig: &tls.Config{
			InsecureSkipVerify: true,
		},
	}

	header := http.Header{}
	
	// Try with graphql-transport-ws protocol first
	log.Printf("DEBUG: Trying graphql-transport-ws protocol")
	header.Set("Sec-WebSocket-Protocol", "graphql-transport-ws")
	conn, resp, err := dialer.Dial(c.URL, header)
	if err != nil {
		log.Printf("DEBUG: graphql-transport-ws failed: %v", err)
		
		// Try graphql-ws as fallback
		log.Printf("DEBUG: Trying graphql-ws protocol as fallback")
		header.Set("Sec-WebSocket-Protocol", "graphql-ws")
		conn, resp, err = dialer.Dial(c.URL, header)
		if err != nil {
			log.Printf("DEBUG: Both protocols failed. Final error: %v", err)
			if resp != nil {
				log.Printf("DEBUG: HTTP Response Status: %s", resp.Status)
				log.Printf("DEBUG: HTTP Response Headers: %v", resp.Header)
			}
			return fmt.Errorf("failed to connect WebSocket: %w", err)
		}
	}

	log.Printf("DEBUG: WebSocket connected successfully")
	log.Printf("DEBUG: Response status: %s", resp.Status)
	log.Printf("DEBUG: Response headers: %v", resp.Header)
	
	// Verify the subprotocol was accepted
	acceptedProtocol := resp.Header.Get("Sec-WebSocket-Protocol")
	log.Printf("DEBUG: Accepted subprotocol: %s", acceptedProtocol)
	
	if acceptedProtocol != "graphql-transport-ws" {
		log.Printf("DEBUG: WARNING - Expected 'graphql-transport-ws' but server accepted: '%s'", acceptedProtocol)
	}

	c.conn = conn
	c.connected = true

	// Start message handling
	go c.handleMessages()

	// Send connection init
	initPayload := map[string]interface{}{
		"Authorization": "Bearer " + c.AuthToken,
	}
	payloadBytes, _ := json.Marshal(initPayload)
	
	initMsg := WebSocketMessage{
		Type: TypeConnectionInit,
		Payload: json.RawMessage(payloadBytes),
	}

	log.Printf("DEBUG: Sending connection_init message: %+v", initMsg)
	if err := c.sendMessage(initMsg); err != nil {
		log.Printf("DEBUG: Failed to send connection_init: %v", err)
		c.conn.Close()
		c.connected = false
		return fmt.Errorf("failed to send connection init: %w", err)
	}

	// Wait for connection ack
	log.Printf("DEBUG: Waiting for connection_ack...")
	return c.waitForConnectionAck()
}

// Disconnect closes the WebSocket connection
func (c *WebSocketClient) Disconnect() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !c.connected {
		return nil
	}

	// Stop all subscriptions
	for _, sub := range c.subscriptions {
		close(sub.stopCh)
	}
	c.subscriptions = make(map[string]*Subscription)

	// Send connection terminate
	terminateMsg := WebSocketMessage{
		Type: TypeConnectionTerminate,
	}
	c.sendMessage(terminateMsg)

	c.cancel()
	c.conn.Close()
	c.connected = false

	return nil
}

// Subscribe starts a new subscription
func (c *WebSocketClient) Subscribe(query string, variables map[string]interface{}, callbacks SubscriptionCallbacks) (*Subscription, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !c.connected {
		log.Printf("DEBUG: Cannot subscribe - WebSocket not connected")
		return nil, fmt.Errorf("WebSocket not connected")
	}

	// Generate unique subscription ID
	subID := fmt.Sprintf("sub_%d", time.Now().UnixNano())
	log.Printf("DEBUG: Creating subscription with ID: %s", subID)

	payload := SubscriptionPayload{
		Query:     query,
		Variables: variables,
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		log.Printf("DEBUG: Failed to marshal subscription payload: %v", err)
		return nil, fmt.Errorf("failed to marshal subscription payload: %w", err)
	}

	startMsg := WebSocketMessage{
		ID:      subID,
		Type:    TypeStart, // "subscribe" in graphql-transport-ws
		Payload: payloadBytes,
	}

	log.Printf("DEBUG: Sending subscription start message: %s", string(payloadBytes))
	if err := c.sendMessage(startMsg); err != nil {
		log.Printf("DEBUG: Failed to send subscription start: %v", err)
		return nil, fmt.Errorf("failed to send subscription start: %w", err)
	}

	subscription := &Subscription{
		ID:        subID,
		client:    c,
		callbacks: callbacks,
		stopCh:    make(chan struct{}),
	}

	c.subscriptions[subID] = subscription
	log.Printf("DEBUG: Subscription %s created and stored", subID)

	return subscription, nil
}

// sendMessage sends a WebSocket message
func (c *WebSocketClient) sendMessage(msg WebSocketMessage) error {
	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("DEBUG: Failed to marshal message: %v", err)
		return fmt.Errorf("failed to marshal message: %w", err)
	}

	log.Printf("DEBUG: Sending WebSocket message: %s", string(data))
	err = c.conn.WriteMessage(websocket.TextMessage, data)
	if err != nil {
		log.Printf("DEBUG: Failed to write WebSocket message: %v", err)
		return err
	}
	log.Printf("DEBUG: Message sent successfully")
	return nil
}

// waitForConnectionAck waits for the connection acknowledgment
func (c *WebSocketClient) waitForConnectionAck() error {
	timeout := time.NewTimer(10 * time.Second)
	defer timeout.Stop()

	for {
		select {
		case <-timeout.C:
			log.Printf("DEBUG: Timeout waiting for connection_ack")
			return fmt.Errorf("timeout waiting for connection ack")
		default:
			var msg WebSocketMessage
			log.Printf("DEBUG: Reading message for connection_ack...")
			if err := c.conn.ReadJSON(&msg); err != nil {
				log.Printf("DEBUG: Failed to read connection_ack message: %v", err)
				return fmt.Errorf("failed to read connection ack: %w", err)
			}

			log.Printf("DEBUG: Received message: Type=%s, ID=%s, Payload=%s", msg.Type, msg.ID, string(msg.Payload))

			switch msg.Type {
			case TypeConnectionAck:
				log.Printf("DEBUG: Connection acknowledged!")
				return nil
			case TypeConnectionError:
				log.Printf("DEBUG: Connection error received: %s", string(msg.Payload))
				return fmt.Errorf("connection error: %s", string(msg.Payload))
			default:
				log.Printf("DEBUG: Unexpected message type while waiting for ack: %s", msg.Type)
				// Continue waiting for ack
			}
		}
	}
}

// handleMessages handles incoming WebSocket messages
func (c *WebSocketClient) handleMessages() {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("WebSocket message handler panic: %v", r)
		}
	}()

	log.Printf("DEBUG: Starting WebSocket message handler")

	for {
		select {
		case <-c.ctx.Done():
			log.Printf("DEBUG: WebSocket message handler context cancelled")
			return
		default:
			// Set read deadline to prevent indefinite blocking
			c.conn.SetReadDeadline(time.Now().Add(30 * time.Second))
			
			// Try to read with more robust error handling
			var msg WebSocketMessage
			err := func() error {
				// Use a more defensive approach to reading
				messageType, reader, err := c.conn.NextReader()
				if err != nil {
					return err
				}
				
				log.Printf("DEBUG: NextReader returned messageType: %d", messageType)
				
				// Only process text messages
				if messageType != websocket.TextMessage {
					log.Printf("DEBUG: Ignoring non-text message type: %d", messageType)
					return nil // Skip this message
				}
				
				// Read the data from the reader
				data, err := io.ReadAll(reader)
				if err != nil {
					return fmt.Errorf("failed to read message data: %w", err)
				}
				
				log.Printf("DEBUG: Received message data: %s", string(data))
				
				// Parse JSON
				if err := json.Unmarshal(data, &msg); err != nil {
					return fmt.Errorf("failed to unmarshal JSON: %w", err)
				}
				
				return nil
			}()
			
			if err != nil {
				if websocket.IsCloseError(err, websocket.CloseNormalClosure, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
					log.Printf("DEBUG: WebSocket closed: %v", err)
				} else {
					log.Printf("DEBUG: WebSocket read error: %v", err)
				}
				return
			}
			
			// If we successfully read a message, handle it
			if msg.Type != "" {
				log.Printf("DEBUG: Parsed WebSocket message: Type=%s, ID=%s, Payload=%s", 
					msg.Type, msg.ID, string(msg.Payload))
				c.handleMessage(msg)
			}
		}
	}
}

// handleMessage handles a single WebSocket message
func (c *WebSocketClient) handleMessage(msg WebSocketMessage) {
	log.Printf("DEBUG: Handling message type: %s, ID: %s", msg.Type, msg.ID)
	
	c.mu.RLock()
	sub, exists := c.subscriptions[msg.ID]
	c.mu.RUnlock()

	switch msg.Type {
	case TypeData: // "next" in graphql-transport-ws
		log.Printf("DEBUG: Received data message for subscription %s", msg.ID)
		if exists && sub.callbacks.OnData != nil {
			sub.callbacks.OnData(msg.Payload)
		} else {
			log.Printf("DEBUG: No subscription found for ID %s or no OnData callback", msg.ID)
		}

	case TypeError:
		log.Printf("DEBUG: Received error message for subscription %s: %s", msg.ID, string(msg.Payload))
		if exists && sub.callbacks.OnError != nil {
			sub.callbacks.OnError(fmt.Errorf("subscription error: %s", string(msg.Payload)))
		}

	case TypeComplete:
		log.Printf("DEBUG: Received complete message for subscription %s", msg.ID)
		if exists {
			if sub.callbacks.OnComplete != nil {
				sub.callbacks.OnComplete()
			}
			c.mu.Lock()
			delete(c.subscriptions, msg.ID)
			c.mu.Unlock()
			log.Printf("DEBUG: Removed subscription %s", msg.ID)
		}

	case TypeConnectionKeepAlive: // "ping" in graphql-transport-ws
		log.Printf("DEBUG: Received ping, sending pong")
		pongMsg := WebSocketMessage{
			Type: "pong",
		}
		if err := c.sendMessage(pongMsg); err != nil {
			log.Printf("DEBUG: Failed to send pong: %v", err)
		}

	default:
		log.Printf("DEBUG: Unknown WebSocket message type: %s", msg.Type)
	}
}