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
  int numSpikes = 3,
  bool makeLastHoming = true,
}) {
  final List<Spike> spikes = [];
  final List<HomingSpike> homing = [];

  // Precompute alpha mask for the spike sprite (1 = opaque, 0 = transparent)
  final int imgW = spikeNatural.x.toInt();
  final int imgH = spikeNatural.y.toInt();
  final Uint8List alphaMask = Uint8List(imgW * imgH);
  for (int y = 0; y < imgH; y++) {
    for (int x = 0; x < imgW; x++) {
      final idx = (y * imgW + x) * 4;
      alphaMask[y * imgW + x] = spikePixels[idx + 3] > 10 ? 1 : 0;
    }
  }

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

  // Generate `numSpikes` positions evenly spaced across the canvas width.
  // Keep a margin on both sides so spikes are not flush to edges.
  final margin = canvasWidth * 0.08;
  final usable = (canvasWidth - margin * 2).clamp(0.0, canvasWidth);
  final positions = <double>[];
  if (numSpikes <= 1) {
    positions.add(margin + usable / 2);
  } else {
    for (int i = 0; i < numSpikes; i++) {
      final t = i / (numSpikes - 1);
      positions.add(margin + t * usable);
    }
  }

  for (int i = 0; i < positions.length; i++) {
    final x = positions[i];
    final bool isLast = i == positions.length - 1;
    if (isLast && makeLastHoming) {
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
        alphaMask: alphaMask,
        naturalSize: spikeNatural,
      );
      spikes.add(spike);
    }
  }

  return SpikeCreateResult(spikes, homing);
}
