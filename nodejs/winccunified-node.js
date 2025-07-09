// Node.js-compatible WinCC Unified library
// Uses Node.js modules (ws, node-fetch) instead of browser APIs

const WebSocket = require('ws');
const { QUERIES, MUTATIONS, SUBSCRIPTIONS } = require('./winccunified-graphql.js');

// Use built-in fetch if available (Node.js 18+), otherwise require node-fetch
let fetch;
try {
  fetch = globalThis.fetch;
} catch {
  // Fallback for older Node.js versions
  fetch = require('node-fetch');
}

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

        this.ws.on('open', () => {
          console.log('[GraphQL-WS] WebSocket connect ' + this.url + ' Token: ' + (this.token || 'none'));
          
          // Send connection init message with auth
          this.ws.send(JSON.stringify({
            type: 'connection_init',
            payload: {
              "Authorization": this.token ? `Bearer ${this.token}` : undefined,
              "Content-Type": 'application/json'
            }
          }));
        });

        this.ws.on('message', (data) => {
          clearTimeout(connectionTimeout);
          const message = JSON.parse(data.toString());
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
        });

        this.ws.on('error', (error) => {
          clearTimeout(connectionTimeout);
          console.error('[GraphQL-WS] WebSocket error:', error);
          this.connectionState = 'disconnected';
          reject(error);
        });

        this.ws.on('close', (code, reason) => {
          clearTimeout(connectionTimeout);
          console.log(`[GraphQL-WS] WebSocket closed: ${code} ${reason}`);
          this.connectionState = 'disconnected';
          this.stopKeepAlive();
          
          // Notify all active subscriptions of disconnection
          this.subscriptions.forEach(sub => {
            if (sub.onError) {
              sub.onError(new Error('WebSocket connection closed'));
            }
          });
          
          if (this.connectionState === 'connecting') {
            reject(new Error(`WebSocket closed during connection: ${reason}`));
          }
        });

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

// Main WinCC Unified class for Node.js with WebSocket support
class WinCCUnifiedNode {
  constructor(httpUrl, wsUrl) {
    this.client = new GraphQLClient(httpUrl, wsUrl);
    this.token = null;
  }

  /**
   * Logs a user in based on their username and password.
   * Returns: Session object containing user info, token, and expiry timestamp
   * JSON Structure: { user: { id, name, groups, fullName, language, autoLogoffSec }, token: string, expires: timestamp, error?: { code, description } }
   * Errors: 101 - Incorrect credentials provided, 102 - UMC error
   */
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

  /**
   * Returns information about the current session. If allSessions is true, returns all sessions of the current user.
   * Returns: Array of Session objects with user info, token, and expiry timestamp
   * JSON Structure: [{ user: { id, name, groups, fullName, language, autoLogoffSec }, token: string, expires: timestamp, error?: { code, description } }]
   */
  async getSession(allSessions = false) {
    const result = await this.client.request(QUERIES.SESSION, { allSessions });
    return result.session;
  }

  /**
   * Queries tag values based on the provided names list. If directRead is true, values are taken directly from PLC.
   * Returns: Array of TagValueResult objects with tag name, value, and quality information
   * JSON Structure: [{ name: string, value: { value: variant, timestamp: timestamp, quality: { quality, subStatus, limit, extendedSubStatus, sourceQuality, sourceTime, timeCorrected } }, error?: { code, description } }]
   * Errors: 2 - Cannot resolve provided name, 202 - Only leaf elements of a Structure Tag can be addressed
   */
  async getTagValues(names, directRead = false) {
    const result = await this.client.request(QUERIES.TAG_VALUES, { names, directRead });
    return result.tagValues;
  }

