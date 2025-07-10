#!/usr/bin/env dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Wrapper for subscription that handles proper cancellation
class _SubscriptionWrapper implements StreamSubscription {
  final StreamSubscription _subscription;
  final String _subscriptionId;
  final WinCCUnifiedClient _client;

  _SubscriptionWrapper(this._subscription, this._subscriptionId, this._client);

  @override
  Future<void> cancel() async {
    // Send complete message to server
    _client._sendCompleteMessage(_subscriptionId);
    
    // Cancel the local subscription
    return _subscription.cancel();
  }

  @override
  void onData(void Function(dynamic)? handleData) => _subscription.onData(handleData);

  @override
  void onError(Function? handleError) => _subscription.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _subscription.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => _subscription.pause(resumeSignal);

  @override
  void resume() => _subscription.resume();

  @override
  bool get isPaused => _subscription.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _subscription.asFuture(futureValue);
}

/// Simple WinCC Unified GraphQL Client for Dart
class WinCCUnifiedClient {
  final String httpUrl;
  final String wsUrl;
  String? _token;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  bool _connectionInitialized = false;
  final Map<String, StreamController<Map<String, dynamic>>> _subscriptions = {};

  WinCCUnifiedClient({
    required this.httpUrl,
    required this.wsUrl,
  });

  /// Login with username and password
  Future<Map<String, dynamic>> login(String username, String password) async {
    const String loginMutation = '''
      mutation Login(\$username: String!, \$password: String!) {
        login(username: \$username, password: \$password) {
          token
          expires
          user {
            name
            fullName
            groups {
              id
              name
            }
          }
        }
      }
    ''';

    final response = await _makeRequest(loginMutation, {
      'username': username,
      'password': password,
    });

    if (response['data']?['login'] != null) {
      final session = response['data']['login'];
      _token = session['token'];
      return session;
    } else {
      throw Exception('Login failed: ${response['errors']}');
    }
  }

  /// Get current session information
  Future<List<Map<String, dynamic>>> getSession() async {
    const String sessionQuery = '''
      query GetSession {
        session {
          user {
            name
            fullName
            groups {
              id
              name
            }
          }
          expires
        }
      }
    ''';

    final response = await _makeRequest(sessionQuery, {});
    
    if (response['data']?['session'] != null) {
      final session = response['data']['session'];
      return session is List ? List<Map<String, dynamic>>.from(session) : [Map<String, dynamic>.from(session)];
    }
    return [];
  }

  /// Browse available objects
  Future<List<Map<String, dynamic>>> browse({List<String>? nameFilters}) async {
    String browseQuery = '''
      query Browse(\$nameFilters: [String]) {
        browse(nameFilters: \$nameFilters) {
          name
          displayName
          objectType
          dataType
        }
      }
    ''';

    final response = await _makeRequest(browseQuery, {
      if (nameFilters != null) 'nameFilters': nameFilters,
    });

    if (response['data']?['browse'] != null) {
      return List<Map<String, dynamic>>.from(response['data']['browse']);
    }
    return [];
  }

  /// Get tag values
  Future<List<Map<String, dynamic>>> getTagValues(List<String> names) async {
    const String tagValuesQuery = '''
      query GetTagValues(\$names: [String!]!) {
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
        }
      }
    ''';

    final response = await _makeRequest(tagValuesQuery, {'names': names});
    
    if (response['data']?['tagValues'] != null) {
      return List<Map<String, dynamic>>.from(response['data']['tagValues']);
    }
    return [];
  }

  /// Write tag values
  Future<List<Map<String, dynamic>>> writeTagValues(List<Map<String, dynamic>> input) async {
    const String writeTagValuesMutation = '''
      mutation WriteTagValues(\$input: [TagValueInput!]!) {
        writeTagValues(input: \$input) {
          name
          error {
            code
            description
          }
        }
      }
    ''';

    final response = await _makeRequest(writeTagValuesMutation, {'input': input});
    
    if (response['data']?['writeTagValues'] != null) {
      return List<Map<String, dynamic>>.from(response['data']['writeTagValues']);
    }
    return [];
  }

