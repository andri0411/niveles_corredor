import 'package:flame/components.dart';
import 'dart:typed_data';
import 'dart:math';
import 'spikes.dart';

class SpikeCreateResult {
  final List<Spike> spikes;
  final List<HomingSpike> homingSpikes;
  SpikeCreateResult(this.spikes, this.homingSpikes);
}

/// Creates spike components (static + homing) given the image and pixel data.
SpikeCreateResult createSpikesForScene({
  required Sprite spikeSprite,
  required Vector2 spikeNatural,
  required Uint8List spikePixels,
  required double visibleTop,
  required double groundHeight,
  required double canvasWidth,
}) {
  final List<Spike> spikes = [];
  final List<HomingSpike> homing = [];

  final double playerJumpSpeed = 420.0;
  final double playerGravity = 900.0;
  final double maxJump =
      (playerJumpSpeed * playerJumpSpeed) / (2 * playerGravity);
  final double spikeHeight = (min(
    groundHeight * 0.5,
    maxJump * 0.6,
  )).clamp(20.0, groundHeight);
  final double spikeScale = spikeHeight / spikeNatural.y;
  final double spikeWidth = spikeNatural.x * spikeScale;

  final List<double> spikeXs = [
    canvasWidth * 0.3,
    canvasWidth * 0.5,
    canvasWidth * 0.7,
  ];

  for (int i = 0; i < spikeXs.length; i++) {
    final x = spikeXs[i];
    if (i == spikeXs.length - 1) {
      final hom = HomingSpike(
        target: null, // will be assigned by caller if needed
        speed: 250.0,
        startDelay: 1.5,
        sprite: spikeSprite,
        position: Vector2(x, visibleTop),
        size: Vector2(spikeWidth, spikeHeight),
        anchor: Anchor.bottomCenter,
      );
      homing.add(hom);
    } else {
      final spike = Spike(
        sprite: spikeSprite,
        position: Vector2(x, visibleTop),
        size: Vector2(spikeWidth, spikeHeight),
        anchor: Anchor.bottomCenter,
        pixels: spikePixels,
        naturalSize: spikeNatural,
      );
      spikes.add(spike);
    }
  }

  return SpikeCreateResult(spikes, homing);
}
