import 'dart:typed_data';
import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'obstacles/spikes.dart';

bool checkPixelPerfectCollision(Rect playerRect, Spike spike) {
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
  final Uint8List mask = spike.alphaMask;

  // Prefill left/top for clarity and to avoid recomputing the same values.
  final double spikeLeft = spike.position.x - spike.size.x / 2;
  final double spikeTop = spike.position.y - spike.size.y;

  // Dynamic sampling: when overlap area is small, sample every pixel for
  // accuracy; otherwise sample a grid to reduce cost.
  final double overlapArea = overlap.width * overlap.height;
  final bool fineSample = overlapArea < 400; // e.g. 20x20
  final int stepX = fineSample ? 1 : max(1, (overlap.width / 10).floor());
  final int stepY = fineSample ? 1 : max(1, (overlap.height / 10).floor());

  for (double wy = overlap.top; wy < overlap.bottom; wy += stepY) {
    for (double wx = overlap.left; wx < overlap.right; wx += stepX) {
      final idx = _indexForWorldPointOnSpike(
        spike,
        wx,
        wy,
        spikeLeft,
        spikeTop,
        imgW,
        imgH,
      );
      if (idx >= 0 && mask[idx] != 0) return true;
    }
  }
  // Fallback: sample the center of the overlap once in case the stepped
  // sampling missed a thin spike (can happen on small overlaps).
  final wx = overlap.left + overlap.width / 2;
  final wy = overlap.top + overlap.height / 2;
  final idx = _indexForWorldPointOnSpike(
    spike,
    wx,
    wy,
    spikeLeft,
    spikeTop,
    imgW,
    imgH,
  );
  if (idx >= 0 && mask[idx] != 0) return true;
  return false;
}

// Helper: map a world point (worldX, worldY) into the spike image mask index.
// Returns -1 if the point lies outside the spike's rectangle.
int _indexForWorldPointOnSpike(
  Spike spike,
  double worldX,
  double worldY,
  double spikeLeft,
  double spikeTop,
  int imgW,
  int imgH,
) {
  final localX = worldX - spikeLeft;
  final localY = worldY - spikeTop;
  if (localX < 0 ||
      localY < 0 ||
      localX > spike.size.x ||
      localY > spike.size.y)
    return -1;
  int imgX = ((localX / spike.size.x) * imgW).floor();
  int imgY = ((localY / spike.size.y) * imgH).floor();
  imgX = max(0, min(imgX, imgW - 1));
  imgY = max(0, min(imgY, imgH - 1));
  return imgY * imgW + imgX;
}

bool checkPixelPerfectDoorCollision(
  Rect playerRect,
  Rect doorRect,
  Vector2 doorNaturalSize,
  Uint8List doorPixels,
) {
  final overlap = playerRect.intersect(doorRect);
  if (overlap.width <= 0 || overlap.height <= 0) return false;

  final int imgW = doorNaturalSize.x.toInt();
  final int imgH = doorNaturalSize.y.toInt();
  final Uint8List px = doorPixels;

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
