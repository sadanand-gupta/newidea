import 'dart:convert';

class User {
  User({
    required this.id,
    required this.username,
    this.email,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String? email;
  final DateTime createdAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    username: json['username'] as String,
    email: json['email'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'created_at': createdAt.toIso8601String(),
  };

  String toJsonString() => jsonEncode(toJson());

  factory User.fromJsonString(String json) => User.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

class AuthResponse {
  AuthResponse({required this.user, required this.token});

  final User user;
  final String token;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    user: User.fromJson(json['user'] as Map<String, dynamic>),
    token: json['token'] as String,
  );
}
