import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'activity_recorder_page.dart';
import 'activity_session_controller.dart';

class FloatingActivityBubble extends StatefulWidget {
  const FloatingActivityBubble({
    super.key,
    required this.session,
    this.onCompleted,
  });

  final ActivitySessionController session;
  final Future<void> Function(ActivityStopResult result)? onCompleted;

  @override
  State<FloatingActivityBubble> createState() => _FloatingActivityBubbleState();
}

class _FloatingActivityBubbleState extends State<FloatingActivityBubble> {
  Offset _offset = const Offset(16, 120);
  bool _stopping = false;

  Future<void> _stopFromBubble() async {
    if (_stopping || !widget.session.isRecording) return;
    setState(() => _stopping = true);
    final result = await widget.session.stop(save: true);
    await widget.onCompleted?.call(result);
    if (!mounted) return;
    setState(() => _stopping = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    if (!session.isRecording || !session.isMinimized) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.sizeOf(context);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: _offset.dx.clamp(8, size.width - 196),
      top: _offset.dy.clamp(56, size.height - bottomSafe - 140),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() => _offset += details.delta);
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              session.expand();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ActivityRecorderPage(
                    activityType: session.activityType ?? 'Aktivite',
                    session: session,
                    onCompleted: widget.onCompleted,
                  ),
                ),
              );
            },
            child: Container(
              width: 180,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF6B6B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          session.activityType ?? 'Aktivite',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => unawaited(_stopFromBubble()),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.stop_circle_rounded,
                            color: Color(0xFFFF8A80),
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    session.formattedElapsed,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.formattedDistance,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (session.heartRateBpm != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '♥ ${session.formattedHeartRate} bpm · ↑ ${session.formattedElevation}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
