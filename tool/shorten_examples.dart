import 'dart:convert';
import 'dart:io';

int wordCount(String s) =>
    s.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).length;

/// Score an example sentence. Lower score = better example.
/// Range 3..12 words is best (score 3..12).
/// Range 13..20 words is second best (score 100 + wc).
/// > 20 words is fallback when nothing shorter exists (score 1000 + wc).
/// < 3 words is heavily penalized.
int scoreExample(String text) {
  final wc = wordCount(text);
  if (wc < 3) return 10000 + (3 - wc);
  if (wc <= 12) return wc;
  if (wc <= 20) return 100 + wc;
  return 1000 + wc;
}

Future<void> main(List<String> args) async {
  final vocabFile = File('assets/vocab.json');
  final jsonlPath = args.isNotEmpty
      ? args[0]
      : r'C:\src\parler-raw\fr-wiktionary.jsonl';

  if (!File(jsonlPath).existsSync()) {
    stderr.writeln('JSONL file not found at $jsonlPath');
    exit(1);
  }

  final vocabJson =
      jsonDecode(vocabFile.readAsStringSync()) as Map<String, dynamic>;
  final words = (vocabJson['words'] as List).cast<List>();

  final byLemma = <String, List<int>>{};
  for (var i = 0; i < words.length; i++) {
    final lemma = (words[i][0] as String).toLowerCase().trim();
    byLemma.putIfAbsent(lemma, () => []).add(i);
  }

  stdout.writeln('Loaded ${words.length} words from vocab.json');

  final bestExamples = <int, String>{};
  final bestScores = <int, int>{};

  // Pre-seed with existing examples so we never discard an example if no shorter one is found
  for (var i = 0; i < words.length; i++) {
    final existing = words[i][7] as String? ?? '';
    if (existing.trim().isNotEmpty) {
      bestExamples[i] = existing;
      bestScores[i] = scoreExample(existing);
    }
  }

  final headRegex = RegExp(r'^\{"word":\s*"((?:[^"\\]|\\.)*)"');
  var lineCount = 0;
  final stopwatch = Stopwatch()..start();

  await for (final line in File(jsonlPath)
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    lineCount++;
    if (lineCount % 250000 == 0) {
      final mb = (lineCount / 1000000).toStringAsFixed(1);
      stdout.write('\rRead $mb M lines in ${stopwatch.elapsed.inSeconds}s...');
    }

    final m = headRegex.firstMatch(line);
    if (m == null) continue;
    final rawWord = jsonDecode('"${m.group(1)}"') as String;
    final rowIndices = byLemma[rawWord.toLowerCase().trim()];
    if (rowIndices == null) continue;

    final entry = jsonDecode(line) as Map<String, dynamic>;
    final senses = (entry['senses'] as List?) ?? const [];

    for (final s in senses) {
      final examples = (s['examples'] as List?) ?? const [];
      for (final ex in examples) {
        final text = ex['text'] as String?;
        if (text == null) continue;
        final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (clean.isEmpty) continue;
        final score = scoreExample(clean);

        for (final idx in rowIndices) {
          final curBest = bestScores[idx];
          if (curBest == null || score < curBest) {
            bestScores[idx] = score;
            bestExamples[idx] = clean;
          }
        }
      }
    }
  }

  stdout.writeln('\nFinished reading in ${stopwatch.elapsed.inSeconds}s');

  var replaced = 0;
  for (var i = 0; i < words.length; i++) {
    final cand = bestExamples[i];
    if (cand != null && cand != words[i][7]) {
      words[i][7] = cand;
      replaced++;
    }
  }

  stdout.writeln(
      'Writing back to assets/vocab.json ($replaced examples updated)...');
  vocabFile.writeAsStringSync(jsonEncode(vocabJson));

  var shortCount = 0;
  var medCount = 0;
  var longCount = 0;
  var emptyCount = 0;

  for (final w in words) {
    final ex = (w[7] as String).trim();
    if (ex.isEmpty) {
      emptyCount++;
    } else {
      final c = wordCount(ex);
      if (c <= 12) {
        shortCount++;
      } else if (c <= 20) {
        medCount++;
      } else {
        longCount++;
      }
    }
  }

  stdout.writeln('Vocab examples stats:');
  stdout.writeln('<= 12 words (short): $shortCount');
  stdout.writeln('13..20 words (medium): $medCount');
  stdout.writeln('> 20 words (long fallback): $longCount');
  stdout.writeln('No example: $emptyCount');
}
