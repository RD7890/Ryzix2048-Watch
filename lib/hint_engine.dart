import 'dart:math';
import 'game.dart';

/// 1:1 port of hint-engine.js (Expectimax + monotonicity / smoothness /
/// empty / max-tile / corner / merge-potential heuristics).
class HintResult {
  HintResult(this.direction, this.confidence, this.scores);
  final Dir direction;
  final double confidence;
  final Map<Dir, double?> scores;
}

class HintEngine {
  static const List<Dir> _dirs = [Dir.left, Dir.up, Dir.right, Dir.down];

  static double _log2(num v) => log(v) / ln2;

  /// Convenience wrapper kept for existing callers.
  static Dir? getBestMove(Game2048 game) =>
      bestMove(game.board)?.direction;

  static HintResult? bestMove(List<List<int>> board, {int? depth}) {
    final empty = _countEmpty(board);
    int d = depth ?? (empty >= 8 ? 3 : (empty >= 4 ? 4 : 5));

    Dir? bestDir;
    double bestVal = -double.infinity;
    final scores = <Dir, double?>{};

    for (final dir in _dirs) {
      final res = _simulateMove(board, dir);
      if (!res.moved) {
        scores[dir] = null;
        continue;
      }
      final val =
          _expectimax(res.board, d - 1, false) + res.scoreGained * 0.01;
      scores[dir] = val;
      if (val > bestVal) {
        bestVal = val;
        bestDir = dir;
      }
    }

    if (bestDir == null) return null;

    final valid = scores.values.whereType<double>().toList()
      ..sort((a, b) => b.compareTo(a));
    final confidence = valid.length > 1
        ? min(1.0, (valid[0] - valid[1]) / (valid[0].abs() + 0.001))
        : 1.0;

    return HintResult(bestDir, confidence, scores);
  }

