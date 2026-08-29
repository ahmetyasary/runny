import 'package:flutter/material.dart';

import '../../../core/models/activity.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/route_preview.dart';
import 'activity_history_controller.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final history = ActivityHistoryScope.of(context);

    return AnimatedBuilder(
      animation: history,
      builder: (context, _) {
        final activities = history.activities;

        return RefreshIndicator(
          onRefresh: history.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aktivitelerim',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Tamamladığın kayıtlar burada.',
                              style: TextStyle(
                                color: AppColors.mutedInk,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: history.refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      _Stat(
                        value: history.totalKm.toStringAsFixed(1),
                        label: 'Toplam km',
                      ),
                      _Stat(value: '${history.count}', label: 'Aktivite'),
                      _Stat(value: history.avgPace, label: 'Ort. tempo'),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 27, 20, 11),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Son aktiviteler',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextButton(
                        onPressed: history.refresh,
                        child: const Text('Yenile'),
                      ),
                    ],
                  ),
                ),
              ),
              if (history.loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (activities.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Henüz aktiviten yok.\n+ ile kayıt başlat, bitince burada görünecek.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.mutedInk,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverList.separated(
                    itemCount: activities.length,
                    itemBuilder: (context, index) => _ActivityListItem(
                      activity: activities[index],
                    ),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedInk, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityListItem extends StatelessWidget {
  const _ActivityListItem({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 85,
              height: 85,
              child: RoutePreview(height: 85, showLabel: false),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(activity.type.icon, size: 17, color: activity.type.color),
                      const SizedBox(width: 6),
                      Text(
                        activity.type.label,
                        style: TextStyle(
                          color: activity.type.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        activity.when,
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    activity.title,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Text(
                        '${activity.distance.toStringAsFixed(2)} km',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        activity.duration,
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 12,
                        ),
                      ),
                      if (activity.calories > 0) ...[
                        const SizedBox(width: 12),
                        Text(
                          '${activity.calories} kcal',
                          style: const TextStyle(
                            color: AppColors.mutedInk,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (activity.avgHeartRate != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          '♥ ${activity.avgHeartRate}',
                          style: const TextStyle(
                            color: AppColors.mutedInk,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (activity.elevationGainMeters > 0) ...[
                        const SizedBox(width: 12),
                        Text(
                          '↑ ${activity.elevationGainMeters.round()} m',
                          style: const TextStyle(
                            color: AppColors.mutedInk,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
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
