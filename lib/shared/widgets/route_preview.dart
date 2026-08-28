import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class RoutePreview extends StatelessWidget {
  const RoutePreview({
    super.key,
    this.height = 160,
    this.showLabel = true,
    this.locationLabel,
    this.accentColor,
  });

  final double height;
  final bool showLabel;
  final String? locationLabel;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final label = (locationLabel != null && locationLabel!.trim().isNotEmpty)
        ? locationLabel!.trim()
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _RouteMapPainter(accentColor: accentColor),
            ),
            if (showLabel && label != null)
              Positioned(
                left: 14,
                top: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .88),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: accentColor ?? AppColors.primaryDark,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  _RouteMapPainter({this.accentColor});

  final Color? accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final routeColor = accentColor ?? AppColors.primaryDark;
    final background = Paint()..color = const Color(0xFFE8F0E6);
    canvas.drawRect(Offset.zero & size, background);

    final park = Paint()..color = const Color(0xFFD4E8D0);
    canvas.drawOval(
      Rect.fromLTWH(size.width * .05, size.height * .15, size.width * .35, size.height * .8),
      park,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * .64, -size.height * .2, size.width * .48, size.height * .75),
      park,
    );

    final road = Paint()
      ..color = Colors.white.withValues(alpha: .8)
      ..strokeWidth = 2;
    for (var i = 1; i < 6; i++) {
      final y = size.height * i / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 18), road);
    }
    for (var i = -1; i < 7; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x + 110, size.height), road);
    }

    final route = Paint()
      ..color = routeColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .15, size.height * .73)
      ..cubicTo(
        size.width * .22,
        size.height * .25,
        size.width * .46,
        size.height * .18,
        size.width * .55,
        size.height * .5,
      )
      ..cubicTo(
        size.width * .63,
        size.height * .78,
        size.width * .77,
        size.height * .8,
        size.width * .84,
        size.height * .35,
      );
    canvas.drawPath(path, route);

    canvas.drawCircle(
      Offset(size.width * .15, size.height * .73),
      6,
      Paint()..color = AppColors.orange,
    );
    canvas.drawCircle(
      Offset(size.width * .84, size.height * .35),
      7,
      Paint()..color = routeColor,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}
