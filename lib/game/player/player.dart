import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'movement_behavior.dart';
import 'jump_behavior.dart';
import '../game_api.dart';
// dart:math not required here

/// Player component moved to its own file. Uses dynamic access to gameRef
/// to avoid circular imports with RunnerGame.
class Player extends PositionComponent with HasGameRef {
  Vector2 velocity = Vector2.zero();
  bool moveLeft = false;
  bool moveRight = false;
  double invulnerable = 0.0;

  late final MovementBehavior movement;
  late final JumpBehavior jumpBehavior;

  Player({Vector2? position, Vector2? size})
    : super(
        position: position ?? Vector2.zero(),
        size: size ?? Vector2(50, 50),
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.topLeft;
    movement = MovementBehavior(velocity);
    jumpBehavior = JumpBehavior(velocity);
    add(RectangleComponent(size: size, paint: Paint()..color = Colors.red));
  }

  @override
  void update(double dt) {
    super.update(dt);
    final GameApi gr = gameRef as GameApi;

    final isPlaying = gr.gameState == GameState.playing;
    if (!isPlaying) {
      movement.moveLeft = false;
      movement.moveRight = false;
      movement.updateHorizontal(dt);
      return;
    }

    movement.moveLeft = moveLeft;
    movement.moveRight = moveRight;
    movement.updateHorizontal(dt);

    final double groundY = gr.size.y - gr.groundHeight;
    jumpBehavior.updateVertical(dt, this, groundY);

    position += velocity * dt;

    if (position.x < 0) {
      position.x = 0;
      if (velocity.x < 0) velocity.x = 0;
    }
    final double gameW = gr.size.x;
    if (position.x + size.x > gameW) {
      position.x = gameW - size.x;
      if (velocity.x > 0) velocity.x = 0;
    }

    if (invulnerable > 0) {
      invulnerable -= dt;
      if (invulnerable < 0) invulnerable = 0;
    }
  }

  void pressJump() => jumpBehavior.pressJump();
  void releaseJump() => jumpBehavior.releaseJump();
  void jump() => pressJump();
}
