class UserInfo {
  final String id;
  final String username;
  final String displayName;

  const UserInfo({required this.id, required this.username, required this.displayName});

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
      );
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final UserInfo user;

  const AuthResponse({required this.accessToken, required this.refreshToken, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        user: UserInfo.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class Participant {
  final String id;
  final String username;
  final String displayName;
  final bool online;

  const Participant({
    required this.id,
    required this.username,
    required this.displayName,
    required this.online,
  });

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        online: json['online'] as bool? ?? false,
      );
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class Conversation {
  final String id;
  final List<Participant> participants;
  final ChatMessage? lastMessage;
  final DateTime createdAt;

  const Conversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        participants: (json['participants'] as List)
            .map((p) => Participant.fromJson(p as Map<String, dynamic>))
            .toList(),
        lastMessage: json['lastMessage'] != null
            ? ChatMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  /// Get the other participant (not the current user) for 1:1 display
  Participant otherParticipant(String currentUserId) {
    return participants.firstWhere(
      (p) => p.id != currentUserId,
      orElse: () => participants.first,
    );
  }
}
