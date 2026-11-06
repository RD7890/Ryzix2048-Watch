import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game.dart';
import '../hint_engine.dart';
import '../sound.dart';
import '../store.dart';
import '../theme.dart';
import '../watch.dart';
import '../widgets/modals.dart';
import '../widgets/planet_backdrop.dart';
import '../widgets/tile_view.dart';
import '../widgets/wbutton.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.gridSize});
  final int gridSize;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final Game2048 _game = Game2048(widget.gridSize);
  bool _animating = false;
  final _store = RyzixStore.I;
  int _best = 0;
  bool _newRecord = false;
  final List<_ScorePop> _pops = [];

  Dir? _pendingHint;
  Dir? _glowDir;
  Timer? _hintTimer;
  Timer? _glowTimer;
  String? _toast;
  Timer? _toastTimer;
  int _popId = 0;
  Offset _dragStart = Offset.zero;
  double _swipeMin = 24; // swipe distance, scaled to the watch screen

  @override
  void initState() {
    super.initState();
    // Resume the previous board when it was left unfinished; a finished
    // (or missing / mismatched) save always starts a brand new game.
    final saved = _store.savedGame(widget.gridSize);
    if (!_game.restore(saved) || _game.isGameOver) {
      _game.reset();
      _persistGame();
    }
    _best = _store.bestFor(widget.gridSize);
  }

  /// Writes the live board to disk so an app kill loses nothing.
  void _persistGame() => _store.saveGame(widget.gridSize, _game.toJson());

  Future<void> _restart() async {
    if (_animating) return;
    final ok = await confirmDialog(
      context,
      title: 'Restart game?',
      message: 'Your current board and score will be lost.',
      confirmLabel: 'YES, RESTART',
    );
    if (!ok || !mounted) return;
    setState(() {
      _game.reset();
      _pops.clear();
      _pendingHint = null;
      _glowDir = null;
    });
    _persistGame();
  }

  void _undo() {
    if (_animating) return;
    Sfx.I.click();
    if (_game.undo()) {
      setState(() {});
      _persistGame();
    }
  }


  void _handleInput(Dir dir) {
    if (_animating) return;
    final res = _game.move(dir);
    if (!res.moved) return;

    setState(() {
      _animating = true;
      if (res.scoreGained > 0) {
        final id = _popId++;
        _pops.add(_ScorePop(id, '+${res.scoreGained}'));
        Timer(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _pops.removeWhere((p) => p.id == id));
        });
      }
      if (_game.score > _best) {
        _best = _game.score;
        _newRecord = _store.submitScore(widget.gridSize, _game.score);
      }
    });

    if (res.scoreGained > 0) {
      Sfx.I.merge(res.maxMergedVal);
      HapticFeedback.lightImpact();
    } else {
      Sfx.I.slide();
      HapticFeedback.selectionClick();
    }

    Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() {
        _game.settle();
        _animating = false;
      });
      _persistGame();
      if (_game.isGameOver) {
        // Finished game: no resume point, the next entry starts fresh.
        _store.clearSavedGame(widget.gridSize);
        Timer(const Duration(milliseconds: 300), () async {
          if (!mounted) return;
          Sfx.I.gameOver();
          _store.submitScore(widget.gridSize, _game.score);
          _store.recordGameFinished(_game.score);

          await showRyzixModal(
            context,
            ResultModal(
              title: _newRecord ? 'New Best!' : 'Game Over!',
              score: _game.score,
              best: _store.bestFor(widget.gridSize),
              player: _store.currentUser ?? 'Guest',
            ),
          );
          if (mounted) Navigator.of(context).pop();
        });
      }
    });
  }

  void _onDragEnd(Offset delta) {
    if (delta.dx.abs() > delta.dy.abs()) {
      if (delta.dx > _swipeMin) {
        _handleInput(Dir.right);
      } else if (delta.dx < -_swipeMin) {
        _handleInput(Dir.left);
      }
    } else {
      if (delta.dy > _swipeMin) {
        _handleInput(Dir.down);
      } else if (delta.dy < -_swipeMin) {
        _handleInput(Dir.up);
      }
    }
  }

  void _showToast(String msg) {
    _toastTimer?.cancel();
    setState(() => _toast = msg);
    _toastTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  String _dirName(Dir d) => switch (d) {
        Dir.up => 'UP',
        Dir.down => 'DOWN',
        Dir.left => 'LEFT',
        Dir.right => 'RIGHT',
      };

  void _useHint() {
    if (_animating) return;

    // Second tap: auto-play the pending hint.
    if (_pendingHint != null) {
      final dir = _pendingHint!;
      _pendingHint = null;
      _hintTimer?.cancel();
      _showToast('Playing: ${_dirName(dir)}');
      Sfx.I.click();
      _handleInput(dir);
      return;
    }

    final result = HintEngine.bestMove(_game.board);
    Sfx.I.click();
    if (result == null) {
      _showToast('No moves available');
      return;
    }

    _showToast('Best: ${_dirName(result.direction)} (tap again to play)');

    setState(() => _glowDir = result.direction);
    _glowTimer?.cancel();
    _glowTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _glowDir = null);
    });

    _pendingHint = result.direction;
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 1500), () {
      _pendingHint = null;
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _glowTimer?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    _swipeMin = math.max(14.0, 16 * u);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _dragStart = e.position,
      onPointerUp: (e) => _onDragEnd(e.position - _dragStart),
      child: Stack(
        children: [
          const Positioned.fill(child: Scrim(0.82)),
          LayoutBuilder(
            builder: (context, box) {
              final headerH = 28 * u;
              final dockH = 30 * u;
              final gap = 6 * u;
              final vPad = 6 * u;
              final availH =
                  box.maxHeight - headerH - dockH - gap * 2 - vPad * 2;
              final bs =
                  math.max(60.0, math.min(box.maxWidth - 14 * u, availH));
              final dockW = math.min(
                  box.maxWidth - 28 * u, math.max(bs * 0.8, 120 * u));
              return Padding(
                padding: EdgeInsets.symmetric(vertical: vPad),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _header(u, box.maxWidth - 14 * u, headerH),
                    SizedBox(height: gap),
                    _board(bs),
                    SizedBox(height: gap),
                    SizedBox(
                      width: dockW,
                      child: WDock(
                        height: 30,
                        items: [
                          WDockItem(
                            icon: Icons.rotate_left_rounded,
                            color: _game.canUndo ? C.cream : C.dim,
                            onTap: _undo,
                          ),
                          WDockItem(
                            icon: Icons.lightbulb_rounded,
                            active: true,
                            onTap: _useHint,
                          ),
                          WDockItem(
                            icon: Icons.rotate_right_rounded,
                            onTap: _restart,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_toast != null)
            Positioned(
              top: 4 * u,
              left: 0,
              right: 0,
              child: Center(child: _HintToast(text: _toast!)),
            ),
        ],
      ),
    );
  }

  Widget _header(double u, double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        children: [
          SizedBox(
            width: 50 * u,
            child: Align(
              alignment: Alignment.centerLeft,
              child: WRound(
                icon: Icons.home_rounded,
                size: 26,
                onTap: () {
                  Sfx.I.click();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _scoreBlock('SCORE', _game.score, big: true),
                for (final p in _pops)
                  Positioned(
                    top: -8 * u,
                    child: _ScorePopView(key: ValueKey(p.id), text: p.text),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 50 * u,
            child: Align(
              alignment: Alignment.centerRight,
              child: _scoreBlock('BEST', _best, big: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBlock(String label, int value, {required bool big}) {
    final u = context.u;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label,
            style: wLabel(context.fs(8),
                color: big ? C.copper : C.dim, ls: 1.6)),
        SizedBox(height: 1 * u),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$value',
            style: wLight(
              context.fs(big ? 22 : 14),
              color: big ? C.text : (_newRecord ? C.gold : C.blush),
              ls: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _board(double bs) {
    final n = widget.gridSize;
    const bw = 1.2; // board border width
    final pad = math.max(3.0, bs * 0.03);
    final g = math.max(2.0, bs * (n == 5 ? 0.018 : 0.026));
    final cell = (bs - 2 * (pad + bw) - g * (n - 1)) / n;
    final fs = cell * (n == 3 ? 0.40 : 0.42);
    final radius = bs * 0.075;
    final cellRadius = cell * 0.22;
    return RepaintBoundary(
      child: SizedBox(
        width: bs,
        height: bs,
        child: Stack(
          children: [
            Container(
              width: bs,
              height: bs,
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                color: const Color(0xE6090605),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: C.line, width: bw),
                boxShadow: const [
                  BoxShadow(color: Color(0x1FE37C48), blurRadius: 20),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // cell backgrounds
                  for (var r = 0; r < n; r++)
                    for (var c = 0; c < n; c++)
                      Positioned(
                        left: c * (cell + g),
                        top: r * (cell + g),
                        child: Container(
                          width: cell,
                          height: cell,
                          decoration: BoxDecoration(
                            color: const Color(0xFF17100D),
                            borderRadius: BorderRadius.circular(cellRadius),
                          ),
                        ),
                      ),
                  // tiles
                  for (final t in _game.tiles)
                    AnimatedPositioned(
                      key: ValueKey(t.id),
                      duration: const Duration(milliseconds: 150),
                      curve: const Cubic(0.25, 1, 0.5, 1),
                      left: t.x * (cell + g),
                      top: t.y * (cell + g),
                      child: TileView(
                        value: t.val,
                        size: cell,
                        fontSize: fs,
                        isNew: t.isNew,
                      ),
                    ),
                ],
              ),
            ),
            // hint: the best direction glows along that edge of the board
            if (_glowDir != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: _HintEdge(dir: _glowDir!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Copper glow + arrow along the board edge the hint engine recommends.
class _HintEdge extends StatelessWidget {
  const _HintEdge({required this.dir});
  final Dir dir;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final Alignment edge = switch (dir) {
      Dir.up => Alignment.topCenter,
      Dir.down => Alignment.bottomCenter,
      Dir.left => Alignment.centerLeft,
      Dir.right => Alignment.centerRight,
    };
    final Alignment opposite = Alignment(-edge.x, -edge.y);
    final IconData icon = switch (dir) {
      Dir.up => Icons.keyboard_arrow_up_rounded,
      Dir.down => Icons.keyboard_arrow_down_rounded,
      Dir.left => Icons.keyboard_arrow_left_rounded,
      Dir.right => Icons.keyboard_arrow_right_rounded,
    };
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: edge,
                end: opposite,
                colors: [
                  C.copper.withOpacity(0.62),
                  C.copper.withOpacity(0.0),
                ],
                stops: const [0.0, 0.42],
              ),
            ),
          ),
        ),
        Align(
          alignment: edge,
          child: Padding(
            padding: EdgeInsets.all(2 * u),
            child: Icon(icon, size: 20 * u, color: C.cream),
          ),
        ),
      ],
    );
  }
}

class _HintToast extends StatelessWidget {
  const _HintToast({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return IgnorePointer(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 176 * u),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10 * u, vertical: 5 * u),
          decoration: BoxDecoration(
            color: const Color(0xF5120D0B),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x80E37C48), width: 1),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 14),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: wLabel(context.fs(10), color: C.cream, ls: 0.3),
          ),
        ),
      ),
    );
  }
}

class _ScorePop {
  _ScorePop(this.id, this.text);
  final int id;
  final String text;
}

class _ScorePopView extends StatefulWidget {
  const _ScorePopView({super.key, required this.text});
  final String text;

  @override
  State<_ScorePopView> createState() => _ScorePopViewState();
}

class _ScorePopViewState extends State<_ScorePopView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, -16 * u * t),
          child: Opacity(
            opacity: 1 - t,
            child: Text(widget.text,
                style: wLabel(context.fs(12), color: C.copper, ls: 0.2)),
          ),
        );
      },
    );
  }
}
