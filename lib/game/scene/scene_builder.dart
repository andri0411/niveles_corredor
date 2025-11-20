import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class SceneBuildResult {
  final List<Component> components;
  final double groundHeight;
  final double visibleTop;

  SceneBuildResult(this.components, this.groundHeight, this.visibleTop);
}

/// Construye background y tiles de suelo y devuelve componentes listos para añadir al game.
SceneBuildResult buildGroundParts(
  ui.Image groundImage,
  Vector2 canvasSize,
  int topTrim,
) {
  final List<Component> comps = [];

  final background = RectangleComponent(
    position: Vector2.zero(),
    size: canvasSize,
    paint: Paint()..color = Colors.lightBlue,
  )..priority = -2;
  comps.add(background);

  final groundSprite = Sprite(groundImage);
  final spriteSize = Vector2(
    groundImage.width.toDouble(),
    groundImage.height.toDouble(),
  );
  final maxGround = canvasSize.y * 0.25;
  final desiredHeight = spriteSize.y <= maxGround ? spriteSize.y : maxGround;
  final scale = desiredHeight / spriteSize.y;
  final tileWidth = spriteSize.x * scale;
  final groundHeight = desiredHeight;

  final tiles = (canvasSize.x / tileWidth).ceil() + 1;
  for (int i = 0; i < tiles; i++) {
    final tile = SpriteComponent(
      sprite: groundSprite,
      position: Vector2(i * tileWidth, canvasSize.y),
      size: Vector2(tileWidth, groundHeight),
      anchor: Anchor.bottomLeft,
    )..priority = -1;
    comps.add(tile);
  }

  final visibleTop = canvasSize.y - groundHeight + topTrim * scale;

  return SceneBuildResult(comps, groundHeight, visibleTop);
}