  /// Get logged tag values
  Future<List<Map<String, dynamic>>> getLoggedTagValues(
    List<String> names,
    String startTime,
    String endTime,
    int maxNumberOfValues,
  ) async {
    const String loggedTagValuesQuery = '''
      query GetLoggedTagValues(
        \$names: [String!]!
        \$startTime: Timestamp!
        \$endTime: Timestamp!
        \$maxNumberOfValues: Int
      ) {
        loggedTagValues(
          names: \$names
          startTime: \$startTime
          endTime: \$endTime
          maxNumberOfValues: \$maxNumberOfValues
        ) {
          loggingTagName
          values {
            value {
              value
              timestamp
              quality {
                quality
              }
            }
          }
          error {
            code
            description
          }
        }
      }
    ''';

    final response = await _makeRequest(loggedTagValuesQuery, {
      'names': names,
      'startTime': startTime,
      'endTime': endTime,
      'maxNumberOfValues': maxNumberOfValues,
    });

    if (response['data']?['loggedTagValues'] != null) {
      return List<Map<String, dynamic>>.from(response['data']['loggedTagValues']);
    }
    return [];
  }

  /// Get active alarms
  Future<List<Map<String, dynamic>>> getActiveAlarms() async {
    const String activeAlarmsQuery = '''
      query GetActiveAlarms {
        activeAlarms {
          name
          eventText
          priority
          raiseTime
          state
        }
      }
    ''';

    final response = await _makeRequest(activeAlarmsQuery, {});
    
    if (response['data']?['activeAlarms'] != null) {
      return List<Map<String, dynamic>>.from(response['data']['activeAlarms']);
    }
    return [];
  }

  /// Subscribe to tag values
  Future<StreamSubscription> subscribeToTagValues(
    List<String> names,
    void Function(Map<String, dynamic>) onData,
    {void Function(dynamic)? onError}
  ) async {
    const String subscription = '''
      subscription TagValues(\$names: [String!]!) {
        tagValues(names: \$names) {
          name
          value {
            value
            timestamp
            quality {
              quality
            }
          }
          notificationReason
        }
      }
    ''';

    return _subscribe(subscription, {'names': names}, onData, onError: onError);
  }

  /// Subscribe to active alarms
  Future<StreamSubscription> subscribeToActiveAlarms(
    void Function(Map<String, dynamic>) onData,
    {void Function(dynamic)? onError}
  ) async {
    const String subscription = '''
      subscription ActiveAlarms {
        activeAlarms {
          name
          eventText
          priority
          raiseTime
          state
          notificationReason
        }
      }
    ''';

    return _subscribe(subscription, {}, onData, onError: onError);
  }

  /// Logout
  Future<void> logout() async {
    const String logoutMutation = '''
      mutation Logout {
        logout
      }
    ''';

    await _makeRequest(logoutMutation, {});
    _token = null;
    
    // Close WebSocket connection
    await _closeWebSocketConnection();
  }

