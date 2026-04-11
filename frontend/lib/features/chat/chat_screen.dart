import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../call/call_screen.dart';

bool _isSameDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _otherTyping = false;
  Timer? _typingTimer;
  Timer? _sendTypingStopTimer;
  StreamSubscription? _typingSub;
  final Set<String> _readMessageIds = {};
  StreamSubscription? _readSub;

  @override
  void initState() {
    super.initState();
    _readSub = ref.read(wsClientProvider).messages.listen((msg) {
      if (msg['type'] == 'message.read' &&
          msg['conversationId'] == widget.conversationId) {
        setState(() => _readMessageIds.add(msg['messageId'] as String));
      }
    });

    _typingSub = ref.read(wsClientProvider).messages.listen((msg) {
      if (msg['type'] == 'typing.start' &&
          msg['conversationId'] == widget.conversationId) {
        setState(() => _otherTyping = true);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _otherTyping = false);
        });
      } else if (msg['type'] == 'typing.stop' &&
          msg['conversationId'] == widget.conversationId) {
        setState(() => _otherTyping = false);
      }
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _typingSub?.cancel();
    _readSub?.cancel();
    _typingTimer?.cancel();
    _sendTypingStopTimer?.cancel();
    super.dispose();
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    ref.read(messagesProvider(widget.conversationId).notifier).send(text);
    _inputCtrl.clear();

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _startCall(String callType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          targetUserId: widget.otherUserId,
          targetUserName: widget.otherUserName,
          callType: callType,
          isIncoming: false,
        ),
      ),
    );
  }

  void _onTextChanged(String text) {
    final ws = ref.read(wsClientProvider);
    if (text.isNotEmpty) {
      ws.sendTypingStart(widget.conversationId);
      _sendTypingStopTimer?.cancel();
      _sendTypingStopTimer = Timer(const Duration(seconds: 2), () {
        ws.sendTypingStop(widget.conversationId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.conversationId));
    final currentUserId = ref.watch(authProvider).user?.id ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    if (messages.isNotEmpty && messages.last.senderId != currentUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(wsClientProvider).sendMessageRead(
          widget.conversationId,
          messages.last.id,
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName, style: const TextStyle(fontSize: 17)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () => _startCall('AUDIO'),
            tooltip: 'Voice call',
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () => _startCall('VIDEO'),
            tooltip: 'Video call',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: messages.isEmpty
                ? Center(
              child: Text('Say hello!',
                  style: TextStyle(color: AppColors.textHint)),
            )
                : ListView.builder(
              controller: _scrollCtrl,
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: messages.length,
              itemBuilder: (ctx, i) {
                final msg = messages[i];
                final showDate = i == 0 ||
                    !_isSameDay(
                        messages[i - 1].createdAt, msg.createdAt);

                return Column(
                  children: [
                    if (showDate) _DateSeparator(date: msg.createdAt),
                    _MessageBubble(
                      message: msg,
                      isMe: msg.senderId == currentUserId,
                      isRead: _readMessageIds.contains(msg.id),
                    ),
                  ],
                );
              },
            ),
          ),

          // Typing indicator
          if (_otherTyping)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.otherUserName} is typing...',
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      onChanged: _onTextChanged,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, size: 20),
                      color: AppColors.background,
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ──

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isRead;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.isRead = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
        BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.bubbleSent : AppColors.bubbleReceived,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
            isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight:
            isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(
              message.content,
              style: TextStyle(
                color: isMe
                    ? AppColors.bubbleSentText
                    : AppColors.bubbleReceivedText,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    color: isMe
                        ? AppColors.bubbleSentText.withOpacity(0.6)
                        : AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead
                        ? AppColors.accentLight
                        : AppColors.bubbleSentText.withOpacity(0.5),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

// ── Date separator ──

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(
              child: Divider(color: AppColors.divider, thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDate(date),
              style: const TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ),
          const Expanded(
              child: Divider(color: AppColors.divider, thickness: 0.5)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(local.year, local.month, local.day);

    if (dateDay == today) return 'Today';
    if (dateDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }
}