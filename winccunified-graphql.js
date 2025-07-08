// GraphQL Queries, Mutations, and Subscriptions for WinCC Unified
// Shared between browser and Node.js versions
// Version: 1.0.0

const QUERIES = {
  SESSION: `
    query GetSession($allSessions: Boolean) {
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
  `,

  TAG_VALUES: `
    query GetTagValues($names: [String!]!, $directRead: Boolean = false) {
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
  `,

  LOGGED_TAG_VALUES: `
    query GetLoggedTagValues($names: [String!]!, $startTime: Timestamp, $endTime: Timestamp, $maxNumberOfValues: Int, $sortingMode: LoggedTagValuesSortingModeEnum) {
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
            }
          }
        }
      }
    }
  `,

  NONCE: `
    query GetNonce {
      nonce {
        value
        validFor
      }
    }
  `,

  IDENTITY_PROVIDER_URL: `
    query GetIdentityProviderURL {
      identityProviderURL
    }
  `,

  BROWSE: `
    query Browse($nameFilters: [String], $objectTypeFilters: [ObjectTypesEnum], $baseTypeFilters: [String], $language: String) {
      browse(nameFilters: $nameFilters, objectTypeFilters: $objectTypeFilters, baseTypeFilters: $baseTypeFilters, language: $language) {
        name
        displayName
        objectType
        dataType
      }
    }
  `,

  ACTIVE_ALARMS: `
    query GetActiveAlarms($systemNames: [String], $filterString: String, $filterLanguage: String, $languages: [String]) {
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
  `,

  LOGGED_ALARMS: `
    query GetLoggedAlarms($systemNames: [String], $filterString: String, $filterLanguage: String, $languages: [String], $startTime: Timestamp, $endTime: Timestamp, $maxNumberOfResults: Int) {
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
  `
};

const MUTATIONS = {
  LOGIN: `
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
  `,

  LOGIN_SWAC: `
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
  `,

  EXTEND_SESSION: `
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
  `,

  LOGOUT: `
    mutation Logout($allSessions: Boolean) {
      logout(allSessions: $allSessions)
    }
  `,

  WRITE_TAG_VALUES: `
    mutation WriteTagValues($input: [TagValueInput]!, $timestamp: Timestamp, $quality: QualityInput) {
      writeTagValues(input: $input, timestamp: $timestamp, quality: $quality) {
        name
        error {
          code
          description
        }
      }
    }
  `,

  ACKNOWLEDGE_ALARMS: `
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
  `,

  RESET_ALARMS: `
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
  `,

  DISABLE_ALARMS: `
    mutation DisableAlarms($names: [String]!) {
      disableAlarms(names: $names) {
        alarmName
        error {
          code
          description
        }
      }
    }
  `,

  ENABLE_ALARMS: `
    mutation EnableAlarms($names: [String]!) {
      enableAlarms(names: $names) {
        alarmName
        error {
          code
          description
        }
      }
    }
  `,

  SHELVE_ALARMS: `
    mutation ShelveAlarms($names: [String]!, $shelveTimeout: Timespan) {
      shelveAlarms(names: $names, shelveTimeout: $shelveTimeout) {
        alarmName
        error {
          code
          description
        }
      }
    }
  `,

  UNSHELVE_ALARMS: `
    mutation UnshelveAlarms($names: [String]!) {
      unshelveAlarms(names: $names) {
        alarmName
        error {
          code
          description
        }
      }
    }
  `
};

const SUBSCRIPTIONS = {
  TAG_VALUES: `
    subscription SubscribeToTagValues($names: [String!]!) {
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
  `,

  ACTIVE_ALARMS: `
    subscription SubscribeToActiveAlarms($systemNames: [String], $filterString: String, $filterLanguage: String, $languages: [String]) {
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
  `,

  REDU_STATE: `
    subscription SubscribeToReduState {
      reduState {
        value {
          value
          timestamp
        }
        notificationReason
      }
    }
  `
};

// Export for both browser and Node.js environments
if (typeof module !== 'undefined' && module.exports) {
  // Node.js environment
  module.exports = {
    QUERIES,
    MUTATIONS,
    SUBSCRIPTIONS
  };
} else {
  // Browser environment
  console.log('Setting up WinCCUnifiedGraphQL on window object');
  window.WinCCUnifiedGraphQL = {
    QUERIES,
    MUTATIONS,
    SUBSCRIPTIONS
  };
  console.log('WinCCUnifiedGraphQL setup complete:', Object.keys(window.WinCCUnifiedGraphQL));
}