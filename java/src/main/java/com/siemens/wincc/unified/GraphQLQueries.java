package com.siemens.wincc.unified;

/**
 * GraphQL queries, mutations, and subscriptions for WinCC Unified
 * Based on the GraphQL schema definition
 */
public final class GraphQLQueries {
    
    // Queries
    public static final class QUERIES {
        public static final String SESSION = """
            query Session($allSessions: Boolean) {
                session(allSessions: $allSessions) {
                    user {
                        id
                        name
                        groups {
                            id
                            name
                        }
                        fullName
                        language
                        autoLogoffSec
                    }
                    token
                    expires
                    error {
                        code
                        description
                    }
                }
            }
            """;
        
        public static final String NONCE = """
            query Nonce {
                nonce {
                    value
                    validFor
                }
            }
            """;
        
        public static final String IDENTITY_PROVIDER_URL = """
            query IdentityProviderURL {
                identityProviderURL
            }
            """;
        
        public static final String TAG_VALUES = """
            query TagValues($names: [String!]!, $directRead: Boolean) {
                tagValues(names: $names, directRead: $directRead) {
                    name
                    value {
                        value
                        timestamp
                        quality {
                            quality
                            subStatus
                            limit
                            extendedSubStatus
                            sourceQuality
                            sourceTime
                            timeCorrected
                        }
                    }
                    error {
                        code
                        description
                    }
                }
            }
            """;
        
        public static final String LOGGED_TAG_VALUES = """
            query LoggedTagValues($names: [String]!, $startTime: Timestamp, $endTime: Timestamp, $maxNumberOfValues: Int, $sortingMode: LoggedTagValuesSortingModeEnum) {
                loggedTagValues(names: $names, startTime: $startTime, endTime: $endTime, maxNumberOfValues: $maxNumberOfValues, sortingMode: $sortingMode) {
                    loggingTagName
                    error {
                        code
                        description
                    }
                    values {
                        value {
                            value
                            timestamp
                            quality {
                                quality
                                subStatus
                                limit
                                extendedSubStatus
                                sourceQuality
                                sourceTime
                                timeCorrected
                            }
                        }
                        flags
                    }
                }
            }
            """;
        
        public static final String BROWSE = """
            query Browse($nameFilters: [String], $objectTypeFilters: [ObjectTypesEnum], $baseTypeFilters: [String], $language: String) {
                browse(nameFilters: $nameFilters, objectTypeFilters: $objectTypeFilters, baseTypeFilters: $baseTypeFilters, language: $language) {
                    name
                    displayName
                    objectType
                    dataType
                }
            }
            """;
        
        public static final String ACTIVE_ALARMS = """
            query ActiveAlarms($systemNames: [String], $filterString: String, $filterLanguage: String, $languages: [String]) {
                activeAlarms(systemNames: $systemNames, filterString: $filterString, filterLanguage: $filterLanguage, languages: $languages) {
                    name
                    instanceID
                    alarmGroupID
                    raiseTime
                    acknowledgmentTime
                    clearTime
                    resetTime
                    modificationTime
                    state
                    textColor
                    backColor
                    flashing
                    languages
                    alarmClassName
                    alarmClassSymbol
                    alarmClassID
                    stateMachine
                    priority
                    alarmParameterValues
                    alarmType
                    eventText
                    infoText
                    alarmText1
                    alarmText2
                    alarmText3
                    alarmText4
                    alarmText5
                    alarmText6
                    alarmText7
                    alarmText8
                    alarmText9
                    stateText
                    origin
                    area
                    changeReason
                    connectionName
                    valueLimit
                    sourceType
                    suppressionState
                    hostName
                    userName
                    value
                    valueQuality {
                        quality
                        subStatus
                        limit
                        extendedSubStatus
                        sourceQuality
                        sourceTime
                        timeCorrected
                    }
                    quality {
                        quality
                        subStatus
                        limit
                        extendedSubStatus
                        sourceQuality
                        sourceTime
                        timeCorrected
                    }
                    invalidFlags {
                        invalidConfiguration
                        invalidTimestamp
                        invalidAlarmParameter
                        invalidEventText
                    }
                    deadBand
                    producer
                    duration
                    durationIso
                    sourceID
                    systemSeverity
                    loopInAlarm
                    loopInAlarmParameterValues
                    path
                    userResponse
                }
            }
            """;
        
