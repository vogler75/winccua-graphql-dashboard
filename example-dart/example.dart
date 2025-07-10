#!/usr/bin/env dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Simple WinCC Unified GraphQL Client for Dart
class WinCCUnifiedClient {
  final String httpUrl;
  final String wsUrl;
  String? _token;
  WebSocketChannel? _wsChannel;
  final Map<String, StreamController<dynamic>> _subscriptions = {};

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
            roles
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
            roles
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
  Future<List<Map<String, dynamic>>> browse({String? nameFilter}) async {
    String browseQuery = '''
      query Browse(\$nameFilter: String) {
        browse(nameFilter: \$nameFilter) {
          name
          objectType
          path
        }
      }
    ''';

    final response = await _makeRequest(browseQuery, {
      if (nameFilter != null) 'nameFilter': nameFilter,
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
              qualityBits
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
  Future<List<Map<String, dynamic>>> writeTagValues(List<Map<String, dynamic>> tagValues) async {
    const String writeTagValuesMutation = '''
      mutation WriteTagValues(\$tagValues: [TagValueInput!]!) {
        writeTagValues(tagValues: \$tagValues) {
          name
          error {
            code
            description
          }
        }
      }
    ''';

    final response = await _makeRequest(writeTagValuesMutation, {'tagValues': tagValues});
    
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
        \$startTime: String!
        \$endTime: String!
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
          timestamp
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
          timestamp
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
    _wsChannel?.sink.close();
    _wsChannel = null;
    
    // Close all subscriptions
    for (var controller in _subscriptions.values) {
      controller.close();
    }
    _subscriptions.clear();
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
    if (_wsChannel == null) {
      _wsChannel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['graphql-ws'],
      );

      // Initialize WebSocket connection
      _wsChannel!.sink.add(json.encode({
        'type': 'connection_init',
        'payload': {
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      }));
    }

    final subscriptionId = DateTime.now().millisecondsSinceEpoch.toString();
    
    _wsChannel!.sink.add(json.encode({
      'id': subscriptionId,
      'type': 'start',
      'payload': {
        'query': subscription,
        'variables': variables,
      },
    }));

    final controller = StreamController<dynamic>();
    _subscriptions[subscriptionId] = controller;

    final streamSubscription = _wsChannel!.stream.listen(
      (message) {
        final data = json.decode(message);
        if (data['id'] == subscriptionId && data['type'] == 'data') {
          onData(data['payload']);
        }
      },
      onError: onError,
    );

    return streamSubscription;
  }

  void dispose() {
    _wsChannel?.sink.close();
    for (var controller in _subscriptions.values) {
      controller.close();
    }
    _subscriptions.clear();
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
