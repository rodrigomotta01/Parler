// Builds assets/vocab.json from FLELex (CEFR levels) + fr.wiktionary (kaikki.org).
//
//   dart run tool/build_vocab.dart [flelex.tsv] [fr-wiktionary.jsonl]
//
// Inputs (not committed):
//   https://cental.uclouvain.be/cefrlex/static/resources/fr/FleLex_TT_Beacco.tsv  (CC BY-NC-SA)
//   https://kaikki.org/frwiktionary/Fran%C3%A7ais/kaikki.org-dictionary-Fran%C3%A7ais.jsonl (CC BY-SA)
import 'dart:convert';
import 'dart:io';

const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

// FLELex TreeTagger tag -> wiktionary pos.
String posOf(String tag) => switch (tag.split(':').first) {
      'NOM' => 'noun',
      'VER' => 'verb',
      'ADJ' => 'adj',
      'ADV' => 'adv',
      'PRO' => 'pron',
      'PRP' => 'prep',
      'KON' => 'conj',
      'DET' => 'det',
      'INT' => 'intj',
      'NUM' => 'num',
      _ => 'other',
    };

Future<void> main(List<String> args) async {
  final tsv = args.isNotEmpty ? args[0] : 'tool/raw/FleLex_TT_Beacco.tsv';
  final jsonl = args.length > 1 ? args[1] : r'C:\src\parler-raw\fr-wiktionary.jsonl';

  // 1. FLELex rows (one entry per lemma, keeping highest-frequency tag).
  final byLemma = <String, Map<String, dynamic>>{};
  for (final line in File(tsv).readAsLinesSync().skip(1)) {
    final c = line.split('\t');
    if (c.length < 10 || !levels.contains(c[9].trim())) continue;
    final lemma = c[0].trim();
    if (lemma.startsWith('-')) continue;
    final freq = double.tryParse(c[8]) ?? 0;
    final prev = byLemma[lemma];
    if (prev == null || freq > (prev['freq'] as double)) {
      byLemma[lemma] = {
        'lemma': lemma,
        'pos': posOf(c[1]),
        'level': c[9].trim(),
        'freq': freq,
      };
    }
  }

  // 2. Stream wiktionary; only decode lines whose headword we care about,
  //    or that declare an inflected form ("form_of").
  final formToLemma = <String, String>{};
  final head = RegExp(r'^\{"word": "((?:[^"\\]|\\.)*)"');
  var n = 0;
  await for (final line in File(jsonl)
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    if (++n % 200000 == 0) stdout.write('\r$n lines');
    final m = head.firstMatch(line);
    if (m == null) continue;
    final word = jsonDecode('"${m.group(1)}"') as String;
    final w = byLemma[word];
    if (w == null && !line.contains('"form_of"')) continue;
    final e = jsonDecode(line) as Map<String, dynamic>;
    final senses = (e['senses'] as List?) ?? const [];

    if (w == null) {
      // Inflected form entry -> map to its lemma, if the lemma is in FLELex.
      for (final s in senses) {
        for (final f in (s['form_of'] as List?) ?? const []) {
          final lemma = f['word'] as String?;
          if (lemma != null && byLemma.containsKey(lemma)) {
            formToLemma.putIfAbsent(word.toLowerCase(), () => lemma);
          }
        }
      }
      continue;
    }

    // Prefer the matching POS entry, or fill missing fields from any POS entry.
    final matchPos = w['pos'] == e['pos'];
    final tr = (e['translations'] as List?) ?? const [];
    String trIn(String code) => {
          for (final t in tr)
            if (t['lang_code'] == code && t['word'] != null) t['word'] as String
        }.take(4).join(', ');
    final pt = trIn('pt');
    final en = trIn('en');
    if (pt.isNotEmpty && ((w['pt'] ?? '').isEmpty || matchPos)) w['pt'] = pt;
    if (en.isNotEmpty && ((w['en'] ?? '').isEmpty || matchPos)) w['en'] = en;
    if ((w['ipa'] ?? '').isEmpty) {
      for (final s in (e['sounds'] as List?) ?? const []) {
        if (s['ipa'] != null) {
          w['ipa'] = s['ipa'];
          break;
        }
      }
    }
    for (final s in senses) {
      final g = (s['glosses'] as List?)?.cast<String>();
      if (g != null && g.isNotEmpty && ((w['def'] ?? '').isEmpty || matchPos && w['defPos'] != true)) {
        w['def'] = g.first;
        if (matchPos) w['defPos'] = true;
      }
      final ex = (s['examples'] as List?) ?? const [];
      if ((w['ex'] ?? '').isEmpty && ex.isNotEmpty && ex.first['text'] != null) {
        w['ex'] = ex.first['text'];
      }
    }
    for (final f in (e['forms'] as List?) ?? const []) {
      final form = (f['form'] as String?)?.toLowerCase();
      if (form != null) formToLemma.putIfAbsent(form, () => word);
    }
  }
  stdout.writeln();

  final words = byLemma.values
      .where((w) =>
          (w['pt'] ?? '').isNotEmpty ||
          (w['en'] ?? '').isNotEmpty ||
          (w['def'] ?? '').isNotEmpty)
      .toList();

  // 3. Sort: level, then frequency (most useful first). Assign ids.
  words.sort((a, b) {
    final l = levels.indexOf(a['level']).compareTo(levels.indexOf(b['level']));
    return l != 0 ? l : (b['freq'] as double).compareTo(a['freq'] as double);
  });
  final idOf = <String, int>{};
  for (var i = 0; i < words.length; i++) {
    idOf.putIfAbsent(words[i]['lemma'], () => i);
  }
  final forms = {
    for (final e in formToLemma.entries)
      if (!idOf.containsKey(e.key) && idOf.containsKey(e.value))
        e.key: idOf[e.value]!
  };

  // Compact rows: [lemma, pos, level, pt, en, ipa, def, example]
  final out = {
    'words': [
      for (final w in words)
        [
          w['lemma'], w['pos'], w['level'], w['pt'] ?? '', w['en'] ?? '',
          w['ipa'] ?? '', w['def'] ?? '', w['ex'] ?? '',
        ]
    ],
    'forms': forms,
  };
  File('assets/vocab.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(out));

  // Sanity report.
  for (final l in levels) {
    final ws = words.where((w) => w['level'] == l).toList();
    final pt = ws.where((w) => (w['pt'] ?? '').isNotEmpty).length;
    final any = ws
        .where((w) => (w['pt'] ?? '').isNotEmpty || (w['en'] ?? '').isNotEmpty)
        .length;
    stdout.writeln('$l: ${ws.length} words, pt ${(100 * pt / ws.length).round()}%, '
        'pt|en ${(100 * any / ws.length).round()}%');
  }
  stdout.writeln('forms: ${forms.length}');
}

