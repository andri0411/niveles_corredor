import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

enum GameState {
  playing,
  won,
  intro,
  gameOver,
}

class RunnerGame extends FlameGame with TapCallbacks {
  GameState gameState = GameState.intro;
  Player? player;
  late double groundHeight;
  ui.Image? _groundImage;
  ui.Image? _spikeImage;
  Uint8List? _spikePixels;
  ui.Image? _doorImage;
  Uint8List? _doorPixels;
  Vector2? _doorNaturalSize;
  Rect? _doorRect;
  int? _groundTopTrim;
  final List<Component> _groundComponents = [];
  final List<Component> _spikeComponents = [];
  final List<Component> _homingSpikes = [];
  final double _playerStartX = 100.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await images.load('map.png');
    _groundImage = images.fromCache('map.png');
    _groundTopTrim = await _computeTopNonTransparent(_groundImage!);

    try {
      await images.load('pinchos.png');
      _spikeImage = images.fromCache('pinchos.png');
      final bd = await _spikeImage!.toByteData(format: ui.ImageByteFormat.rawRgba);
      _spikePixels = bd?.buffer.asUint8List();
    } catch (_) {
      _spikeImage = null;
    }

    try {
      await images.load('puerta.png');
      _doorImage = images.fromCache('puerta.png');
      final bd2 = await _doorImage!.toByteData(format: ui.ImageByteFormat.rawRgba);
      _doorPixels = bd2?.buffer.asUint8List();
    } catch (_) {
      _doorImage = null;
      _doorPixels = null;
    }

    if (size != Vector2.zero()) {
      _buildScene(size);
    }
    // Start in intro state, wait for a tap to begin
    gameState = GameState.intro;
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
    if (_groundImage == null) return;

    for (final c in _groundComponents) {
      remove(c);
    }
    _groundComponents.clear();

    for (final c in _homingSpikes) {
      remove(c);
    }
    _homingSpikes.clear();

    final background = RectangleComponent(position: Vector2.zero(), size: canvasSize, paint: Paint()..color = Colors.lightBlue)
      ..priority = -2;
    add(background);
    _groundComponents.add(background);

    final groundSprite = Sprite(_groundImage!);
    final spriteSize = Vector2(_groundImage!.width.toDouble(), _groundImage!.height.toDouble());
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

    final topTrim = _groundTopTrim ?? 0;
    final visibleTop = canvasSize.y - groundHeight + topTrim * scale;

    _doorRect = null;
    if (_doorImage != null) {
      final doorNatural = Vector2(_doorImage!.width.toDouble(), _doorImage!.height.toDouble());
      _doorNaturalSize = doorNatural;
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

    if (player != null) {
      remove(player!);
    }
    player = Player(size: Vector2(50, 50));
    player!.position = Vector2(_playerStartX, visibleTop - player!.size.y);
    add(player!);

    _addPinchos(visibleTop);
  }

