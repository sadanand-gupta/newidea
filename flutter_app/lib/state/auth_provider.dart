import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api);

  final ApiService _api;
  SharedPreferences? _prefs;

  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await restoreSession();
  }

  Future<void> restoreSession() async {
    _prefs ??= await SharedPreferences.getInstance();
    final tokenStr = _prefs?.getString('auth_token');
    final userStr = _prefs?.getString('auth_user');

    if (tokenStr != null && userStr != null) {
      try {
        _token = tokenStr;
        _user = User.fromJsonString(userStr);
        _api.setAuthToken(_token);
        notifyListeners();
      } catch (_) {
        await logout();
      }
    }
  }

  Future<bool> signup(String username, String password, [String? email]) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.signup(username, password, email);
      _user = response.user;
      _token = response.token;
      _api.setAuthToken(_token);

      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString('auth_token', _token!);
      await _prefs!.setString('auth_user', _user!.toJsonString());

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.login(username, password);
      _user = response.user;
      _token = response.token;
      _api.setAuthToken(_token);

      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString('auth_token', _token!);
      await _prefs!.setString('auth_user', _user!.toJsonString());

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    _error = null;
    _api.setAuthToken(null);

    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove('auth_token');
    await _prefs!.remove('auth_user');

    notifyListeners();
  }
}
