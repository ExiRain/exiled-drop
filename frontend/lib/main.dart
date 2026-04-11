import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/api/server_config.dart';
import 'core/providers/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/call/call_screen.dart';
import 'features/call/incoming_call_dialog.dart';
import 'features/chat/conversation_list_screen.dart';
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request all needed permissions
    await [
      Permission.microphone,
      Permission.camera,
      Permission.notification,
      Permission.bluetoothConnect,
    ].request();

    // Create high-priority notification channel
    const channel = AndroidNotificationChannel(
      'exiled_drop_messages',
      'Messages',
      description: 'Exiled Drop message notifications',
      importance: Importance.high,
    );

    final localNotifications = FlutterLocalNotificationsPlugin();
    await localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Initialize local notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await localNotifications.initialize(
      settings: initSettings,
    );
  }

  await ServerConfig.load();
  runApp(const ProviderScope(child: ExiledDropApp()));
}

class ExiledDropApp extends ConsumerWidget {
  const ExiledDropApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Exiled Drop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _AppShell(),
    );
  }
}

class _AppShell extends ConsumerStatefulWidget {
  const _AppShell();

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  StreamSubscription? _callSub;

  @override
  void initState() {
    super.initState();
    Future.microtask(_listenForIncomingCalls);
    _setupForegroundNotifications();
  }

  void _setupForegroundNotifications() {
    if (kIsWeb) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        const androidDetails = AndroidNotificationDetails(
          'exiled_drop_messages',
          'Messages',
          channelDescription: 'Exiled Drop message notifications',
          importance: Importance.high,
          priority: Priority.high,
        );
        const details = NotificationDetails(android: androidDetails);

        FlutterLocalNotificationsPlugin().show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: details,
        );
      }
    });
  }

  void _listenForIncomingCalls() {
    _callSub?.cancel();
    _callSub = ref.read(wsClientProvider).messages.listen((msg) {
      if (msg['type'] == 'call.offer' && mounted) {
        _showIncomingCall(msg);
      }
    });
  }

  void _showIncomingCall(Map<String, dynamic> msg) {
    final callerId = msg['callerId'] as String;
    final callerName = msg['callerName'] as String;
    final sdp = msg['sdp'] as String;
    final callType = msg['callType'] as String? ?? 'AUDIO';

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (ctx) => IncomingCallDialog(
        callerName: callerName,
        callType: callType,
        onDecline: () {
          ref.read(wsClientProvider).sendReject(callerId);
          Navigator.pop(ctx);
        },
        onAccept: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(
                targetUserId: callerId,
                targetUserName: callerName,
                callType: callType,
                isIncoming: true,
                incomingSdp: sdp,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    if (auth.isLoggedIn) {
      return const ConversationListScreen();
    }
    return const AuthScreen();
  }
}