        public static final String LOGGED_ALARMS = """
            query LoggedAlarms($systemNames: [String], $filterString: String, $filterLanguage: String, $languages: [String], $startTime: Timestamp, $endTime: Timestamp, $maxNumberOfResults: Int) {
                loggedAlarms(systemNames: $systemNames, filterString: $filterString, filterLanguage: $filterLanguage, languages: $languages, startTime: $startTime, endTime: $endTime, maxNumberOfResults: $maxNumberOfResults) {
                    name
                    instanceID
                    alarmGroupID
                    raiseTime
                    acknowledgmentTime
                    clearTime
                    resetTime
                    modificationTime
                    state
                    textColor
                    backColor
                    languages
                    alarmClassName
                    alarmClassSymbol
                    alarmClassID
                    stateMachine
                    priority
                    alarmParameterValues
                    alarmType
                    eventText
                    infoText
                    alarmText1
                    alarmText2
                    alarmText3
                    alarmText4
                    alarmText5
                    alarmText6
                    alarmText7
                    alarmText8
                    alarmText9
                    stateText
                    origin
                    area
                    changeReason
                    valueLimit
                    sourceType
                    suppressionState
                    hostName
                    userName
                    value
                    valueQuality {
                        quality
                        subStatus
                        limit
                        extendedSubStatus
                        sourceQuality
                        sourceTime
                        timeCorrected
                    }
                    quality {
                        quality
                        subStatus
                        limit
                        extendedSubStatus
                        sourceQuality
                        sourceTime
                        timeCorrected
                    }
                    invalidFlags {
                        invalidConfiguration
                        invalidTimestamp
                        invalidAlarmParameter
                        invalidEventText
                    }
                    deadband
                    producer
                    duration
                    durationIso
                    hasComments
                }
            }
            """;
    }
    
    // Mutations
    public static final class MUTATIONS {
        public static final String LOGIN = """
            mutation Login($username: String!, $password: String!) {
                login(username: $username, password: $password) {
                    user {
                        id
                        name
                        groups {
                            id
                            name
                        }
                        fullName
                        language
                        autoLogoffSec
                    }
                    token
                    expires
                    error {
                        code
                        description
                    }
                }
            }
            """;
        
        public static final String LOGIN_SWAC = """
            mutation LoginSWAC($claim: String!, $signedClaim: String!) {
                loginSWAC(claim: $claim, signedClaim: $signedClaim) {
                    user {
                        id
                        name
                        groups {
                            id
                            name
                        }
                        fullName
                        language
                        autoLogoffSec
                    }
                    token
                    expires
                    error {
                        code
                        description
                    }
                }
            }
            """;
        
        public static final String EXTEND_SESSION = """
            mutation ExtendSession {
                extendSession {
                    user {
                        id
                        name
                        groups {
                            id
                            name
                        }
                        fullName
                        language
                        autoLogoffSec
                    }
                    token
                    expires
                    error {
                        code
                        description
                    }
                }
            }
            """;
        
        public static final String LOGOUT = """
            mutation Logout($allSessions: Boolean) {
                logout(allSessions: $allSessions)
            }
            """;
        
        public static final String WRITE_TAG_VALUES = """
            mutation WriteTagValues($input: [TagValueInput]!, $timestamp: Timestamp, $quality: QualityInput) {
                writeTagValues(input: $input, timestamp: $timestamp, quality: $quality) {
                    name
                    error {
                        code
                        description
                    }
                }
            }
            """;
        
        public static final String ACKNOWLEDGE_ALARMS = """
            mutation AcknowledgeAlarms($input: [AlarmIdentifierInput]!) {
                acknowledgeAlarms(input: $input) {
                    alarmName
                    alarmInstanceID
                    error {
                        code
                        description
                    }
                }
            }
            """;
        
