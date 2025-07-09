package com.siemens.wincc.unified;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Async wrapper for WinCC Unified client providing CompletableFuture-based async operations
 * All methods return CompletableFuture objects for non-blocking operations
 */
public class WinCCUnifiedAsyncClient implements AutoCloseable {
    private static final Logger logger = LoggerFactory.getLogger(WinCCUnifiedAsyncClient.class);
    
    private final WinCCUnifiedClient syncClient;
    private final ExecutorService executor;
    
    public WinCCUnifiedAsyncClient(String httpUrl, String wsUrl) {
        this.syncClient = new WinCCUnifiedClient(httpUrl, wsUrl);
        this.executor = Executors.newCachedThreadPool();
    }
    
    public WinCCUnifiedAsyncClient(String httpUrl, String wsUrl, ExecutorService executor) {
        this.syncClient = new WinCCUnifiedClient(httpUrl, wsUrl);
        this.executor = executor;
    }
    
    public void setToken(String token) {
        syncClient.setToken(token);
    }
    
    /**
     * Asynchronously logs a user in based on their username and password.
     * Returns: CompletableFuture<Session> containing user info, token, and expiry timestamp
     * JSON Structure: { user: { id, name, groups, fullName, language, autoLogoffSec }, token: string, expires: timestamp, error?: { code, description } }
     * Errors: 101 - Incorrect credentials provided, 102 - UMC error
     */
    public CompletableFuture<Map<String, Object>> login(String username, String password) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.login(username, password);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    /**
     * Asynchronously returns information about the current session.
     * Returns: CompletableFuture<Array<Session>> with user info, token, and expiry timestamp
     * JSON Structure: [{ user: { id, name, groups, fullName, language, autoLogoffSec }, token: string, expires: timestamp, error?: { code, description } }]
     */
    public CompletableFuture<List<Map<String, Object>>> getSession(boolean allSessions) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.getSession(allSessions);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    public CompletableFuture<List<Map<String, Object>>> getSession() {
        return getSession(false);
    }
    
    /**
     * Asynchronously queries tag values based on the provided names list.
     * Returns: CompletableFuture<Array<TagValueResult>> with tag name, value, and quality information
     * JSON Structure: [{ name: string, value: { value: variant, timestamp: timestamp, quality: { quality, subStatus, limit, extendedSubStatus, sourceQuality, sourceTime, timeCorrected } }, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name, 202 - Only leaf elements of a Structure Tag can be addressed
     */
    public CompletableFuture<List<Map<String, Object>>> getTagValues(List<String> names, boolean directRead) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.getTagValues(names, directRead);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    public CompletableFuture<List<Map<String, Object>>> getTagValues(List<String> names) {
        return getTagValues(names, false);
    }
    
    /**
     * Asynchronously queries logged tag values from the database.
     * Returns: CompletableFuture<Array<LoggedTagValuesResult>> with logging tag name, error info, and array of logged values
     * JSON Structure: [{ loggingTagName: string, error?: { code, description }, values: [{ value: { value: variant, timestamp: timestamp, quality: quality }, flags: [flag_enum] }] }]
     * Sorting modes: TIME_ASC, TIME_DESC. Bounding modes: NO_BOUNDING_VALUES, LEFT_BOUNDING_VALUES, RIGHT_BOUNDING_VALUES, LEFTRIGHT_BOUNDING_VALUES
     * Errors: 1 - Generic error, 2 - Cannot resolve provided name, 3 - Argument error
     */
    public CompletableFuture<List<Map<String, Object>>> getLoggedTagValues(List<String> names, String startTime, String endTime, int maxNumberOfValues, String sortingMode) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.getLoggedTagValues(names, startTime, endTime, maxNumberOfValues, sortingMode);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    public CompletableFuture<List<Map<String, Object>>> getLoggedTagValues(List<String> names, String startTime, String endTime, int maxNumberOfValues) {
        return getLoggedTagValues(names, startTime, endTime, maxNumberOfValues, "TIME_ASC");
    }
    
