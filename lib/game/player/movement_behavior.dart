import 'package:flame/components.dart';

/// Lógica de movimiento horizontal separada.
class MovementBehavior {
  final Vector2 velocity;

  bool moveLeft = false;
  bool moveRight = false;

  final double acceleration;
  final double maxSpeed;
  final double friction;

  MovementBehavior(
    this.velocity, {
    this.acceleration = 1000,
    this.maxSpeed = 300,
    this.friction = 400,
  });

  /// Actualiza solo la componente X de velocity.
  void updateHorizontal(double dt) {
    if (moveLeft) {
      velocity.x = (velocity.x - acceleration * dt).clamp(-maxSpeed, maxSpeed);
    } else if (moveRight) {
      velocity.x = (velocity.x + acceleration * dt).clamp(-maxSpeed, maxSpeed);
    } else {
      if (velocity.x > 0) {
        velocity.x = (velocity.x - friction * dt).clamp(0, maxSpeed);
      } else if (velocity.x < 0) {
        velocity.x = (velocity.x + friction * dt).clamp(-maxSpeed, 0);
      }
    }
  }
}
