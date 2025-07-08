// Browser-compatible WinCC Unified library
// Uses native browser APIs (fetch, WebSocket) instead of Node.js modules
// Version: 1.0.0

class GraphQLWSClient {
  constructor(url, token) {
    this.url = url;
    this.token = token;
    this.ws = null;
    this.subscriptions = new Map();
    this.subscriptionIdCounter = 0;
    this.connectionState = 'disconnected'; // disconnected, connecting, connected
    this.connectionPromise = null;
    this.keepAliveTimer = null;
  }

  generateSubscriptionId() {
    return `sub_${++this.subscriptionIdCounter}`;
  }

  async connect() {
    if (this.connectionState === 'connected') {
      return Promise.resolve();
    }

    if (this.connectionState === 'connecting') {
      return this.connectionPromise;
    }

    this.connectionState = 'connecting';
    
    this.connectionPromise = new Promise((resolve, reject) => {
      try {
        this.ws = new WebSocket(this.url, 'graphql-transport-ws');

        const connectionTimeout = setTimeout(() => {
          reject(new Error('WebSocket connection timeout'));
          this.ws.close();
        }, 10000);

        this.ws.onopen = () => {
          console.log('[GraphQL-WS] WebSocket connect ' + this.url + ' Token: ' + (this.token || 'none'));
          
          // Send connection init message with auth
          this.ws.send(JSON.stringify({
            type: 'connection_init',
            payload: {
              "Authorization": this.token ? `Bearer ${this.token}` : undefined,
              "Content-Type": 'application/json'
            }
          }));
        };

        this.ws.onmessage = (event) => {
          clearTimeout(connectionTimeout);
          const message = JSON.parse(event.data);
          //console.log('[GraphQL-WS] Message received:', message);

          switch (message.type) {
            case 'connection_ack':
              console.log('[GraphQL-WS] Connection acknowledged');
              this.connectionState = 'connected';
              this.startKeepAlive();
              resolve();
              break;

            case 'connection_error':
              console.error('[GraphQL-WS] Connection error:', message.payload);
              this.connectionState = 'disconnected';
              reject(new Error(`Connection error: ${JSON.stringify(message.payload)}`));
              break;

            case 'next':
              this.handleDataMessage(message);
              break;

            case 'error':
              this.handleErrorMessage(message);
              break;

            case 'complete':
              this.handleCompleteMessage(message);
              break;

            case 'pong': // keep alive
              console.log('[GraphQL-WS] Keep alive received');
              break;

            default:
              console.warn('[GraphQL-WS] Unknown message type:', message.type);
          }
        };

        this.ws.onerror = (error) => {
          clearTimeout(connectionTimeout);
          console.error('[GraphQL-WS] WebSocket error:', error);
          this.connectionState = 'disconnected';
          reject(error);
        };

        this.ws.onclose = (event) => {
          clearTimeout(connectionTimeout);
          console.log(`[GraphQL-WS] WebSocket closed: ${event.code} ${event.reason}`);
          this.connectionState = 'disconnected';
          this.stopKeepAlive();
          
          // Notify all active subscriptions of disconnection
          this.subscriptions.forEach(sub => {
            if (sub.onError) {
              sub.onError(new Error('WebSocket connection closed'));
            }
          });
          
          if (this.connectionState === 'connecting') {
            reject(new Error(`WebSocket closed during connection: ${event.reason}`));
          }
        };

      } catch (error) {
        this.connectionState = 'disconnected';
        reject(error);
      }
    });

    return this.connectionPromise;
  }

