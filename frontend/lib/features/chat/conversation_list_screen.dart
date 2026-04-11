import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../chat/chat_screen.dart';
import 'user_search_screen.dart';

class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends ConsumerState<ConversationListScreen> {
  @override
  void initState() {
    super.initState();
    // Load conversations and listen for real-time updates
    Future.microtask(() {
      ref.read(conversationsProvider.notifier).load();
      ref.read(conversationsProvider.notifier).listenForMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final conversations = ref.watch(conversationsProvider);
    final currentUserId = auth.user?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exiled Drop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: conversations.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to start a new chat',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(conversationsProvider.notifier).load(),
              child: ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (ctx, i) => _ConversationTile(
                  conversation: conversations[i],
                  currentUserId: currentUserId,
                  onTap: () => _openChat(conversations[i]),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openSearch(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openChat(Conversation conv) {
    final currentUserId = ref.read(authProvider).user?.id ?? '';
    final other = conv.otherParticipant(currentUserId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conv.id,
          otherUserName: other.displayName,
          otherUserId: other.id,
        ),
      ),
    );
  }

  void _openSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserSearchScreen()),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final other = conversation.otherParticipant(currentUserId);
    final lastMsg = conversation.lastMessage;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: other.online ? const Color(0xFFE94560) : const Color(0xFF2A2A4E),
          child: Text(
            other.displayName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                other.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (other.online)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF27AE60),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: lastMsg != null
            ? Text(
                lastMsg.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[500]),
              )
            : Text('No messages yet', style: TextStyle(color: Colors.grey[600])),
      ),
    );
  }
}
