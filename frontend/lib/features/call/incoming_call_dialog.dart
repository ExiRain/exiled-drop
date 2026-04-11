import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Full-screen incoming call overlay — replaces the raw AlertDialog.
///
/// Usage in your HomeScreen or wherever you listen for call.offer:
/// ```dart
/// void _showIncomingCall(Map<String, dynamic> msg) {
///   showDialog(
///     context: context,
///     barrierDismissible: false,
///     barrierColor: Colors.black87,
///     builder: (_) => IncomingCallDialog(
///       callerName: msg['callerName'] as String,
///       callType: msg['callType'] as String? ?? 'AUDIO',
///       onAccept: () { Navigator.pop(context); /* push CallScreen */ },
///       onDecline: () { ref.read(wsClientProvider).sendReject(callerId); Navigator.pop(context); },
///     ),
///   );
/// }
/// ```
class IncomingCallDialog extends StatefulWidget {
  final String callerName;
  final String callType;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallDialog({
    super.key,
    required this.callerName,
    required this.callType,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  bool get _isVideo => widget.callType == 'VIDEO';

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: pad.top + 60),

            // ── Type label ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ── Pulsing avatar ──
            ScaleTransition(
              scale: _pulse,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentSurface,
                  border: Border.all(
                    color: AppColors.accent.withOpacity(0.4),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.callerName.isNotEmpty
                        ? widget.callerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              widget.callerName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),
            const Text(
              'Exiled Drop',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textHint,
              ),
            ),

            const Spacer(),

            // ── Accept / Decline buttons ──
            Padding(
              padding: EdgeInsets.only(
                left: 48,
                right: 48,
                bottom: pad.bottom + 48,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Decline
                  _RoundCallButton(
                    icon: Icons.call_end_rounded,
                    label: 'Decline',
                    color: AppColors.callRed,
                    onTap: widget.onDecline,
                  ),

                  // Accept
                  _RoundCallButton(
                    icon: _isVideo
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    label: 'Accept',
                    color: AppColors.callGreen,
                    onTap: widget.onAccept,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundCallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RoundCallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}