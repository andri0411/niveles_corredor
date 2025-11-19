import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class RunnerGame extends FlameGame {
  Player? player;
  late double groundHeight;
  // cache loaded image and keep references to created background/ground components
  ui.Image? _groundImage;
  ui.Image? _spikeImage;
  Uint8List? _spikePixels;
  ui.Image? _doorImage;
  Uint8List? _doorPixels;
  Vector2? _doorNaturalSize;
  Rect? _doorRect;
  int? _groundTopTrim; // rows of transparent pixels at top of the image
  final List<Component> _groundComponents = [];
  final List<Component> _spikeComponents = [];
  final double _playerStartX = 100.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // load ground image; actual sizing and placement will happen in onGameResize
    const groundAssetKey = 'map.png';
    await images.load(groundAssetKey);
    _groundImage = images.fromCache(groundAssetKey);
    // compute top transparent trim once
    _groundTopTrim = await _computeTopNonTransparent(_groundImage!);
    // load spike image if available
    const spikeKey = 'pinchos.png';
    try {
      await images.load(spikeKey);
      _spikeImage = images.fromCache(spikeKey);
      final bd = await _spikeImage!.toByteData(format: ui.ImageByteFormat.rawRgba);
      _spikePixels = bd?.buffer.asUint8List();
    } catch (_) {
      _spikeImage = null;
    }
    // load door image if available
    const doorKey = 'puerta.png';
    try {
      await images.load(doorKey);
      _doorImage = images.fromCache(doorKey);
      final bd2 = await _doorImage!.toByteData(format: ui.ImageByteFormat.rawRgba);
      _doorPixels = bd2?.buffer.asUint8List();
    } catch (_) {
      _doorImage = null;
      _doorPixels = null;
    }
    // image loaded - attempt build with current size (onGameResize will also rebuild)
    if (size != Vector2.zero()) {
      _buildScene(size);
    }
  }

  Future<int> _computeTopNonTransparent(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return 0;
    final data = byteData.buffer.asUint8List();
    final width = image.width;
    final height = image.height;

    for (int y = 0; y < height; y++) {
      final rowStart = y * width * 4;
      for (int x = 0; x < width; x++) {
        final alpha = data[rowStart + x * 4 + 3];
        if (alpha > 10) {
          return y;
        }
      }
    }
    return 0;
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    _buildScene(canvasSize);
  }

  void _buildScene(Vector2 canvasSize) {
    // if the ground image isn't loaded yet, skip building (onLoad will call _buildScene)
    if (_groundImage == null) {
      return;
    }

    // remove previous ground/background components
    for (final c in _groundComponents) {
      remove(c);
    }
    _groundComponents.clear();

    // background
    final background = RectangleComponent(position: Vector2.zero(), size: canvasSize, paint: Paint()..color = Colors.lightBlue)
      ..priority = -2;
    add(background);
    _groundComponents.add(background);

    // create tiled ground using the loaded image
    final groundSprite = Sprite(_groundImage!);
    final spriteSize = Vector2(_groundImage!.width.toDouble(), _groundImage!.height.toDouble());

    // cap the ground height to 25% of the screen height (keep natural height otherwise)
    final maxGround = canvasSize.y * 0.25;
    final desiredHeight = spriteSize.y <= maxGround ? spriteSize.y : maxGround;
    final scale = desiredHeight / spriteSize.y;
    final tileWidth = spriteSize.x * scale;
    groundHeight = desiredHeight;

    final tiles = (canvasSize.x / tileWidth).ceil() + 1;
    for (int i = 0; i < tiles; i++) {
      final tile = SpriteComponent(
        sprite: groundSprite,
        position: Vector2(i * tileWidth, canvasSize.y),
        size: Vector2(tileWidth, groundHeight),
        anchor: Anchor.bottomLeft,
      )..priority = -1;
      add(tile);
      _groundComponents.add(tile);
    }

    // compute visible top of the ground (where visible pixels start)
    final topTrim = _groundTopTrim ?? 0;
    final visibleTop = canvasSize.y - groundHeight + topTrim * scale; // where visible pixels start

    // place door at right edge (if available)
    _doorRect = null;
    if (_doorImage != null) {
      final doorNatural = Vector2(_doorImage!.width.toDouble(), _doorImage!.height.toDouble());
      _doorNaturalSize = doorNatural;
      // scale door so it doesn't exceed 1.5x ground height
      final doorHeight = min(doorNatural.y, groundHeight * 1.5);
      final doorScale = doorHeight / doorNatural.y;
      final doorWidth = doorNatural.x * doorScale;
      final doorComponent = SpriteComponent(
        sprite: Sprite(_doorImage!),
        position: Vector2(canvasSize.x, visibleTop),
        size: Vector2(doorWidth, doorHeight),
        anchor: Anchor.bottomRight,
      )..priority = 1;
      add(doorComponent);
      final doorLeft = canvasSize.x - doorWidth;
      _doorRect = Rect.fromLTWH(doorLeft, visibleTop - doorHeight, doorWidth, doorHeight);
    }

    // place spikes dispersed on the ground if the asset is available
    for (final c in _spikeComponents) {
      remove(c);
    }
    _spikeComponents.clear();
    if (_spikeImage != null && _spikePixels != null) {
      final spikeSprite = Sprite(_spikeImage!);
      final spikeNatural = Vector2(_spikeImage!.width.toDouble(), _spikeImage!.height.toDouble());
      // estimate player's max jump height using Player defaults
      final double playerJumpSpeed = 420.0;
      final double playerGravity = 900.0;
      final double maxJump = (playerJumpSpeed * playerJumpSpeed) / (2 * playerGravity);
      // spike height should be less than player's reachable height
      final double spikeHeight = (min(groundHeight * 0.5, maxJump * 0.6)).clamp(20.0, groundHeight);
      final double spikeScale = spikeHeight / spikeNatural.y;
      final double spikeWidth = spikeNatural.x * spikeScale;

      // generate exactly 3 spikes, randomly dispersed, never near the player's start
      final int spikeCount = 3;
      final rand = Random();
      // player's initial x (we place player at x=100)
      const double playerStartX = 100.0;
      final double minDistance = spikeWidth * 1.5; // minimum distance between spikes

      final List<double> spikeXs = [];
      int attempts = 0;
      while (spikeXs.length < spikeCount && attempts < 500) {
        attempts++;
        final double x = (rand.nextDouble() * (canvasSize.x - spikeWidth)) + spikeWidth / 2;
        // avoid near player start
        if ((x - playerStartX).abs() < spikeWidth * 1.5) continue;
        // avoid being too close to door
        if (_doorRect != null) {
          final doorLeft = _doorRect!.left;
          final doorRight = _doorRect!.right;
          if (x + spikeWidth / 2 > doorLeft && x - spikeWidth / 2 < doorRight) continue;
        }
        // avoid being too close to existing spikes
        var ok = true;
        for (final px in spikeXs) {
          if ((px - x).abs() < minDistance) {
            ok = false;
            break;
          }
        }
        if (ok) spikeXs.add(x);
      }

      // fallback: if not enough spikes found, distribute evenly but still avoid player start and door
      if (spikeXs.length < spikeCount) {
        spikeXs.clear();
        for (int i = 0; i < spikeCount; i++) {
          double x = ((i + 1) * canvasSize.x) / (spikeCount + 1);
          if ((x - playerStartX).abs() < spikeWidth * 1.5) {
            x = (x + minDistance).clamp(spikeWidth / 2, canvasSize.x - spikeWidth / 2);
          }
          if (_doorRect != null) {
            final doorLeft = _doorRect!.left;
            final doorRight = _doorRect!.right;
            if (x + spikeWidth / 2 > doorLeft && x - spikeWidth / 2 < doorRight) {
              x = (doorLeft - minDistance).clamp(spikeWidth / 2, canvasSize.x - spikeWidth / 2);
            }
          }
          spikeXs.add(x);
        }
      }

      for (final x in spikeXs) {
        final spike = Spike(
          sprite: spikeSprite,
          position: Vector2(x, visibleTop),
          size: Vector2(spikeWidth, spikeHeight),
          anchor: Anchor.bottomCenter,
          pixels: _spikePixels!,
          naturalSize: spikeNatural,
        )..priority = 0;
        add(spike);
        _spikeComponents.add(spike);
      }
    }

    // (re)place player exactly on top of the visible part of the ground
    if (player != null && player!.isMounted) {
      remove(player!);
    }
    player = Player(size: Vector2(50, 50));
    player!.position = Vector2(_playerStartX, visibleTop - player!.size.y);
    add(player!);
  }

  void respawnPlayer() {
    if (player == null) return;
    final canvasSize = size;
    final topTrim = _groundTopTrim ?? 0;
    final spriteHeight = _groundImage!.height.toDouble();
    final desiredHeight = groundHeight;
    final scale = desiredHeight / spriteHeight;
    final visibleTop = canvasSize.y - groundHeight + topTrim * scale;
    player!.position = Vector2(_playerStartX, visibleTop - player!.size.y);
    player!.velocity = Vector2.zero();
    player!.invulnerable = 1.0; // 1 second invulnerability after respawn
  }

  void onLevelComplete() {
    overlays.add('LevelComplete');
  }

  void restartLevel() {
    // hide overlay and rebuild scene with new random spikes
    overlays.remove('LevelComplete');
    _buildScene(size);
  }

  void moveLeftStart() => player?.moveLeft = true;
  void moveRightStart() => player?.moveRight = true;
  void moveStop() {
    player?.moveLeft = false;
    player?.moveRight = false;
  }

  void jump() => player?.jump();
}

