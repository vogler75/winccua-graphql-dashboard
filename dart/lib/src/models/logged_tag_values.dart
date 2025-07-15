import 'package:json_annotation/json_annotation.dart';
import 'error.dart';
import 'tag_value.dart';

part 'logged_tag_values.g.dart';

@JsonSerializable()
class LoggedTagValuesResult {
  final String? loggingTagName;
  final Error? error;
  final List<LoggedValue>? values;

  LoggedTagValuesResult({
    this.loggingTagName,
    this.error,
    this.values,
  });

  factory LoggedTagValuesResult.fromJson(Map<String, dynamic> json) => _$LoggedTagValuesResultFromJson(json);
  Map<String, dynamic> toJson() => _$LoggedTagValuesResultToJson(this);
}

@JsonSerializable()
class LoggedValue {
  final Value? value;
  final List<LoggedTagValueFlag>? flags;

  LoggedValue({
    this.value,
    this.flags,
  });

  factory LoggedValue.fromJson(Map<String, dynamic> json) => _$LoggedValueFromJson(json);
  Map<String, dynamic> toJson() => _$LoggedValueToJson(this);
}

enum LoggedTagValueFlag {
  @JsonValue('EXTRA')
  extra,
  @JsonValue('CALCULATED')
  calculated,
  @JsonValue('PARTIAL')
  partial,
  @JsonValue('BOUNDING')
  bounding,
  @JsonValue('NO_DATA')
  noData,
  @JsonValue('FIRST_STORED')
  firstStored,
  @JsonValue('LAST_STORED')
  lastStored,
  @JsonValue('HAS_REF_TIMESTAMP')
  hasRefTimestamp,
  @JsonValue('IS_MULTIVALUE')
  isMultivalue,
  @JsonValue('LAST_AGGREGATED_VALUE_BEFORE_VERY_LAST_CYCLE')
  lastAggregatedValueBeforeVeryLastCycle,
}

enum LoggedTagValuesSortingMode {
  @JsonValue('TIME_ASC')
  timeAsc,
  @JsonValue('TIME_DESC')
  timeDesc,
}

enum LoggedTagValuesBoundingMode {
  @JsonValue('NO_BOUNDING_VALUES')
  noBoundingValues,
  @JsonValue('LEFT_BOUNDING_VALUES')
  leftBoundingValues,
  @JsonValue('RIGHT_BOUNDING_VALUES')
  rightBoundingValues,
  @JsonValue('LEFTRIGHT_BOUNDING_VALUES')
  leftrightBoundingValues,
}