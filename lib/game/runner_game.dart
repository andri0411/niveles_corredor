import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'player/player.dart';
import 'obstacles/spikes.dart';
import 'obstacles/spike_manager.dart';
import 'scene/scene_builder.dart';

enum GameState { playing, won, intro, gameOver }

class RunnerGame extends FlameGame with TapCallbacks {
  GameState gameState = GameState.intro;
  Player? player;
  late double groundHeight;
  ui.Image? _groundImage;
  ui.Image? _spikeImage;
  Uint8List? _spikePixels;
  ui.Image? _doorImage;
  // These are read dynamically by `Player` (outside this file).
  // ignore: unused_field
  Uint8List? _doorPixels;
  // ignore: unused_field
  Vector2? _doorNaturalSize;
  // ignore: unused_field
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
      final bd = await _spikeImage!.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      _spikePixels = bd?.buffer.asUint8List();
    } catch (_) {
      _spikeImage = null;
    }

    try {
      await images.load('puerta.png');
      _doorImage = images.fromCache('puerta.png');
      final bd2 = await _doorImage!.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
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

    final scene = buildGroundParts(
      _groundImage!,
      canvasSize,
      _groundTopTrim ?? 0,
    );
    for (final c in scene.components) {
      add(c);
      _groundComponents.add(c);
    }
    groundHeight = scene.groundHeight;
    final visibleTop = scene.visibleTop;

    _doorRect = null;
    if (_doorImage != null) {
      final doorNatural = Vector2(
        _doorImage!.width.toDouble(),
        _doorImage!.height.toDouble(),
      );
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
      _doorRect = Rect.fromLTWH(
        doorLeft,
        visibleTop - doorHeight,
        doorWidth,
        doorHeight,
      );
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
    // Remove previous spikes
    for (final c in _spikeComponents) remove(c);
    _spikeComponents.clear();
    for (final c in _homingSpikes) remove(c);
    _homingSpikes.clear();

    if (_spikeImage != null && _spikePixels != null) {
      final spikeSprite = Sprite(_spikeImage!);
      final spikeNatural = Vector2(
        _spikeImage!.width.toDouble(),
        _spikeImage!.height.toDouble(),
      );
      final result = createSpikesForScene(
        spikeSprite: spikeSprite,
        spikeNatural: spikeNatural,
        spikePixels: _spikePixels!,
        visibleTop: visibleTop,
        groundHeight: groundHeight,
        canvasWidth: size.x,
      );

      for (final s in result.spikes) {
        s.priority = 0;
        add(s);
        _spikeComponents.add(s);
      }
      for (final h in result.homingSpikes) {
        // assign target now that player exists
        // HomingSpike.target is typed as dynamic in obstacles, so we set via cast
        try {
          (h as dynamic).target = player;
        } catch (_) {}
        h.priority = 0;
        add(h);
        _homingSpikes.add(h);
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
      player?.pressJump();
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (gameState == GameState.playing) {
      player?.releaseJump();
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

  @override
  void update(double dt) {
    super.update(dt);

    // Centralizar detección de colisiones aquí: si el jugador toca un pincho => morir
    if (player == null || !player!.isMounted) return;

    if (player!.invulnerable <= 0 && gameState == GameState.playing) {
      final playerRect = Rect.fromLTWH(
        player!.position.x,
        player!.position.y,
        player!.size.x,
        player!.size.y,
      );
      for (final c in _spikeComponents) {
        if (c is Spike) {
          if (_checkPixelPerfectCollision(playerRect, c)) {
            onPlayerDied();
            return;
          }
        }
      }

      if (_doorRect != null) {
        if (playerRect.overlaps(_doorRect!)) {
          if (_doorPixels != null && _doorNaturalSize != null) {
            if (_checkPixelPerfectDoorCollision(playerRect, _doorRect!)) {
              onLevelComplete();
            }
          } else {
            onLevelComplete();
          }
        }
      }
    }
  }

  bool _checkPixelPerfectCollision(Rect playerRect, Spike spike) {
    final spikeRect = Rect.fromLTWH(
      spike.position.x - spike.size.x / 2,
      spike.position.y - spike.size.y,
      spike.size.x,
      spike.size.y,
    );
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

    final int imgW = _doorNaturalSize!.x.toInt();
    final int imgH = _doorNaturalSize!.y.toInt();
    final Uint8List px = _doorPixels!;

    final int stepX = max(1, (overlap.width / 10).floor());
    final int stepY = max(1, (overlap.height / 10).floor());

    for (double wy = overlap.top; wy < overlap.bottom; wy += stepY) {
      for (double wx = overlap.left; wx < overlap.right; wx += stepX) {
        final localX = wx - doorRect.left;
        final localY = wy - doorRect.top;
        int imgX = ((localX / doorRect.width) * imgW).floor().clamp(
          0,
          imgW - 1,
        );
        int imgY = ((localY / doorRect.height) * imgH).floor().clamp(
          0,
          imgH - 1,
        );
        final idx = (imgY * imgW + imgX) * 4;
        if (px[idx + 3] > 10) return true;
      }
    }
    return false;
  }
}
