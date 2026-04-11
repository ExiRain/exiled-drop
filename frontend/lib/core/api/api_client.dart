import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'server_config.dart';

class ApiClient {
  // Change this to your backend IP if testing from a physical device
  String get _baseUrl => ServerConfig.httpBaseUrl;
  void Function(String newToken)? onTokenRefresh;

  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;

  void setTokens(String access, String refresh) {
    _accessToken = access;
    _refreshToken = refresh;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  // ── Auth ──

  Future<http.Response> _authGet(Uri uri) async {
    var res = await http.get(uri, headers: _headers);
    if (res.statusCode == 403 && _refreshToken != null) {
      await _doRefresh();
      res = await http.get(uri, headers: _headers);
    }
    return res;
  }

  Future<void> registerFcmToken(String token) async {
    await _authPost(
      Uri.parse('$_baseUrl/devices/fcm-token'),
      body: jsonEncode({'token': token}),
    );
  }

  Future<http.Response> _authPost(Uri uri, {Object? body}) async {
    var res = await http.post(uri, headers: _headers, body: body);
    if (res.statusCode == 403 && _refreshToken != null) {
      await _doRefresh();
      res = await http.post(uri, headers: _headers, body: body);
    }
    return res;
  }

  Future<void> _doRefresh() async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': _refreshToken}),
    );
    if (res.statusCode == 200) {
      final auth = AuthResponse.fromJson(jsonDecode(res.body));
      setTokens(auth.accessToken, auth.refreshToken);
      onTokenRefresh?.call(auth.accessToken);
    }
  }

  Future<AuthResponse> register(String username, String displayName, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'displayName': displayName, 'password': password}),
    );
    if (res.statusCode == 201) {
      final auth = AuthResponse.fromJson(jsonDecode(res.body));
      setTokens(auth.accessToken, auth.refreshToken);
      return auth;
    }
    throw ApiException(res.statusCode, _errorMessage(res));
  }

  Future<AuthResponse> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode == 200) {
      final auth = AuthResponse.fromJson(jsonDecode(res.body));
      setTokens(auth.accessToken, auth.refreshToken);
      return auth;
    }
    throw ApiException(res.statusCode, _errorMessage(res));
  }

  // ── Users ──

  Future<UserInfo> me() async {
    final res = await _authGet(Uri.parse('$_baseUrl/users/me'));
    if (res.statusCode == 200) return UserInfo.fromJson(jsonDecode(res.body));
    throw ApiException(res.statusCode, _errorMessage(res));
  }

  Future<List<UserInfo>> searchUsers(String query) async {
    final res = await _authGet(Uri.parse('$_baseUrl/users/search?q=$query'));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((u) => UserInfo.fromJson(u as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(res.statusCode, _errorMessage(res));
  }
  // ── Conversations ──

  Future<Conversation> createConversation(String participantId) async {
    final res = await _authPost(
      Uri.parse('$_baseUrl/conversations'),
      body: jsonEncode({'participantId': participantId}),
    );
    if (res.statusCode == 201) return Conversation.fromJson(jsonDecode(res.body));
    throw ApiException(res.statusCode, _errorMessage(res));
  }

  Future<List<Conversation>> getConversations() async {
    final res = await _authGet(Uri.parse('$_baseUrl/conversations'));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(res.statusCode, _errorMessage(res));
  }

  Future<List<ChatMessage>> getMessages(String conversationId, {int page = 0, int size = 50}) async {
    final res = await _authGet(
      Uri.parse('$_baseUrl/conversations/$conversationId/messages?page=$page&size=$size'),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['content'] as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(res.statusCode, _errorMessage(res));
  }

  String _errorMessage(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      return body['message'] ?? 'Request failed';
    } catch (_) {
      return 'Request failed (${res.statusCode})';
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}