class Player extends PositionComponent with HasGameRef<RunnerGame> {
  Vector2 velocity = Vector2.zero();
  bool moveLeft = false;
  bool moveRight = false;
  double invulnerable = 0.0;

  final double speed = 200;
  final double gravity = 900;
  final double jumpSpeed = -420;

  Player({Vector2? position, Vector2? size}) : super(position: position ?? Vector2.zero(), size: size ?? Vector2(50, 50));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.topLeft;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.red;
    canvas.drawRect(size.toRect(), paint);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (moveLeft) {
      velocity.x = -speed;
    } else if (moveRight) {
      velocity.x = speed;
    } else {
      velocity.x = 0;
    }

    velocity.y += gravity * dt;
    position += velocity * dt;

    final groundY = gameRef.size.y - gameRef.groundHeight;
    if (position.y + size.y >= groundY) {
      position.y = groundY - size.y;
      velocity.y = 0;
    }

    // keep within horizontal bounds
    if (position.x < 0) position.x = 0;
    if (position.x + size.x > gameRef.size.x) position.x = gameRef.size.x - size.x;

    // reduce invulnerability timer
    if (invulnerable > 0) {
      invulnerable -= dt;
      if (invulnerable < 0) invulnerable = 0;
    }

    // collision with spikes (only if not invulnerable) - pixel-perfect
    if (invulnerable <= 0) {
      final playerRect = Rect.fromLTWH(position.x, position.y, size.x, size.y);
      for (final c in gameRef._spikeComponents) {
        if (c is Spike) {
          final sx = c.position.x;
          final sy = c.position.y;
          final sw = c.size.x;
          final sh = c.size.y;
          final spikeLeft = sx - sw / 2;
          final spikeTop = sy - sh;
          final spikeRect = Rect.fromLTWH(spikeLeft, spikeTop, sw, sh);
          if (!playerRect.overlaps(spikeRect)) continue;

          // compute overlapping rect in world coords
          final overlap = playerRect.intersect(spikeRect);
          if (overlap.width <= 0 || overlap.height <= 0) continue;

          // map overlap area to spike image pixels and test alpha
          final int imgW = c.naturalSize.x.toInt();
          final int imgH = c.naturalSize.y.toInt();
          final Uint8List px = c.pixels;

          // sample every 2 pixels to save work
          final int stepX = max(1, (overlap.width / 20).floor());
          final int stepY = max(1, (overlap.height / 20).floor());

          bool hit = false;
          for (double wy = overlap.top; wy < overlap.bottom && !hit; wy += stepY) {
            for (double wx = overlap.left; wx < overlap.right; wx += stepX) {
              final localX = wx - spikeLeft; // 0..sw
              final localY = wy - spikeTop; // 0..sh
              int imgX = ((localX / sw) * imgW).floor();
              int imgY = ((localY / sh) * imgH).floor();
              imgX = imgX.clamp(0, imgW - 1);
              imgY = imgY.clamp(0, imgH - 1);
              final idx = (imgY * imgW + imgX) * 4;
              final a = px[idx + 3];
              if (a > 10) {
                hit = true;
                break;
              }
            }
          }
          if (hit) {
            gameRef.respawnPlayer();
            break;
          }
        }
      }
    }
    
