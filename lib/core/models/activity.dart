import 'package:flutter/material.dart';

enum ActivityType { run, walk, bike, hike, swim, trail, gym, yoga }

extension ActivityTypeLabel on ActivityType {
  String get label => switch (this) {
        ActivityType.run => 'Koşu',
        ActivityType.walk => 'Yürüyüş',
        ActivityType.bike => 'Bisiklet',
        ActivityType.hike => 'Hiking',
        ActivityType.swim => 'Yüzme',
        ActivityType.trail => 'Trail',
        ActivityType.gym => 'Fitness',
        ActivityType.yoga => 'Yoga',
      };

  IconData get icon => switch (this) {
        ActivityType.run => Icons.directions_run_rounded,
        ActivityType.walk => Icons.directions_walk_rounded,
        ActivityType.bike => Icons.directions_bike_rounded,
        ActivityType.hike => Icons.terrain_rounded,
        ActivityType.swim => Icons.pool_rounded,
        ActivityType.trail => Icons.hiking_rounded,
        ActivityType.gym => Icons.fitness_center_rounded,
        ActivityType.yoga => Icons.self_improvement_rounded,
      };

  Color get color => switch (this) {
        ActivityType.run => const Color(0xFF49B86A),
        ActivityType.walk => const Color(0xFF4A9BE8),
        ActivityType.bike => const Color(0xFFFFA14A),
        ActivityType.hike => const Color(0xFF9B7ADE),
        ActivityType.swim => const Color(0xFF2AA8A0),
        ActivityType.trail => const Color(0xFF7A9B4A),
        ActivityType.gym => const Color(0xFFE15B64),
        ActivityType.yoga => const Color(0xFF6D62C5),
      };
}

class Activity {
  const Activity({
    required this.id,
    required this.userName,
    required this.userHandle,
    required this.type,
    required this.title,
    required this.location,
    required this.distance,
    required this.duration,
    required this.when,
    required this.likes,
    required this.comments,
    this.userId,
    this.calories = 0,
    this.elevationGainMeters = 0,
    this.avgHeartRate,
    this.maxHeartRate,
    this.isLiked = false,
  });

  final String id;
  final String? userId;
  final String userName;
  final String userHandle;
  final ActivityType type;
  final String title;
  final String location;
  final double distance;
  final String duration;
  final String when;
  final int likes;
  final int comments;
  final int calories;
  final double elevationGainMeters;
  final int? avgHeartRate;
  final int? maxHeartRate;
  final bool isLiked;

  Activity copyWith({
    int? likes,
    int? comments,
    bool? isLiked,
  }) {
    return Activity(
      id: id,
      userId: userId,
      userName: userName,
      userHandle: userHandle,
      type: type,
      title: title,
      location: location,
      distance: distance,
      duration: duration,
      when: when,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      calories: calories,
      elevationGainMeters: elevationGainMeters,
      avgHeartRate: avgHeartRate,
      maxHeartRate: maxHeartRate,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

const demoActivities = [
  Activity(
    id: '1',
    userName: 'Mert Kaya',
    userHandle: '@mertkaya',
    type: ActivityType.run,
    title: 'Sabah koşusu',
    location: 'Caddebostan Sahili',
    distance: 8.42,
    duration: '46:18',
    when: '12 dk önce',
    likes: 24,
    comments: 3,
    calories: 540,
  ),
  Activity(
    id: '2',
    userName: 'Buse Demir',
    userHandle: '@busedemir',
    type: ActivityType.bike,
    title: 'Şehir turu',
    location: 'İzmir, Kordon',
    distance: 22.8,
    duration: '1:24:06',
    when: '2 saat önce',
    likes: 41,
    comments: 7,
    calories: 780,
  ),
  Activity(
    id: '3',
    userName: 'Can Yıldız',
    userHandle: '@canyildiz',
    type: ActivityType.hike,
    title: 'Hafta sonu rotası',
    location: 'Belgrad Ormanı',
    distance: 11.3,
    duration: '2:18:42',
    when: 'Dün',
    likes: 68,
    comments: 12,
    calories: 920,
  ),
];
