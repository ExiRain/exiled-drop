import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../api/ws_client.dart';
import '../models/models.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ── Singletons ──
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final wsClientProvider = Provider<WsClient>((ref) => WsClient());

// ── Auth State ──
class AuthState {
  final UserInfo? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});
  bool get isLoggedIn => user != null;

  AuthState copyWith({UserInfo? user, bool? isLoading, String? error}) =>
      AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  final WsClient _ws;

  Future<void> _registerFcmToken() async {
    if (kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _api.registerFcmToken(token);
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _api.registerFcmToken(newToken);
      });
    } catch (_) {}
  }

  AuthNotifier(this._api, this._ws) : super(const AuthState()) {
    _api.onTokenRefresh = (newToken) {
      _ws.disconnect();
      _ws.connect(newToken);
      _registerFcmToken();
    };
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final refresh = prefs.getString('refresh_token');
    if (token != null && refresh != null) {
      _api.setTokens(token, refresh);
      try {
        final user = await _api.me();
        _ws.connect(token);
        _registerFcmToken();
        state = AuthState(user: user);
      } catch (_) {
        _api.clearTokens();
        await prefs.clear();
      }
    }
  }

  Future<void> register(String username, String displayName, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final auth = await _api.register(username, displayName, password);
      await _saveTokens(auth.accessToken, auth.refreshToken);
      _ws.connect(auth.accessToken);
      _registerFcmToken();
      state = AuthState(user: auth.user);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final auth = await _api.login(username, password);
      await _saveTokens(auth.accessToken, auth.refreshToken);
      _ws.connect(auth.accessToken);
      _registerFcmToken();
      state = AuthState(user: auth.user);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<void> logout() async {
    _ws.disconnect();
    _api.clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const AuthState();
  }

  Future<void> _saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider), ref.read(wsClientProvider));
});

// ── Conversations ──
class ConversationsNotifier extends StateNotifier<List<Conversation>> {
  final ApiClient _api;
  final WsClient _ws;
  StreamSubscription? _sub;

  ConversationsNotifier(this._api, this._ws) : super([]);

  Future<void> load() async {
    try {
      final convs = await _api.getConversations();
      convs.sort((a, b) {
        final aTime = a.lastMessage?.createdAt ?? a.createdAt;
        final bTime = b.lastMessage?.createdAt ?? b.createdAt;
        return bTime.compareTo(aTime); // newest first
      });
      state = convs;
    } catch (_) {}
  }

  void listenForMessages() {
    _sub?.cancel();
    _sub = _ws.messages.listen((msg) {
      final type = msg['type'] as String?;
      if (type == 'chat.message.new' ||
          type == 'presence.update') {
        load();
      }
    });
  }

  Future<Conversation> createOrOpen(String participantId) async {
    final conv = await _api.createConversation(participantId);
    await load();
    return conv;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, List<Conversation>>((ref) {
  return ConversationsNotifier(
    ref.read(apiClientProvider),
    ref.read(wsClientProvider),
  );
});

// ── Messages for a conversation ──
class MessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final ApiClient _api;
  final WsClient _ws;
  final String conversationId;
  final String currentUserId;
  StreamSubscription? _sub;

  MessagesNotifier(this._api, this._ws, this.conversationId, this.currentUserId)
      : super([]) {
    _loadHistory();
    _listenForNew();
  }

  Future<void> _loadHistory() async {
    try {
      final msgs = await _api.getMessages(conversationId);
      state = msgs.reversed.toList(); // API returns DESC, we want ASC
    } catch (_) {}
  }

  void _listenForNew() {
    _sub = _ws.messages.listen((msg) {
      if (msg['type'] == 'chat.message.new' &&
          msg['conversationId'] == conversationId) {
        final newMsg = ChatMessage.fromJson(msg);
        state = [...state, newMsg];
      }
    });
  }

  void send(String content) {
    _ws.sendChatMessage(conversationId, content);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final messagesProvider =
    StateNotifierProvider.family<MessagesNotifier, List<ChatMessage>, String>(
  (ref, conversationId) {
    final auth = ref.read(authProvider);
    return MessagesNotifier(
      ref.read(apiClientProvider),
      ref.read(wsClientProvider),
      conversationId,
      auth.user?.id ?? '',
    );
  },
);
