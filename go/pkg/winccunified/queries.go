package winccunified

const (
	loginMutation = `
		mutation Login($username: String!, $password: String!) {
			Login(user: $username, password: $password) {
				token
				sessionId
				error {
					code
					description
				}
			}
		}`

	logoutMutation = `
		mutation Logout($sessionId: ID!) {
			Logout(sessionId: $sessionId) {
				error {
					code
					description
				}
			}
		}`

	extendSessionMutation = `
		mutation ExtendSession($sessionId: ID!) {
			ExtendSession(sessionId: $sessionId) {
				error {
					code
					description
				}
			}
		}`

	readTagsQuery = `
		query ReadTags($tags: [String!]!) {
			ReadTags(tags: $tags) {
				name
				value
				quality
				timestamp
				error {
					code
					description
				}
			}
		}`

	writeTagsMutation = `
		mutation WriteTags($tags: [TagInput!]!) {
			WriteTags(tags: $tags) {
				name
				error {
					code
					description
				}
			}
		}`

	browseQuery = `
		query Browse($path: String) {
			Browse(path: $path) {
				items {
					name
					type
					address
					childrenCount
				}
				error {
					code
					description
				}
			}
		}`

	getActiveAlarmsQuery = `
		query GetActiveAlarms {
			GetActiveAlarms {
				id
				state
				name
				text
				className
				comeTime
				goTime
				ackTime
				error {
					code
					description
				}
			}
		}`

	getAlarmHistoryQuery = `
		query GetAlarmHistory($startTime: DateTime!, $endTime: DateTime!) {
			GetAlarmHistory(startTime: $startTime, endTime: $endTime) {
				id
				state
				name
				text
				className
				comeTime
				goTime
				ackTime
				error {
					code
					description
				}
			}
		}`

	acknowledgeAlarmMutation = `
		mutation AcknowledgeAlarm($alarmId: ID!) {
			AcknowledgeAlarm(alarmId: $alarmId) {
				error {
					code
					description
				}
			}
		}`

	resetAlarmMutation = `
		mutation ResetAlarm($alarmId: ID!) {
			ResetAlarm(alarmId: $alarmId) {
				error {
					code
					description
				}
			}
		}`

	readHistoricalValuesQuery = `
		query ReadHistoricalValues($tag: String!, $startTime: DateTime!, $endTime: DateTime!, $maxValues: Int) {
			ReadHistoricalValues(tag: $tag, startTime: $startTime, endTime: $endTime, maxValues: $maxValues) {
				name
				values {
					value
					quality
					timestamp
				}
				error {
					code
					description
				}
			}
		}`

	getRedundancyStateQuery = `
		query GetRedundancyState {
			GetRedundancyState {
				isMaster
				state
				error {
					code
					description
				}
			}
		}`

	subscribeToTagsSubscription = `
		subscription SubscribeToTags($tags: [String!]!) {
			SubscribeToTags(tags: $tags) {
				name
				value
				quality
				timestamp
				error {
					code
					description
				}
			}
		}`

	subscribeToAlarmsSubscription = `
		subscription SubscribeToAlarms {
			SubscribeToAlarms {
				id
				state
				name
				text
				className
				comeTime
				goTime
				ackTime
				error {
					code
					description
				}
			}
		}`

	subscribeToRedundancyStateSubscription = `
		subscription SubscribeToRedundancyState {
			SubscribeToRedundancyState {
				isMaster
				state
				error {
					code
					description
				}
			}
		}`
)