import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';
import 'server_config.dart';

typedef WsMessageHandler = void Function(Map<String, dynamic> message);

class WsClient {
  String get _wsBaseUrl => ServerConfig.wsBaseUrl;

  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  String? _token;
  Timer? _reconnectTimer;
  bool _intentionalClose = false;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _channel != null;

  void connect(String token) {
    _token = token;
    _intentionalClose = false;
    _doConnect();
  }

  void _doConnect() {
    if (_token == null) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse('$_wsBaseUrl?token=$_token'));

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _messageController.add(json);
          } catch (e) {
            // ignore malformed messages
          }
        },
        onError: (error) {
          _scheduleReconnect();
        },
        onDone: () {
          if (!_intentionalClose) {
            _scheduleReconnect();
          }
        },
      );
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _channel = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _doConnect);
  }

  // ── Chat ──

  void sendChatMessage(String conversationId, String content) {
    _send({
      'type': 'chat.message',
      'conversationId': conversationId,
      'content': content,
    });
  }

  // ── Call Signaling ──

  void sendCallOffer(String targetUserId, String sdp, String callType) {
    _send({
      'type': 'call.offer',
      'targetUserId': targetUserId,
      'sdp': sdp,
      'callType': callType,
    });
  }

  void sendCallAnswer(String targetUserId, String sdp) {
    _send({
      'type': 'call.answer',
      'targetUserId': targetUserId,
      'sdp': sdp,
    });
  }

  void sendIceCandidate(String targetUserId, String candidate, String sdpMid, int sdpMLineIndex) {
    _send({
      'type': 'call.ice',
      'targetUserId': targetUserId,
      'candidate': candidate,
      'sdpMid': sdpMid,
      'sdpMLineIndex': sdpMLineIndex,
    });
  }

  void sendHangup(String targetUserId) {
    _send({'type': 'call.hangup', 'targetUserId': targetUserId});
  }

  void sendReject(String targetUserId) {
    _send({'type': 'call.reject', 'targetUserId': targetUserId});
  }

  // ── Internals ──

  void sendTypingStart(String conversationId) {
    _send({'type': 'typing.start', 'conversationId': conversationId});
  }

  void sendTypingStop(String conversationId) {
    _send({'type': 'typing.stop', 'conversationId': conversationId});
  }

  void sendMessageRead(String conversationId, String messageId) {
    _send({'type': 'message.read', 'conversationId': conversationId, 'messageId': messageId});
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void disconnect() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
