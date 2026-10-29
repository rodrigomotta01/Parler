// Data: read-only vocab (assets/vocab.json, in memory) + progress (user.db).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'srs.dart';

const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

typedef Chapter = ({String title, List<String> paragraphs});
typedef UserBook = ({
  int id,
  String title,
  String level,
  List<Chapter> chapters,
  int chapterIdx,
  int paraIdx,
  int sentIdx,
  int wordIdx,
});

class Word {
  Word(this.id, List r)
      : lemma = r[0],
        pos = r[1],
        level = r[2],
        pt = r[3],
        en = r[4],
        ipa = r[5],
        def = r[6],
        ex = r[7];
  final int id;
  final String lemma, pos, level, pt, en, ipa, def, ex;

  /// Meaning strictly in PT-BR (never English).
  String get gloss => pt.isNotEmpty ? pt : lemma;
}

class Vocab {
  Vocab(Map<String, dynamic> j)
      : words = [
          for (final (i, r) in (j['words'] as List).indexed) Word(i, r as List)
        ],
        forms = (j['forms'] as Map).cast<String, int>() {
    for (final w in words) {
      byLemma.putIfAbsent(w.lemma.toLowerCase(), () => w.id);
    }
  }
  final List<Word> words;
  final Map<String, int> forms;
  final byLemma = <String, int>{};

  Word? lookup(String raw) {
    for (final c in candidates(raw)) {
      final id = byLemma[c] ?? forms[c];
      if (id != null) return words[id];
    }
    return null;
  }
}

class Store extends ChangeNotifier {
  Store._(this.vocab, this._db, this.mediaDir);
  final Vocab vocab;
  final Database _db;
  final String mediaDir;

  final settings = <String, String>{};
  final cardIds = <int>{};
  final _trCache = <String, String>{};
  final _trInflight = <String, Future<String>>{};
  final _trWaiters = <Completer<void>>[];
  int _trActive = 0;
  List<UserBook> ebooks = [];
  Map<String, Day> days = {};

  String get level => settings['level'] ?? 'A1';
  bool get onboarded => settings.containsKey('level');
  int get newPerDay => int.parse(settings['newPerDay'] ?? '10');
  int get goalRev => int.parse(settings['goalRev'] ?? '$goalReviews');
  int get goalListenMin =>
      int.parse(settings['goalListenMin'] ?? '${goalListenSec ~/ 60}');
  int get goalSec => goalListenMin * 60;
  bool get freeze => settings['freeze'] != 'false';
  int get reminderHour => int.parse(settings['reminderHour'] ?? '20');
  List<String> get feeds =>
      (settings['feeds'] ?? '').split('\n').where((s) => s.isNotEmpty).toList();

  Day? get today => days[dayKey(DateTime.now())];
  bool get todayMet => metGoal(today, goalRev: goalRev, goalSec: goalSec);
  double get todayProgress =>
      goalProgress(today, goalRev: goalRev, goalSec: goalSec);
  int get streakDays => streak(days, DateTime.now(),
      goalRev: goalRev, goalSec: goalSec, freeze: freeze);

