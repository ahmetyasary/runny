class SportGoal {
  const SportGoal({
    this.weeklyKm,
    this.weeklyCount,
  });

  /// Haftalık mesafe hedefi (km). Mesafe sporları için.
  final double? weeklyKm;

  /// Haftalık seans hedefi. Fitness / yoga için (veya ek).
  final int? weeklyCount;

  bool get hasTarget =>
      (weeklyKm != null && weeklyKm! > 0) ||
      (weeklyCount != null && weeklyCount! > 0);

  SportGoal copyWith({
    double? weeklyKm,
    int? weeklyCount,
    bool clearKm = false,
    bool clearCount = false,
  }) {
    return SportGoal(
      weeklyKm: clearKm ? null : (weeklyKm ?? this.weeklyKm),
      weeklyCount: clearCount ? null : (weeklyCount ?? this.weeklyCount),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (weeklyKm != null && weeklyKm! > 0) 'weekly_km': weeklyKm,
      if (weeklyCount != null && weeklyCount! > 0) 'weekly_count': weeklyCount,
    };
  }

  factory SportGoal.fromJson(Map<String, dynamic> json) {
    return SportGoal(
      weeklyKm: (json['weekly_km'] as num?)?.toDouble(),
      weeklyCount: (json['weekly_count'] as num?)?.toInt(),
    );
  }

  static Map<String, SportGoal> mapFromJson(dynamic value) {
    if (value is! Map) return const {};
    final result = <String, SportGoal>{};
    value.forEach((key, raw) {
      if (raw is Map) {
        final goal = SportGoal.fromJson(Map<String, dynamic>.from(raw));
        if (goal.hasTarget) {
          result[key.toString()] = goal;
        }
      }
    });
    return result;
  }

  static Map<String, dynamic> mapToJson(Map<String, SportGoal> goals) {
    return {
      for (final entry in goals.entries)
        if (entry.value.hasTarget) entry.key: entry.value.toJson(),
    };
  }
}
