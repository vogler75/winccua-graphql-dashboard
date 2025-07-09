package com.siemens.wincc.unified;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Main WinCC Unified client for Java
 * Provides synchronous access to WinCC Unified GraphQL API
 */
public class WinCCUnifiedClient implements AutoCloseable {
    private static final Logger logger = LoggerFactory.getLogger(WinCCUnifiedClient.class);
    
    private final GraphQLClient client;
    private String token;
    
    public WinCCUnifiedClient(String httpUrl, String wsUrl) {
        this.client = new GraphQLClient(httpUrl, wsUrl);
    }
    
    public void setToken(String token) {
        this.token = token;
        client.setToken(token);
    }
    
    /**
     * Logs a user in based on their username and password.
     * Returns: Session object containing user info, token, and expiry timestamp
     * JSON Structure: { user: { id, name, groups, fullName, language, autoLogoffSec }, token: string, expires: timestamp, error?: { code, description } }
     * Errors: 101 - Incorrect credentials provided, 102 - UMC error
     */
    public Map<String, Object> login(String username, String password) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("username", username);
        variables.put("password", password);
        
        Map<String, Object> result = client.request(GraphQLQueries.MUTATIONS.LOGIN, variables);
        
        @SuppressWarnings("unchecked")
        Map<String, Object> loginResult = (Map<String, Object>) result.get("login");
        
        if (loginResult != null && loginResult.get("token") != null) {
            this.token = (String) loginResult.get("token");
            client.setToken(this.token);
            return loginResult;
        }
        