  startKeepAlive() {
    this.stopKeepAlive();
    this.keepAliveTimer = setInterval(() => {
      if (this.ws && this.ws.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify({ type: 'ping' })); // GraphQL server says "invalid message type"
      }
    }, 30000); // Send keep alive every 30 seconds
  }

  stopKeepAlive() {
    if (this.keepAliveTimer) {
      clearInterval(this.keepAliveTimer);
      this.keepAliveTimer = null;
    }
  }

  handleDataMessage(message) {
    const subscription = this.subscriptions.get(message.id);
    if (subscription && subscription.onData) {
      subscription.onData(message.payload);
    }
  }

  handleErrorMessage(message) {
    const subscription = this.subscriptions.get(message.id);
    if (subscription && subscription.onError) {
      subscription.onError(new Error(JSON.stringify(message.payload)));
    }
  }

  handleCompleteMessage(message) {
    const subscription = this.subscriptions.get(message.id);
    if (subscription) {
      if (subscription.onComplete) {
        subscription.onComplete();
      }
      this.subscriptions.delete(message.id);
    }
  }

  async subscribe(query, variables = {}, callbacks = {}) {
    await this.connect();

    const subscriptionId = this.generateSubscriptionId();
    
    // Store subscription callbacks
    this.subscriptions.set(subscriptionId, {
      onData: callbacks.onData,
      onError: callbacks.onError,
      onComplete: callbacks.onComplete
    });

    // Send start message
    const startMessage = {
      id: subscriptionId,
      type: 'subscribe',
      payload: {
        query,
        variables
      }
    };

    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(startMessage));
      console.log(`[GraphQL-WS] Subscription started: ${subscriptionId}`);
    } else {
      this.subscriptions.delete(subscriptionId);
      throw new Error('WebSocket not connected');
    }

    // Return subscription object with unsubscribe method
    return {
      id: subscriptionId,
      unsubscribe: () => this.unsubscribe(subscriptionId)
    };
  }

  unsubscribe(subscriptionId) {
    if (this.subscriptions.has(subscriptionId)) {
      // Send stop message
      if (this.ws && this.ws.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify({
          id: subscriptionId,
          type: 'complete'
        }));
      }
      
      this.subscriptions.delete(subscriptionId);
      console.log(`[GraphQL-WS] Subscription stopped: ${subscriptionId}`);
    }
  }

  disconnect() {
    this.stopKeepAlive();
    
    // Stop all subscriptions
    this.subscriptions.forEach((_, id) => {
      this.unsubscribe(id);
    });
    
    // Send connection terminate
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      //this.ws.send(JSON.stringify({ type: 'connection_terminate' })); // GraphQL server says "invalid message type"
    }
    
    // Close WebSocket
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    
    this.connectionState = 'disconnected';
    this.connectionPromise = null;
  }

  updateToken(token) {
    this.token = token;
    // If we're connected, we need to reconnect with the new token
    if (this.connectionState === 'connected') {
      console.log('[GraphQL-WS] Token updated, reconnecting...');
      this.disconnect();
    }
  }
}

class GraphQLClient {
  constructor(httpUrl, wsUrl) {
    this.httpUrl = httpUrl;
    this.wsUrl = wsUrl;
    this.token = null;
    this.wsClient = null;
  }

  setToken(token) {
    this.token = token;

    // Update WebSocket client token if it exists
    if (this.wsClient) {
      this.wsClient.updateToken(token);
    }
  }

  getWebSocketClient() {
    if (!this.wsClient) {
      this.wsClient = new GraphQLWSClient(this.wsUrl, this.token);
    }
    return this.wsClient;
  }

  async request(query, variables = {}) {
    const response = await fetch(this.httpUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': this.token ? `Bearer ${this.token}` : undefined
      },
      body: JSON.stringify({
        query,
        variables
      })
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const result = await response.json();
    
    if (result.errors) {
      throw new Error(`GraphQL error: ${result.errors.map(e => e.message).join(', ')}`);
    }

    return result.data;
  }

  async subscribe(query, variables = {}, callbacks = {}) {
    const wsClient = this.getWebSocketClient();
    return wsClient.subscribe(query, variables, callbacks);
  }

  dispose() {
    if (this.wsClient) {
      this.wsClient.disconnect();
      this.wsClient = null;
    }
  }
}


