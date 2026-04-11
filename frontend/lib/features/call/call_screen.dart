import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

class CallScreen extends ConsumerStatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final String callType; // AUDIO or VIDEO
  final bool isIncoming;
  final String? incomingSdp;

  const CallScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    required this.callType,
    required this.isIncoming,
    this.incomingSdp,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  StreamSubscription? _wsSub;

  bool _isMuted = false;
  bool _isCameraOff = true;
  bool _isSpeakerOn = false;
  bool _isConnected = false;
  bool _controlsVisible = true;
  String _status = 'Connecting...';
  Timer? _callTimer;
  int _callSeconds = 0;
  Timer? _hideControlsTimer;

  RTCRtpSender? _videoSender;

  static const _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {
        'urls': 'turn:192.168.1.154:3478',
        'username': 'exileddrop',
        'credential': 'turnpassword',
      },
    ],
  };

  bool get isVideo => widget.callType == 'VIDEO';

  @override
  void initState() {
    super.initState();
    // Speaker ON for video, earpiece for audio
    _isSpeakerOn = isVideo;
    _isCameraOff = !isVideo;
    _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _startLocalMedia();
    _listenForSignaling();

    if (widget.isIncoming) {
      setState(() => _status = 'Connecting...');
      await _createPeerConnection();
      await _pc!.setRemoteDescription(
        RTCSessionDescription(widget.incomingSdp!, 'offer'),
      );
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      ref
          .read(wsClientProvider)
          .sendCallAnswer(widget.targetUserId, answer.sdp!);
    } else {
      setState(() => _status = 'Ringing...');
      await _createPeerConnection();
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      ref.read(wsClientProvider).sendCallOffer(
        widget.targetUserId,
        offer.sdp!,
        widget.callType,
      );
    }
  }

  Future<void> _startLocalMedia() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': isVideo ? {'facingMode': 'user'} : false,
      });
      _localRenderer.srcObject = _localStream;
      Helper.setSpeakerphoneOn(_isSpeakerOn);
      setState(() {});
    } catch (e) {
      setState(() => _status = 'Media error');
    }
  }

  Future<void> _createPeerConnection() async {
    _pc = await createPeerConnection(_iceServers);

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        final sender = await _pc!.addTrack(track, _localStream!);
        if (track.kind == 'video') {
          _videoSender = sender;
        }
      }
    }

    _pc!.onIceCandidate = (candidate) {
      ref.read(wsClientProvider).sendIceCandidate(
        widget.targetUserId,
        candidate.candidate!,
        candidate.sdpMid!,
        candidate.sdpMLineIndex!,
      );
    };

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
        setState(() {
          _isConnected = true;
          _status = 'Connected';
        });
        _startCallTimer();
      }
    };

    _pc!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _hangup();
      }
    };
  }

  void _listenForSignaling() {
    _wsSub = ref.read(wsClientProvider).messages.listen((msg) {
      final type = msg['type'] as String?;
      if (type == 'call.answer') {
        _handleAnswer(msg);
      } else if (type == 'call.ice') {
        _handleIce(msg);
      } else if (type == 'call.hangup' || type == 'call.reject') {
        _hangup();
      }
    });
  }

  Future<void> _handleAnswer(Map<String, dynamic> msg) async {
    await _pc?.setRemoteDescription(
        RTCSessionDescription(msg['sdp'] as String, 'answer'));
  }

  Future<void> _handleIce(Map<String, dynamic> msg) async {
    await _pc?.addCandidate(RTCIceCandidate(
      msg['candidate'] as String,
      msg['sdpMid'] as String,
      msg['sdpMLineIndex'] as int,
    ));
  }

  // ── Controls ──

  void _toggleMute() {
    final audioTracks = _localStream?.getAudioTracks();
    if (audioTracks != null && audioTracks.isNotEmpty) {
      final enabled = audioTracks[0].enabled;
      audioTracks[0].enabled = !enabled;
      setState(() => _isMuted = enabled);
    }
  }

  /// Toggle camera — works mid-call even if started as audio-only.
  Future<void> _toggleCamera() async {
    if (_isCameraOff) {
      // ── Turn camera ON ──
      final existingVideo = _localStream?.getVideoTracks();
      if (existingVideo != null && existingVideo.isNotEmpty) {
        existingVideo[0].enabled = true;
      } else {
        // Audio-only call: acquire video track and add to peer connection
        try {
          final videoStream = await navigator.mediaDevices.getUserMedia({
            'audio': false,
            'video': {'facingMode': 'user'},
          });
          final videoTrack = videoStream.getVideoTracks().first;

          _localStream?.addTrack(videoTrack);
          _localRenderer.srcObject = _localStream;

          if (_pc != null) {
            if (_videoSender != null) {
              await _videoSender!.replaceTrack(videoTrack);
            } else {
              _videoSender =
              await _pc!.addTrack(videoTrack, _localStream!);
            }
          }
        } catch (e) {
          return; // camera unavailable
        }
      }
      setState(() => _isCameraOff = false);
    } else {
      // ── Turn camera OFF ──
      final videoTracks = _localStream?.getVideoTracks();
      if (videoTracks != null && videoTracks.isNotEmpty) {
        videoTracks[0].enabled = false;
      }
      setState(() => _isCameraOff = true);
    }
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    Helper.setSpeakerphoneOn(_isSpeakerOn);
  }

  void _switchCamera() {
    final videoTracks = _localStream?.getVideoTracks();
    if (videoTracks != null && videoTracks.isNotEmpty) {
      Helper.switchCamera(videoTracks[0]);
    }
  }

  void _hangup() {
    ref.read(wsClientProvider).sendHangup(widget.targetUserId);
    _cleanup();
    if (mounted) Navigator.of(context).pop();
  }

  void _cleanup() {
    _callTimer?.cancel();
    _hideControlsTimer?.cancel();
    _wsSub?.cancel();
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _pc?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  // ── Timer ──

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callSeconds++);
    });
  }

  String get _formattedDuration {
    final m = (_callSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_callSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Auto-hide ──

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isConnected && !_isCameraOff) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _onTapScreen() {
    setState(() => _controlsVisible = true);
    if (!_isCameraOff) _scheduleHideControls();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final showVideo = _isConnected && !_isCameraOff;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onTap: _onTapScreen,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full-screen remote video when active
            if (showVideo) ...[
              RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
              _buildVideoOverlay(),
            ] else
              _buildAudioLayout(),

            // Local PIP when camera on
            if (!_isCameraOff) _buildLocalPip(),
          ],
        ),
      ),
    );
  }

  /// Audio call: avatar + name at top, 2×2 controls at bottom.
  Widget _buildAudioLayout() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),

            // Avatar
            Container(
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
                  widget.targetUserName.isNotEmpty
                      ? widget.targetUserName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              widget.targetUserName,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _isConnected ? _formattedDuration : _status,
              style: TextStyle(
                fontSize: 15,
                color:
                _isConnected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),

            // Push controls to the bottom
            const Spacer(),

            _buildControlGrid(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Video call: top bar + bottom controls overlay.
  Widget _buildVideoOverlay() {
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: Column(
        children: [
          // Top bar
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 12,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  color: AppColors.textPrimary,
                  onPressed: _hangup,
                ),
                const Spacer(),
                Column(
                  children: [
                    Text(
                      widget.targetUserName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isConnected ? _formattedDuration : _status,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.cameraswitch_rounded, size: 22),
                  color: AppColors.textPrimary,
                  onPressed: _switchCamera,
                ),
              ],
            ),
          ),

          const Spacer(),

          // Bottom controls
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
            child: _buildControlGrid(),
          ),
        ],
      ),
    );
  }

  /// 2×2 grid of controls with translucent backdrop.
  Widget _buildControlGrid() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Speaker | Mute
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CallControl(
                icon: _isSpeakerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                active: _isSpeakerOn,
                onTap: _toggleSpeaker,
              ),
              _CallControl(
                icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: _isMuted ? 'Unmute' : 'Mute',
                active: _isMuted,
                onTap: _toggleMute,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Row 2: Camera | End
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CallControl(
                icon: _isCameraOff
                    ? Icons.videocam_off_rounded
                    : Icons.videocam_rounded,
                label: _isCameraOff ? 'Cam On' : 'Cam Off',
                active: _isCameraOff,
                onTap: _toggleCamera,
              ),
              _CallControl(
                icon: Icons.call_end_rounded,
                label: 'End',
                isDestructive: true,
                onTap: _hangup,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocalPip() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 64,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 100,
          height: 140,
          child: RTCVideoView(
            _localRenderer,
            mirror: true,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      ),
    );
  }
}

class _CallControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool isDestructive;
  final VoidCallback onTap;

  const _CallControl({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;

    if (isDestructive) {
      bg = AppColors.callRed;
      fg = Colors.white;
    } else if (active) {
      bg = AppColors.accent.withOpacity(0.2);
      fg = AppColors.accent;
    } else {
      bg = AppColors.surfaceVariant;
      fg = AppColors.textPrimary;
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: fg, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}