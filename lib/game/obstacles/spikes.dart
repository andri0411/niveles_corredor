import 'package:flame/components.dart';
import 'dart:typed_data';
import '../game_api.dart';

class Spike extends SpriteComponent {
  final Uint8List pixels;
  // Precomputed alpha mask: 1 for opaque, 0 for transparent, length = imgW * imgH
  final Uint8List alphaMask;
  final Vector2 naturalSize;

  Spike({
    Sprite? sprite,
    Vector2? position,
    Vector2? size,
    Anchor? anchor,
    required this.pixels,
    required this.alphaMask,
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
  // `target` must be mutable so caller can assign the player after
  // constructing the spike (avoids circular import issues).
  dynamic target;
  final double speed;
  final double startDelay;
  double _timeSinceSpawn = 0.0;
  bool _isMoving = false;
  double? _targetX;

  HomingSpike({
    this.target,
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
    // Use the typed GameApi when available.
    if (gameRef is GameApi) {
      final GameApi gr = gameRef as GameApi;
      if (gr.gameState != GameState.playing) return;
    } else {
      return;
    }

    if (target == null) return;

    if (!_isMoving) {
      _timeSinceSpawn += dt;
      if (_timeSinceSpawn >= startDelay) {
        _isMoving = true;
        // assume caller assigned a valid target (player) with position/size
        _targetX = target.position.x + target.size.x / 2;
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

    if (toRect().overlaps((target as dynamic).toRect())) {
      final inv = (target as dynamic).invulnerable ?? 0;
      if (inv <= 0) {
        if (gameRef is GameApi) {
          (gameRef as GameApi).onPlayerDied();
        }
        removeFromParent();
      }
    }
  }
}
