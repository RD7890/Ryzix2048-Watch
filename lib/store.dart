import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Ryzix persistent store.
///
/// A single JSON document is kept on external app storage:
///   /storage/emulated/0/Android/data/<applicationId>/files/ryzix/ryzix_db.json
///
/// The store also provisions the companion folders the app owns:
///   /storage/emulated/0/Android/media/<applicationId>/Ryzix2048
///   /storage/emulated/0/Android/obb/<applicationId>
///
/// Every write is atomic (tmp file + rename) and mirrored to internal support
/// storage so a profile is never lost if external storage is unavailable.
class RyzixStore {
  RyzixStore._();
  static final RyzixStore I = RyzixStore._();

  static const _fileName = 'ryzix_db.json';
  static const _schema = 1;

  Directory? _dataDir; // Android/data/<pkg>/files/ryzix
  Directory? _fallbackDir; // internal app support dir
  String? mediaPath;
  String? obbPath;
  bool _ready = false;

  Map<String, dynamic> _db = _emptyDb();
  Future<void> _writeChain = Future.value();
  Timer? _flushTimer;
  bool _dirty = false;

  static Map<String, dynamic> _emptyDb() => <String, dynamic>{
        'schema': _schema,
        'currentUser': null,
        'users': <String, dynamic>{},
        'config': <String, dynamic>{'sfx': true, 'haptics': true},
      };

  bool get isReady => _ready;
  String get dbPath => _dataDir == null
      ? '$_fileName (internal)'
      : '${_dataDir!.path}/$_fileName';

  // ---------------------------------------------------------------- lifecycle

  Future<void> init() async {
    if (_ready) return;
    try {
      _fallbackDir = await getApplicationSupportDirectory();
    } catch (_) {}

    try {
      final ext = await getExternalStorageDirectory(); // Android/data/<pkg>/files
      if (ext != null) {
        _dataDir = Directory('${ext.path}/ryzix');
        await _dataDir!.create(recursive: true);
        await _provisionCompanionDirs(ext.path);
      }
    } catch (_) {
      _dataDir = null;
    }

    await _load();
    _ready = true;
  }