        public static final String RESET_ALARMS = """
            mutation ResetAlarms($input: [AlarmIdentifierInput]!) {
                resetAlarms(input: $input) {
                    alarmName
                    alarmInstanceID
                    error {
                        code
                        description
                    }
                }
            }
            """;
        
        public static final String DISABLE_ALARMS = """
            mutation DisableAlarms($names: [String]!) {
                disableAlarms(names: $names) {
                    alarmName
                    error {
                        code
                        description
                    }
                }
            }
            """;
        
        public static final String ENABLE_ALARMS = """
            mutation EnableAlarms($names: [String]!) {
                enableAlarms(names: $names) {
                    alarmName
                    error {
                        code
                        description
                    }
                }
            }
            """;
        
        public static final String SHELVE_ALARMS = """
            mutation ShelveAlarms($names: [String]!, $shelveTimeout: Timespan) {
                shelveAlarms(names: $names, shelveTimeout: $shelveTimeout) {
                    alarmName
                    error {
                        code
                        description
                    }
                }
            }
            """;
        
        public static final String UNSHELVE_ALARMS = """
            mutation UnshelveAlarms($names: [String]!) {
                unshelveAlarms(names: $names) {
                    alarmName
                    error {
                        code
                        description
                    }
                }
            }
            """;
    }
    
    // Subscriptions
    public static final class SUBSCRIPTIONS {
        public static final String TAG_VALUES = """
            subscription TagValues($names: [String!]!) {
                tagValues(names: $names) {
                    name
                    value {
                        value
                        timestamp
                        quality {
                            quality
                            subStatus
                            limit
                            extendedSubStatus
                            sourceQuality
                            sourceTime
                            timeCorrected
                        }
                    }
                    error {
                        code
                        description
                    }
                    notificationReason
                }
            }
            """;
        
        public static final String ACTIVE_ALARMS = """
            subscription ActiveAlarms($systemNames: [String], $filterString: String, $filterLanguage: String, $languages: [String]) {
                activeAlarms(systemNames: $systemNames, filterString: $filterString, filterLanguage: $filterLanguage, languages: $languages) {
                    name
                    instanceID
                    alarmGroupID
                    raiseTime
                    acknowledgmentTime
                    clearTime
                    resetTime
                    modificationTime
                    state
                    textColor
                    backColor
                    flashing
                    languages
                    alarmClassName
                    alarmClassSymbol
                    alarmClassID
                    stateMachine
                    priority
                    alarmParameterValues
                    alarmType
                    eventText
                    infoText
                    alarmText1
                    alarmText2
                    alarmText3
                    alarmText4
                    alarmText5
                    alarmText6
                    alarmText7
                    alarmText8
                    alarmText9
                    stateText
                    origin
                    area
                    changeReason
                    connectionName
                    valueLimit
                    sourceType
                    suppressionState
                    hostName
                    userName
                    value
                    valueQuality {
                        quality
                        subStatus
                        limit
                        extendedSubStatus
                        sourceQuality
                        sourceTime
                        timeCorrected
                    }
                    quality {
                        quality
                        subStatus
                        limit
                        extendedSubStatus
                        sourceQuality
                        sourceTime
                        timeCorrected
                    }
                    invalidFlags {
                        invalidConfiguration
                        invalidTimestamp
                        invalidAlarmParameter
                        invalidEventText
                    }
                    deadBand
                    producer
                    duration
                    durationIso
                    sourceID
                    systemSeverity
                    loopInAlarm
                    loopInAlarmParameterValues
                    path
                    userResponse
                    notificationReason
                }
            }
            """;
        
        public static final String REDU_STATE = """
            subscription ReduState {
                reduState {
                    value {
                        value
                        timestamp
                    }
                    notificationReason
                }
            }
            """;
    }
    
    private GraphQLQueries() {
        // Utility class
    }
}