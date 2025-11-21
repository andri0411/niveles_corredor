import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'game/runner_game.dart';
import 'game/game_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final runner = RunnerGame();

  // Keys to identify overlay controls so the global Listener can ignore pointer
  // events that belong to UI controls (avoid triggering jump when pressing move buttons).
  final leftKey = GlobalKey();
  final rightKey = GlobalKey();
  final jumpKey = GlobalKey();

  // Pointer tracking structures for multitouch control handling.
  final Map<int, String> pointerToControl = <int, String>{};
  final Map<String, Set<int>> controlPointers = {
    'left': <int>{},
    'right': <int>{},
    'jump': <int>{},
  };

  // Notifiers so the overlay can reflect pressed state (for color change).
  final leftPressCount = ValueNotifier<int>(0);
  final rightPressCount = ValueNotifier<int>(0);
  final jumpPressCount = ValueNotifier<int>(0);

  void _startControl(String control) {
    if (runner.gameState != GameState.playing) return;
    switch (control) {
      case 'left':
        runner.moveLeftStart();
        break;
      case 'right':
        runner.moveRightStart();
        break;
      case 'jump':
        runner.pressJumpImmediate();
        break;
    }
  }

  void _stopControl(String control) {
    if (runner.gameState != GameState.playing) return;
    switch (control) {
      case 'left':
      case 'right':
        runner.moveStop();
        break;
      case 'jump':
        runner.releaseJumpImmediate();
        break;
    }
  }

  runApp(
    Listener(
      behavior: HitTestBehavior.opaque,
      // Track pointer ids to support robust multi-touch for left/right/jump
      // controls. We map each active pointer id to a control (left/right/jump)
      // and call the matching RunnerGame methods when the first pointer
      // presses a control and when the last pointer for that control lifts.
      onPointerDown: (ev) {
        // If we're in intro state, start the game on any pointer down.
        if (runner.gameState == GameState.intro) {
          runner.startGame();
          return;
        }

        // Hit-test overlays: prefer jump over left/right if overlapping.
        String? hit;
        final jumpObj = jumpKey.currentContext?.findRenderObject();
        if (jumpObj is RenderBox) {
          final jumpRect = jumpObj.localToGlobal(Offset.zero) & jumpObj.size;
          if (jumpRect.contains(ev.position)) hit = 'jump';
        }
        if (hit == null) {
          final leftObj = leftKey.currentContext?.findRenderObject();
          if (leftObj is RenderBox) {
            final leftRect = leftObj.localToGlobal(Offset.zero) & leftObj.size;
            if (leftRect.contains(ev.position)) hit = 'left';
          }
        }
        if (hit == null) {
          final rightObj = rightKey.currentContext?.findRenderObject();
          if (rightObj is RenderBox) {
            final rightRect =
                rightObj.localToGlobal(Offset.zero) & rightObj.size;
            if (rightRect.contains(ev.position)) hit = 'right';
          }
        }

        if (hit != null) {
          pointerToControl[ev.pointer] = hit;
          final set = controlPointers[hit]!;
          set.add(ev.pointer);
          if (set.length == 1) _startControl(hit);
          // update notifier for UI
          if (hit == 'left') leftPressCount.value = set.length;
          if (hit == 'right') rightPressCount.value = set.length;
          if (hit == 'jump') jumpPressCount.value = set.length;
        }
      },

      onPointerMove: (ev) {
        // Handle dragging between controls: update mapping if pointer moved
        // from one control to another.
        final previous = pointerToControl[ev.pointer];
        String? now;
        final jumpObj = jumpKey.currentContext?.findRenderObject();
        if (jumpObj is RenderBox) {
          final jumpRect = jumpObj.localToGlobal(Offset.zero) & jumpObj.size;
          if (jumpRect.contains(ev.position)) now = 'jump';
        }
        if (now == null) {
          final leftObj = leftKey.currentContext?.findRenderObject();
          if (leftObj is RenderBox) {
            final leftRect = leftObj.localToGlobal(Offset.zero) & leftObj.size;
            if (leftRect.contains(ev.position)) now = 'left';
          }
        }
        if (now == null) {
          final rightObj = rightKey.currentContext?.findRenderObject();
          if (rightObj is RenderBox) {
            final rightRect =
                rightObj.localToGlobal(Offset.zero) & rightObj.size;
            if (rightRect.contains(ev.position)) now = 'right';
          }
        }

        if (previous == now) return;

        // Remove from previous
        if (previous != null) {
          final prevSet = controlPointers[previous]!;
          prevSet.remove(ev.pointer);
          if (prevSet.isEmpty) _stopControl(previous);
          pointerToControl.remove(ev.pointer);
          // update previous notifier
          if (previous == 'left') leftPressCount.value = prevSet.length;
          if (previous == 'right') rightPressCount.value = prevSet.length;
          if (previous == 'jump') jumpPressCount.value = prevSet.length;
        }

        // Add to new
        if (now != null) {
          pointerToControl[ev.pointer] = now;
          final nowSet = controlPointers[now]!;
          nowSet.add(ev.pointer);
          if (nowSet.length == 1) _startControl(now);
          // update notifier for new control
          if (now == 'left') leftPressCount.value = nowSet.length;
          if (now == 'right') rightPressCount.value = nowSet.length;
          if (now == 'jump') jumpPressCount.value = nowSet.length;
        }
      },

      onPointerUp: (ev) {
        final control = pointerToControl.remove(ev.pointer);
        if (control != null) {
          final set = controlPointers[control]!;
          set.remove(ev.pointer);
          if (set.isEmpty) _stopControl(control);
          if (control == 'left') leftPressCount.value = set.length;
          if (control == 'right') rightPressCount.value = set.length;
          if (control == 'jump') jumpPressCount.value = set.length;
        }
      },

      onPointerCancel: (ev) {
        final control = pointerToControl.remove(ev.pointer);
        if (control != null) {
          final set = controlPointers[control]!;
          set.remove(ev.pointer);
          if (set.isEmpty) _stopControl(control);
          if (control == 'left') leftPressCount.value = set.length;
          if (control == 'right') rightPressCount.value = set.length;
          if (control == 'jump') jumpPressCount.value = set.length;
        }
      },
      child: GameWidget(
        game: runner,
        overlayBuilderMap: {
          'Controls': (context, game) {
            return SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left side: movement controls (aligned horizontally)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Left control: plain container; input handled by the
                          // top-level Listener using hit-testing + pointer ids.
                          ValueListenableBuilder<int>(
                            valueListenable: leftPressCount,
                            builder: (ctx, count, child) {
                              return Container(
                                key: leftKey,
                                width: 80,
                                height: 80,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: count > 0
                                      ? Colors.blueAccent.withOpacity(0.75)
                                      : Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.arrow_left,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: rightPressCount,
                            builder: (ctx, count, child) {
                              return Container(
                                key: rightKey,
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: count > 0
                                      ? Colors.blueAccent.withOpacity(0.75)
                                      : Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.arrow_right,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      // Right side: jump button (use press/release for lower latency)
                      // Jump control
                      ValueListenableBuilder<int>(
                        valueListenable: jumpPressCount,
                        builder: (ctx, count, child) {
                          return Container(
                            key: jumpKey,
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: count > 0
                                  ? Colors.blueAccent.withOpacity(0.75)
                                  : Colors.black54,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.arrow_upward,
                              color: Colors.white,
                              size: 36,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          'LevelComplete': (context, game) {
            final RunnerGame g = game as RunnerGame;
            return Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Has ganado',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Game Over',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
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
          },
        },
        initialActiveOverlays: const ['Controls'],
      ),
    ),
  );
}
