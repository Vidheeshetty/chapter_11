import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late SharedPreferences _prefs;

  // Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Get a string value
  String? getString(String key) {
    return _prefs.getString(key);
  }

  // Set a string value
  Future<bool> setString(String key, String value) {
    return _prefs.setString(key, value);
  }

  // Get a boolean value
  bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  // Set a boolean value
  Future<bool> setBool(String key, bool value) {
    return _prefs.setBool(key, value);
  }

  // Get a JSON object
  Map<String, dynamic>? getJson(String key) {
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;

    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // Set a JSON object
  Future<bool> setJson(String key, Map<String, dynamic> value) {
    return _prefs.setString(key, jsonEncode(value));
  }

  // Remove a value
  Future<bool> remove(String key) {
    return _prefs.remove(key);
  }

  // Clear all values
  Future<bool> clear() {
    return _prefs.clear();
  }
}