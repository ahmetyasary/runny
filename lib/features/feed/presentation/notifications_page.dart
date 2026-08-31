import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../social/presentation/public_profile_page.dart';

enum FeedNotificationKind { activity, follow }

class FeedNotificationItem {
  FeedNotificationItem({
    required this.id,
    required this.kind,
    required this.userId,
    required this.userName,
    required this.createdAt,
    this.userHandle,
    this.avatarUrl,
    this.activityId,
    this.activityType = '',
    this.title = '',
    this.distanceKm,
    this.isRead = false,
  });

  final String id;
  final FeedNotificationKind kind;
  final String userId;
  final String userName;
  final String? userHandle;
  final String? avatarUrl;
  final String? activityId;
  final String activityType;
  final String title;
  final DateTime createdAt;
  final double? distanceKm;
  bool isRead;

  String get body {
    if (kind == FeedNotificationKind.follow) {
      return userHandle ?? 'Seni takip etmeye başladı';
    }
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
    required this.onOpenItem,
    required this.onMarkAllRead,
  });

  final List<FeedNotificationItem> items;
  final void Function(FeedNotificationItem item) onOpenItem;
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
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Henüz bildirim yok.\nBirisi seni takip ettiğinde veya takip ettiklerin aktivite paylaşınca burada görünür.',
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
                return item.kind == FeedNotificationKind.follow
                    ? _FollowNotificationCard(
                        item: item,
                        onTap: () {
                          onOpenItem(item);
                          _openProfile(context, item.userId);
                        },
                      )
                    : _ActivityNotificationTile(
                        item: item,
                        onTap: () {
                          onOpenItem(item);
                          _openProfile(context, item.userId);
                        },
                      );
              },
            ),
    );
  }

  void _openProfile(BuildContext context, String userId) {
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfilePage(profileId: userId),
      ),
    );
  }
}

/// Anlık takip kutlaması — ekranın üstünde şık kart.
class FollowToastCard extends StatelessWidget {
  const FollowToastCard({
    super.key,
    required this.userName,
    this.userHandle,
    this.avatarUrl,
    required this.onOpen,
    required this.onDismiss,
  });

  final String userName;
  final String? userHandle;
  final String? avatarUrl;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(userName);

    return Material(
      elevation: 10,
      shadowColor: AppColors.primaryDark.withValues(alpha: .25),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1F6B3A),
                Color(0xFF2F9E55),
                Color(0xFF49B86A),
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withValues(alpha: .2),
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                    child: avatarUrl == null
                        ? Text(
                            initials,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 14,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Yeni takipçi',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      userHandle == null || userHandle!.isEmpty
                          ? 'Seni takip etmeye başladı'
                          : '$userHandle · seni takip ediyor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  backgroundColor: AppColors.card,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 34),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Gör',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yukarıdan kayarak gelir, kapanırken yukarı kayarak çıkar.
class AnimatedFollowToast extends StatefulWidget {
  const AnimatedFollowToast({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onDismiss,
  });

  static const Duration animDuration = Duration(milliseconds: 380);

  final FeedNotificationItem? item;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  State<AnimatedFollowToast> createState() => _AnimatedFollowToastState();
}

class _AnimatedFollowToastState extends State<AnimatedFollowToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  FeedNotificationItem? _displayed;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AnimatedFollowToast.animDuration,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.15),
      end: Offset.zero,
    ).animate(curve);
    _fade = Tween<double>(begin: 0, end: 1).animate(curve);

    if (widget.item != null) {
      _displayed = widget.item;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedFollowToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.item;
    final prev = oldWidget.item;

    if (next != null && next.id != prev?.id) {
      // Yeni toast: hemen göster + aşağı kaydır.
      setState(() => _displayed = next);
      _controller.forward(from: 0);
    } else if (next != null && prev != null && next.id == prev.id) {
      // Enrich (isim/avatar güncellemesi).
      setState(() => _displayed = next);
    } else if (next == null && prev != null) {
      // Kapanış: yukarı kaydır, bitince kaldır.
      _controller.reverse().whenComplete(() {
        if (!mounted) return;
        if (widget.item == null) {
          setState(() => _displayed = null);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _displayed;
    if (item == null) return const SizedBox.shrink();

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: FollowToastCard(
              userName: item.userName,
              userHandle: item.userHandle,
              avatarUrl: item.avatarUrl,
              onOpen: widget.onOpen,
              onDismiss: widget.onDismiss,
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowNotificationCard extends StatelessWidget {
  const _FollowNotificationCard({
    required this.item,
    required this.onTap,
  });

  final FeedNotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(item.userName);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: item.isRead
                  ? const [Color(0xFFF3F8F4), Color(0xFFEAF4EC)]
                  : const [Color(0xFFE2F4E7), Color(0xFFD3EFD9)],
            ),
            border: Border.all(
              color: item.isRead
                  ? AppColors.line
                  : AppColors.primary.withValues(alpha: .35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.softGreen,
                      backgroundImage: item.avatarUrl != null
                          ? NetworkImage(item.avatarUrl!)
                          : null,
                      child: item.avatarUrl == null
                          ? Text(
                              initials,
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
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
                              style: TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            TextSpan(
                              text: ' seni takip etmeye başladı',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.userHandle != null &&
                          item.userHandle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.userHandle!,
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _relativeTime(item.createdAt),
                        style: TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Profil',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityNotificationTile extends StatelessWidget {
  const _ActivityNotificationTile({
    required this.item,
    required this.onTap,
  });

  final FeedNotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(item.userName);

    return Material(
      color: item.isRead ? AppColors.card : (AppColors.isDark ? const Color(0xFF243528) : const Color(0xFFE8F5E9)),
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
                        style: TextStyle(
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
                            style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
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
                      style: TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _relativeTime(item.createdAt),
                      style: TextStyle(
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
                  decoration: BoxDecoration(
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
}

String _initials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed
      .split(RegExp(r'\s+'))
      .take(2)
      .map((p) => p.isEmpty ? '' : p[0].toUpperCase())
      .join();
}

String _relativeTime(DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return 'Az önce';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} sa önce';
  if (diff.inDays < 7) return '${diff.inDays} gün önce';
  return '${at.day}.${at.month}.${at.year}';
}