  /// Make HTTP GraphQL request
  Future<Map<String, dynamic>> _makeRequest(String query, Map<String, dynamic> variables) async {
    final headers = {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };

    final body = json.encode({
      'query': query,
      'variables': variables,
    });

    final response = await http.post(
      Uri.parse(httpUrl),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Create WebSocket subscription
  Future<StreamSubscription> _subscribe(
    String subscription,
    Map<String, dynamic> variables,
    void Function(Map<String, dynamic>) onData,
    {void Function(dynamic)? onError}
  ) async {
    await _ensureWebSocketConnection();

    final subscriptionId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Store subscription callback
    final controller = StreamController<Map<String, dynamic>>();
    _subscriptions[subscriptionId] = controller;

    // Send subscription message
    _wsChannel!.sink.add(json.encode({
      'id': subscriptionId,
      'type': 'subscribe', // Use 'start' for compatibility with both protocols
      'payload': {
        'query': subscription,
        'variables': variables,
      },
    }));

    // Return a subscription that can be cancelled
    final streamSubscription = controller.stream.listen(onData, onError: onError);
    
    // Create a wrapper that sends complete message when cancelled
    return _SubscriptionWrapper(streamSubscription, subscriptionId, this);
  }

  /// Ensure WebSocket connection is established and initialized
  Future<void> _ensureWebSocketConnection() async {
    if (_wsChannel == null || _wsSubscription == null) {
      await _connectWebSocket();
    }
  }

  /// Connect to WebSocket and set up message handling
  Future<void> _connectWebSocket() async {
    // Close existing connection if any
    await _closeWebSocketConnection();

    // Try different protocols
    try {
      _wsChannel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['graphql-transport-ws'],
      );
      await _initializeWebSocketConnection();
    } catch (e) {
      print('Failed to connect with graphql-transport-ws, trying without protocol: $e');
      try {
        _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
        await _initializeWebSocketConnection();
      } catch (e2) {
        print('Failed to connect without protocol: $e2');
        rethrow;
      }
    }
  }

  /// Initialize WebSocket connection and set up message handling
  Future<void> _initializeWebSocketConnection() async {
    if (_wsChannel == null) return;

    final completer = Completer<void>();
    bool connectionAcknowledged = false;

    // Set up message listener
    _wsSubscription = _wsChannel!.stream.listen(
      (message) {
        final data = json.decode(message);
        // print('WebSocket message: $data'); // Debug logging
        
        // Handle connection acknowledgment
        if (data['type'] == 'connection_ack' && !connectionAcknowledged) {
          connectionAcknowledged = true;
          _connectionInitialized = true;
          completer.complete();
          return;
        }

        // Handle subscription messages
        final subscriptionId = data['id'];
        if (subscriptionId != null && _subscriptions.containsKey(subscriptionId)) {
          final controller = _subscriptions[subscriptionId]!;
          
          switch (data['type']) {
            case 'next': // graphql-transport-ws
            case 'data': // graphql-ws
              final payload = data['payload'];
              if (payload is Map<String, dynamic>) {
                controller.add(payload);
              }
              break;
            case 'error':
              controller.addError(data['payload']);
              break;
            case 'complete':
              controller.close();
              _subscriptions.remove(subscriptionId);
              break;
          }
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    // Send connection init
    _wsChannel!.sink.add(json.encode({
      'type': 'connection_init',
      'payload': {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    }));

    // Wait for connection acknowledgment
    await completer.future.timeout(Duration(seconds: 10));
  }

  /// Send complete message to stop subscription
  void _sendCompleteMessage(String subscriptionId) {
    if (_wsChannel != null) {
      _wsChannel!.sink.add(json.encode({
        'id': subscriptionId,
        'type': 'complete',
      }));
      
      // Clean up local subscription
      final controller = _subscriptions[subscriptionId];
      if (controller != null) {
        controller.close();
        _subscriptions.remove(subscriptionId);
      }
    }
  }

  /// Close WebSocket connection
  Future<void> _closeWebSocketConnection() async {
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    _wsChannel?.sink.close();
    _wsChannel = null;
    _connectionInitialized = false;
    
    // Close all subscription controllers
    for (var controller in _subscriptions.values) {
      controller.close();
    }
    _subscriptions.clear();
  }

  void dispose() {
    _closeWebSocketConnection();
  }
}

/// Main example application
Future<void> main() async {
  // Configuration - get URLs and credentials from environment variables or use defaults
  final httpUrl = Platform.environment['GRAPHQL_HTTP_URL'] ?? 'https://your-wincc-server/graphql';
  final wsUrl = Platform.environment['GRAPHQL_WS_URL'] ?? 'wss://your-wincc-server/graphql';
  final username = Platform.environment['GRAPHQL_USERNAME'] ?? 'username';
  final password = Platform.environment['GRAPHQL_PASSWORD'] ?? 'password';

  print('WinCC Unified Dart Client Example');
  print('=' * 40);
  print('');
  print('Note: Please set GRAPHQL_HTTP_URL, GRAPHQL_WS_URL, GRAPHQL_USERNAME, and GRAPHQL_PASSWORD environment variables or update values in the code before running');
  print('');

  final client = WinCCUnifiedClient(httpUrl: httpUrl, wsUrl: wsUrl);

  try {
    // Login
    print('Logging in...');
    final session = await client.login(username, password);
    print('Logged in as: ${session['user']['name']}');
    print('Token expires: ${session['expires']}');

    // Get session info
    print('\nGetting session info...');
    final sessionInfo = await client.getSession();
    
    if (sessionInfo.isEmpty) {
      print('No session info found');
    } else {
      print('Session info:');
      for (final sInfo in sessionInfo) {
        print('  - User: ${sInfo['user']['fullName']}, Expires: ${sInfo['expires']}');
      }
    }

    // Browse available objects
    print('\nBrowsing available objects...');
    final objects = await client.browse();
    print('Found ${objects.length} objects');
    for (int i = 0; i < objects.length && i < 5; i++) {
      final obj = objects[i];
      print('  - ${obj['name']} (${obj['objectType']})');
    }

    // Get tag values
    print('\nGetting tag values...');
    final tagNames = ['HMI_Tag_1', 'HMI_Tag_2']; // Replace with actual tag names
    try {
      final tags = await client.getTagValues(tagNames);
      for (final tag in tags) {
        if (tag['error'] != null) {
          print('  - ${tag['name']}: ERROR - ${tag['error']['description']}');
        } else {
          final value = tag['value'];
          final quality = value['quality'];
          print('  - ${tag['name']}: ${value['value']} (Quality: ${quality['quality']}, Time: ${value['timestamp']})');
        }
      }
    } catch (e) {
      print('Error getting tag values: $e');
    }

    // Get logged tag values
    print('\nGetting logged tag values...');
    try {
      // Get values from the last 24 hours
      final endTime = DateTime.now();
      final startTime = endTime.subtract(const Duration(hours: 24));
      
      final loggedValues = await client.getLoggedTagValues(
        ['PV-Vogler-PC::Meter_Input_WattAct:LoggingTag_1'],
        startTime.toIso8601String(),
        endTime.toIso8601String(),
        10,
      );
      
      print('Found ${loggedValues.length} logged tag results');
      for (final result in loggedValues) {
        if (result['error'] != null && result['error']['code'] != '0') {
          print('  - ${result['loggingTagName']}: ERROR - ${result['error']['description']}');
          continue;
        }
        
        final values = result['values'] as List<dynamic>;
        print('  - ${result['loggingTagName']}: ${values.length} values');
        
        // Show last 5 values
        final lastValues = values.length > 5 ? values.sublist(values.length - 5) : values;
        for (final val in lastValues) {
          final valueData = val['value'];
          final quality = valueData['quality'];
          print('    ${valueData['timestamp']}: ${valueData['value']} (Quality: ${quality['quality']})');
        }
      }
    } catch (e) {
      print('Error getting logged tag values: $e');
    }

    // Get active alarms
    print('\nGetting active alarms...');
    try {
      final alarms = await client.getActiveAlarms();
      print('Found ${alarms.length} active alarms');
      for (int i = 0; i < alarms.length && i < 3; i++) {
        final alarm = alarms[i];
        final eventText = alarm['eventText'] is List ? 
          (alarm['eventText'] as List).isNotEmpty ? alarm['eventText'][0] : 'No event text' :
          alarm['eventText'] ?? 'No event text';
        print('  - ${alarm['name']}: $eventText (Priority: ${alarm['priority']})');
      }
    } catch (e) {
      print('Error getting alarms: $e');
    }

    // Example of writing tag values
    print('\nWriting tag values...');
    try {
      final writeResults = await client.writeTagValues([
        {'name': 'HMI_Tag_1', 'value': 100},
        {'name': 'HMI_Tag_2', 'value': 200},
      ]);
      
      for (final result in writeResults) {
        if (result['error'] != null) {
          print('  - ${result['name']}: ERROR - ${result['error']['description']}');
        } else {
          print('  - ${result['name']}: Written successfully');
        }
      }
    } catch (e) {
      print('Error writing tag values: $e');
    }

    // Set up subscription for tag values
    print('\nSetting up tag value subscription...');
    try {
      final tagSubscription = await client.subscribeToTagValues(
        tagNames,
        (data) {
          final tagValues = data['data']['tagValues'];
          if (tagValues != null) {
            final value = tagValues['value'];
            final reason = tagValues['notificationReason'] ?? 'UPDATE';
            print('  [SUBSCRIPTION] ${tagValues['name']}: ${value['value']} ($reason) at ${value['timestamp']}');
          }
        },
        onError: (error) {
          print('  [SUBSCRIPTION ERROR] $error');
        },
      );

      print('Tag subscription active. Waiting for updates...');
      
      // Keep subscription active for 30 seconds
      await Future.delayed(const Duration(seconds: 30));
      
      // Unsubscribe
      print('Unsubscribing from tag values...');
      tagSubscription.cancel();
      
    } catch (e) {
      print('Error setting up subscription: $e');
    }

    // Set up subscription for active alarms
    print('\nSetting up alarm subscription...');
    try {
      final alarmSubscription = await client.subscribeToActiveAlarms(
        (data) {
          final activeAlarms = data['data']['activeAlarms'];
          if (activeAlarms != null) {
            final reason = activeAlarms['notificationReason'] ?? 'UPDATE';
            final eventText = activeAlarms['eventText'] is List ?
              (activeAlarms['eventText'] as List).isNotEmpty ? activeAlarms['eventText'][0] : 'No event text' :
              activeAlarms['eventText'] ?? 'No event text';
            print('  [ALARM] ${activeAlarms['name']}: $eventText ($reason)');
          }
        },
        onError: (error) {
          print('  [ALARM ERROR] $error');
        },
      );

      print('Alarm subscription active. Waiting for updates...');
      
      // Keep subscription active for 30 seconds
      await Future.delayed(const Duration(seconds: 30));
      
      // Unsubscribe
      print('Unsubscribing from alarms...');
      alarmSubscription.cancel();
      
    } catch (e) {
      print('Error setting up alarm subscription: $e');
    }

    // Logout
    print('\nLogging out...');
    await client.logout();
    print('Logged out successfully');

  } catch (e) {
    print('Error: $e');
  } finally {
    client.dispose();
  }
}
