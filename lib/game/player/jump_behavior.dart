import 'package:flame/components.dart';

/// Lógica de salto: gravedad variable, coyote time y jump buffer.
/// Trabaja sobre la `velocity` compartida por el Player.
class JumpBehavior {
  final Vector2 velocity;

  // Parámetros ajustables
  final double gravity;
  final double jumpSpeed;
  final double holdJumpGravityMultiplier;
  final double shortHopMultiplier;
  final double coyoteTimeMax;
  final double jumpBufferMax;

  // Estados internos
  double _coyoteTimer = 0.0;
  double _jumpBufferTimer = 0.0;
  bool _jumpHeld = false;

  JumpBehavior(
    this.velocity, {
    this.gravity = 900,
    this.jumpSpeed = -420,
    this.holdJumpGravityMultiplier = 0.6,
    this.shortHopMultiplier = 0.5,
    this.coyoteTimeMax = 0.12,
    this.jumpBufferMax = 0.12,
  });

  void pressJump() {
    _jumpBufferTimer = jumpBufferMax;
  }

  void releaseJump() {
    _jumpHeld = false;
    if (velocity.y < 0) {
      velocity.y = velocity.y * shortHopMultiplier;
    }
  }

  /// Update vertical: modifica velocity.y y gestiona timers.
  /// `owner` y `groundY` se pasan desde Player para detectar suelo.
  void updateVertical(double dt, PositionComponent owner, double groundY) {
    // aplicar gravedad variable
    double gravityToApply = gravity;
    if (velocity.y < 0 && _jumpHeld)
      gravityToApply = gravity * holdJumpGravityMultiplier;
    velocity.y += gravityToApply * dt;

    // NOTA: no movemos owner.position aquí; Player hará position += velocity * dt

    // comprobar contacto con suelo
    if (owner.position.y + owner.size.y >= groundY) {
      owner.position.y = groundY - owner.size.y;
      velocity.y = 0;
      _coyoteTimer = coyoteTimeMax;
    }

    if (_coyoteTimer > 0) _coyoteTimer -= dt;
    if (_jumpBufferTimer > 0) _jumpBufferTimer -= dt;

    if (_jumpBufferTimer > 0 && _coyoteTimer > 0) {
      // ejecutar salto
      velocity.y = jumpSpeed;
      _jumpBufferTimer = 0.0;
      _coyoteTimer = 0.0;
      _jumpHeld = true;
    }
  }
}
