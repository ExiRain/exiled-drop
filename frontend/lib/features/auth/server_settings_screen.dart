import 'package:flutter/material.dart';
import '../../core/api/server_config.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _hostCtrl = TextEditingController();
  String _status = '';

  @override
  void initState() {
    super.initState();
    _hostCtrl.text = ServerConfig.currentHost;
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) return;

    await ServerConfig.setHost(host);
    setState(() => _status = 'Saved! Restart the app to apply.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server Settings')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Server Address',
                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _hostCtrl,
              decoration: const InputDecoration(
                hintText: '192.168.1.100:8080',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_status, style: TextStyle(color: Colors.grey[400])),
            ],
          ],
        ),
      ),
    );
  }
}