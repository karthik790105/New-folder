import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ApiClient {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(String endpoint, {bool auth = false, Map<String, String>? params}) async {
    try {
      var uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
      if (params != null) uri = uri.replace(queryParameters: params);
      final response = await http.get(uri, headers: await _headers(auth: auth)).timeout(const Duration(seconds: 15));
      return _handle(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body, {bool auth = false}) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}$endpoint'),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      return _handle(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> body, {bool auth = false}) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}$endpoint'),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      return _handle(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Map<String, dynamic> _handle(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      }
      return {'error': data['error'] ?? 'Request failed'};
    } catch (e) {
      return {'error': 'Invalid response'};
    }
  }
}