  /**
   * Queries logged tag values from the database. Names must be LoggingTag names or Tag names (if only one logging tag exists).
   * Returns: Array of LoggedTagValuesResult objects with logging tag name, error info, and array of logged values
   * JSON Structure: [{ loggingTagName: string, error?: { code, description }, values: [{ value: { value: variant, timestamp: timestamp, quality: quality }, flags: [flag_enum] }] }]
   * Sorting modes: TIME_ASC, TIME_DESC. Bounding modes: NO_BOUNDING_VALUES, LEFT_BOUNDING_VALUES, RIGHT_BOUNDING_VALUES, LEFTRIGHT_BOUNDING_VALUES
   * Errors: 1 - Generic error, 2 - Cannot resolve provided name, 3 - Argument error
   */
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

  /**
   * Returns a nonce that can be used with e.g. the UMC SWAC login method.
   * Returns: Nonce object with value and validity duration
   * JSON Structure: { value: string, validFor: number }
   */
  async getNonce() {
    const result = await this.client.request(QUERIES.NONCE);
    return result.nonce;
  }

  /**
   * Returns the URL of the identity provider for UMC SWAC authentication.
   * Returns: String URL where user should be redirected for SWAC login
   * JSON Structure: string (URL)
   */
  async getIdentityProviderURL() {
    const result = await this.client.request(QUERIES.IDENTITY_PROVIDER_URL);
    return result.identityProviderURL;
  }

  /**
   * Queries tags, elements, types, alarms, logging tags based on filter criteria. Each filter parameter supports arrays with OR relation, while parameters have AND relation.
   * Returns: Array of BrowseTagsResult objects with name, display name, object type, and data type
   * JSON Structure: [{ name: string, displayName: string, objectType: string, dataType: string }]
   * ObjectTypes: TAG, SIMPLETAG, STRUCTURETAG, TAGTYPE, STRUCTURETAGTYPE, SIMPLETAGTYPE, ALARM, ALARMCLASS, LOGGINGTAG
   * Errors: 1 - Generic error, 2 - Cannot resolve provided name, 3 - Argument error
   */
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

  /**
   * Query active alarms from the provided systems using ChromQueryLanguage filter.
   * Returns: Array of ActiveAlarm objects with comprehensive alarm information
   * JSON Structure: [{ name: string, instanceID: number, alarmGroupID: number, raiseTime: timestamp, acknowledgmentTime: timestamp, clearTime: timestamp, resetTime: timestamp, modificationTime: timestamp, state: AlarmState, textColor: color, backColor: color, flashing: boolean, languages: [string], alarmClassName: string, alarmClassSymbol: [string], alarmClassID: number, stateMachine: AlarmStateMachine, priority: number, alarmParameterValues: [variant], alarmType: [string], eventText: [string], infoText: [string], alarmText1-9: [string], stateText: [string], origin: string, area: string, changeReason: [AlarmChangeReason], connectionName: string, valueLimit: variant, sourceType: AlarmSourceType, suppressionState: AlarmSuppressionState, hostName: string, userName: string, value: variant, valueQuality: Quality, quality: Quality, invalidFlags: AlarmInvalidFlags, deadBand: variant, producer: AlarmProducer, duration: timespan, durationIso: timespanIso, sourceID: string, systemSeverity: number, loopInAlarm: string, loopInAlarmParameterValues: variant, path: string, userResponse: AlarmUserResponse }]
   * Errors: 301 - Syntax error in query string, 302 - Invalid language, 303 - Invalid filter language
   */
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

  /**
   * Query logged alarms from the storage system using ChromQueryLanguage filter and time boundaries.
   * Returns: Array of LoggedAlarm objects with comprehensive historical alarm information
   * JSON Structure: [{ name: string, instanceID: number, alarmGroupID: number, raiseTime: timestamp, acknowledgmentTime: timestamp, clearTime: timestamp, resetTime: timestamp, modificationTime: timestamp, state: AlarmState, textColor: color, backColor: color, languages: [string], alarmClassName: string, alarmClassSymbol: [string], alarmClassID: number, stateMachine: AlarmStateMachine, priority: number, alarmParameterValues: [variant], alarmType: [string], eventText: [string], infoText: [string], alarmText1-9: [string], stateText: [string], origin: string, area: string, changeReason: [AlarmChangeReason], valueLimit: variant, sourceType: AlarmSourceType, suppressionState: AlarmSuppressionState, hostName: string, userName: string, value: variant, valueQuality: Quality, quality: Quality, invalidFlags: AlarmInvalidFlags, deadband: variant, producer: AlarmProducer, duration: timespan, durationIso: timespanIso, hasComments: boolean }]
   * Errors: 301 - Syntax error in query string, 302 - Invalid language (or not logged), 303 - Invalid filter language (or not logged)
   */
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

