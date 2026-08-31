import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/activity.dart';
import '../../../core/theme/app_theme.dart';
import 'activity_map_view.dart';

class ActivityDetailPage extends StatelessWidget {
  const ActivityDetailPage({super.key, required this.activity});

  final Activity activity;

  String get _dateLabel {
    final d = activity.startedAt;
    if (d == null) return activity.when;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year} · $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final points = activity.routePoints;
    final center = points.isNotEmpty
        ? points[points.length ~/ 2]
        : const LatLng(41.0082, 28.9784);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(activity.title),
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 280,
            child: points.length >= 2
                ? ActivityMapView(
                    points: points,
                    initialCenter: center,
                    fitRoute: true,
                    interactive: true,
                  )
                : Container(
                    color: const Color(0xFFE8F0E6),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          activity.type.icon,
                          size: 40,
                          color: activity.type.color,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Bu aktivite için kayıtlı rota yok',
                          style: TextStyle(color: AppColors.mutedInk),
                        ),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: activity.type.color.withValues(alpha: .15),
                      child: Icon(
                        activity.type.icon,
                        color: activity.type.color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.type.label,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _dateLabel,
                            style: TextStyle(
                              color: AppColors.mutedInk,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (activity.location.isNotEmpty &&
                    activity.location != 'Konum yok') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: AppColors.mutedInk,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          activity.location,
                          style: TextStyle(
                            color: AppColors.mutedInk,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Özet',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _StatsGrid(
                  items: [
                    _StatItem(
                      label: 'Mesafe',
                      value: '${activity.distance.toStringAsFixed(2)} km',
                      icon: Icons.straighten_rounded,
                    ),
                    _StatItem(
                      label: 'Süre',
                      value: activity.duration,
                      icon: Icons.timer_outlined,
                    ),
                    _StatItem(
                      label: 'Tempo',
                      value: activity.paceLabel ?? '—',
                      icon: Icons.speed_rounded,
                    ),
                    _StatItem(
                      label: 'Kalori',
                      value: activity.calories > 0
                          ? '${activity.calories} kcal'
                          : '—',
                      icon: Icons.local_fire_department_outlined,
                    ),
                    _StatItem(
                      label: 'Tırmanış',
                      value: activity.elevationGainMeters > 0
                          ? '${activity.elevationGainMeters.toStringAsFixed(0)} m'
                          : '—',
                      icon: Icons.terrain_rounded,
                    ),
                    _StatItem(
                      label: 'Ort. nabız',
                      value: activity.avgHeartRate != null
                          ? '${activity.avgHeartRate} bpm'
                          : '—',
                      icon: Icons.favorite_outline_rounded,
                    ),
                    _StatItem(
                      label: 'Maks. nabız',
                      value: activity.maxHeartRate != null
                          ? '${activity.maxHeartRate} bpm'
                          : '—',
                      icon: Icons.monitor_heart_outlined,
                    ),
                    _StatItem(
                      label: 'Rota noktası',
                      value: '${activity.routePoints.length}',
                      icon: Icons.route_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.items});

  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width - 50) / 2,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.icon, size: 18, color: AppColors.mutedInk),
                  const SizedBox(height: 10),
                  Text(
                    item.value,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
