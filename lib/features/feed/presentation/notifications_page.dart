import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../social/presentation/public_profile_page.dart';

class FeedNotificationItem {
  FeedNotificationItem({
    required this.activityId,
    required this.userId,
    required this.userName,
    required this.activityType,
    required this.title,
    required this.createdAt,
    this.avatarUrl,
    this.distanceKm,
    this.isRead = false,
  });

  final String activityId;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String activityType;
  final String title;
  final DateTime createdAt;
  final double? distanceKm;
  bool isRead;

  String get body {
    final dist = distanceKm;
    if (dist != null && dist > 0) {
      return '$activityType · ${dist.toStringAsFixed(dist >= 10 ? 0 : 1)} km';
    }
    return activityType;
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    required this.items,
    required this.onOpenActivity,
    required this.onMarkAllRead,
  });

  final List<FeedNotificationItem> items;
  final void Function(FeedNotificationItem item) onOpenActivity;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => onMarkAllRead());

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text(
          'Bildirimler',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      body: items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Henüz bildirim yok.\nTakip ettiklerin aktivite paylaşınca burada görünür.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedInk, height: 1.5),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return _NotificationTile(
                  item: item,
                  onTap: () {
                    onOpenActivity(item);
                    if (item.userId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PublicProfilePage(profileId: item.userId),
                        ),
                      );
                    }
                  },
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  final FeedNotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = item.userName.trim().isEmpty
        ? '?'
        : item.userName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((p) => p.isEmpty ? '' : p[0].toUpperCase())
            .join();

    return Material(
      color: item.isRead ? Colors.white : const Color(0xFFE8F5E9),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.softGreen,
                backgroundImage: item.avatarUrl != null
                    ? NetworkImage(item.avatarUrl!)
                    : null,
                child: item.avatarUrl == null
                    ? Text(
                        initials,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: item.userName,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const TextSpan(
                            text: ' yeni bir aktivite paylaştı',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.title.isNotEmpty ? item.title : item.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _relativeTime(item.createdAt),
                      style: const TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryDark,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeTime(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${at.day}.${at.month}.${at.year}';
  }
}
