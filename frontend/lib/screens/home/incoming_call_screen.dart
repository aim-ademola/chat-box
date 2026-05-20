import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/constant/app_colors.dart';
import 'package:frontend/core/constant/app_style.dart';
import 'package:frontend/model/call_session_model.dart';
import 'package:frontend/provider/call_provider.dart';
import 'package:frontend/repositry/call_repositry.dart';
import 'package:frontend/screens/home/active_call_screen.dart';
import 'package:frontend/widget/user_avatar_widget.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key, required this.call});

  final CallSessionModel call;

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  bool _busy = false;
  Timer? _ringTimer;

  @override
  void initState() {
    super.initState();
    _startRinging();
  }

  @override
  void dispose() {
    _stopRinging();
    super.dispose();
  }

  void _startRinging() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.vibrate();

    _ringTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.vibrate();
    });
  }

  void _stopRinging() {
    _ringTimer?.cancel();
    _ringTimer = null;
  }

  Future<void> _accept() async {
    if (_busy) return;

    _stopRinging();
    setState(() {
      _busy = true;
    });

    try {
      final session = await ref
          .read(callRepositryProvider)
          .acceptCall(widget.call.id);
      ref.invalidate(recentCallsProvider);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ActiveCallScreen(session: session)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not accept this call.')),
      );
    }
  }

  Future<void> _reject() async {
    if (_busy) return;

    _stopRinging();
    setState(() {
      _busy = true;
    });

    try {
      await ref.read(callRepositryProvider).rejectCall(widget.call.id);
      ref.invalidate(recentCallsProvider);
    } catch (_) {
      // Still close the incoming-call screen if the local user rejects.
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _busy ? null : onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.white, size: 30),
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

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final callType = call.isVideoCall ? 'Video call' : 'Audio call';

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              UserAvatarWidget(
                initials: _initials(call.peerName),
                backgroundColor: AppColors.primary,
                radius: 58,
                profilePicUrl: call.peerProfilePicUrl,
              ),
              const SizedBox(height: 22),
              Text(
                call.peerName,
                textAlign: TextAlign.center,
                style: AppStyle.circularTextStyle(
                  size: 28,
                  weight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Incoming $callType',
                style: AppStyle.circularTextStyle(
                  size: 16,
                  weight: FontWeight.w500,
                  color: AppColors.textColor,
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    onTap: _reject,
                  ),
                  _buildButton(
                    icon: call.isVideoCall ? Icons.videocam : Icons.call,
                    color: AppColors.primary,
                    onTap: _accept,
                  ),
                ],
              ),
              const SizedBox(height: 44),
            ],
          ),
        ),
      ),
    );
  }
}