  static double _expectimax(
      List<List<int>> board, int depth, bool isPlayerTurn) {
    if (depth == 0) return _evaluate(board);

    if (isPlayerTurn) {
      double bestVal = -double.infinity;
      for (final dir in _dirs) {
        final res = _simulateMove(board, dir);
        if (!res.moved) continue;
        final val = _expectimax(res.board, depth - 1, false);
        if (val > bestVal) bestVal = val;
      }
      return bestVal == -double.infinity ? _evaluate(board) : bestVal;
    }

    final size = board.length;
    final emptyCells = <Point<int>>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (board[r][c] == 0) emptyCells.add(Point(c, r));
      }
    }
    if (emptyCells.isEmpty) return _evaluate(board);

    var sampled = emptyCells;
    if (emptyCells.length > 6) {
      sampled = (emptyCells.toList()..shuffle()).sublist(0, 6);
    }

    double total = 0;
    for (final cell in sampled) {
      final b2 = _cloneBoard(board);
      b2[cell.y][cell.x] = 2;
      total += 0.9 * _expectimax(b2, depth - 1, true);

      final b4 = _cloneBoard(board);
      b4[cell.y][cell.x] = 4;
      total += 0.1 * _expectimax(b4, depth - 1, true);
    }
    return total / sampled.length;
  }

  // ---------- heuristics ----------

  static int _countEmpty(List<List<int>> board) {
    var count = 0;
    for (final row in board) {
      for (final v in row) {
        if (v == 0) count++;
      }
    }
    return count;
  }

  static int _maxTile(List<List<int>> board) {
    var maxV = 0;
    for (final row in board) {
      for (final v in row) {
        if (v > maxV) maxV = v;
      }
    }
    return maxV;
  }

  static double _monotonicity(List<List<int>> board) {
    final size = board.length;
    final totals = [0.0, 0.0, 0.0, 0.0]; // up, down, left, right

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        final curr = board[r][c] != 0 ? _log2(board[r][c]) : 0.0;
        final next = board[r][c + 1] != 0 ? _log2(board[r][c + 1]) : 0.0;
        if (curr > next) {
          totals[2] += next - curr;
        } else if (next > curr) {
          totals[3] += curr - next;
        }
      }
    }

    for (var c = 0; c < size; c++) {
      for (var r = 0; r < size - 1; r++) {
        final curr = board[r][c] != 0 ? _log2(board[r][c]) : 0.0;
        final next = board[r + 1][c] != 0 ? _log2(board[r + 1][c]) : 0.0;
        if (curr > next) {
          totals[0] += next - curr;
        } else if (next > curr) {
          totals[1] += curr - next;
        }
      }
    }

    return max(totals[0], totals[1]) + max(totals[2], totals[3]);
  }

  static double _smoothness(List<List<int>> board) {
    final size = board.length;
    double smooth = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (board[r][c] == 0) continue;
        final val = _log2(board[r][c]);
        if (c + 1 < size && board[r][c + 1] != 0) {
          smooth -= (val - _log2(board[r][c + 1])).abs();
        }
        if (r + 1 < size && board[r + 1][c] != 0) {
          smooth -= (val - _log2(board[r + 1][c])).abs();
        }
      }
    }
    return smooth;
  }

  static double _cornerBonus(List<List<int>> board) {
    final size = board.length;
    final maxV = _maxTile(board);
    if (maxV == 0) return 0;
    final corners = [
      board[0][0],
      board[0][size - 1],
      board[size - 1][0],
      board[size - 1][size - 1],
    ];
    return corners.contains(maxV) ? _log2(maxV) * 3 : 0;
  }

  static double _mergePotential(List<List<int>> board) {
    final size = board.length;
    var merges = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (board[r][c] == 0) continue;
        if (c + 1 < size && board[r][c] == board[r][c + 1]) merges++;
        if (r + 1 < size && board[r][c] == board[r + 1][c]) merges++;
      }
    }
    return merges.toDouble();
  }

  static double _evaluate(List<List<int>> board) {
    final empty = _countEmpty(board);
    final maxV = _maxTile(board);
    final maxLog = maxV > 0 ? _log2(maxV) : 0.0;

    return _monotonicity(board) * 1.0 +
        _smoothness(board) * 0.1 +
        _log2(empty + 1) * 2.7 +
        maxLog * 1.0 +
        _cornerBonus(board) * 1.0 +
        _mergePotential(board) * 0.8;
  }

  // ---------- simulation ----------

  static List<List<int>> _cloneBoard(List<List<int>> board) =>
      board.map((row) => List<int>.from(row)).toList();

  static _SimResult _simulateMove(List<List<int>> board, Dir dir) {
    final size = board.length;
    final out = List.generate(size, (_) => List.filled(size, 0));

    List<int> getLine(int i) {
      final line = <int>[];
      for (var j = 0; j < size; j++) {
        switch (dir) {
          case Dir.left:
            line.add(board[i][j]);
          case Dir.right:
            line.add(board[i][size - 1 - j]);
          case Dir.up:
            line.add(board[j][i]);
          case Dir.down:
            line.add(board[size - 1 - j][i]);
        }
      }
      return line;
    }

    void setLine(int i, List<int> line) {
      for (var j = 0; j < size; j++) {
        final v = line[j];
        switch (dir) {
          case Dir.left:
            out[i][j] = v;
          case Dir.right:
            out[i][size - 1 - j] = v;
          case Dir.up:
            out[j][i] = v;
          case Dir.down:
            out[size - 1 - j][i] = v;
        }
      }
    }

    var scoreGained = 0;
    for (var i = 0; i < size; i++) {
      final line = getLine(i).where((v) => v != 0).toList();
      final merged = <int>[];
      for (var j = 0; j < line.length; j++) {
        if (j + 1 < line.length && line[j] == line[j + 1]) {
          final v = line[j] * 2;
          merged.add(v);
          scoreGained += v;
          j++;
        } else {
          merged.add(line[j]);
        }
      }
      while (merged.length < size) {
        merged.add(0);
      }
      setLine(i, merged);
    }

    var moved = false;
    for (var r = 0; r < size && !moved; r++) {
      for (var c = 0; c < size; c++) {
        if (out[r][c] != board[r][c]) {
          moved = true;
          break;
        }
      }
    }

    return _SimResult(moved, scoreGained, out);
  }
}

class _SimResult {
  _SimResult(this.moved, this.scoreGained, this.board);
  final bool moved;
  final int scoreGained;
  final List<List<int>> board;
}
