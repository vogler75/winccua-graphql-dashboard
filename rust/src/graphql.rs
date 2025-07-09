//! GraphQL queries, mutations, and subscriptions for WinCC Unified API

/// GraphQL queries
pub mod queries {
    pub const SESSION: &str = r#"
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
    "#;

    pub const NONCE: &str = r#"
        query Nonce {
            nonce {
                value
                validFor
            }
        }
    "#;

    pub const IDENTITY_PROVIDER_URL: &str = r#"
        query IdentityProviderURL {
            identityProviderURL
        }
    "#;

    pub const TAG_VALUES: &str = r#"
        query TagValues($names: [String!]!, $directRead: Boolean = false) {
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
    "#;

    pub const LOGGED_TAG_VALUES: &str = r#"
        query LoggedTagValues($names: [String]!, $startTime: Timestamp, $endTime: Timestamp, $maxNumberOfValues: Int = 0, $sortingMode: LoggedTagValuesSortingModeEnum = TIME_ASC, $boundingValuesMode: LoggedTagValuesBoundingModeEnum = NO_BOUNDING_VALUES) {
            loggedTagValues(names: $names, startTime: $startTime, endTime: $endTime, maxNumberOfValues: $maxNumberOfValues, sortingMode: $sortingMode, boundingValuesMode: $boundingValuesMode) {
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
    "#;

    pub const BROWSE: &str = r#"
        query Browse($nameFilters: [String] = [], $objectTypeFilters: [ObjectTypesEnum] = [], $baseTypeFilters: [String] = [], $language: String = "en-US") {
            browse(nameFilters: $nameFilters, objectTypeFilters: $objectTypeFilters, baseTypeFilters: $baseTypeFilters, language: $language) {
                name
                displayName
                objectType
                dataType
            }
        }
    "#;

    pub const ACTIVE_ALARMS: &str = r#"
        query ActiveAlarms($systemNames: [String] = [], $filterString: String = "", $filterLanguage: String = "en-US", $languages: [String] = ["en-US"]) {
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
    "#;

    pub const LOGGED_ALARMS: &str = r#"
        query LoggedAlarms($systemNames: [String] = [], $filterString: String = "", $filterLanguage: String = "en-US", $languages: [String] = ["en-US"], $startTime: Timestamp, $endTime: Timestamp, $maxNumberOfResults: Int = 0) {
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
    "#;
}

/// GraphQL mutations
pub mod mutations {
    pub const LOGIN: &str = r#"
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
    "#;

    pub const LOGIN_SWAC: &str = r#"
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
    "#;

    pub const EXTEND_SESSION: &str = r#"
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
    "#;

    pub const LOGOUT: &str = r#"
        mutation Logout($allSessions: Boolean) {
            logout(allSessions: $allSessions)
        }
    "#;

    pub const WRITE_TAG_VALUES: &str = r#"
        mutation WriteTagValues($input: [TagValueInput]!, $timestamp: Timestamp, $quality: QualityInput) {
            writeTagValues(input: $input, timestamp: $timestamp, quality: $quality) {
                name
                error {
                    code
                    description
                }
            }
        }
    "#;

    pub const ACKNOWLEDGE_ALARMS: &str = r#"
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
    "#;

    pub const RESET_ALARMS: &str = r#"
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
    "#;

    pub const DISABLE_ALARMS: &str = r#"
        mutation DisableAlarms($names: [String]!) {
            disableAlarms(names: $names) {
                alarmName
                error {
                    code
                    description
                }
            }
        }
    "#;

    pub const ENABLE_ALARMS: &str = r#"
        mutation EnableAlarms($names: [String]!) {
            enableAlarms(names: $names) {
                alarmName
                error {
                    code
                    description
                }
            }
        }
    "#;

    pub const SHELVE_ALARMS: &str = r#"
        mutation ShelveAlarms($names: [String]!, $shelveTimeout: Timespan = 0) {
            shelveAlarms(names: $names, shelveTimeout: $shelveTimeout) {
                alarmName
                error {
                    code
                    description
                }
            }
        }
    "#;

    pub const UNSHELVE_ALARMS: &str = r#"
        mutation UnshelveAlarms($names: [String]!) {
            unshelveAlarms(names: $names) {
                alarmName
                error {
                    code
                    description
                }
            }
        }
    "#;
}

/// GraphQL subscriptions
pub mod subscriptions {
    pub const TAG_VALUES: &str = r#"
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
    "#;

    pub const ACTIVE_ALARMS: &str = r#"
        subscription ActiveAlarms($systemNames: [String] = [], $filterString: String = "", $filterLanguage: String = "en-US", $languages: [String] = ["en-US"]) {
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
    "#;

    pub const REDU_STATE: &str = r#"
        subscription ReduState {
            reduState {
                value {
                    value
                    timestamp
                }
                notificationReason
            }
        }
    "#;
}