  /**
   * Logs a user in based on the claim and signed claim from UMC SWAC authentication.
   * Returns: Session object containing user info, token, and expiry timestamp
   * JSON Structure: { user: { id, name, groups, fullName, language, autoLogoffSec }, token: string, expires: timestamp, error?: { code, description } }
   * Errors: 101 - Incorrect credentials provided, 103 - Nonce expired
   */
  async loginSWAC(claim, signedClaim) {
    const result = await this.client.request(MUTATIONS.LOGIN_SWAC, { claim, signedClaim });
    if (result.loginSWAC && result.loginSWAC.token) {
      this.token = result.loginSWAC.token;
      this.client.setToken(this.token);
      return result.loginSWAC;
    }
    throw new Error('SWAC login failed: ' + (result.loginSWAC?.error?.description || 'Unknown error'));
  }

  /**
   * Extends the user's current session expiry by the 'session expires' value from the identity provider (UMC).
   * Returns: Session object with updated expiry timestamp
   * JSON Structure: { user: { id, name, groups, fullName, language, autoLogoffSec }, token: string, expires: timestamp, error?: { code, description } }
   */
  async extendSession() {
    const result = await this.client.request(MUTATIONS.EXTEND_SESSION);
    if (result.extendSession && result.extendSession.token) {
      this.token = result.extendSession.token;
      this.client.setToken(this.token);
      return result.extendSession;
    }
    throw new Error('Session extension failed: ' + (result.extendSession?.error?.description || 'Unknown error'));
  }

  /**
   * Logs out the current user. If allSessions is true, all sessions of the current user will be terminated.
   * Returns: Boolean indicating success
   * JSON Structure: boolean
   */
  async logout(allSessions = false) {
    const result = await this.client.request(MUTATIONS.LOGOUT, { allSessions });
    this.token = null;
    this.client.setToken(null);
    return result.logout;
  }

  /**
   * Updates tags based on the provided TagValueInput list. Uses fallback timestamp and quality if not specified per tag.
   * Returns: Array of WriteTagValuesResult objects with tag name and error information
   * JSON Structure: [{ name: string, error?: { code, description } }]
   * Errors: 2 - Cannot resolve provided name, 201 - Cannot convert provided value to data type, 202 - Only leaf elements of a Structure Tag can be addressed
   */
  async writeTagValues(input, timestamp = null, quality = null) {
    const variables = { input };
    if (timestamp) variables.timestamp = timestamp;
    if (quality) variables.quality = quality;
    
    const result = await this.client.request(MUTATIONS.WRITE_TAG_VALUES, variables);
    return result.writeTagValues;
  }

  /**
   * Acknowledge one or more alarms. Each alarm identifier must have the alarm name and optionally an instanceID.
   * Returns: Array of ActiveAlarmMutationResult objects with alarm name, instance ID, and error information
   * JSON Structure: [{ alarmName: string, alarmInstanceID: number, error?: { code, description } }]
   * Errors: 2 - Cannot resolve provided name, 304 - Invalid object state, 305 - Alarm cannot be acknowledged in current state
   */
  async acknowledgeAlarms(input) {
    const result = await this.client.request(MUTATIONS.ACKNOWLEDGE_ALARMS, { input });
    return result.acknowledgeAlarms;
  }

