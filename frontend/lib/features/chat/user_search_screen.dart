import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import 'chat_screen.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _searchCtrl = TextEditingController();
  List<UserInfo> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      _results = await api.searchUsers(query.trim());
    } catch (_) {
      _results = [];
    }
    setState(() => _loading = false);
  }

  Future<void> _startChat(UserInfo user) async {
    try {
      final conv = await ref.read(conversationsProvider.notifier).createOrOpen(user.id);
      if (mounted) {
        // Replace this screen with the chat
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conv.id,
              otherUserName: user.displayName,
              otherUserId: user.id,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create conversation: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search by username...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _search,
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: _results.isEmpty && !_loading
                ? Center(
                    child: Text(
                      _searchCtrl.text.isEmpty
                          ? 'Type a username to search'
                          : 'No users found',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (ctx, i) {
                      final user = _results[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF2A2A4E),
                            child: Text(
                              user.displayName[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(user.displayName),
                          subtitle: Text('@${user.username}',
                              style: TextStyle(color: Colors.grey[500])),
                          trailing: const Icon(Icons.chat, color: Color(0xFFE94560)),
                          onTap: () => _startChat(user),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
