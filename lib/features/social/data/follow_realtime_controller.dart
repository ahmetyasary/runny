import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../feed/presentation/notifications_page.dart';
import '../../watch/data/watch_bridge.dart';
import 'social_repository.dart';

/// Uygulama genelinde takip realtime dinleyicisi.
/// HomeShell ayakta olduğu sürece her sekmede çalışır.
class FollowRealtimeController extends ChangeNotifier {
  RealtimeChannel? _channel;
  final Set<String> _seen = {};
  FeedNotificationItem? toast;
  Timer? _toastTimer;
  bool _listening = false;

  /// Feed bildirim listesine eklemek için.
  void Function(FeedNotificationItem item)? onFollowNotification;

  Future<void> start() async {
    if (_listening) return;
    _listening = true;
    await _subscribe();
  }

  Future<void> stop() async {
    _listening = false;
    _toastTimer?.cancel();
    toast = null;
    await _teardown();
  }

  Future<void> _teardown() async {
    final channel = _channel;
    _channel = null;
    final client = SupabaseService.client;
    if (channel == null || client == null) return;
    try {
      await client.removeChannel(channel);
    } catch (_) {}
  }

  Future<void> _subscribe() async {
    final client = SupabaseService.client;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null) {
      await _teardown();
      return;
    }

    await _teardown();

    final channel = client.channel('follows-inbox-$uid');
    // Filtreyi client-side yap — server filter bazı ortamlarda event düşürüyor.
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'follows',
      callback: (payload) => _onInsert(payload, uid),
    );
    channel.subscribe((status, [error]) {
      debugPrint('FollowRealtime status=$status error=$error');
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (_listening) unawaited(_subscribe());
        });
      }
    });
    _channel = channel;
    debugPrint('FollowRealtime subscribed for $uid');
  }

  void _onInsert(PostgresChangePayload payload, String me) {
    final row = payload.newRecord;
    final followerId = row['follower_id'] as String?;
    final followingId = row['following_id'] as String?;
    if (followerId == null || followingId == null) return;
    if (followingId != me || followerId == me) return;

    final notifId = 'follow_$followerId';
    if (_seen.contains(notifId)) return;
    _seen.add(notifId);

    final createdRaw = row['created_at'] as String?;
    final createdAt = createdRaw != null
        ? DateTime.tryParse(createdRaw)?.toLocal() ?? DateTime.now()
        : DateTime.now();

    final item = FeedNotificationItem(
      id: notifId,
      kind: FeedNotificationKind.follow,
      userId: followerId,
      userName: 'Yeni takipçi',
      createdAt: createdAt,
      isRead: false,
    );

    // Hemen toast — profil enrich beklenmeden.
    _showToast(item);
    onFollowNotification?.call(item);
    unawaited(_enrich(item));
  }

  Future<void> _enrich(FeedNotificationItem item) async {
    final client = SupabaseService.client;
    if (client == null) return;
    try {
      final profile =
          await SocialRepository(client).fetchProfileById(item.userId);
      if (profile == null) return;
      final enriched = FeedNotificationItem(
        id: item.id,
        kind: FeedNotificationKind.follow,
        userId: profile.id,
        userName: profile.name,
        userHandle: profile.handle,
        avatarUrl: profile.avatarUrl,
        createdAt: item.createdAt,
        isRead: item.isRead,
      );
      // Toast güncelle
      if (toast?.id == item.id) {
        toast = enriched;
        notifyListeners();
      }
      onFollowNotification?.call(enriched);
      await WatchBridge.notifyLocal(
        title: 'Yeni takipçi 👋',
        body: '${profile.name} seni takip etmeye başladı',
      );
    } catch (e) {
      debugPrint('FollowRealtime enrich failed: $e');
    }
  }

  void _showToast(FeedNotificationItem item) {
    _toastTimer?.cancel();
    toast = item;
    notifyListeners();
    _toastTimer = Timer(const Duration(seconds: 7), dismissToast);
  }

  void dismissToast() {
    _toastTimer?.cancel();
    if (toast == null) return;
    toast = null;
    notifyListeners();
  }
}