      // detect collision with door (pixel-perfect if door pixels available)
      if (gameRef._doorRect != null) {
        final playerRect2 = Rect.fromLTWH(position.x, position.y, size.x, size.y);
        final doorRect = gameRef._doorRect!;
        if (playerRect2.overlaps(doorRect)) {
          // if we have pixel data for the door, do pixel-perfect check
          if (gameRef._doorPixels != null && gameRef._doorNaturalSize != null) {
            final overlap = playerRect2.intersect(doorRect);
            if (overlap.width > 0 && overlap.height > 0) {
              final int imgW = gameRef._doorNaturalSize!.x.toInt();
              final int imgH = gameRef._doorNaturalSize!.y.toInt();
              final Uint8List px = gameRef._doorPixels!;

              final double sw = doorRect.width;
              final double sh = doorRect.height;
              final double spikeLeft = doorRect.left; // reuse naming
              final double spikeTop = doorRect.top;

              final int stepX = max(1, (overlap.width / 20).floor());
              final int stepY = max(1, (overlap.height / 20).floor());
              bool doorHit = false;
              for (double wy = overlap.top; wy < overlap.bottom && !doorHit; wy += stepY) {
                for (double wx = overlap.left; wx < overlap.right && !doorHit; wx += stepX) {
                  final localX = wx - spikeLeft; // 0..sw
                  final localY = wy - spikeTop; // 0..sh
                  int imgX = ((localX / sw) * imgW).floor();
                  int imgY = ((localY / sh) * imgH).floor();
                  imgX = imgX.clamp(0, imgW - 1);
                  imgY = imgY.clamp(0, imgH - 1);
                  final idx = (imgY * imgW + imgX) * 4;
                  final a = px[idx + 3];
                  if (a > 10) {
                    doorHit = true;
                    break;
                  }
                }
              }
              if (doorHit) {
                gameRef.onLevelComplete();
              }
            }
          } else {
            // fallback to bounding-box
            gameRef.onLevelComplete();
          }
        }
      }
  }

  void jump() {
    final groundY = gameRef.size.y - gameRef.groundHeight;
    if ((position.y + size.y) >= groundY - 0.5) {
      velocity.y = jumpSpeed;
    }
  }
}

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
  }) : super(sprite: sprite, position: position ?? Vector2.zero(), size: size ?? Vector2.zero(), anchor: anchor ?? Anchor.topLeft);
}
