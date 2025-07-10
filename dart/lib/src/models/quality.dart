import 'package:json_annotation/json_annotation.dart';

part 'quality.g.dart';

@JsonSerializable()
class Quality {
  final MainQuality? quality;
  final QualitySubStatus? subStatus;
  final QualityLimit? limit;
  final QualityExtendedSubStatus? extendedSubStatus;
  final bool? sourceQuality;
  final bool? sourceTime;
  final bool? timeCorrected;

  Quality({
    this.quality,
    this.subStatus,
    this.limit,
    this.extendedSubStatus,
    this.sourceQuality,
    this.sourceTime,
    this.timeCorrected,
  });

  factory Quality.fromJson(Map<String, dynamic> json) => _$QualityFromJson(json);
  Map<String, dynamic> toJson() => _$QualityToJson(this);
}

@JsonSerializable()
class QualityInput {
  final MainQuality quality;
  final QualitySubStatus? subStatus;

  QualityInput({
    required this.quality,
    this.subStatus,
  });

  factory QualityInput.fromJson(Map<String, dynamic> json) => _$QualityInputFromJson(json);
  Map<String, dynamic> toJson() => _$QualityInputToJson(this);
}

enum MainQuality {
  @JsonValue('BAD')
  bad,
  @JsonValue('UNCERTAIN')
  uncertain,
  @JsonValue('GOOD_NON_CASCADE')
  goodNonCascade,
  @JsonValue('GOOD_CASCADE')
  goodCascade,
}

enum QualitySubStatus {
  @JsonValue('NON_SPECIFIC')
  nonSpecific,
  @JsonValue('CONFIGURATION_ERROR')
  configurationError,
  @JsonValue('NOT_CONNECTED')
  notConnected,
  @JsonValue('SENSOR_FAILURE')
  sensorFailure,
  @JsonValue('DEVICE_FAILURE')
  deviceFailure,
  @JsonValue('NO_COMMUNICATION_WITH_LAST_USABLE_VALUE')
  noCommunicationWithLastUsableValue,
  @JsonValue('NO_COMMUNICATION_NO_USABLE_VALUE')
  noCommunicationNoUsableValue,
  @JsonValue('OUT_OF_SERVICE')
  outOfService,
  @JsonValue('LAST_USABLE_VALUE')
  lastUsableValue,
  @JsonValue('SUBSTITUTE_VALUE')
  substituteValue,
  @JsonValue('INITIAL_VALUE')
  initialValue,
  @JsonValue('SENSOR_CONVERSION')
  sensorConversion,
  @JsonValue('RANGE_VIOLATION')
  rangeViolation,
  @JsonValue('SUB_NORMAL')
  subNormal,
  @JsonValue('CONFIG_ERROR')
  configError,
  @JsonValue('SIMULATED_VALUE')
  simulatedValue,
  @JsonValue('SENSOR_CALIBRATION')
  sensorCalibration,
  @JsonValue('UPDATE_EVENT')
  updateEvent,
  @JsonValue('ADVISORY_ALARM')
  advisoryAlarm,
  @JsonValue('CRITICAL_ALARM')
  criticalAlarm,
  @JsonValue('UNACK_UPDATE_EVENT')
  unackUpdateEvent,
  @JsonValue('UNACK_ADVISORY_ALARM')
  unackAdvisoryAlarm,
  @JsonValue('UNACK_CRITICAL_ALARM')
  unackCriticalAlarm,
  @JsonValue('INIT_FAILSAFE')
  initFailsafe,
  @JsonValue('MAINTENANCE_REQUIRED')
  maintenanceRequired,
  @JsonValue('INIT_ACKED')
  initAcked,
  @JsonValue('INITREQ')
  initreq,
  @JsonValue('NOT_INVITED')
  notInvited,
  @JsonValue('DO_NOT_SELECT')
  doNotSelect,
  @JsonValue('LOCAL_OVERRIDE')
  localOverride,
}

enum QualityLimit {
  @JsonValue('OK')
  ok,
  @JsonValue('LOW_LIMIT_VIOLATION')
  lowLimitViolation,
  @JsonValue('HIGH_LIMIT_VIOLATION')
  highLimitViolation,
  @JsonValue('CONSTANT')
  constant,
}

enum QualityExtendedSubStatus {
  @JsonValue('NON_SPECIFIC')
  nonSpecific,
  @JsonValue('AGGREGATED_VALUE')
  aggregatedValue,
  @JsonValue('UNUSABLE_VALUE')
  unusableValue,
  @JsonValue('DISABLED')
  disabled,
  @JsonValue('MANUAL_INPUT')
  manualInput,
  @JsonValue('CORRECTED_VALUE')
  correctedValue,
  @JsonValue('LAST_USABLE_VALUE')
  lastUsableValue,
  @JsonValue('INITIAL_VALUE')
  initialValue,
}