// Main WinCC Unified class for browser with WebSocket support
class WinCCUnified {
  constructor(httpUrl, wsUrl) {
    this.client = new GraphQLClient(httpUrl, wsUrl);
    this.token = null;
  }

  async login(username, password) {
    const result = await this.client.request(MUTATIONS.LOGIN, { username, password });
    if (result.login && result.login.token) {
      this.token = result.login.token;
      this.client.setToken(this.token);
      return result.login;
    }
    throw new Error('Login failed: ' + (result.login?.error?.description || 'Unknown error'));
  }

  setToken(token) {
    this.token = token;
    this.client.setToken(token);
  }

  async getSession(allSessions = false) {
    const result = await this.client.request(QUERIES.SESSION, { allSessions });
    return result.session;
  }

  async getTagValues(names, directRead = false) {
    const result = await this.client.request(QUERIES.TAG_VALUES, { names, directRead });
    return result.tagValues;
  }

  async getLoggedTagValues(names, startTime, endTime, maxNumberOfValues = 1000, sortingMode = 'TIME_ASC') {
    console.log('Fetching logged tag values:', names, startTime, endTime, maxNumberOfValues, sortingMode);
    
    // Build variables object, only including startTime if it's not null
    const variables = { 
      names, 
      endTime, 
      maxNumberOfValues, 
      sortingMode 
    };
    
    if (startTime) {
      variables.startTime = startTime;
    }
    
    const result = await this.client.request(QUERIES.LOGGED_TAG_VALUES, variables);
    return result.loggedTagValues;
  }

  async getNonce() {
    const result = await this.client.request(QUERIES.NONCE);
    return result.nonce;
  }

  async getIdentityProviderURL() {
    const result = await this.client.request(QUERIES.IDENTITY_PROVIDER_URL);
    return result.identityProviderURL;
  }

  async browse(options = {}) {
    const { nameFilters = [], objectTypeFilters = [], baseTypeFilters = [], language = 'en-US' } = options;
    const result = await this.client.request(QUERIES.BROWSE, {
      nameFilters,
      objectTypeFilters,
      baseTypeFilters,
      language
    });
    return result.browse;
  }

  async getActiveAlarms(options = {}) {
    const { systemNames = [], filterString = '', filterLanguage = 'en-US', languages = ['en-US'] } = options;
    const result = await this.client.request(QUERIES.ACTIVE_ALARMS, {
      systemNames,
      filterString,
      filterLanguage,
      languages
    });
    return result.activeAlarms;
  }

  async getLoggedAlarms(options = {}) {
    const { 
      systemNames = [], 
      filterString = '', 
      filterLanguage = 'en-US', 
      languages = ['en-US'],
      startTime,
      endTime,
      maxNumberOfResults = 0
    } = options;
    
    const variables = {
      systemNames,
      filterString,
      filterLanguage,
      languages,
      maxNumberOfResults
    };

    if (startTime) variables.startTime = startTime;
    if (endTime) variables.endTime = endTime;

    const result = await this.client.request(QUERIES.LOGGED_ALARMS, variables);
    return result.loggedAlarms;
  }

  async loginSWAC(claim, signedClaim) {
    const result = await this.client.request(MUTATIONS.LOGIN_SWAC, { claim, signedClaim });
    if (result.loginSWAC && result.loginSWAC.token) {
      this.token = result.loginSWAC.token;
      this.client.setToken(this.token);
      return result.loginSWAC;
    }
    throw new Error('SWAC login failed: ' + (result.loginSWAC?.error?.description || 'Unknown error'));
  }

  async extendSession() {
    const result = await this.client.request(MUTATIONS.EXTEND_SESSION);
    if (result.extendSession && result.extendSession.token) {
      this.token = result.extendSession.token;
      this.client.setToken(this.token);
      return result.extendSession;
    }
    throw new Error('Session extension failed: ' + (result.extendSession?.error?.description || 'Unknown error'));
  }

