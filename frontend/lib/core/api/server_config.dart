import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  static const String _defaultHost = 'localhost:8080';
  static const String _key = 'server_host';

  static String _host = _defaultHost;

  static String get httpBaseUrl => 'http://$_host/api';
  static String get wsBaseUrl => 'ws://$_host/ws';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString(_key) ?? _defaultHost;
  }

  static Future<void> setHost(String host) async {
    _host = host;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, host);
  }

  static String get currentHost => _host;
}