  void _addPinchos(double visibleTop) {
    for (final c in _spikeComponents) {
      remove(c);
    }
    _spikeComponents.clear();

    if (_spikeImage != null && _spikePixels != null) {
      final spikeSprite = Sprite(_spikeImage!);
      final spikeNatural = Vector2(_spikeImage!.width.toDouble(), _spikeImage!.height.toDouble());
      final double playerJumpSpeed = 420.0;
      final double playerGravity = 900.0;
      final double maxJump = (playerJumpSpeed * playerJumpSpeed) / (2 * playerGravity);
      final double spikeHeight = (min(groundHeight * 0.5, maxJump * 0.6)).clamp(20.0, groundHeight);
      final double spikeScale = spikeHeight / spikeNatural.y;
      final double spikeWidth = spikeNatural.x * spikeScale;

      // Posiciones fijas para los pinchos
      final List<double> spikeXs = [
        size.x * 0.3,
        size.x * 0.5,
        size.x * 0.7,
      ];

      for (int i = 0; i < spikeXs.length; i++) {
        final x = spikeXs[i];
        // El último pincho será el que se mueve
        if (i == spikeXs.length - 1) {
          final homingSpike = HomingSpike(
            target: player!,
            speed: 250.0, // Velocidad reducida para que sea más fácil
            startDelay: 1.5,
            sprite: spikeSprite,
            position: Vector2(x, visibleTop),
            size: Vector2(spikeWidth, spikeHeight),
            anchor: Anchor.bottomCenter,
          )..priority = 0;
          add(homingSpike);
          _homingSpikes.add(homingSpike);
        } else {
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
    }
  }

  void onPlayerDied() {
    if (gameState == GameState.playing) {
      gameState = GameState.gameOver;
      overlays.add('GameOver');
      pauseEngine();
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (gameState == GameState.intro) {
      startGame();
    } else if (gameState == GameState.playing) {
      player?.jump();
    }
  }

  void startGame() {
    gameState = GameState.playing;
    overlays.remove('intro');
    resumeEngine();
  }

  void resetGame() {
    // Eliminar overlays
    overlays.remove('GameOver');
    overlays.remove('win');

    // Reiniciar estado y reconstruir la escena
    gameState = GameState.playing;
    _buildScene(size);
    if (player != null) {
      player!.invulnerable = 1.0; // Dar un segundo de invulnerabilidad
    }
    resumeEngine();
  }

  void onLevelComplete() {
    if (gameState == GameState.playing) {
      gameState = GameState.won;
      pauseEngine();
      overlays.add('win');
    }
  }

  void moveLeftStart() {
    if (gameState == GameState.playing) player?.moveLeft = true;
  }
  void moveRightStart() {
    if (gameState == GameState.playing) player?.moveRight = true;
  }
  void moveStop() {
    player?.moveLeft = false;
    player?.moveRight = false;
  }

  void jump() {
    if (gameState == GameState.playing) player?.jump();
  }
}

class Player extends PositionComponent with HasGameRef<RunnerGame> {
  Vector2 velocity = Vector2.zero();
  bool moveLeft = false;
  bool moveRight = false;
  double invulnerable = 0.0;

  final double acceleration = 1000;
  final double maxSpeed = 300;
  final double friction = 400;
  final double gravity = 900;
  final double jumpSpeed = -420;

  Player({Vector2? position, Vector2? size}) : super(position: position ?? Vector2.zero(), size: size ?? Vector2(50, 50));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.topLeft;
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.red,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (gameRef.gameState != GameState.playing) {
      // Si el juego no está en 'playing', no actualizar movimiento.
      // Aplicar fricción para que el personaje se detenga.
      if (velocity.x > 0) {
        velocity.x = (velocity.x - friction * dt).clamp(0, maxSpeed);
      } else if (velocity.x < 0) {
        velocity.x = (velocity.x + friction * dt).clamp(-maxSpeed, 0);
      }
      return;
    }

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

    velocity.y += gravity * dt;
    position += velocity * dt;

    final groundY = gameRef.size.y - gameRef.groundHeight;
    if (position.y + size.y >= groundY) {
      position.y = groundY - size.y;
      velocity.y = 0;
    }

    if (position.x < 0) {
      position.x = 0;
      if(velocity.x < 0) velocity.x = 0;
    }
    if (position.x + size.x > gameRef.size.x) {
      position.x = gameRef.size.x - size.x;
      if(velocity.x > 0) velocity.x = 0;
    }

    if (invulnerable > 0) {
      invulnerable -= dt;
      if (invulnerable < 0) invulnerable = 0;
    }

    if (invulnerable <= 0) {
      final playerRect = Rect.fromLTWH(position.x, position.y, size.x, size.y);
      for (final c in gameRef._spikeComponents) {
        if (c is Spike) {
          if (_checkPixelPerfectCollision(playerRect, c)) {
            gameRef.onPlayerDied();
            return;
          }
        }
      }
    }
    
    if (gameRef._doorRect != null) {
      final playerRect2 = Rect.fromLTWH(position.x, position.y, size.x, size.y);
      final doorRect = gameRef._doorRect!;
      if (playerRect2.overlaps(doorRect)) {
        if (gameRef._doorPixels != null && gameRef._doorNaturalSize != null) {
          if (_checkPixelPerfectDoorCollision(playerRect2, doorRect)) {
            gameRef.onLevelComplete();
          }
        } else {
          gameRef.onLevelComplete();
        }
      }
    }
  }

  bool _checkPixelPerfectCollision(Rect playerRect, Spike spike) {
    final spikeRect = Rect.fromLTWH(spike.position.x - spike.size.x / 2, spike.position.y - spike.size.y, spike.size.x, spike.size.y);
    if (!playerRect.overlaps(spikeRect)) return false;

    final overlap = playerRect.intersect(spikeRect);
    if (overlap.width <= 0 || overlap.height <= 0) return false;

    final int imgW = spike.naturalSize.x.toInt();
    final int imgH = spike.naturalSize.y.toInt();
    final Uint8List px = spike.pixels;

    final int stepX = max(1, (overlap.width / 10).floor());
    final int stepY = max(1, (overlap.height / 10).floor());

    for (double wy = overlap.top; wy < overlap.bottom; wy += stepY) {
      for (double wx = overlap.left; wx < overlap.right; wx += stepX) {
        final localX = wx - (spike.position.x - spike.size.x / 2);
        final localY = wy - (spike.position.y - spike.size.y);
        int imgX = ((localX / spike.size.x) * imgW).floor().clamp(0, imgW - 1);
        int imgY = ((localY / spike.size.y) * imgH).floor().clamp(0, imgH - 1);
        final idx = (imgY * imgW + imgX) * 4;
        if (px[idx + 3] > 10) return true;
      }
    }
    return false;
  }

  bool _checkPixelPerfectDoorCollision(Rect playerRect, Rect doorRect) {
    final overlap = playerRect.intersect(doorRect);
    if (overlap.width <= 0 || overlap.height <= 0) return false;

    final int imgW = gameRef._doorNaturalSize!.x.toInt();
    final int imgH = gameRef._doorNaturalSize!.y.toInt();
    final Uint8List px = gameRef._doorPixels!;

    final int stepX = max(1, (overlap.width / 10).floor());
    final int stepY = max(1, (overlap.height / 10).floor());

    for (double wy = overlap.top; wy < overlap.bottom; wy += stepY) {
      for (double wx = overlap.left; wx < overlap.right; wx += stepX) {
        final localX = wx - doorRect.left;
        final localY = wy - doorRect.top;
        int imgX = ((localX / doorRect.width) * imgW).floor().clamp(0, imgW - 1);
        int imgY = ((localY / doorRect.height) * imgH).floor().clamp(0, imgH - 1);
        final idx = (imgY * imgW + imgX) * 4;
        if (px[idx + 3] > 10) return true;
      }
    }
    return false;
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

class HomingSpike extends SpriteComponent with HasGameRef<RunnerGame> {
  final Player target;
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

    if (gameRef.gameState != GameState.playing) {
      return; // No se mueve si el juego no está en estado 'playing'
    }

    if (!target.isMounted) {
      removeFromParent();
      return;
    }

    if (!_isMoving) {
      _timeSinceSpawn += dt;
      if (_timeSinceSpawn >= startDelay) {
        _isMoving = true;
        _targetX = target.position.x + target.size.x / 2;
      } else {
        return;
      }
    }

    if (_targetX != null) {
      final directionX = (_targetX! - position.x).sign;
      position.x += directionX * speed * dt;

      if ((directionX > 0 && position.x >= _targetX!) || (directionX < 0 && position.x <= _targetX!)) {
        position.x = _targetX!;
        _targetX = null; // Detenerse al llegar al objetivo
      }
    }

    if (toRect().overlaps(target.toRect())) {
      if (target.invulnerable <= 0) {
        gameRef.onPlayerDied();
        removeFromParent();
      }
    }
  }
}