  async logout(allSessions = false) {
    const result = await this.client.request(MUTATIONS.LOGOUT, { allSessions });
    this.token = null;
    this.client.setToken(null);
    return result.logout;
  }

  async writeTagValues(input, timestamp = null, quality = null) {
    const variables = { input };
    if (timestamp) variables.timestamp = timestamp;
    if (quality) variables.quality = quality;
    
    const result = await this.client.request(MUTATIONS.WRITE_TAG_VALUES, variables);
    return result.writeTagValues;
  }

  async acknowledgeAlarms(input) {
    const result = await this.client.request(MUTATIONS.ACKNOWLEDGE_ALARMS, { input });
    return result.acknowledgeAlarms;
  }

  async resetAlarms(input) {
    const result = await this.client.request(MUTATIONS.RESET_ALARMS, { input });
    return result.resetAlarms;
  }

  async disableAlarms(names) {
    const result = await this.client.request(MUTATIONS.DISABLE_ALARMS, { names });
    return result.disableAlarms;
  }

  async enableAlarms(names) {
    const result = await this.client.request(MUTATIONS.ENABLE_ALARMS, { names });
    return result.enableAlarms;
  }

  async shelveAlarms(names, shelveTimeout = null) {
    const variables = { names };
    if (shelveTimeout) variables.shelveTimeout = shelveTimeout;
    
    const result = await this.client.request(MUTATIONS.SHELVE_ALARMS, variables);
    return result.shelveAlarms;
  }

  async unshelveAlarms(names) {
    const result = await this.client.request(MUTATIONS.UNSHELVE_ALARMS, { names });
    return result.unshelveAlarms;
  }

  async subscribeToTagValues(names, callback) {
    try {
      const subscription = await this.client.subscribe(
        SUBSCRIPTIONS.TAG_VALUES,
        { names },
        {
          onData: (data) => {
            if (callback && data.data?.tagValues) {
              callback(data.data.tagValues, null);
            }
          },
          onError: (error) => {
            console.error('Tag values subscription error:', error);
            if (callback) callback(null, error);
          },
          onComplete: () => {
            console.log('Tag values subscription completed');
          }
        }
      );
      
      return subscription;
    } catch (error) {
      console.error('Failed to create tag values subscription:', error);
      if (callback) callback(null, error);
      throw error;
    }
  }

  async subscribeToActiveAlarms(options = {}, callback) {
    const { systemNames = [], filterString = '', filterLanguage = 'en-US', languages = ['en-US'] } = options;
    
    try {
      const subscription = await this.client.subscribe(
        SUBSCRIPTIONS.ACTIVE_ALARMS,
        { systemNames, filterString, filterLanguage, languages },
        {
          onData: (data) => {
            if (callback && data.data?.activeAlarms) {
              callback(data.data.activeAlarms, null);
            }
          },
          onError: (error) => {
            console.error('Active alarms subscription error:', error);
            if (callback) callback(null, error);
          },
          onComplete: () => {
            console.log('Active alarms subscription completed');
          }
        }
      );
      
      return subscription;
    } catch (error) {
      console.error('Failed to create active alarms subscription:', error);
      if (callback) callback(null, error);
      throw error;
    }
  }

  async subscribeToReduState(callback) {
    try {
      const subscription = await this.client.subscribe(
        SUBSCRIPTIONS.REDU_STATE,
        {},
        {
          onData: (data) => {
            if (callback && data.data?.reduState) {
              callback(data.data.reduState, null);
            }
          },
          onError: (error) => {
            console.error('Redu state subscription error:', error);
            if (callback) callback(null, error);
          },
          onComplete: () => {
            console.log('Redu state subscription completed');
          }
        }
      );
      
      return subscription;
    } catch (error) {
      console.error('Failed to create redu state subscription:', error);
      if (callback) callback(null, error);
      throw error;
    }
  }

  dispose() {
    this.client.dispose();
  }
}

// Make it available globally for the browser
window.WinCCUnified = WinCCUnified;
console.log('WinCCUnified class exported to window object');