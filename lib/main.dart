import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'game/runner_game.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(GameWidget(
    game: RunnerGame(),
    overlayBuilderMap: {
      'Controls': (context, game) {
        final RunnerGame g = game as RunnerGame;
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side: movement controls (aligned horizontally)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTapDown: (_) => g.moveLeftStart(),
                        onTapUp: (_) => g.moveStop(),
                        onTapCancel: () => g.moveStop(),
                        child: Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.arrow_left, color: Colors.white),
                        ),
                      ),
                      GestureDetector(
                        onTapDown: (_) => g.moveRightStart(),
                        onTapUp: (_) => g.moveStop(),
                        onTapCancel: () => g.moveStop(),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.arrow_right, color: Colors.white),
                        ),
                      ),
                    ],
                  ),

                  // Right side: jump button
                  GestureDetector(
                    onTap: () => g.jump(),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.arrow_upward, color: Colors.white, size: 36),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      ,
      'LevelComplete': (context, game) {
        final RunnerGame g = game as RunnerGame;
        return Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Has ganado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    g.resetGame();
                  },
                  child: const Text('Volver a jugar'),
                ),
              ],
            ),
          ),
        );
      },
      'GameOver': (context, game) {
        final RunnerGame g = game as RunnerGame;
        return Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Game Over', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    g.resetGame();
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        );
      }
    },
    initialActiveOverlays: const ['Controls'],
  ));
}