        String errorMsg = "Unknown error";
        if (loginResult != null && loginResult.get("error") != null) {
            @SuppressWarnings("unchecked")
            Map<String, Object> error = (Map<String, Object>) loginResult.get("error");
            errorMsg = (String) error.get("description");
        }
        throw new IOException("Login failed: " + errorMsg);
    }
    
    /**
     * Returns information about the current session. If allSessions is true, returns all sessions of the current user.
     * Returns: Array of Session objects with user info, token, and expiry timestamp
     * JSON Structure: [{ user: { id, name, groups, fullName, language, autoLogoffSec }, token: string, expires: timestamp, error?: { code, description } }]
     */
    public List<Map<String, Object>> getSession(boolean allSessions) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("allSessions", allSessions);
        
        Map<String, Object> result = client.request(GraphQLQueries.QUERIES.SESSION, variables);
        
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> session = (List<Map<String, Object>>) result.get("session");
        return session;
    }
    
    public List<Map<String, Object>> getSession() throws IOException {
        return getSession(false);
    }
    
    /**
     * Queries tag values based on the provided names list. If directRead is true, values are taken directly from PLC.
     * Returns: Array of TagValueResult objects with tag name, value, and quality information
     * JSON Structure: [{ name: string, value: { value: variant, timestamp: timestamp, quality: { quality, subStatus, limit, extendedSubStatus, sourceQuality, sourceTime, timeCorrected } }, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name, 202 - Only leaf elements of a Structure Tag can be addressed
     */
    public List<Map<String, Object>> getTagValues(List<String> names, boolean directRead) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("names", names);
        variables.put("directRead", directRead);
        
        Map<String, Object> result = client.request(GraphQLQueries.QUERIES.TAG_VALUES, variables);
        
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> tagValues = (List<Map<String, Object>>) result.get("tagValues");
        return tagValues;
    }
    
    public List<Map<String, Object>> getTagValues(List<String> names) throws IOException {
        return getTagValues(names, false);
    }
    
    /**
     * Queries logged tag values from the database. Names must be LoggingTag names or Tag names (if only one logging tag exists).
     * Returns: Array of LoggedTagValuesResult objects with logging tag name, error info, and array of logged values
     * JSON Structure: [{ loggingTagName: string, error?: { code, description }, values: [{ value: { value: variant, timestamp: timestamp, quality: quality }, flags: [flag_enum] }] }]
     * Sorting modes: TIME_ASC, TIME_DESC. Bounding modes: NO_BOUNDING_VALUES, LEFT_BOUNDING_VALUES, RIGHT_BOUNDING_VALUES, LEFTRIGHT_BOUNDING_VALUES
     * Errors: 1 - Generic error, 2 - Cannot resolve provided name, 3 - Argument error
     */
    public List<Map<String, Object>> getLoggedTagValues(List<String> names, String startTime, String endTime, int maxNumberOfValues, String sortingMode) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("names", names);
        variables.put("maxNumberOfValues", maxNumberOfValues);
        variables.put("sortingMode", sortingMode);
        
        if (startTime != null) {
            variables.put("startTime", startTime);
        }
        if (endTime != null) {
            variables.put("endTime", endTime);
        }
        
        Map<String, Object> result = client.request(GraphQLQueries.QUERIES.LOGGED_TAG_VALUES, variables);
        
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> loggedTagValues = (List<Map<String, Object>>) result.get("loggedTagValues");
        return loggedTagValues;
    }
    
    public List<Map<String, Object>> getLoggedTagValues(List<String> names, String startTime, String endTime, int maxNumberOfValues) throws IOException {
        return getLoggedTagValues(names, startTime, endTime, maxNumberOfValues, "TIME_ASC");
    }
    
    /**
     * Returns a nonce that can be used with e.g. the UMC SWAC login method.
     * Returns: Nonce object with value and validity duration
     * JSON Structure: { value: string, validFor: number }
     */
    public Map<String, Object> getNonce() throws IOException {
        Map<String, Object> result = client.request(GraphQLQueries.QUERIES.NONCE, null);
        
        @SuppressWarnings("unchecked")
        Map<String, Object> nonce = (Map<String, Object>) result.get("nonce");
        return nonce;
    }
    
    /**
     * Returns the URL of the identity provider for UMC SWAC authentication.
     * Returns: String URL where user should be redirected for SWAC login
     * JSON Structure: string (URL)
     */
    public String getIdentityProviderURL() throws IOException {
        Map<String, Object> result = client.request(GraphQLQueries.QUERIES.IDENTITY_PROVIDER_URL, null);
        return (String) result.get("identityProviderURL");
    }
    
    /**
     * Queries tags, elements, types, alarms, logging tags based on filter criteria. Each filter parameter supports arrays with OR relation, while parameters have AND relation.
     * Returns: Array of BrowseTagsResult objects with name, display name, object type, and data type
     * JSON Structure: [{ name: string, displayName: string, objectType: string, dataType: string }]
     * ObjectTypes: TAG, SIMPLETAG, STRUCTURETAG, TAGTYPE, STRUCTURETAGTYPE, SIMPLETAGTYPE, ALARM, ALARMCLASS, LOGGINGTAG
     * Errors: 1 - Generic error, 2 - Cannot resolve provided name, 3 - Argument error
     */
    public List<Map<String, Object>> browse(List<String> nameFilters, List<String> objectTypeFilters, List<String> baseTypeFilters, String language) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("nameFilters", nameFilters);
        variables.put("objectTypeFilters", objectTypeFilters);
        variables.put("baseTypeFilters", baseTypeFilters);
        variables.put("language", language);
        
        Map<String, Object> result = client.request(GraphQLQueries.QUERIES.BROWSE, variables);
        
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> browse = (List<Map<String, Object>>) result.get("browse");
        return browse;
    }
    
    public List<Map<String, Object>> browse() throws IOException {
        return browse(List.of(), List.of(), List.of(), "en-US");
    }
    
    /**
     * Query active alarms from the provided systems using ChromQueryLanguage filter.
     * Returns: Array of ActiveAlarm objects with comprehensive alarm information
     * JSON Structure: [{ name: string, instanceID: number, alarmGroupID: number, raiseTime: timestamp, acknowledgmentTime: timestamp, clearTime: timestamp, resetTime: timestamp, modificationTime: timestamp, state: AlarmState, textColor: color, backColor: color, flashing: boolean, languages: [string], alarmClassName: string, alarmClassSymbol: [string], alarmClassID: number, stateMachine: AlarmStateMachine, priority: number, alarmParameterValues: [variant], alarmType: [string], eventText: [string], infoText: [string], alarmText1-9: [string], stateText: [string], origin: string, area: string, changeReason: [AlarmChangeReason], connectionName: string, valueLimit: variant, sourceType: AlarmSourceType, suppressionState: AlarmSuppressionState, hostName: string, userName: string, value: variant, valueQuality: Quality, quality: Quality, invalidFlags: AlarmInvalidFlags, deadBand: variant, producer: AlarmProducer, duration: timespan, durationIso: timespanIso, sourceID: string, systemSeverity: number, loopInAlarm: string, loopInAlarmParameterValues: variant, path: string, userResponse: AlarmUserResponse }]
     * Errors: 301 - Syntax error in query string, 302 - Invalid language, 303 - Invalid filter language
     */
    public List<Map<String, Object>> getActiveAlarms(List<String> systemNames, String filterString, String filterLanguage, List<String> languages) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("systemNames", systemNames);
        variables.put("filterString", filterString);
        variables.put("filterLanguage", filterLanguage);
        variables.put("languages", languages);
        
        Map<String, Object> result = client.request(GraphQLQueries.QUERIES.ACTIVE_ALARMS, variables);
        
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> activeAlarms = (List<Map<String, Object>>) result.get("activeAlarms");
        return activeAlarms;
    }
    
    public List<Map<String, Object>> getActiveAlarms() throws IOException {
        return getActiveAlarms(List.of(), "", "en-US", List.of("en-US"));
    }
    
    /**
     * Query logged alarms from the storage system using ChromQueryLanguage filter and time boundaries.
     * Returns: Array of LoggedAlarm objects with comprehensive historical alarm information
     * JSON Structure: [{ name: string, instanceID: number, alarmGroupID: number, raiseTime: timestamp, acknowledgmentTime: timestamp, clearTime: timestamp, resetTime: timestamp, modificationTime: timestamp, state: AlarmState, textColor: color, backColor: color, languages: [string], alarmClassName: string, alarmClassSymbol: [string], alarmClassID: number, stateMachine: AlarmStateMachine, priority: number, alarmParameterValues: [variant], alarmType: [string], eventText: [string], infoText: [string], alarmText1-9: [string], stateText: [string], origin: string, area: string, changeReason: [AlarmChangeReason], valueLimit: variant, sourceType: AlarmSourceType, suppressionState: AlarmSuppressionState, hostName: string, userName: string, value: variant, valueQuality: Quality, quality: Quality, invalidFlags: AlarmInvalidFlags, deadband: variant, producer: AlarmProducer, duration: timespan, durationIso: timespanIso, hasComments: boolean }]
     * Errors: 301 - Syntax error in query string, 302 - Invalid language (or not logged), 303 - Invalid filter language (or not logged)
     */
    public List<Map<String, Object>> getLoggedAlarms(List<String> systemNames, String filterString, String filterLanguage, List<String> languages, String startTime, String endTime, int maxNumberOfResults) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("systemNames", systemNames);
        variables.put("filterString", filterString);
        variables.put("filterLanguage", filterLanguage);
        variables.put("languages", languages);
        variables.put("maxNumberOfResults", maxNumberOfResults);
        
        if (startTime != null) {
            variables.put("startTime", startTime);
        }
        if (endTime != null) {
            variables.put("endTime", endTime);
        }
        
        Map<String, Object> result = client.request(GraphQLQueries.QUERIES.LOGGED_ALARMS, variables);
        
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> loggedAlarms = (List<Map<String, Object>>) result.get("loggedAlarms");
        return loggedAlarms;
    }
    
    public List<Map<String, Object>> getLoggedAlarms() throws IOException {
        return getLoggedAlarms(List.of(), "", "en-US", List.of("en-US"), null, null, 0);
    }
    
    /**
     * Logs a user in based on the claim and signed claim from UMC SWAC authentication.
     * Returns: Session object containing user info, token, and expiry timestamp
     * JSON Structure: { user: { id, name, groups, fullName, language, autoLogoffSec }, token: string, expires: timestamp, error?: { code, description } }
     * Errors: 101 - Incorrect credentials provided, 103 - Nonce expired
     */
    public Map<String, Object> loginSWAC(String claim, String signedClaim) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("claim", claim);
        variables.put("signedClaim", signedClaim);
        
        Map<String, Object> result = client.request(GraphQLQueries.MUTATIONS.LOGIN_SWAC, variables);
        
        @SuppressWarnings("unchecked")
        Map<String, Object> loginResult = (Map<String, Object>) result.get("loginSWAC");
        
        if (loginResult != null && loginResult.get("token") != null) {
            this.token = (String) loginResult.get("token");
            client.setToken(this.token);
            return loginResult;
        }
        
        String errorMsg = "Unknown error";
        if (loginResult != null && loginResult.get("error") != null) {
            @SuppressWarnings("unchecked")
            Map<String, Object> error = (Map<String, Object>) loginResult.get("error");
            errorMsg = (String) error.get("description");
        }
        throw new IOException("SWAC login failed: " + errorMsg);
    }
    
    /**
     * Extends the user's current session expiry by the 'session expires' value from the identity provider (UMC).
     * Returns: Session object with updated expiry timestamp
     * JSON Structure: { user: { id, name, groups, fullName, language, autoLogoffSec }, token: string, expires: timestamp, error?: { code, description } }
     */
    public Map<String, Object> extendSession() throws IOException {
        Map<String, Object> result = client.request(GraphQLQueries.MUTATIONS.EXTEND_SESSION, null);
        
        @SuppressWarnings("unchecked")
        Map<String, Object> extendResult = (Map<String, Object>) result.get("extendSession");
        
        if (extendResult != null && extendResult.get("token") != null) {
            this.token = (String) extendResult.get("token");
            client.setToken(this.token);
            return extendResult;
        }
        
        String errorMsg = "Unknown error";
        if (extendResult != null && extendResult.get("error") != null) {
            @SuppressWarnings("unchecked")
            Map<String, Object> error = (Map<String, Object>) extendResult.get("error");
            errorMsg = (String) error.get("description");
        }
        throw new IOException("Session extension failed: " + errorMsg);
    }
    
    /**
     * Logs out the current user. If allSessions is true, all sessions of the current user will be terminated.
     * Returns: Boolean indicating success
     * JSON Structure: boolean
     */
    public boolean logout(boolean allSessions) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("allSessions", allSessions);
        
        Map<String, Object> result = client.request(GraphQLQueries.MUTATIONS.LOGOUT, variables);
        
        this.token = null;
        client.setToken(null);
        
        return (Boolean) result.get("logout");
    }
    
    public boolean logout() throws IOException {
        return logout(false);
    }
    
    /**
     * Updates tags based on the provided TagValueInput list. Uses fallback timestamp and quality if not specified per tag.
     * Returns: Array of WriteTagValuesResult objects with tag name and error information
     * JSON Structure: [{ name: string, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name, 201 - Cannot convert provided value to data type, 202 - Only leaf elements of a Structure Tag can be addressed
     */
    public List<Map<String, Object>> writeTagValues(List<Map<String, Object>> input, String timestamp, Map<String, Object> quality) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("input", input);
        
        if (timestamp != null) {
            variables.put("timestamp", timestamp);
        }
        if (quality != null) {
            variables.put("quality", quality);
        }
        
        Map<String, Object> result = client.request(GraphQLQueries.MUTATIONS.WRITE_TAG_VALUES, variables);
        
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> writeTagValues = (List<Map<String, Object>>) result.get("writeTagValues");
        return writeTagValues;
    }
    
    public List<Map<String, Object>> writeTagValues(List<Map<String, Object>> input) throws IOException {
        return writeTagValues(input, null, null);
    }
    
    /**
     * Acknowledge one or more alarms. Each alarm identifier must have the alarm name and optionally an instanceID.
     * Returns: Array of ActiveAlarmMutationResult objects with alarm name, instance ID, and error information
     * JSON Structure: [{ alarmName: string, alarmInstanceID: number, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name, 304 - Invalid object state, 305 - Alarm cannot be acknowledged in current state
     */
    public List<Map<String, Object>> acknowledgeAlarms(List<Map<String, Object>> input) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("input", input);
        
        Map<String, Object> result = client.request(GraphQLQueries.MUTATIONS.ACKNOWLEDGE_ALARMS, variables);
        
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> acknowledgeAlarms = (List<Map<String, Object>>) result.get("acknowledgeAlarms");
        return acknowledgeAlarms;
    }
    
    /**
     * Reset one or more alarms. Each alarm identifier must have the alarm name and optionally an instanceID.
     * Returns: Array of ActiveAlarmMutationResult objects with alarm name, instance ID, and error information
     * JSON Structure: [{ alarmName: string, alarmInstanceID: number, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name, 304 - Invalid object state, 305 - Alarm cannot be reset in current state
     */
    public List<Map<String, Object>> resetAlarms(List<Map<String, Object>> input) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("input", input);
        
        Map<String, Object> result = client.request(GraphQLQueries.MUTATIONS.RESET_ALARMS, variables);
        
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> resetAlarms = (List<Map<String, Object>>) result.get("resetAlarms");
        return resetAlarms;
    }
    
    /**
     * Disable the creation of new alarm instances for one or more alarms.
     * Returns: Array of AlarmMutationResult objects with alarm name and error information
     * JSON Structure: [{ alarmName: string, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name
     */
    public List<Map<String, Object>> disableAlarms(List<String> names) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("names", names);
        
        Map<String, Object> result = client.request(GraphQLQueries.MUTATIONS.DISABLE_ALARMS, variables);
        
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> disableAlarms = (List<Map<String, Object>>) result.get("disableAlarms");
        return disableAlarms;
    }
    
    /**
     * Enable the creation of new alarm instances for one or more alarms.
     * Returns: Array of AlarmMutationResult objects with alarm name and error information
     * JSON Structure: [{ alarmName: string, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name
     */
    public List<Map<String, Object>> enableAlarms(List<String> names) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("names", names);
        
        Map<String, Object> result = client.request(GraphQLQueries.MUTATIONS.ENABLE_ALARMS, variables);
        
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> enableAlarms = (List<Map<String, Object>>) result.get("enableAlarms");
        return enableAlarms;
    }
    
    /**
     * Shelve all active alarm instances of the provided configured alarms. Uses runtime's configured shelving timeout if not specified.
     * Returns: Array of AlarmMutationResult objects with alarm name and error information
     * JSON Structure: [{ alarmName: string, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name
     */
    public List<Map<String, Object>> shelveAlarms(List<String> names, String shelveTimeout) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("names", names);
        
        if (shelveTimeout != null) {
            variables.put("shelveTimeout", shelveTimeout);
        }
        
        Map<String, Object> result = client.request(GraphQLQueries.MUTATIONS.SHELVE_ALARMS, variables);
        
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> shelveAlarms = (List<Map<String, Object>>) result.get("shelveAlarms");
        return shelveAlarms;
    }
    
    public List<Map<String, Object>> shelveAlarms(List<String> names) throws IOException {
        return shelveAlarms(names, null);
    }
    
    /**
     * Revert the Shelve action for the provided configured alarms. Unshelving causes a notification for all concerned alarm instances.
     * Returns: Array of AlarmMutationResult objects with alarm name and error information
     * JSON Structure: [{ alarmName: string, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name
     */
    public List<Map<String, Object>> unshelveAlarms(List<String> names) throws IOException {
        Map<String, Object> variables = new HashMap<>();
        variables.put("names", names);
        
        Map<String, Object> result = client.request(GraphQLQueries.MUTATIONS.UNSHELVE_ALARMS, variables);
        
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> unshelveAlarms = (List<Map<String, Object>>) result.get("unshelveAlarms");
        return unshelveAlarms;
    }
    
    /**
     * Subscribes to tag values for the tags based on the provided names list. Notifications contain reason (Added, Modified, Removed, Removed (Name changed)).
     * Returns: Subscription object with unsubscribe method
     * Callback receives: TagValueNotification object { name: string, value: { value: variant, timestamp: timestamp, quality: Quality }, error?: { code, description }, notificationReason: string }
     * Errors: 2 - Cannot resolve provided name, 202 - Only leaf elements of a Structure Tag can be addressed
     */
    public Subscription subscribeToTagValues(List<String> names, SubscriptionCallbacks callbacks) {
        Map<String, Object> variables = new HashMap<>();
        variables.put("names", names);
        
        return client.subscribe(GraphQLQueries.SUBSCRIPTIONS.TAG_VALUES, variables, callbacks);
    }
    
    /**
     * Subscribe for active alarms matching the given filters. Notifications contain reason (Added, Modified, Removed).
     * Returns: Subscription object with unsubscribe method
     * Callback receives: ActiveAlarmNotification object with all ActiveAlarm fields plus notificationReason: string
     * Errors: 301 - Syntax error in query string, 302 - Invalid language, 303 - Invalid filter language
     */
    public Subscription subscribeToActiveAlarms(List<String> systemNames, String filterString, String filterLanguage, List<String> languages, SubscriptionCallbacks callbacks) {
        Map<String, Object> variables = new HashMap<>();
        variables.put("systemNames", systemNames);
        variables.put("filterString", filterString);
        variables.put("filterLanguage", filterLanguage);
        variables.put("languages", languages);
        
        return client.subscribe(GraphQLQueries.SUBSCRIPTIONS.ACTIVE_ALARMS, variables, callbacks);
    }
    
    public Subscription subscribeToActiveAlarms(SubscriptionCallbacks callbacks) {
        return subscribeToActiveAlarms(List.of(), "", "en-US", List.of("en-US"), callbacks);
    }
    
    /**
     * Subscribes to redu state. Notifications contain information about the active/passive state of the system on state changes.
     * Returns: Subscription object with unsubscribe method
     * Callback receives: ReduStateNotification object { value: { value: ReduState (ACTIVE | PASSIVE), timestamp: timestamp }, notificationReason: string }
     */
    public Subscription subscribeToReduState(SubscriptionCallbacks callbacks) {
        return client.subscribe(GraphQLQueries.SUBSCRIPTIONS.REDU_STATE, null, callbacks);
    }
    
    @Override
    public void close() {
        client.close();
    }
}