  /// Creates Android/media/<pkg>/… and Android/obb/<pkg>/ next to Android/data.
  Future<void> _provisionCompanionDirs(String filesPath) async {
    final marker = '/Android/data/';
    final i = filesPath.indexOf(marker);
    if (i < 0) return;
    final androidRoot = filesPath.substring(0, i + '/Android'.length);
    final pkg = filesPath
        .substring(i + marker.length)
        .split('/')
        .first; // applicationId

    Future<void> mk(String path) async {
      try {
        final d = Directory(path);
        if (!await d.exists()) await d.create(recursive: true);
      } catch (_) {
        // Some OEM ROMs block obb creation; never fatal.
      }
    }

    mediaPath = '$androidRoot/media/$pkg/Ryzix2048';
    obbPath = '$androidRoot/obb/$pkg';
    await mk(mediaPath!);
    await mk('$mediaPath/screenshots');
    await mk(obbPath!);
    try {
      final readme = File('$mediaPath/README.txt');
      if (!await readme.exists()) {
        await readme.writeAsString(
            'Ryzix 2048 shared media folder.\nSaved boards and exports land here.\n');
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    for (final dir in [_dataDir, _fallbackDir]) {
      if (dir == null) continue;
      try {
        final f = File('${dir.path}/$_fileName');
        if (!await f.exists()) continue;
        final raw = jsonDecode(await f.readAsString());
        if (raw is Map<String, dynamic> && raw['users'] is Map) {
          _db = _migrate(raw);
          return;
        }
      } catch (_) {
        // corrupt file -> fall through to the next candidate
      }
    }
    _db = _emptyDb();
  }

  Map<String, dynamic> _migrate(Map<String, dynamic> raw) {
    final db = _emptyDb();
    db['currentUser'] = raw['currentUser'];
    db['users'] = Map<String, dynamic>.from(raw['users'] as Map);
    if (raw['config'] is Map) {
      db['config'] = {
        ...db['config'] as Map<String, dynamic>,
        ...Map<String, dynamic>.from(raw['config'] as Map),
      };
    }
    return db;
  }

  void _persist() {
    _dirty = true;
    // Commit straight away: the document is tiny and a debounced/async write
    // was routinely dropped when the process was killed, which lost the
    // signed-in profile and every saved board.
    flushNow();
  }

  void _flush() async {
    if (!_dirty) return;
    _dirty = false;
    final String payload;
    try {
      payload = jsonEncode(_db);
    } catch (_) {
      return;
    }
    _writeChain = _writeChain.then((_) async {
      for (final dir in [_dataDir, _fallbackDir]) {
        if (dir == null) continue;
        try {
          await dir.create(recursive: true);
          final tmp = File('${dir.path}/$_fileName.tmp');
          await tmp.writeAsString(payload, flush: true);
          await tmp.rename('${dir.path}/$_fileName');
        } catch (_) {}
      }
    });
  }


  /// Writes any pending state to disk immediately and synchronously.
  ///
  /// Used when the app goes to background / is about to be killed: the
  /// debounced async flush can be dropped by the OS before it lands, so the
  /// resume point must be committed on the spot.
  void flushNow() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _dirty = false;
    final String payload;
    try {
      payload = jsonEncode(_db);
    } catch (_) {
      return;
    }
    for (final dir in [_dataDir, _fallbackDir]) {
      if (dir == null) continue;
      try {
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final tmp = File('${dir.path}/$_fileName.tmp');
        tmp.writeAsStringSync(payload, flush: true);
        tmp.renameSync('${dir.path}/$_fileName');
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------------ config

  bool get sfxEnabled => (_db['config']['sfx'] as bool?) ?? true;
  set sfxEnabled(bool v) {
    _db['config']['sfx'] = v;
    _persist();
  }

  bool get hapticsEnabled => (_db['config']['haptics'] as bool?) ?? true;
  set hapticsEnabled(bool v) {
    _db['config']['haptics'] = v;
    _persist();
  }

  // ----------------------------------------------------------------- profiles

  String? get currentUser => _db['currentUser'] as String?;

  List<String> get users =>
      (_db['users'] as Map<String, dynamic>).keys.toList()..sort();

  Map<String, dynamic> _user(String name) {
    final users = _db['users'] as Map<String, dynamic>;
    return users.putIfAbsent(
        name,
        () => <String, dynamic>{
              'name': name,
              'guest': name == 'Guest',
              'created': DateTime.now().toIso8601String(),
              'bests': <String, dynamic>{},
              'games': 0,
              'totalScore': 0,
              'streak': 0,
              'diamonds': 3,
            }) as Map<String, dynamic>;
  }

  /// Signs a profile in, creating it on first use.
  void signIn(String name) {
    final clean = name.trim().isEmpty ? 'Guest' : name.trim();
    _user(clean);
    _db['currentUser'] = clean;
    _persist();
  }

  void signOut() {
    _db['currentUser'] = null;
    _persist();
  }

  bool get isGuest => currentUser == 'Guest';

  /// Best score of the signed-in player for a grid size (0 when unplayed).
  int bestFor(int gridSize) {
    final u = currentUser;
    if (u == null) return 0;
    final bests = _user(u)['bests'] as Map<String, dynamic>;
    return (bests['$gridSize'] as int?) ?? 0;
  }

  /// Highest best across every grid of the signed-in player.
  int get overallBest {
    final u = currentUser;
    if (u == null) return 0;
    final bests = _user(u)['bests'] as Map<String, dynamic>;
    var top = 0;
    for (final v in bests.values) {
      if (v is int && v > top) top = v;
    }
    return top;
  }

  int get gamesPlayed {
    final u = currentUser;
    if (u == null) return 0;
    return (_user(u)['games'] as int?) ?? 0;
  }

  /// Records a best score. Returns true when it beat the previous record.
  bool submitScore(int gridSize, int score) {
    final u = currentUser;
    if (u == null) return false;
    final user = _user(u);
    final bests = user['bests'] as Map<String, dynamic>;
    final prev = (bests['$gridSize'] as int?) ?? 0;
    final improved = score > prev;
    if (improved) bests['$gridSize'] = score;
    _persist();
    return improved;
  }

  void recordGameFinished(int score) {
    final u = currentUser;
    if (u == null) return;
    final user = _user(u);
    user['games'] = (user['games'] as int? ?? 0) + 1;
    user['totalScore'] = (user['totalScore'] as int? ?? 0) + score;
    user['streak'] = (user['streak'] as int? ?? 0) + 1;
    _persist();
  }

  int get streak {
    final u = currentUser;
    if (u == null) return 0;
    return (_user(u)['streak'] as int?) ?? 0;
  }

  int get diamonds {
    final u = currentUser;
    if (u == null) return 3;
    return (_user(u)['diamonds'] as int?) ?? 3;
  }

  set diamonds(int v) {
    final u = currentUser;
    if (u == null) return;
    _user(u)['diamonds'] = v;
    _persist();
  }

  // ------------------------------------------------------- in-progress saves

  /// Saved (unfinished) board for a grid size of the signed-in player.
  /// Returns null when there is nothing to resume.
  Map<String, dynamic>? savedGame(int gridSize) {
    final u = currentUser;
    if (u == null) return null;
    final saves = _user(u)['saves'];
    if (saves is! Map) return null;
    final s = saves['$gridSize'];
    if (s is! Map) return null;
    return Map<String, dynamic>.from(s);
  }

  bool hasSavedGame(int gridSize) => savedGame(gridSize) != null;

  /// Stores the live board so an app kill resumes exactly where it stopped.
  void saveGame(int gridSize, Map<String, dynamic> state) {
    final u = currentUser;
    if (u == null) return;
    final user = _user(u);
    final saves = (user['saves'] is Map)
        ? Map<String, dynamic>.from(user['saves'] as Map)
        : <String, dynamic>{};
    saves['$gridSize'] = state;
    user['saves'] = saves;
    _persist();
  }

  /// Drops the resume point (game finished or restarted).
  void clearSavedGame(int gridSize) {
    final u = currentUser;
    if (u == null) return;
    final user = _user(u);
    if (user['saves'] is! Map) return;
    final saves = Map<String, dynamic>.from(user['saves'] as Map);
    if (saves.remove('$gridSize') != null) {
      user['saves'] = saves;
      _persist();
    }
  }
}

