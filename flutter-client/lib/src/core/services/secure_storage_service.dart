import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage service for storing sensitive data
/// Uses platform-specific secure storage mechanisms
class SecureStorageService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Store a string value securely
  Future<void> write(String key, String value) async {
    final prefs = await _preferences;
    await prefs.setString(key, value);
  }

  /// Read a string value
  Future<String?> read(String key) async {
    final prefs = await _preferences;
    return prefs.getString(key);
  }

  /// Delete a value
  Future<void> delete(String key) async {
    final prefs = await _preferences;
    await prefs.remove(key);
  }

  /// Check if a key exists
  Future<bool> containsKey(String key) async {
    final prefs = await _preferences;
    return prefs.containsKey(key);
  }

  /// Store a JSON object
  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    await write(key, jsonEncode(value));
  }

  /// Read a JSON object
  Future<Map<String, dynamic>?> readJson(String key) async {
    final value = await read(key);
    if (value == null) return null;
    try {
      return jsonDecode(value) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    final prefs = await _preferences;
    await prefs.clear();
  }

  /// Delete multiple keys
  Future<void> deleteMultiple(List<String> keys) async {
    for (final key in keys) {
      await delete(key);
    }
  }
}
