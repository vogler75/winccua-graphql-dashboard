class GraphQLQueries {
  static const String session = '''
    query GetSession(\$allSessions: Boolean) {
      session(allSessions: \$allSessions) {
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
  ''';

  static const String tagValues = '''
    query GetTagValues(\$names: [String!]!, \$directRead: Boolean = false) {
      tagValues(names: \$names, directRead: \$directRead) {
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
  ''';

  static const String loggedTagValues = '''
    query GetLoggedTagValues(
      \$names: [String]!
      \$startTime: Timestamp = "1970-01-01T00:00:00.000Z"
      \$endTime: Timestamp = "1970-01-01T00:00:00.000Z"
      \$maxNumberOfValues: Int = 0
      \$sortingMode: LoggedTagValuesSortingModeEnum = TIME_ASC
      \$boundingValuesMode: LoggedTagValuesBoundingModeEnum = NO_BOUNDING_VALUES
    ) {
      loggedTagValues(
        names: \$names
        startTime: \$startTime
        endTime: \$endTime
        maxNumberOfValues: \$maxNumberOfValues
        sortingMode: \$sortingMode
        boundingValuesMode: \$boundingValuesMode
      ) {
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
  ''';

  static const String activeAlarms = '''
    query GetActiveAlarms(
      \$systemNames: [String] = []
      \$filterString: String = ""
      \$filterLanguage: String = "en-US"
      \$languages: [String] = ["en-US"]
    ) {
      activeAlarms(
        systemNames: \$systemNames
        filterString: \$filterString
        filterLanguage: \$filterLanguage
        languages: \$languages
      ) {
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
  ''';

  static const String login = '''
    mutation Login(\$username: String!, \$password: String!) {
      login(username: \$username, password: \$password) {
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
  ''';

  static const String loginSWAC = '''
    mutation LoginSWAC(\$claim: String!, \$signedClaim: String!) {
      loginSWAC(claim: \$claim, signedClaim: \$signedClaim) {
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
  ''';

  static const String extendSession = '''
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
  ''';

  static const String logout = '''
    mutation Logout(\$allSessions: Boolean) {
      logout(allSessions: \$allSessions)
    }
  ''';

  static const String writeTagValues = '''
    mutation WriteTagValues(
      \$input: [TagValueInput]!
      \$timestamp: Timestamp
      \$quality: QualityInput
    ) {
      writeTagValues(input: \$input, timestamp: \$timestamp, quality: \$quality) {
        name
        error {
          code
          description
        }
      }
    }
  ''';

  static const String acknowledgeAlarms = '''
    mutation AcknowledgeAlarms(\$input: [AlarmIdentifierInput]!) {
      acknowledgeAlarms(input: \$input) {
        alarmName
        alarmInstanceID
        error {
          code
          description
        }
      }
    }
  ''';

  static const String resetAlarms = '''
    mutation ResetAlarms(\$input: [AlarmIdentifierInput]!) {
      resetAlarms(input: \$input) {
        alarmName
        alarmInstanceID
        error {
          code
          description
        }
      }
    }
  ''';

  static const String tagValuesSubscription = '''
    subscription TagValues(\$names: [String!]!) {
      tagValues(names: \$names) {
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
  ''';

  static const String activeAlarmsSubscription = '''
    subscription ActiveAlarms(
      \$systemNames: [String] = []
      \$filterString: String = ""
      \$filterLanguage: String = "en-US"
      \$languages: [String] = ["en-US"]
    ) {
      activeAlarms(
        systemNames: \$systemNames
        filterString: \$filterString
        filterLanguage: \$filterLanguage
        languages: \$languages
      ) {
        name
        instanceID
        notificationReason
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
  ''';
}