import 'dart:ui';

class GameCircle {
  final String id;
  final Offset position;
  final Color color;
  final double radius;
  final DateTime spawnTime;

  GameCircle({
    required this.id,
    required this.position,
    required this.color,
    this.radius = 30,
    required this.spawnTime,
  });
}