  /**
   * Reset one or more alarms. Each alarm identifier must have the alarm name and optionally an instanceID.
   * Returns: Array of ActiveAlarmMutationResult objects with alarm name, instance ID, and error information
   * JSON Structure: [{ alarmName: string, alarmInstanceID: number, error?: { code, description } }]
   * Errors: 2 - Cannot resolve provided name, 304 - Invalid object state, 305 - Alarm cannot be reset in current state
   */
  async resetAlarms(input) {
    const result = await this.client.request(MUTATIONS.RESET_ALARMS, { input });
    return result.resetAlarms;
  }

  /**
   * Disable the creation of new alarm instances for one or more alarms.
   * Returns: Array of AlarmMutationResult objects with alarm name and error information
   * JSON Structure: [{ alarmName: string, error?: { code, description } }]
   * Errors: 2 - Cannot resolve provided name
   */
  async disableAlarms(names) {
    const result = await this.client.request(MUTATIONS.DISABLE_ALARMS, { names });
    return result.disableAlarms;
  }

  /**
   * Enable the creation of new alarm instances for one or more alarms.
   * Returns: Array of AlarmMutationResult objects with alarm name and error information
   * JSON Structure: [{ alarmName: string, error?: { code, description } }]
   * Errors: 2 - Cannot resolve provided name
   */
  async enableAlarms(names) {
    const result = await this.client.request(MUTATIONS.ENABLE_ALARMS, { names });
    return result.enableAlarms;
  }

  /**
   * Shelve all active alarm instances of the provided configured alarms. Uses runtime's configured shelving timeout if not specified.
   * Returns: Array of AlarmMutationResult objects with alarm name and error information
   * JSON Structure: [{ alarmName: string, error?: { code, description } }]
   * Errors: 2 - Cannot resolve provided name
   */
  async shelveAlarms(names, shelveTimeout = null) {
    const variables = { names };
    if (shelveTimeout) variables.shelveTimeout = shelveTimeout;
    
    const result = await this.client.request(MUTATIONS.SHELVE_ALARMS, variables);
    return result.shelveAlarms;
  }

  /**
   * Revert the Shelve action for the provided configured alarms. Unshelving causes a notification for all concerned alarm instances.
   * Returns: Array of AlarmMutationResult objects with alarm name and error information
   * JSON Structure: [{ alarmName: string, error?: { code, description } }]
   * Errors: 2 - Cannot resolve provided name
   */
  async unshelveAlarms(names) {
    const result = await this.client.request(MUTATIONS.UNSHELVE_ALARMS, { names });
    return result.unshelveAlarms;
  }

  /**
   * Subscribes to tag values for the tags based on the provided names list. Notifications contain reason (Added, Modified, Removed, Removed (Name changed)).
   * Returns: Subscription object with unsubscribe method
   * Callback receives: TagValueNotification object { name: string, value: { value: variant, timestamp: timestamp, quality: Quality }, error?: { code, description }, notificationReason: string }
   * Errors: 2 - Cannot resolve provided name, 202 - Only leaf elements of a Structure Tag can be addressed
   */
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

  /**
   * Subscribe for active alarms matching the given filters. Notifications contain reason (Added, Modified, Removed).
   * Returns: Subscription object with unsubscribe method
   * Callback receives: ActiveAlarmNotification object with all ActiveAlarm fields plus notificationReason: string
   * Errors: 301 - Syntax error in query string, 302 - Invalid language, 303 - Invalid filter language
   */
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

  /**
   * Subscribes to redu state. Notifications contain information about the active/passive state of the system on state changes.
   * Returns: Subscription object with unsubscribe method
   * Callback receives: ReduStateNotification object { value: { value: ReduState (ACTIVE | PASSIVE), timestamp: timestamp }, notificationReason: string }
   */
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

// Export for Node.js
module.exports = {
  WinCCUnifiedNode,
  GraphQLClient,
  GraphQLWSClient,
  QUERIES,
  MUTATIONS,
  SUBSCRIPTIONS
};