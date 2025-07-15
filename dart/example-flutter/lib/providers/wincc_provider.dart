import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:winccua_graphql_client/winccua_graphql_client.dart';
import 'dart:async';

class WinCCProvider extends ChangeNotifier {
  WinCCUnifiedClient? _client;
  Session? _session;
  bool _isConnected = false;
  String? _serverUrl;
  
  // Tag values
  Map<String, Value?> _tagValues = {};
  
  // Subscriptions
  StreamSubscription? _tagSubscription;
  
  // Active alarms
  List<ActiveAlarm> _activeAlarms = [];
  
  // Getters
  bool get isConnected => _isConnected;
  String? get serverUrl => _serverUrl;
  Session? get session => _session;
  Map<String, Value?> get tagValues => _tagValues;
  List<ActiveAlarm> get activeAlarms => _activeAlarms;
  
  // Get a specific tag value
  double? getTagValue(String tagName) {
    final value = _tagValues[tagName];
    if (value?.value is num) {
      return (value!.value as num).toDouble();
    }
    return null;
  }
  
  // Login method
  Future<bool> login(String serverUrl, String username, String password) async {
    try {
      // Clean up any existing connection
      await disconnect();
      
      _serverUrl = serverUrl;
      
      // Initialize client
      _client = WinCCUnifiedClient(
        httpUrl: serverUrl,
        wsUrl: serverUrl.replaceFirst('http', 'ws'),
        ignoreSslCertificateErrors: !kIsWeb, // Only ignore SSL errors on non-web platforms
      );
      
      // Attempt login
      _session = await _client!.login(username, password);
      
      if (_session?.error != null) {
        throw Exception(_session!.error!.description);
      }
      
      _isConnected = true;
      notifyListeners();
      return true;
    } catch (e) {
      _isConnected = false;
      _client?.dispose();
      _client = null;
      _session = null;
      notifyListeners();
      rethrow;
    }
  }
  
  // Subscribe to tag values
  Future<void> subscribeToTags(List<String> tagNames) async {
    if (_client == null || !_isConnected) return;
    
    try {
      // Cancel existing subscription
      await _tagSubscription?.cancel();
      
      // Get initial values
      final initialValues = await _client!.getTagValues(tagNames);
      for (final result in initialValues) {
        if (result.value != null && result.name != null) {
          _tagValues[result.name!] = result.value;
        }
      }
      notifyListeners();
      
      // Subscribe to changes
      _tagSubscription = _client!.subscribeToTagValues(tagNames).listen(
        (notification) {
          if (notification.name != null) {
            _tagValues[notification.name!] = notification.value;
            notifyListeners();
          }
        },
        onError: (error) {
          print('Tag subscription error: $error');
        },
      );
    } catch (e) {
      print('Error subscribing to tags: $e');
    }
  }
  
  // Fetch active alarms
  Future<void> fetchActiveAlarms() async {
    if (_client == null || !_isConnected) return;
    
    try {
      _activeAlarms = await _client!.getActiveAlarms(
        languages: ['en-US'],
      );
      notifyListeners();
    } catch (e) {
      print('Error fetching alarms: $e');
    }
  }
  
  // Get historical data for charts
  Future<List<LoggedTagValuesResult>> getHistoricalData(
    List<String> tagNames,
    DateTime startTime,
    DateTime endTime,
  ) async {
    if (_client == null || !_isConnected) return [];
    
    try {
      return await _client!.getLoggedTagValues(
        names: tagNames,
        startTime: startTime.toUtc().toIso8601String(),
        endTime: endTime.toUtc().toIso8601String(),
        maxNumberOfValues: 1000,
        sortingMode: LoggedTagValuesSortingMode.timeAsc,
      );
    } catch (e) {
      print('Error fetching historical data: $e');
      return [];
    }
  }
  
  // Disconnect
  Future<void> disconnect() async {
    _isConnected = false;
    await _tagSubscription?.cancel();
    _tagSubscription = null;
    await _client?.logout();
    _client?.dispose();
    _client = null;
    _session = null;
    _tagValues.clear();
    _activeAlarms.clear();
    notifyListeners();
  }
  
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}