    /**
     * Asynchronously returns a nonce that can be used with e.g. the UMC SWAC login method.
     * Returns: CompletableFuture<Nonce> with value and validity duration
     * JSON Structure: { value: string, validFor: number }
     */
    public CompletableFuture<Map<String, Object>> getNonce() {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.getNonce();
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    /**
     * Asynchronously returns the URL of the identity provider for UMC SWAC authentication.
     * Returns: CompletableFuture<String> URL where user should be redirected for SWAC login
     * JSON Structure: string (URL)
     */
    public CompletableFuture<String> getIdentityProviderURL() {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.getIdentityProviderURL();
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    /**
     * Asynchronously queries tags, elements, types, alarms, logging tags based on filter criteria.
     * Returns: CompletableFuture<Array<BrowseTagsResult>> with name, display name, object type, and data type
     * JSON Structure: [{ name: string, displayName: string, objectType: string, dataType: string }]
     * ObjectTypes: TAG, SIMPLETAG, STRUCTURETAG, TAGTYPE, STRUCTURETAGTYPE, SIMPLETAGTYPE, ALARM, ALARMCLASS, LOGGINGTAG
     * Errors: 1 - Generic error, 2 - Cannot resolve provided name, 3 - Argument error
     */
    public CompletableFuture<List<Map<String, Object>>> browse(List<String> nameFilters, List<String> objectTypeFilters, List<String> baseTypeFilters, String language) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.browse(nameFilters, objectTypeFilters, baseTypeFilters, language);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    public CompletableFuture<List<Map<String, Object>>> browse() {
        return browse(List.of(), List.of(), List.of(), "en-US");
    }
    
    /**
     * Asynchronously query active alarms from the provided systems using ChromQueryLanguage filter.
     * Returns: CompletableFuture<Array<ActiveAlarm>> with comprehensive alarm information
     * JSON Structure: [{ name: string, instanceID: number, alarmGroupID: number, raiseTime: timestamp, acknowledgmentTime: timestamp, clearTime: timestamp, resetTime: timestamp, modificationTime: timestamp, state: AlarmState, textColor: color, backColor: color, flashing: boolean, languages: [string], alarmClassName: string, alarmClassSymbol: [string], alarmClassID: number, stateMachine: AlarmStateMachine, priority: number, alarmParameterValues: [variant], alarmType: [string], eventText: [string], infoText: [string], alarmText1-9: [string], stateText: [string], origin: string, area: string, changeReason: [AlarmChangeReason], connectionName: string, valueLimit: variant, sourceType: AlarmSourceType, suppressionState: AlarmSuppressionState, hostName: string, userName: string, value: variant, valueQuality: Quality, quality: Quality, invalidFlags: AlarmInvalidFlags, deadBand: variant, producer: AlarmProducer, duration: timespan, durationIso: timespanIso, sourceID: string, systemSeverity: number, loopInAlarm: string, loopInAlarmParameterValues: variant, path: string, userResponse: AlarmUserResponse }]
     * Errors: 301 - Syntax error in query string, 302 - Invalid language, 303 - Invalid filter language
     */
    public CompletableFuture<List<Map<String, Object>>> getActiveAlarms(List<String> systemNames, String filterString, String filterLanguage, List<String> languages) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.getActiveAlarms(systemNames, filterString, filterLanguage, languages);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    public CompletableFuture<List<Map<String, Object>>> getActiveAlarms() {
        return getActiveAlarms(List.of(), "", "en-US", List.of("en-US"));
    }
    
    /**
     * Asynchronously query logged alarms from the storage system using ChromQueryLanguage filter and time boundaries.
     * Returns: CompletableFuture<Array<LoggedAlarm>> with comprehensive historical alarm information
     * JSON Structure: [{ name: string, instanceID: number, alarmGroupID: number, raiseTime: timestamp, acknowledgmentTime: timestamp, clearTime: timestamp, resetTime: timestamp, modificationTime: timestamp, state: AlarmState, textColor: color, backColor: color, languages: [string], alarmClassName: string, alarmClassSymbol: [string], alarmClassID: number, stateMachine: AlarmStateMachine, priority: number, alarmParameterValues: [variant], alarmType: [string], eventText: [string], infoText: [string], alarmText1-9: [string], stateText: [string], origin: string, area: string, changeReason: [AlarmChangeReason], valueLimit: variant, sourceType: AlarmSourceType, suppressionState: AlarmSuppressionState, hostName: string, userName: string, value: variant, valueQuality: Quality, quality: Quality, invalidFlags: AlarmInvalidFlags, deadband: variant, producer: AlarmProducer, duration: timespan, durationIso: timespanIso, hasComments: boolean }]
     * Errors: 301 - Syntax error in query string, 302 - Invalid language (or not logged), 303 - Invalid filter language (or not logged)
     */
    public CompletableFuture<List<Map<String, Object>>> getLoggedAlarms(List<String> systemNames, String filterString, String filterLanguage, List<String> languages, String startTime, String endTime, int maxNumberOfResults) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.getLoggedAlarms(systemNames, filterString, filterLanguage, languages, startTime, endTime, maxNumberOfResults);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    public CompletableFuture<List<Map<String, Object>>> getLoggedAlarms() {
        return getLoggedAlarms(List.of(), "", "en-US", List.of("en-US"), null, null, 0);
    }
    
    /**
     * Asynchronously logs a user in based on the claim and signed claim from UMC SWAC authentication.
     * Returns: CompletableFuture<Session> containing user info, token, and expiry timestamp
     * JSON Structure: { user: { id, name, groups, fullName, language, autoLogoffSec }, token: string, expires: timestamp, error?: { code, description } }
     * Errors: 101 - Incorrect credentials provided, 103 - Nonce expired
     */
    public CompletableFuture<Map<String, Object>> loginSWAC(String claim, String signedClaim) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.loginSWAC(claim, signedClaim);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    /**
     * Asynchronously extends the user's current session expiry by the 'session expires' value from the identity provider (UMC).
     * Returns: CompletableFuture<Session> with updated expiry timestamp
     * JSON Structure: { user: { id, name, groups, fullName, language, autoLogoffSec }, token: string, expires: timestamp, error?: { code, description } }
     */
    public CompletableFuture<Map<String, Object>> extendSession() {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.extendSession();
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    /**
     * Asynchronously logs out the current user. If allSessions is true, all sessions of the current user will be terminated.
     * Returns: CompletableFuture<Boolean> indicating success
     * JSON Structure: boolean
     */
    public CompletableFuture<Boolean> logout(boolean allSessions) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.logout(allSessions);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    public CompletableFuture<Boolean> logout() {
        return logout(false);
    }
    
    /**
     * Asynchronously updates tags based on the provided TagValueInput list.
     * Returns: CompletableFuture<Array<WriteTagValuesResult>> with tag name and error information
     * JSON Structure: [{ name: string, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name, 201 - Cannot convert provided value to data type, 202 - Only leaf elements of a Structure Tag can be addressed
     */
    public CompletableFuture<List<Map<String, Object>>> writeTagValues(List<Map<String, Object>> input, String timestamp, Map<String, Object> quality) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.writeTagValues(input, timestamp, quality);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    public CompletableFuture<List<Map<String, Object>>> writeTagValues(List<Map<String, Object>> input) {
        return writeTagValues(input, null, null);
    }
    
    /**
     * Asynchronously acknowledge one or more alarms.
     * Returns: CompletableFuture<Array<ActiveAlarmMutationResult>> with alarm name, instance ID, and error information
     * JSON Structure: [{ alarmName: string, alarmInstanceID: number, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name, 304 - Invalid object state, 305 - Alarm cannot be acknowledged in current state
     */
    public CompletableFuture<List<Map<String, Object>>> acknowledgeAlarms(List<Map<String, Object>> input) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.acknowledgeAlarms(input);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    /**
     * Asynchronously reset one or more alarms.
     * Returns: CompletableFuture<Array<ActiveAlarmMutationResult>> with alarm name, instance ID, and error information
     * JSON Structure: [{ alarmName: string, alarmInstanceID: number, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name, 304 - Invalid object state, 305 - Alarm cannot be reset in current state
     */
    public CompletableFuture<List<Map<String, Object>>> resetAlarms(List<Map<String, Object>> input) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.resetAlarms(input);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    /**
     * Asynchronously disable the creation of new alarm instances for one or more alarms.
     * Returns: CompletableFuture<Array<AlarmMutationResult>> with alarm name and error information
     * JSON Structure: [{ alarmName: string, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name
     */
    public CompletableFuture<List<Map<String, Object>>> disableAlarms(List<String> names) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.disableAlarms(names);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    /**
     * Asynchronously enable the creation of new alarm instances for one or more alarms.
     * Returns: CompletableFuture<Array<AlarmMutationResult>> with alarm name and error information
     * JSON Structure: [{ alarmName: string, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name
     */
    public CompletableFuture<List<Map<String, Object>>> enableAlarms(List<String> names) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.enableAlarms(names);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    /**
     * Asynchronously shelve all active alarm instances of the provided configured alarms.
     * Returns: CompletableFuture<Array<AlarmMutationResult>> with alarm name and error information
     * JSON Structure: [{ alarmName: string, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name
     */
    public CompletableFuture<List<Map<String, Object>>> shelveAlarms(List<String> names, String shelveTimeout) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.shelveAlarms(names, shelveTimeout);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    public CompletableFuture<List<Map<String, Object>>> shelveAlarms(List<String> names) {
        return shelveAlarms(names, null);
    }
    
    /**
     * Asynchronously revert the Shelve action for the provided configured alarms.
     * Returns: CompletableFuture<Array<AlarmMutationResult>> with alarm name and error information
     * JSON Structure: [{ alarmName: string, error?: { code, description } }]
     * Errors: 2 - Cannot resolve provided name
     */
    public CompletableFuture<List<Map<String, Object>>> unshelveAlarms(List<String> names) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return syncClient.unshelveAlarms(names);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }, executor);
    }
    
