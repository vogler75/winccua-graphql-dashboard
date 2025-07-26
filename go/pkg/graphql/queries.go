// Package graphql contains GraphQL query definitions for WinCC Unified API
package graphql

// Authentication queries and mutations
const (
	LoginMutation = `
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
	`

	LogoutMutation = `
		mutation Logout($allSessions: Boolean) {
			logout(allSessions: $allSessions)
		}
	`

	GetSessionQuery = `
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
	`
)

// Tag operations
const (
	GetTagValuesQuery = `
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
	`

	WriteTagValuesMutation = `
		mutation WriteTagValues($input: [TagValueInput]!, $timestamp: Timestamp, $quality: QualityInput) {
			writeTagValues(input: $input, timestamp: $timestamp, quality: $quality) {
				name
				error {
					code
					description
				}
			}
		}
	`

	BrowseQuery = `
		query Browse($nameFilters: [String] = [], $objectTypeFilters: [ObjectTypesEnum] = [], $baseTypeFilters: [String] = [], $language: String = "en-US") {
			browse(nameFilters: $nameFilters, objectTypeFilters: $objectTypeFilters, baseTypeFilters: $baseTypeFilters, language: $language) {
				name
				displayName
				objectType
				dataType
			}
		}
	`
)

// Alarm operations
const (
	GetActiveAlarmsQuery = `
		query GetActiveAlarms {
			activeAlarms {
				name
				priority
				state
				eventText
			}
		}
	`

	AcknowledgeAlarmsMutation = `
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
	`
)

// Logging operations
const (
	GetLoggedTagValuesQuery = `
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
				}
			}
		}
	`
)

// Subscription queries
const (
	TagValuesSubscription = `
		subscription TagValues($names: [String!]!) {
			tagValues(names: $names) {
				name
				notificationReason
				value {
					value
					timestamp
					quality
				}
				error {
					code
					description
				}
			}
		}
	`

	ActiveAlarmsSubscription = `
		subscription ActiveAlarms {
			activeAlarms {
				name
				notificationReason
				priority
				state
				eventText
			}
		}
	`

	RedundancyStateSubscription = `
		subscription RedundancyState {
			reduState {
				notificationReason
				value {
					value
					timestamp
					quality
				}
			}
		}
	`
)