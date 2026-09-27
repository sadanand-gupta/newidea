import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

class User {
  User({
    required this.id,
    required this.username,
    required this.passwordHash,
    this.email,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String passwordHash;
  final String? email;
  final DateTime createdAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    username: json['username'] as String,
    passwordHash: json['password_hash'] as String,
    email: json['email'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'password_hash': passwordHash,
    'email': email,
    'created_at': createdAt.toIso8601String(),
  };

  Map<String, dynamic> toPublic() => {
    'id': id,
    'username': username,
    'email': email,
    'created_at': createdAt.toIso8601String(),
  };
}

class AuthToken {
  AuthToken({required this.token, required this.username, required this.expiresAt});

  final String token;
  final String username;
  final DateTime expiresAt;

  bool get isValid => DateTime.now().isBefore(expiresAt);
}

String hashPassword(String password) => sha256.convert(utf8.encode(password)).toString();

bool verifyPassword(String password, String hash) => hashPassword(password) == hash;

String generateToken(String username) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = DateTime.now().microsecond.toString();
  final combined = '$username.$timestamp.$random';
  final hash = sha256.convert(utf8.encode(combined)).toString().substring(0, 16);
  return '$username.$timestamp.$hash';
}

class UserStore {
  UserStore({required this.file});

  final File file;
  final Map<String, User> _users = {};
  final Map<String, AuthToken> _tokens = {};

  void load() {
    try {
      final content = file.readAsStringSync();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final users = (data['users'] as List).cast<Map<String, dynamic>>();
      for (final u in users) {
        final user = User.fromJson(u);
        _users[user.username] = user;
      }
    } catch (_) {
      // File doesn't exist or is invalid
    }
  }

  void save() {
    final data = {
      'users': _users.values.map((u) => u.toJson()).toList(),
    };
    file.writeAsStringSync(jsonEncode(data));
  }

  User? signup(String username, String password, [String? email]) {
    if (_users.containsKey(username)) return null;
    if (password.length < 6) return null;

    final user = User(
      id: const Uuid().v4(),
      username: username,
      passwordHash: hashPassword(password),
      email: email,
      createdAt: DateTime.now(),
    );
    _users[username] = user;
    save();
    return user;
  }

  User? login(String username, String password) {
    final user = _users[username];
    if (user == null || !verifyPassword(password, user.passwordHash)) return null;
    return user;
  }

  String createToken(String username) {
    final token = generateToken(username);
    _tokens[token] = AuthToken(
      token: token,
      username: username,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
    return token;
  }

  User? validateToken(String token) {
    final auth = _tokens[token];
    if (auth == null || !auth.isValid) {
      _tokens.remove(token);
      return null;
    }
    return _users[auth.username];
  }

  void revokeToken(String token) => _tokens.remove(token);
}
