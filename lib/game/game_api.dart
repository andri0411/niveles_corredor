import 'package:flame/components.dart';

/// Shared small API to avoid circular imports between game and components.
enum GameState { playing, won, intro, gameOver }

abstract class GameApi {
  GameState get gameState;
  double get groundHeight;
  Vector2 get size;
  void onPlayerDied();
}
