import 'package:json_annotation/json_annotation.dart';
import 'error.dart';
import 'quality.dart';

part 'alarm.g.dart';

@JsonSerializable()
class ActiveAlarm {
  final String? name;
  final int? instanceID;
  final int? alarmGroupID;
  final String? raiseTime;
  final String? acknowledgmentTime;
  final String? clearTime;
  final String? resetTime;
  final String? modificationTime;
  final AlarmState? state;
  final String? textColor;
  final String? backColor;
  final bool? flashing;
  final List<String>? languages;
  final String? alarmClassName;
  final List<String>? alarmClassSymbol;
  final int? alarmClassID;
  final AlarmStateMachine? stateMachine;
  final int? priority;
  final List<dynamic>? alarmParameterValues;
  final List<String>? alarmType;
  final List<String>? eventText;
  final List<String>? infoText;
  final List<String>? alarmText1;
  final List<String>? alarmText2;
  final List<String>? alarmText3;
  final List<String>? alarmText4;
  final List<String>? alarmText5;
  final List<String>? alarmText6;
  final List<String>? alarmText7;
  final List<String>? alarmText8;
  final List<String>? alarmText9;
  final List<String>? stateText;
  final String? origin;
  final String? area;
  final List<AlarmChangeReason>? changeReason;
  final String? connectionName;
  final dynamic valueLimit;
  final AlarmSourceType? sourceType;
  final AlarmSuppressionState? suppressionState;
  final String? hostName;
  final String? userName;
  final dynamic value;
  final Quality? valueQuality;
  final Quality? quality;
  final AlarmInvalidFlags? invalidFlags;
  final dynamic deadBand;
  final AlarmProducer? producer;
  final String? duration;
  final String? durationIso;
  final String? sourceID;
  final int? systemSeverity;
  final String? loopInAlarm;
  final dynamic loopInAlarmParameterValues;
  final String? path;
  final AlarmUserResponse? userResponse;

  ActiveAlarm({
    this.name,
    this.instanceID,
    this.alarmGroupID,
    this.raiseTime,
    this.acknowledgmentTime,
    this.clearTime,
    this.resetTime,
    this.modificationTime,
    this.state,
    this.textColor,
    this.backColor,
    this.flashing,
    this.languages,
    this.alarmClassName,
    this.alarmClassSymbol,
    this.alarmClassID,
    this.stateMachine,
    this.priority,
    this.alarmParameterValues,
    this.alarmType,
    this.eventText,
    this.infoText,
    this.alarmText1,
    this.alarmText2,
    this.alarmText3,
    this.alarmText4,
    this.alarmText5,
    this.alarmText6,
    this.alarmText7,
    this.alarmText8,
    this.alarmText9,
    this.stateText,
    this.origin,
    this.area,
    this.changeReason,
    this.connectionName,
    this.valueLimit,
    this.sourceType,
    this.suppressionState,
    this.hostName,
    this.userName,
    this.value,
    this.valueQuality,
    this.quality,
    this.invalidFlags,
    this.deadBand,
    this.producer,
    this.duration,
    this.durationIso,
    this.sourceID,
    this.systemSeverity,
    this.loopInAlarm,
    this.loopInAlarmParameterValues,
    this.path,
    this.userResponse,
  });

  factory ActiveAlarm.fromJson(Map<String, dynamic> json) => _$ActiveAlarmFromJson(json);
  Map<String, dynamic> toJson() => _$ActiveAlarmToJson(this);
}

@JsonSerializable()
class ActiveAlarmNotification {
  final String? name;
  final int? instanceID;
  final String? notificationReason;
  final ActiveAlarm? alarm;

  ActiveAlarmNotification({
    this.name,
    this.instanceID,
    this.notificationReason,
    this.alarm,
  });

  factory ActiveAlarmNotification.fromJson(Map<String, dynamic> json) => _$ActiveAlarmNotificationFromJson(json);
  Map<String, dynamic> toJson() => _$ActiveAlarmNotificationToJson(this);
}

@JsonSerializable()
class AlarmIdentifierInput {
  final String name;
  final int? instanceID;

  AlarmIdentifierInput({
    required this.name,
    this.instanceID,
  });

  factory AlarmIdentifierInput.fromJson(Map<String, dynamic> json) => _$AlarmIdentifierInputFromJson(json);
  Map<String, dynamic> toJson() => _$AlarmIdentifierInputToJson(this);
}

@JsonSerializable()
class ActiveAlarmMutationResult {
  final String? alarmName;
  final int? alarmInstanceID;
  final Error? error;

  ActiveAlarmMutationResult({
    this.alarmName,
    this.alarmInstanceID,
    this.error,
  });

  factory ActiveAlarmMutationResult.fromJson(Map<String, dynamic> json) => _$ActiveAlarmMutationResultFromJson(json);
  Map<String, dynamic> toJson() => _$ActiveAlarmMutationResultToJson(this);
}

@JsonSerializable()
class AlarmInvalidFlags {
  final bool? invalidConfiguration;
  final bool? invalidTimestamp;
  final bool? invalidAlarmParameter;
  final bool? invalidEventText;

