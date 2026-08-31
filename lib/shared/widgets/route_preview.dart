import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/theme/app_theme.dart';

class RoutePreview extends StatelessWidget {
  const RoutePreview({
    super.key,
    this.height = 160,
    this.showLabel = true,
    this.locationLabel,
    this.accentColor,
    this.routePoints = const [],
  });

  final double height;
  final bool showLabel;
  final String? locationLabel;
  final Color? accentColor;
  final List<LatLng> routePoints;

  @override
  Widget build(BuildContext context) {
    final label = (locationLabel != null && locationLabel!.trim().isNotEmpty)
        ? locationLabel!.trim()
        : null;
    final hasRealRoute = routePoints.length >= 2;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: hasRealRoute
                  ? _RealRoutePainter(
                      points: routePoints,
                      accentColor: accentColor,
                      isDark: dark,
                    )
                  : _RouteMapPainter(
                      accentColor: accentColor,
                      isDark: dark,
                    ),
            ),
            if (!hasRealRoute)
              Positioned(
                right: 12,
                bottom: 10,
                child: Text(
                  'Rota kaydı yok',
                  style: TextStyle(
                    color: AppColors.mutedInk.withValues(alpha: .85),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (showLabel && label != null)
              Positioned(
                left: 14,
                top: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: .92),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
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
                            style: TextStyle(
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

class _RealRoutePainter extends CustomPainter {
  _RealRoutePainter({
    required this.points,
    required this.isDark,
    this.accentColor,
  });

  final List<LatLng> points;
  final Color? accentColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final routeColor = accentColor ?? AppColors.primaryDark;
    final bg = isDark ? const Color(0xFF171E1A) : const Color(0xFFE8F0E6);
    final gridColor = isDark
        ? const Color(0xFF2A3530)
        : Colors.white.withValues(alpha: .55);

    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      final x = size.width * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final latSpan = (maxLat - minLat).abs() < 1e-7 ? 1e-7 : (maxLat - minLat);
    final lngSpan = (maxLng - minLng).abs() < 1e-7 ? 1e-7 : (maxLng - minLng);
    const pad = 18.0;
    final usableW = size.width - pad * 2;
    final usableH = size.height - pad * 2;

    Offset toOffset(LatLng p) {
      final x = pad + ((p.longitude - minLng) / lngSpan) * usableW;
      final y = pad + (1 - (p.latitude - minLat) / latSpan) * usableH;
      return Offset(x, y);
    }

    final sampled = _downsample(points, 120);
    final path = Path()
      ..moveTo(toOffset(sampled.first).dx, toOffset(sampled.first).dy);
    for (var i = 1; i < sampled.length; i++) {
      final o = toOffset(sampled[i]);
      path.lineTo(o.dx, o.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = routeColor
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final start = toOffset(sampled.first);
    final end = toOffset(sampled.last);
    canvas.drawCircle(start, 6, Paint()..color = AppColors.orange);
    canvas.drawCircle(end, 7, Paint()..color = routeColor);
    canvas.drawCircle(
      end,
      7,
      Paint()
        ..color = isDark ? const Color(0xFFE8EEE9) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  List<LatLng> _downsample(List<LatLng> source, int maxPoints) {
    if (source.length <= maxPoints) return source;
    final result = <LatLng>[source.first];
    final step = (source.length - 1) / (maxPoints - 1);
    for (var i = 1; i < maxPoints - 1; i++) {
      result.add(source[(i * step).round()]);
    }
    result.add(source.last);
    return result;
  }

  @override
  bool shouldRepaint(covariant _RealRoutePainter oldDelegate) =>
      oldDelegate.accentColor != accentColor ||
      oldDelegate.isDark != isDark ||
      oldDelegate.points.length != points.length ||
      (points.isNotEmpty &&
          oldDelegate.points.isNotEmpty &&
          (oldDelegate.points.first != points.first ||
              oldDelegate.points.last != points.last));
}

class _RouteMapPainter extends CustomPainter {
  _RouteMapPainter({
    required this.isDark,
    this.accentColor,
  });

  final Color? accentColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final routeColor = accentColor ?? AppColors.primaryDark;
    final bg = isDark ? const Color(0xFF171E1A) : const Color(0xFFE8F0E6);
    final parkColor =
        isDark ? const Color(0xFF1F2C24) : const Color(0xFFD4E8D0);
    final roadColor = isDark
        ? const Color(0xFF2A3530)
        : Colors.white.withValues(alpha: .8);

    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    final park = Paint()..color = parkColor;
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .05,
        size.height * .15,
        size.width * .35,
        size.height * .8,
      ),
      park,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .64,
        -size.height * .2,
        size.width * .48,
        size.height * .75,
      ),
      park,
    );

    final road = Paint()
      ..color = roadColor
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
      ..color = routeColor.withValues(alpha: isDark ? .45 : .35)
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
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor || oldDelegate.isDark != isDark;
}
