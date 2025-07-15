import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final String? id;
  final String? name;
  final List<UserGroup>? groups;
  final String? fullName;
  final String? language;
  final int? autoLogoffSec;

  User({
    this.id,
    this.name,
    this.groups,
    this.fullName,
    this.language,
    this.autoLogoffSec,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

@JsonSerializable()
class UserGroup {
  final String? id;
  final String? name;

  UserGroup({
    this.id,
    this.name,
  });

  factory UserGroup.fromJson(Map<String, dynamic> json) => _$UserGroupFromJson(json);
  Map<String, dynamic> toJson() => _$UserGroupToJson(this);
}