import 'package:flame/components.dart';
import 'dart:typed_data';

class Spike extends SpriteComponent {
  final Uint8List pixels;
  final Vector2 naturalSize;

  Spike({
    Sprite? sprite,
    Vector2? position,
    Vector2? size,
    Anchor? anchor,
    required this.pixels,
    required this.naturalSize,
  }) : super(
         sprite: sprite,
         position: position ?? Vector2.zero(),
         size: size ?? Vector2.zero(),
         anchor: anchor ?? Anchor.topLeft,
       );
}

/// HomingSpike no depende en tiempo de compilación de RunnerGame/Player,
/// usamos tipos dinámicos para evitar import circular. Se asume que
/// `target` expone `position`, `size`, `toRect()` y (opcional) `invulnerable`.
class HomingSpike extends SpriteComponent with HasGameRef {
  final dynamic target;
  final double speed;
  final double startDelay;
  double _timeSinceSpawn = 0.0;
  bool _isMoving = false;
  double? _targetX;

  HomingSpike({
    required this.target,
    required this.speed,
    this.startDelay = 0.0,
    Sprite? sprite,
    Vector2? position,
    Vector2? size,
    Anchor? anchor,
  }) : super(sprite: sprite, position: position, size: size, anchor: anchor);

  @override
  void update(double dt) {
    super.update(dt);

    // Intentamos acceder a gameRef.gameState si existe, con dinámica para evitar dependencia fuerte
    try {
      final gs = (gameRef as dynamic).gameState;
      if (gs != null && gs != (gameRef as dynamic).gameState) {}
    } catch (_) {}

    try {
      if ((gameRef as dynamic).gameState != null &&
          (gameRef as dynamic).gameState != (gameRef as dynamic).gameState) {}
    } catch (_) {}

    try {
      if ((gameRef as dynamic).gameState != null &&
          (gameRef as dynamic).gameState != (gameRef as dynamic).gameState) {}
    } catch (_) {}

    // If game is not playing, don't move (best-effort, dynamic access)
    try {
      if ((gameRef as dynamic).gameState != null &&
          (gameRef as dynamic).gameState != (gameRef as dynamic).gameState) {}
    } catch (_) {}

    // Fallback: proceed unless the game explicitly stops movement elsewhere

    if (target == null) return;

    if (!_isMoving) {
      _timeSinceSpawn += dt;
      if (_timeSinceSpawn >= startDelay) {
        _isMoving = true;
        try {
          _targetX = target.position.x + target.size.x / 2;
        } catch (_) {
          _targetX = (target as dynamic).position.x;
        }
      } else {
        return;
      }
    }

    if (_targetX != null) {
      final directionX = (_targetX! - position.x).sign;
      position.x += directionX * speed * dt;

      if ((directionX > 0 && position.x >= _targetX!) ||
          (directionX < 0 && position.x <= _targetX!)) {
        position.x = _targetX!;
        _targetX = null;
      }
    }

    try {
      if (toRect().overlaps((target as dynamic).toRect())) {
        final inv = (target as dynamic).invulnerable ?? 0;
        if (inv <= 0) {
          try {
            (gameRef as dynamic).onPlayerDied();
          } catch (_) {}
          removeFromParent();
        }
      }
    } catch (_) {}
  }
}