  static Future<Store> open() async {
    final raw = await rootBundle.loadString('assets/vocab.json');
    final vocab = await compute((String s) => Vocab(jsonDecode(s)), raw);
    final dbDir = await getDatabasesPath();
    final mediaDir = p.join(dbDir, 'book_media');
    await Directory(mediaDir).create(recursive: true);
    final db = await openDatabase(
      p.join(dbDir, 'user.db'),
      version: 5,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE cards(word_id INTEGER PRIMARY KEY, '
            'card TEXT, due INTEGER, source TEXT, created TEXT)');
        await db.execute(
            'CREATE TABLE review_log(word_id INTEGER, rating INTEGER, ts INTEGER)');
        await db.execute('CREATE TABLE activity(day TEXT PRIMARY KEY, '
            'reviews INTEGER DEFAULT 0, listen_sec INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE settings(k TEXT PRIMARY KEY, v TEXT)');
        await db.execute(
            'CREATE TABLE translations(fr TEXT PRIMARY KEY, pt TEXT)');
        await db.execute(
            'CREATE TABLE ebooks(id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'title TEXT, level TEXT, chapters TEXT, '
            'chapter_idx INTEGER DEFAULT 0, para_idx INTEGER DEFAULT 0, '
            'sent_idx INTEGER DEFAULT 0, word_idx INTEGER DEFAULT 0)');
      },
      onUpgrade: (db, oldV, _) async {
        if (oldV < 2) {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS translations(fr TEXT PRIMARY KEY, pt TEXT)');
        }
        if (oldV < 3) {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS ebooks(id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'title TEXT, level TEXT, chapters TEXT, '
              'chapter_idx INTEGER DEFAULT 0, para_idx INTEGER DEFAULT 0, '
              'sent_idx INTEGER DEFAULT 0, word_idx INTEGER DEFAULT 0)');
        } else {
          if (oldV < 4) {
            try {
              await db.execute(
                  'ALTER TABLE ebooks ADD COLUMN sent_idx INTEGER DEFAULT 0');
            } catch (_) {}
          }
          if (oldV < 5) {
            try {
              await db.execute(
                  'ALTER TABLE ebooks ADD COLUMN word_idx INTEGER DEFAULT 0');
            } catch (_) {}
          }
        }
      },
    );
    final s = Store._(vocab, db, mediaDir);
    for (final r in await db.query('settings')) {
      s.settings[r['k'] as String] = r['v'] as String;
    }
    for (final r in await db.query('cards', columns: ['word_id'])) {
      s.cardIds.add(r['word_id'] as int);
    }
    for (final r in await db.query('translations')) {
      s._trCache[r['fr'] as String] = r['pt'] as String;
    }
    await s._loadEbooks();
    await s._loadDays();
    return s;
  }

  /// Synchronous lookup of an already-cached translation (prevents UI height flicker).
  String? cachedTranslation(String fr) => _trCache[fr.trim()];

  /// Translates a French sentence/definition/paragraph to PT-BR, cached in SQLite.
  /// Deduplicates in-flight calls and caps concurrency at 3 to prevent rate-limiting.
  Future<String> translate(String fr) {
    final key = fr.trim();
    if (key.isEmpty) return Future.value('');
    if (_trCache[key] case final hit?) return Future.value(hit);
    return _trInflight.putIfAbsent(key, () async {
      if (_trActive >= 3) {
        final w = Completer<void>();
        _trWaiters.add(w);
        await w.future;
      }
      _trActive++;
      try {
        final uri =
            Uri.https('translate.googleapis.com', '/translate_a/single', {
          'client': 'gtx',
          'sl': 'fr',
          'tl': 'pt',
          'dt': 't',
          'q': key,
        });
        for (var attempt = 0; attempt < 2; attempt++) {
          try {
            final res = await http.get(uri).timeout(const Duration(seconds: 8));
            if (res.statusCode == 200) {
              final data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
              final pt = (data[0] as List)
                  .map((s) => (s as List)[0] as String)
                  .join()
                  .trim();
              if (pt.isNotEmpty) {
                _trCache[key] = pt;
                await _db.insert('translations', {'fr': key, 'pt': pt},
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
              return pt;
            }
          } catch (_) {}
          if (attempt == 0) {
            await Future.delayed(const Duration(milliseconds: 350));
          }
        }
        return '';
      } finally {
        _trInflight.remove(key);
        _trActive--;
        if (_trWaiters.isNotEmpty) {
          _trWaiters.removeAt(0).complete();
        }
      }
    });
  }

  Future<void> _loadEbooks() async {
    final rows = await _db.query('ebooks', orderBy: 'id DESC');
    ebooks = [
      for (final r in rows)
        (
          id: r['id'] as int,
          title: r['title'] as String,
          level: (r['level'] as String?) ?? 'B1',
          chapters: [
            for (final c in (jsonDecode(r['chapters'] as String) as List))
              (
                title: (c as Map)['t'] as String,
                paragraphs: ((c)['p'] as List).cast<String>(),
              )
          ],
          chapterIdx: (r['chapter_idx'] as int?) ?? 0,
          paraIdx: (r['para_idx'] as int?) ?? 0,
          sentIdx: (r['sent_idx'] as int?) ?? 0,
          wordIdx: (r['word_idx'] as int?) ?? 0,
        )
    ];
  }

  Future<UserBook> addEbook(
      String title, String level, List<Chapter> chapters) async {
    final encoded = jsonEncode([
      for (final c in chapters) {'t': c.title, 'p': c.paragraphs}
    ]);
    final id = await _db.insert('ebooks', {
      'title': title,
      'level': level,
      'chapters': encoded,
      'chapter_idx': 0,
      'para_idx': 0,
      'sent_idx': 0,
      'word_idx': 0,
    });
    await _loadEbooks();
    notifyListeners();
    return ebooks.firstWhere((b) => b.id == id);
  }

  Future<void> updateEbookProgress(int id, int chapterIdx, int paraIdx,
      [int sentIdx = 0, int wordIdx = 0, bool notify = true]) async {
    await _db.update(
      'ebooks',
      {
        'chapter_idx': chapterIdx,
        'para_idx': paraIdx,
        'sent_idx': sentIdx,
        'word_idx': wordIdx,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    final idx = ebooks.indexWhere((b) => b.id == id);
    if (idx != -1) {
      final b = ebooks[idx];
      ebooks[idx] = (
        id: b.id,
        title: b.title,
        level: b.level,
        chapters: b.chapters,
        chapterIdx: chapterIdx,
        paraIdx: paraIdx,
        sentIdx: sentIdx,
        wordIdx: wordIdx,
      );
    }
    if (notify) notifyListeners();
  }

  Set<String> get grammarDone =>
      (settings['grammarDone'] ?? '').split(',').where((s) => s.isNotEmpty).toSet();

  Future<void> markGrammarDone(String topicId) async {
    final current = grammarDone..add(topicId);
    await set('grammarDone', current.join(','));
    await addReview(1); // counts as completed study activity!
  }

  Future<void> deleteEbook(int id) async {
    await _db.delete('ebooks', where: 'id = ?', whereArgs: [id]);
    await _loadEbooks();
    notifyListeners();
  }

  Future<void> _loadDays() async {
    days = {
      for (final r in await _db.query('activity'))
        r['day'] as String: (
          reviews: r['reviews'] as int,
          listenSec: r['listen_sec'] as int
        )
    };
    notifyListeners();
  }

  Future<void> set(String k, String v) async {
    settings[k] = v;
    await _db.insert('settings', {'k': k, 'v': v},
        conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }

  Future<void> addReview([int by = 1]) => _bump('reviews', by);
  Future<void> addListen(int sec) => _bump('listen_sec', sec);

  Future<void> _bump(String col, int by) async {
    final d = dayKey(DateTime.now());
    await _db.rawInsert(
        'INSERT INTO activity(day, $col) VALUES(?, ?) '
        'ON CONFLICT(day) DO UPDATE SET $col = $col + excluded.$col',
        [d, by]);
    await _loadDays();
  }

  /// Due cards + today's quota of new words (from chosen level upward).
  Future<List<Word>> queue() async {
    final now = DateTime.now();
    final due = await _db.query('cards',
        columns: ['word_id'],
        where: 'due <= ? AND card IS NOT NULL',
        whereArgs: [now.millisecondsSinceEpoch],
        orderBy: 'due');
    final introduced = Sqflite.firstIntValue(await _db.rawQuery(
            "SELECT COUNT(*) FROM cards WHERE source = 'new' AND created = ?",
            [dayKey(now)])) ??
        0;
    // Saved-but-never-reviewed words (e.g. from podcasts) come first.
    final pending = await _db.query('cards',
        columns: ['word_id'], where: 'card IS NULL', orderBy: 'created');
    final fresh = vocab.words
        .where((w) =>
            levels.indexOf(w.level) >= levels.indexOf(level) &&
            !cardIds.contains(w.id))
        .take((newPerDay - introduced).clamp(0, newPerDay));
    return [
      for (final r in [...due, ...pending]) vocab.words[r['word_id'] as int],
      ...fresh,
    ];
  }

  Future<String?> _cardJson(int id) async {
    final r = await _db.query('cards',
        columns: ['card'], where: 'word_id = ?', whereArgs: [id]);
    return r.isEmpty ? null : r.first['card'] as String?;
  }

  /// Preview next due for each rating (for button labels).
  Future<Map<Rating, DateTime>> preview(Word w) async {
    final j = await _cardJson(w.id);
    final now = DateTime.now();
    return {for (final r in Rating.values) r: review(j, w.id, r, now).due};
  }

  Future<DateTime> rate(Word w, Rating r) async {
    final now = DateTime.now();
    final next = review(await _cardJson(w.id), w.id, r, now);
    await _db.transaction((t) async {
      final updated = await t.update(
          'cards', {'card': next.json, 'due': next.due.millisecondsSinceEpoch},
          where: 'word_id = ?', whereArgs: [w.id]);
      if (updated == 0) {
        await t.insert('cards', {
          'word_id': w.id,
          'card': next.json,
          'due': next.due.millisecondsSinceEpoch,
          'source': 'new',
          'created': dayKey(now),
        });
      }
      await t.insert('review_log', {
        'word_id': w.id,
        'rating': r.value,
        'ts': now.millisecondsSinceEpoch
      });
    });
    cardIds.add(w.id);
    await _bump('reviews', 1);
    return next.due;
  }

  /// Save a word for later review (e.g. tapped in a podcast transcript).
  Future<void> save(Word w, String source) async {
    if (cardIds.contains(w.id)) return;
    await _db.insert('cards',
        {'word_id': w.id, 'source': source, 'created': dayKey(DateTime.now())});
    cardIds.add(w.id);
    notifyListeners();
  }

  /// Remove a word from the user's deck.
  Future<void> removeCard(Word w) async {
    await _db.delete('cards', where: 'word_id = ?', whereArgs: [w.id]);
    cardIds.remove(w.id);
    notifyListeners();
  }

  double learned(String lvl) {
    final ws = vocab.words.where((w) => w.level == lvl);
    return ws.isEmpty
        ? 0
        : ws.where((w) => cardIds.contains(w.id)).length / ws.length;
  }
}