    /**
     * Subscribes to tag values for the tags based on the provided names list. This method is already async via websockets.
     * Returns: Subscription object with unsubscribe method
     * Callback receives: TagValueNotification object { name: string, value: { value: variant, timestamp: timestamp, quality: Quality }, error?: { code, description }, notificationReason: string }
     * Errors: 2 - Cannot resolve provided name, 202 - Only leaf elements of a Structure Tag can be addressed
     */
    public Subscription subscribeToTagValues(List<String> names, SubscriptionCallbacks callbacks) {
        return syncClient.subscribeToTagValues(names, callbacks);
    }
    
    /**
     * Subscribe for active alarms matching the given filters. This method is already async via websockets.
     * Returns: Subscription object with unsubscribe method
     * Callback receives: ActiveAlarmNotification object with all ActiveAlarm fields plus notificationReason: string
     * Errors: 301 - Syntax error in query string, 302 - Invalid language, 303 - Invalid filter language
     */
    public Subscription subscribeToActiveAlarms(List<String> systemNames, String filterString, String filterLanguage, List<String> languages, SubscriptionCallbacks callbacks) {
        return syncClient.subscribeToActiveAlarms(systemNames, filterString, filterLanguage, languages, callbacks);
    }
    
    public Subscription subscribeToActiveAlarms(SubscriptionCallbacks callbacks) {
        return subscribeToActiveAlarms(List.of(), "", "en-US", List.of("en-US"), callbacks);
    }
    
    /**
     * Subscribes to redu state. This method is already async via websockets.
     * Returns: Subscription object with unsubscribe method
     * Callback receives: ReduStateNotification object { value: { value: ReduState (ACTIVE | PASSIVE), timestamp: timestamp }, notificationReason: string }
     */
    public Subscription subscribeToReduState(SubscriptionCallbacks callbacks) {
        return syncClient.subscribeToReduState(callbacks);
    }
    
    @Override
    public void close() {
        syncClient.close();
        executor.shutdown();
    }
}