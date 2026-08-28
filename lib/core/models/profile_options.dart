import 'package:flutter/material.dart';

class SportOption {
  const SportOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

class EquipmentOption {
  const EquipmentOption({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

const profileSportOptions = [
  SportOption(
    id: 'walk',
    label: 'Yürüyüş',
    icon: Icons.directions_walk_rounded,
    color: Color(0xFF4A9BE8),
  ),
  SportOption(
    id: 'run',
    label: 'Koşu',
    icon: Icons.directions_run_rounded,
    color: Color(0xFF49B86A),
  ),
  SportOption(
    id: 'bike',
    label: 'Bisiklet',
    icon: Icons.directions_bike_rounded,
    color: Color(0xFFFFA14A),
  ),
  SportOption(
    id: 'swim',
    label: 'Yüzme',
    icon: Icons.pool_rounded,
    color: Color(0xFF2AA8A0),
  ),
  SportOption(
    id: 'hike',
    label: 'Hiking',
    icon: Icons.terrain_rounded,
    color: Color(0xFF9B7ADE),
  ),
  SportOption(
    id: 'trail',
    label: 'Trail',
    icon: Icons.hiking_rounded,
    color: Color(0xFF7A9B4A),
  ),
  SportOption(
    id: 'gym',
    label: 'Fitness',
    icon: Icons.fitness_center_rounded,
    color: Color(0xFFE15B64),
  ),
  SportOption(
    id: 'yoga',
    label: 'Yoga',
    icon: Icons.self_improvement_rounded,
    color: Color(0xFF6D62C5),
  ),
];

const profileEquipmentOptions = [
  EquipmentOption(id: 'shoes', label: 'Koşu ayakkabısı', icon: Icons.snowshoeing_rounded),
  EquipmentOption(id: 'watch', label: 'Akıllı saat', icon: Icons.watch_rounded),
  EquipmentOption(id: 'bike', label: 'Bisiklet', icon: Icons.pedal_bike_rounded),
  EquipmentOption(id: 'hr_monitor', label: 'Nabız monitörü', icon: Icons.monitor_heart_rounded),
  EquipmentOption(id: 'earbuds', label: 'Kulaklık', icon: Icons.headphones_rounded),
  EquipmentOption(id: 'pack', label: 'Çanta / yelek', icon: Icons.backpack_rounded),
  EquipmentOption(id: 'bottle', label: 'Su matarası', icon: Icons.local_drink_rounded),
  EquipmentOption(id: 'goggles', label: 'Yüzme gözlüğü', icon: Icons.visibility_rounded),
];

SportOption? sportById(String id) {
  for (final sport in profileSportOptions) {
    if (sport.id == id) return sport;
  }
  return null;
}

EquipmentOption? equipmentById(String id) {
  for (final item in profileEquipmentOptions) {
    if (item.id == id) return item;
  }
  return null;
}
