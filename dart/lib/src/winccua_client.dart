import 'dart:async';
import 'dart:convert';
import 'package:graphql/client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:rxdart/rxdart.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// Conditional imports for different platforms
import 'ssl_certificate_helper_stub.dart'
    if (dart.library.io) 'ssl_certificate_helper_io.dart'
    if (dart.library.html) 'ssl_certificate_helper_web.dart';

import 'models/session.dart';
import 'models/tag_value.dart';
import 'models/quality.dart';
import 'models/alarm.dart';
import 'models/logged_tag_values.dart';
import 'queries.dart';

class WinCCUnifiedClient {
  final String httpUrl;
  final String wsUrl;
  final bool ignoreSslCertificateErrors;
  late GraphQLClient _client;
  String? _token;
  WebSocketChannel? _wsChannel;
  final Map<String, StreamController<dynamic>> _subscriptions = {};

  WinCCUnifiedClient({
    required this.httpUrl,
    required this.wsUrl,
    this.ignoreSslCertificateErrors = false,
  }) {
    if (ignoreSslCertificateErrors && !kIsWeb) {
      SslCertificateHelper.setupSslCertificateBypass();
    }
    _initializeClient();
  }

  void _initializeClient() {
    http.Client? httpClient;
    
    if (ignoreSslCertificateErrors && !kIsWeb) {
      httpClient = SslCertificateHelper.createHttpClient(ignoreSslCertificateErrors);
    }

    final httpLink = HttpLink(
      httpUrl,
      httpClient: httpClient,
    );
    
    final wsLink = WebSocketLink(wsUrl);

    final authLink = AuthLink(
      getToken: () async => _token != null ? 'Bearer $_token' : null,
    );

    final link = Link.split(
      (request) => request.isSubscription,
      wsLink,
      authLink.concat(httpLink),
    );

    _client = GraphQLClient(
      link: link,
      cache: GraphQLCache(store: InMemoryStore()),
    );
  }

  Future<Session> login(String username, String password) async {
    final options = MutationOptions(
      document: gql(GraphQLQueries.login),
      variables: {
        'username': username,
        'password': password,
      },
    );

    final result = await _client.mutate(options);
    
    if (result.hasException) {
      throw Exception('Login failed: ${result.exception.toString()}');
    }

    final sessionData = result.data?['login'];
    if (sessionData == null) {
      throw Exception('No session data received');
    }

    final session = Session.fromJson(sessionData);
    if (session.token != null) {
      _token = session.token;
    }

    return session;
  }

  Future<Session> loginSWAC(String claim, String signedClaim) async {
    final options = MutationOptions(
      document: gql(GraphQLQueries.loginSWAC),
      variables: {
        'claim': claim,
        'signedClaim': signedClaim,
      },
    );

    final result = await _client.mutate(options);
    
    if (result.hasException) {
      throw Exception('SWAC login failed: ${result.exception.toString()}');
    }

    final sessionData = result.data?['loginSWAC'];
    if (sessionData == null) {
      throw Exception('No session data received');
    }

    final session = Session.fromJson(sessionData);
    if (session.token != null) {
      _token = session.token;
    }

    return session;
  }

  Future<Session> extendSession() async {
    final options = MutationOptions(
      document: gql(GraphQLQueries.extendSession),
    );

    final result = await _client.mutate(options);
    
    if (result.hasException) {
      throw Exception('Session extension failed: ${result.exception.toString()}');
    }

    final sessionData = result.data?['extendSession'];
    if (sessionData == null) {
      throw Exception('No session data received');
    }

    return Session.fromJson(sessionData);
  }

  Future<bool> logout({bool allSessions = false}) async {
    final options = MutationOptions(
      document: gql(GraphQLQueries.logout),
      variables: {
        'allSessions': allSessions,
      },
    );

    final result = await _client.mutate(options);
    
    if (result.hasException) {
      throw Exception('Logout failed: ${result.exception.toString()}');
    }

    final success = result.data?['logout'] ?? false;
    if (success) {
      _token = null;
    }

    return success;
  }

  Future<List<TagValueResult>> getTagValues(
    List<String> names, {
    bool directRead = false,
  }) async {
    final options = QueryOptions(
      document: gql(GraphQLQueries.tagValues),
      variables: {
        'names': names,
        'directRead': directRead,
      },
    );

    final result = await _client.query(options);
    
    if (result.hasException) {
      throw Exception('Tag values query failed: ${result.exception.toString()}');
    }

    final tagValuesData = result.data?['tagValues'] as List<dynamic>? ?? [];
    return tagValuesData
        .map((data) => TagValueResult.fromJson(data as Map<String, dynamic>))
        .toList();
  }

  Future<List<WriteTagValuesResult>> writeTagValues(
    List<TagValueInput> input, {
    String? timestamp,
    QualityInput? quality,
  }) async {
    final options = MutationOptions(
      document: gql(GraphQLQueries.writeTagValues),
      variables: {
        'input': input.map((e) => e.toJson()).toList(),
        if (timestamp != null) 'timestamp': timestamp,
        if (quality != null) 'quality': quality.toJson(),
      },
    );

    final result = await _client.mutate(options);
    
    if (result.hasException) {
      throw Exception('Write tag values failed: ${result.exception.toString()}');
    }

    final writeResultsData = result.data?['writeTagValues'] as List<dynamic>? ?? [];
    return writeResultsData
        .map((data) => WriteTagValuesResult.fromJson(data as Map<String, dynamic>))
        .toList();
  }

