import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/constant/app_colors.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/model/call_session_model.dart';
import 'package:frontend/provider/call_provider.dart';
import 'package:frontend/repositry/call_repositry.dart';
import 'package:frontend/widget/user_avatar_widget.dart';
import 'package:permission_handler/permission_handler.dart';

class ActiveCallScreen extends ConsumerStatefulWidget {
  const ActiveCallScreen({super.key, required this.session});

  final CallSessionModel session;

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _joined = false;
  bool _muted = false;
  bool _cameraOff = false;
  bool _ending = false;
  String _statusText = 'Connecting...';

  bool get _isVideo => widget.session.isVideoCall;

  @override
  void initState() {
    super.initState();
    _startAgora();
  }

  @override
  void dispose() {
    _leaveAgora();
    super.dispose();
  }

  Future<void> _startAgora() async {
    try {
      final hasPermissions = await _requestPermissions();
      if (!hasPermissions) {
        return;
      }

      final engine = createAgoraRtcEngine();
      _engine = engine;

      await engine.initialize(
        RtcEngineContext(appId: widget.session.agoraAppId),
      );

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (!mounted) return;
            setState(() {
              _joined = true;
              _statusText = 'Waiting for ${widget.session.peerName}...';
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted) return;
            setState(() {
              _remoteUid = remoteUid;
              _statusText = 'Connected';
            });
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted || _remoteUid != remoteUid) return;
            setState(() {
              _remoteUid = null;
              _statusText = '${widget.session.peerName} left the call';
            });
          },
          onError: (error, message) {
            if (!mounted) return;
            setState(() {
              _statusText = 'Call error: $message';
            });
          },
        ),
      );

      await engine.enableAudio();
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      if (_isVideo) {
        await engine.enableVideo();
        await engine.startPreview();
      }

      await engine.joinChannel(
        token: widget.session.agoraToken,
        channelId: widget.session.channelName,
        uid: widget.session.agoraUid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } on AgoraRtcException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = _friendlyAgoraError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = e.toString();
      });
    }
  }

  Future<bool> _requestPermissions() async {
    final permissions = <Permission>[Permission.microphone];
    if (_isVideo) {
      permissions.add(Permission.camera);
    }

    try {
      final statuses = await permissions.request();
      final denied = statuses.values.any(
        (status) => status.isDenied || status.isPermanentlyDenied,
      );

      if (denied) {
        if (!mounted) return false;
        setState(() {
          _statusText = _isVideo
              ? 'Camera and microphone permission are needed for video calls.'
              : 'Microphone permission is needed for audio calls.';
        });
        return false;
      }

      return true;
    } on MissingPluginException {
      if (!mounted) return false;
      setState(() {
        _statusText =
            'Permission plugin is not ready. Stop the app and run it again after installing the new call packages.';
      });
      return false;
    }
  }

  Future<void> _leaveAgora() async {
    final engine = _engine;
    if (engine == null) return;

    await engine.leaveChannel();
    await engine.release();
    _engine = null;
  }

  Future<void> _endCall() async {
    if (_ending) return;

    setState(() {
      _ending = true;
      _statusText = 'Ending call...';
    });

    try {
      await ref.read(callRepositryProvider).endCall(widget.session.id);
      ref.invalidate(recentCallsProvider);
    } catch (_) {
      // The local call still needs to close even if saving the log fails.
    }

    await _leaveAgora();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _engine?.muteLocalAudioStream(next);
    if (!mounted) return;
    setState(() {
      _muted = next;
    });
  }

  Future<void> _toggleCamera() async {
    final next = !_cameraOff;
    await _engine?.muteLocalVideoStream(next);
    if (!mounted) return;
    setState(() {
      _cameraOff = next;
    });
  }

  Future<void> _switchCamera() async {
    await _engine?.switchCamera();
  }

  Widget _buildVideoStage() {
    final engine = _engine;
    if (!_isVideo || engine == null) {
      return _buildAudioStage();
    }

    final remoteUid = _remoteUid;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (remoteUid == null)
          _buildAudioStage()
        else
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: engine,
              canvas: VideoCanvas(uid: remoteUid),
              connection: RtcConnection(channelId: widget.session.channelName),
            ),
          ),
        Positioned(
          right: 20,
          top: 28,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 112,
              height: 160,
              child: _cameraOff
                  ? Container(
                      color: Colors.black54,
                      child: const Icon(
                        Icons.videocam_off,
                        color: Colors.white,
                      ),
                    )
                  : AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: engine,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioStage() {
    final peerName = widget.session.peerName.trim().isEmpty
        ? 'Contact'
        : widget.session.peerName.trim();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatarWidget(
            initials: _initials(peerName),
            backgroundColor: AppColors.primary,
            radius: 54,
            profilePicUrl: widget.session.peerProfilePicUrl,
          ),
          const SizedBox(height: 20),
          Text(
            peerName,
            textAlign: TextAlign.center,
            style: AppStyle.circularTextStyle(
              size: 26,
              weight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusText,
            textAlign: TextAlign.center,
            style: AppStyle.circularTextStyle(
              size: 15,
              weight: FontWeight.w500,
              color: AppColors.textColor,
            ),
          ),
          if (_joined) ...[
            const SizedBox(height: 8),
            Text(
              _remoteUid == null ? 'Joined channel' : 'Remote user connected',
              style: AppStyle.circularTextStyle(
                size: 13,
                weight: FontWeight.w500,
                color: AppColors.textColor,
              ),
            ),
          ],
          if (_statusText.contains('permission') ||
              _statusText.contains('Permission')) ...[
            const SizedBox(height: 18),
            TextButton(
              onPressed: openAppSettings,
              child: const Text('Open settings'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControl({
    required IconData icon,
    required Color background,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.white, size: 26),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).take(2).toList();
    final initials = parts
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .join();
    return initials.isEmpty ? 'U' : initials;
  }

  String _friendlyAgoraError(AgoraRtcException error) {
    if (error.code == -102 || error.code == 102) {
      return 'Agora rejected this call channel. Please try starting the call again.';
    }

    return 'Agora call error ${error.code}. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _buildVideoStage()),
              Positioned(
                left: 0,
                right: 0,
                bottom: 34,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildControl(
                      icon: _muted ? Icons.mic_off : Icons.mic,
                      background: Colors.white24,
                      onPressed: _toggleMute,
                    ),
                    if (_isVideo) ...[
                      const SizedBox(width: 18),
                      _buildControl(
                        icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                        background: Colors.white24,
                        onPressed: _toggleCamera,
                      ),
                      const SizedBox(width: 18),
                      _buildControl(
                        icon: Icons.cameraswitch,
                        background: Colors.white24,
                        onPressed: _switchCamera,
                      ),
                    ],
                    const SizedBox(width: 18),
                    _buildControl(
                      icon: Icons.call_end,
                      background: Colors.red,
                      onPressed: _endCall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
