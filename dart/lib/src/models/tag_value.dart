import 'package:json_annotation/json_annotation.dart';
import 'error.dart';
import 'quality.dart';

part 'tag_value.g.dart';

@JsonSerializable()
class TagValueResult {
  final String? name;
  final Value? value;
  final Error? error;

  TagValueResult({
    this.name,
    this.value,
    this.error,
  });

  factory TagValueResult.fromJson(Map<String, dynamic> json) => _$TagValueResultFromJson(json);
  Map<String, dynamic> toJson() => _$TagValueResultToJson(this);
}

@JsonSerializable()
class Value {
  final dynamic value;
  final String? timestamp;
  final Quality? quality;

  Value({
    this.value,
    this.timestamp,
    this.quality,
  });

  factory Value.fromJson(Map<String, dynamic> json) => _$ValueFromJson(json);
  Map<String, dynamic> toJson() => _$ValueToJson(this);
}

@JsonSerializable()
class TagValueInput {
  final String name;
  final dynamic value;
  final String? timestamp;
  final QualityInput? quality;

  TagValueInput({
    required this.name,
    required this.value,
    this.timestamp,
    this.quality,
  });

  factory TagValueInput.fromJson(Map<String, dynamic> json) => _$TagValueInputFromJson(json);
  Map<String, dynamic> toJson() => _$TagValueInputToJson(this);
}

@JsonSerializable()
class WriteTagValuesResult {
  final String? name;
  final Error? error;

  WriteTagValuesResult({
    this.name,
    this.error,
  });

  factory WriteTagValuesResult.fromJson(Map<String, dynamic> json) => _$WriteTagValuesResultFromJson(json);
  Map<String, dynamic> toJson() => _$WriteTagValuesResultToJson(this);
}

@JsonSerializable()
class TagValueNotification {
  final String? name;
  final Value? value;
  final Error? error;
  final String? notificationReason;

  TagValueNotification({
    this.name,
    this.value,
    this.error,
    this.notificationReason,
  });

  factory TagValueNotification.fromJson(Map<String, dynamic> json) => _$TagValueNotificationFromJson(json);
  Map<String, dynamic> toJson() => _$TagValueNotificationToJson(this);
}