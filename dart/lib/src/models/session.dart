import 'package:json_annotation/json_annotation.dart';
import 'error.dart';
import 'user.dart';

part 'session.g.dart';

@JsonSerializable()
class Session {
  final User? user;
  final String? token;
  final String? expires;
  final Error? error;

  Session({
    this.user,
    this.token,
    this.expires,
    this.error,
  });

  factory Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);
  Map<String, dynamic> toJson() => _$SessionToJson(this);
}