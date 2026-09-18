import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../models/models.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _token != null && _user != null;

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userJson = prefs.getString('user_data');
    if (_token != null && userJson != null) {
      try {
        _user = UserModel.fromJson(jsonDecode(userJson));
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<bool> sendOTP(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await ApiClient.post('/auth/send-otp', {'phone': phone});
    _isLoading = false;
    if (result.containsKey('error')) {
      _error = result['error'];
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  Future<bool> verifyOTP(String phone, String otp, {String name = '', String role = 'customer'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await ApiClient.post('/auth/verify-otp', {
      'phone': phone,
      'otp': otp,
      'name': name,
      'role': role,
    });
    _isLoading = false;
    if (result.containsKey('error')) {
      _error = result['error'];
      notifyListeners();
      return false;
    }
    _token = result['token'];
    _user = UserModel.fromJson(result['user']);
    await _saveToStorage();
    notifyListeners();
    return true;
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString('auth_token', _token!);
    if (_user != null) {
      await prefs.setString('user_id', _user!.id);
      await prefs.setString('user_data', jsonEncode({
        '_id': _user!.id,
        'name': _user!.name,
        'phone': _user!.phone,
        'role': _user!.role,
      }));
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
