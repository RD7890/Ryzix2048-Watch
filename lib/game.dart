import 'dart:math';

enum Dir { up, down, left, right }

class TileData {
  TileData({
    required this.id,
    required this.x,
    required this.y,
    required this.val,
    this.isNew = true,
  });

  final int id;
  int x;
  int y;
  int val;
  bool isNew;

  // transient move flags (mirror the web engine)
  bool isMerged = false;
  bool isMerging = false;
  bool mergedThisTurn = false;
  bool toDelete = false;
  int nextVal = 0;

  TileData clone() => TileData(id: id, x: x, y: y, val: val, isNew: false)
    ..isMerged = isMerged;
}

class MoveResult {
  MoveResult(this.moved, this.scoreGained, this.maxMergedVal);
  final bool moved;
  final int scoreGained;
  final int maxMergedVal;
}

class _Snapshot {
  _Snapshot(this.board, this.tiles, this.score);
  final List<List<int>> board;
  final List<TileData> tiles;
  final int score;
}

/// Pure game engine — identical rules & deferred-merge timing to the web build.
class Game2048 {
  Game2048(this.gridSize);

  final int gridSize;
  final _rng = Random();

  late List<List<int>> board;
  List<TileData> tiles = [];
  final List<_Snapshot> _history = [];
  int _idCounter = 1;
  int score = 0;

  bool get canUndo => _history.isNotEmpty;

  void reset() {
    score = 0;
    tiles = [];
    _idCounter = 1;
    _history.clear();
    board = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    spawnTile();
    spawnTile();
  }

  void spawnTile() {
    final empty = <Point<int>>[];
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        if (board[r][c] == 0) empty.add(Point(c, r));
      }
    }
    if (empty.isEmpty) return;
    final cell = empty[_rng.nextInt(empty.length)];
    final val = _rng.nextDouble() < 0.9 ? 2 : 4;
    board[cell.y][cell.x] = val;
    tiles.add(TileData(id: _idCounter++, x: cell.x, y: cell.y, val: val));
  }

  void _saveHistory() {
    _history.add(_Snapshot(
      [for (final row in board) List<int>.from(row)],
      [for (final t in tiles) t.clone()],
      score,
    ));
    if (_history.length > 5) _history.removeAt(0);
  }

  bool undo() {
    if (_history.isEmpty) return false;
    final s = _history.removeLast();
    board = s.board;
    tiles = s.tiles;
    score = s.score;
    return true;
  }

  MoveResult move(Dir dir) {
    _saveHistory();

    var vx = 0, vy = 0;
    switch (dir) {
      case Dir.up:
        vy = -1;
      case Dir.down:
        vy = 1;
      case Dir.left:
        vx = -1;
      case Dir.right:
        vx = 1;
    }

    final xs = List<int>.generate(gridSize, (i) => i);
    final ys = List<int>.generate(gridSize, (i) => i);
    if (vx == 1) xs.setAll(0, xs.reversed.toList());
    if (vy == 1) ys.setAll(0, ys.reversed.toList());

    var moved = false, scoreGained = 0, maxMergedVal = 0;

    // Fast position lookup: avoid scanning the whole tile list per cell.
    final tileByPos = <Point<int>, TileData>{};
    for (final t in tiles) {
      t.mergedThisTurn = false;
      if (!t.toDelete) tileByPos[Point(t.x, t.y)] = t;
    }

    for (final r in ys) {
      for (final c in xs) {
        if (board[r][c] == 0) continue;
        final tile = tileByPos[Point(c, r)];
        if (tile == null) continue;

        var nextX = c, nextY = r;
        while (true) {
          final testX = nextX + vx, testY = nextY + vy;
          if (testX < 0 || testX >= gridSize || testY < 0 || testY >= gridSize) {
            break;
          }
          if (board[testY][testX] == 0) {
            nextX = testX;
            nextY = testY;
          } else if (board[testY][testX] == tile.val) {
            final other = tileByPos[Point(testX, testY)];
            if (other != null && !other.mergedThisTurn) {
              nextX = testX;
              nextY = testY;
              board[r][c] = 0;
              board[nextY][nextX] = tile.val * 2;
              tile.x = nextX;
              tile.y = nextY;
              tile.nextVal = tile.val * 2;
              tile.isMerging = true;
              tile.mergedThisTurn = true;
              other.toDelete = true;
              tileByPos.remove(Point(c, r));
              tileByPos.remove(Point(testX, testY));
              tileByPos[Point(nextX, nextY)] = tile;
              scoreGained += tile.val * 2;
              if (tile.val * 2 > maxMergedVal) maxMergedVal = tile.val * 2;
              moved = true;
            }
            break;
          } else {
            break;
          }
        }

        if (nextX != c || nextY != r) {
          if (!tile.isMerging) {
            board[r][c] = 0;
            board[nextY][nextX] = tile.val;
            tile.x = nextX;
            tile.y = nextY;
            tileByPos.remove(Point(c, r));
            tileByPos[Point(nextX, nextY)] = tile;
          }
          moved = true;
        }
      }
    }

    if (moved) {
      score += scoreGained;
    } else {
      _history.removeLast();
    }
    return MoveResult(moved, scoreGained, maxMergedVal);
  }

  /// Second half of a move: applies deferred merges and spawns a new tile.
  void settle() {
    tiles.removeWhere((t) => t.toDelete);
    for (final t in tiles) {
      if (t.isMerging) {
        t.val = t.nextVal;
        t.isMerged = true;
        t.isMerging = false;
      }
    }
    spawnTile();
  }

  bool get isGameOver {
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        if (board[r][c] == 0) return false;
        if (c < gridSize - 1 && board[r][c] == board[r][c + 1]) return false;
        if (r < gridSize - 1 && board[r][c] == board[r + 1][c]) return false;
      }
    }
    return true;
  }

  // ------------------------------------------------------------ persistence

  /// Serialises the settled board so it can be resumed after an app kill.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'grid': gridSize,
        'score': score,
        'board': [for (final row in board) List<int>.from(row)],
        'tiles': [
          for (final t in tiles)
            {'id': t.id, 'x': t.x, 'y': t.y, 'val': t.val},
        ],
      };

  /// Restores a previously saved board. Returns false when the payload does
  /// not match this grid or is unusable, so the caller can start fresh.
  bool restore(Map<String, dynamic>? data) {
    if (data == null) return false;
    try {
      if (data['grid'] != gridSize) return false;
      final rawBoard = data['board'];
      final rawTiles = data['tiles'];
      if (rawBoard is! List || rawBoard.length != gridSize) return false;
      if (rawTiles is! List || rawTiles.isEmpty) return false;

      final nextBoard = <List<int>>[];
      for (final row in rawBoard) {
        if (row is! List || row.length != gridSize) return false;
        nextBoard.add([for (final v in row) (v as num).toInt()]);
      }

      final nextTiles = <TileData>[];
      var maxId = 0;
      for (final raw in rawTiles) {
        if (raw is! Map) return false;
        final id = (raw['id'] as num).toInt();
        final tile = TileData(
          id: id,
          x: (raw['x'] as num).toInt(),
          y: (raw['y'] as num).toInt(),
          val: (raw['val'] as num).toInt(),
          isNew: false,
        );
        if (id > maxId) maxId = id;
        nextTiles.add(tile);
      }

      board = nextBoard;
      tiles = nextTiles;
      score = (data['score'] as num?)?.toInt() ?? 0;
      _idCounter = maxId + 1;
      _history.clear();
      return true;
    } catch (_) {
      return false;
    }
  }
}