  AlarmInvalidFlags({
    this.invalidConfiguration,
    this.invalidTimestamp,
    this.invalidAlarmParameter,
    this.invalidEventText,
  });

  factory AlarmInvalidFlags.fromJson(Map<String, dynamic> json) => _$AlarmInvalidFlagsFromJson(json);
  Map<String, dynamic> toJson() => _$AlarmInvalidFlagsToJson(this);
}

enum AlarmState {
  @JsonValue('NORMAL')
  normal,
  @JsonValue('RAISED')
  raised,
  @JsonValue('RAISED_CLEARED')
  raisedCleared,
  @JsonValue('RAISED_ACKNOWLEDGED')
  raisedAcknowledged,
  @JsonValue('RAISED_ACKNOWLEDGED_CLEARED')
  raisedAcknowledgedCleared,
  @JsonValue('RAISED_CLEARED_ACKNOWLEDGED')
  raisedClearedAcknowledged,
  @JsonValue('REMOVED')
  removed,
}

enum AlarmStateMachine {
  @JsonValue('RAISE')
  raise,
  @JsonValue('RAISE_CLEAR')
  raiseClear,
  @JsonValue('RAISE_REQUIRES_ACKNOWLEDGMENT')
  raiseRequiresAcknowledgment,
  @JsonValue('RAISE_CLEAR_OPTIONAL_ACKNOWLEDGMENT')
  raiseClearOptionalAcknowledgment,
  @JsonValue('RAISE_CLEAR_REQUIRES_ACKNOWLEDGMENT')
  raiseClearRequiresAcknowledgment,
  @JsonValue('RAISE_CLEAR_REQUIRES_ACKNOWLEDGMENT_AND_RESET')
  raiseClearRequiresAcknowledgmentAndReset,
}

enum AlarmChangeReason {
  @JsonValue('ALARM_STATE_CHANGED_RAISE_EVENT')
  alarmStateChangedRaiseEvent,
  @JsonValue('ALARM_STATE_CHANGED_CLEAR_EVENT')
  alarmStateChangedClearEvent,
  @JsonValue('ALARM_STATE_CHANGED_ACKNOWLEDGE_EVENT')
  alarmStateChangedAcknowledgeEvent,
  @JsonValue('ALARM_STATE_CHANGED_RESET_EVENT')
  alarmStateChangedResetEvent,
  @JsonValue('ALARM_STATE_CHANGED_REMOVE_EVENT')
  alarmStateChangedRemoveEvent,
  @JsonValue('ALARM_QUALITY_CHANGED')
  alarmQualityChanged,
  @JsonValue('ALARM_PARAMETER_VALUES_CHANGED')
  alarmParameterValuesChanged,
  @JsonValue('ALARM_PRIORITY_CHANGED')
  alarmPriorityChanged,
  @JsonValue('ALARM_SUPPRESSION_STATE_CHANGED')
  alarmSuppressionStateChanged,
  @JsonValue('ALARM_ESCALATION_REASON_CHANGED')
  alarmEscalationReasonChanged,
  @JsonValue('ALARM_ENABLE_STATE_CHANGED')
  alarmEnableStateChanged,
  @JsonValue('ALARM_CONFIGURATION_CHANGED')
  alarmConfigurationChanged,
  @JsonValue('ALARM_EXTERNAL_UPDATE')
  alarmExternalUpdate,
}

enum AlarmSourceType {
  @JsonValue('TAG')
  tag,
  @JsonValue('CONTROLLER')
  controller,
  @JsonValue('SYSTEM')
  system,
  @JsonValue('SUMMARY_ALARM')
  summaryAlarm,
}

enum AlarmSuppressionState {
  @JsonValue('UNSUPPRESSED')
  unsuppressed,
  @JsonValue('SUPPRESSED')
  suppressed,
  @JsonValue('SHELVED')
  shelved,
  @JsonValue('SUPPRESSED_AND_SHELVED')
  suppressedAndShelved,
}

enum AlarmProducer {
  @JsonValue('IEPCL_OR_USER_ALARM')
  iepclOrUserAlarm,
  @JsonValue('RSE')
  rse,
  @JsonValue('WR_USMSG')
  wrUsmsg,
  @JsonValue('SIMOTION_CLASSIC')
  simotionClassic,
  @JsonValue('SYS_DIAG')
  sysDiag,
  @JsonValue('SMC')
  smc,
  @JsonValue('SECURITY')
  security,
  @JsonValue('SINUMERIC')
  sinumeric,
  @JsonValue('GRAPH')
  graph,
  @JsonValue('PRO_DIAG')
  proDiag,
  @JsonValue('WINCC')
  wincc,
}

enum AlarmUserResponse {
  @JsonValue('NONE')
  none,
  @JsonValue('ACKNOWLEDGEMENT')
  acknowledgement,
  @JsonValue('RESET')
  reset,
  @JsonValue('SINGLE_ACKNOWLEDGEMENT')
  singleAcknowledgement,
  @JsonValue('SINGLE_RESET')
  singleReset,
}