  Future<List<LoggedTagValuesResult>> getLoggedTagValues({
    required List<String> names,
    String? startTime,
    String? endTime,
    int? maxNumberOfValues,
    LoggedTagValuesSortingMode sortingMode = LoggedTagValuesSortingMode.timeAsc,
    LoggedTagValuesBoundingMode boundingValuesMode = LoggedTagValuesBoundingMode.noBoundingValues,
  }) async {
    final options = QueryOptions(
      document: gql(GraphQLQueries.loggedTagValues),
      variables: {
        'names': names,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
        if (maxNumberOfValues != null) 'maxNumberOfValues': maxNumberOfValues,
        'sortingMode': sortingMode.name.toUpperCase(),
        'boundingValuesMode': boundingValuesMode.name.toUpperCase(),
      },
    );

    final result = await _client.query(options);
    
    if (result.hasException) {
      throw Exception('Logged tag values query failed: ${result.exception.toString()}');
    }

    final loggedValuesData = result.data?['loggedTagValues'] as List<dynamic>? ?? [];
    return loggedValuesData
        .map((data) => LoggedTagValuesResult.fromJson(data as Map<String, dynamic>))
        .toList();
  }

  Future<List<ActiveAlarm>> getActiveAlarms({
    List<String>? systemNames,
    String? filterString,
    String filterLanguage = 'en-US',
    List<String> languages = const ['en-US'],
  }) async {
    final options = QueryOptions(
      document: gql(GraphQLQueries.activeAlarms),
      variables: {
        'systemNames': systemNames ?? [],
        'filterString': filterString ?? '',
        'filterLanguage': filterLanguage,
        'languages': languages,
      },
    );

    final result = await _client.query(options);
    
    if (result.hasException) {
      throw Exception('Active alarms query failed: ${result.exception.toString()}');
    }

    final alarmsData = result.data?['activeAlarms'] as List<dynamic>? ?? [];
    return alarmsData
        .map((data) => ActiveAlarm.fromJson(data as Map<String, dynamic>))
        .toList();
  }

  Future<List<ActiveAlarmMutationResult>> acknowledgeAlarms(
    List<AlarmIdentifierInput> input,
  ) async {
    final options = MutationOptions(
      document: gql(GraphQLQueries.acknowledgeAlarms),
      variables: {
        'input': input.map((e) => e.toJson()).toList(),
      },
    );

    final result = await _client.mutate(options);
    
    if (result.hasException) {
      throw Exception('Acknowledge alarms failed: ${result.exception.toString()}');
    }

    final resultsData = result.data?['acknowledgeAlarms'] as List<dynamic>? ?? [];
    return resultsData
        .map((data) => ActiveAlarmMutationResult.fromJson(data as Map<String, dynamic>))
        .toList();
  }

  Future<List<ActiveAlarmMutationResult>> resetAlarms(
    List<AlarmIdentifierInput> input,
  ) async {
    final options = MutationOptions(
      document: gql(GraphQLQueries.resetAlarms),
      variables: {
        'input': input.map((e) => e.toJson()).toList(),
      },
    );

    final result = await _client.mutate(options);
    
    if (result.hasException) {
      throw Exception('Reset alarms failed: ${result.exception.toString()}');
    }

    final resultsData = result.data?['resetAlarms'] as List<dynamic>? ?? [];
    return resultsData
        .map((data) => ActiveAlarmMutationResult.fromJson(data as Map<String, dynamic>))
        .toList();
  }

  Stream<TagValueNotification> subscribeToTagValues(List<String> names) {
    final subscriptionId = 'tagValues_${names.join('_')}';
    
    if (_subscriptions.containsKey(subscriptionId)) {
      _subscriptions[subscriptionId]!.close();
    }

    final controller = StreamController<TagValueNotification>.broadcast();
    _subscriptions[subscriptionId] = controller;

    final options = SubscriptionOptions(
      document: gql(GraphQLQueries.tagValuesSubscription),
      variables: {
        'names': names,
      },
    );

    final subscription = _client.subscribe(options);
    
    subscription.listen(
      (result) {
        if (result.hasException) {
          controller.addError(result.exception!);
          return;
        }

        final data = result.data?['tagValues'];
        if (data != null) {
          final notification = TagValueNotification.fromJson(data);
          controller.add(notification);
        }
      },
      onError: (error) => controller.addError(error),
      onDone: () => controller.close(),
    );

    return controller.stream;
  }

  Stream<ActiveAlarmNotification> subscribeToActiveAlarms({
    List<String>? systemNames,
    String? filterString,
    String filterLanguage = 'en-US',
    List<String> languages = const ['en-US'],
  }) {
    final subscriptionId = 'activeAlarms_${systemNames?.join('_') ?? 'all'}';
    
    if (_subscriptions.containsKey(subscriptionId)) {
      _subscriptions[subscriptionId]!.close();
    }

    final controller = StreamController<ActiveAlarmNotification>.broadcast();
    _subscriptions[subscriptionId] = controller;

    final options = SubscriptionOptions(
      document: gql(GraphQLQueries.activeAlarmsSubscription),
      variables: {
        'systemNames': systemNames ?? [],
        'filterString': filterString ?? '',
        'filterLanguage': filterLanguage,
        'languages': languages,
      },
    );

    final subscription = _client.subscribe(options);
    
    subscription.listen(
      (result) {
        if (result.hasException) {
          controller.addError(result.exception!);
          return;
        }

        final data = result.data?['activeAlarms'];
        if (data != null) {
          final notification = ActiveAlarmNotification.fromJson(data);
          controller.add(notification);
        }
      },
      onError: (error) => controller.addError(error),
      onDone: () => controller.close(),
    );

    return controller.stream;
  }

  void dispose() {
    for (final controller in _subscriptions.values) {
      controller.close();
    }
    _subscriptions.clear();
    _wsChannel?.sink.close();
    
    if (ignoreSslCertificateErrors && !kIsWeb) {
      SslCertificateHelper.restoreHttpOverrides();
    }
  }
}