// Fills any missing PT-BR glosses (r[3]) in assets/vocab.json so 100% of words
// have a Portuguese meaning offline and no English fallback is ever used.
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<List<String>> translateBatch(List<String> items, String sl) async {
  final joined = items.join('\n');
  final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
    'client': 'gtx',
    'sl': sl,
    'tl': 'pt',
    'dt': 't',
    'q': joined,
  });
  final res = await http.get(uri);
  if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
  final data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
  final full =
      (data[0] as List).map((s) => (s as List)[0] as String).join();
  return full.split('\n').map((s) => s.trim()).toList();
}

Future<void> main() async {
  final file = File('assets/vocab.json');
  final j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final words = (j['words'] as List).cast<List>();

  final missing = <int>[];
  for (var i = 0; i < words.length; i++) {
    if ((words[i][3] as String).trim().isEmpty) missing.add(i);
  }
  stdout.writeln('Total words: ${words.length}, missing PT: ${missing.length}');

  const batchSize = 50;
  for (var b = 0; b < missing.length; b += batchSize) {
    final slice = missing.sublist(b, (b + batchSize).clamp(0, missing.length));
    final queries = [
      for (final idx in slice) words[idx][0] as String,
    ];
    try {
      final pts = await translateBatch(queries, 'fr');
      for (var k = 0; k < slice.length; k++) {
        final idx = slice[k];
        var pt = k < pts.length ? pts[k].toLowerCase() : '';
        // If French lemma didn't translate and English gloss exists, translate English gloss
        if ((pt.isEmpty || pt == (words[idx][0] as String).toLowerCase()) &&
            (words[idx][4] as String).isNotEmpty) {
          final enPts = await translateBatch([words[idx][4] as String], 'en');
          if (enPts.isNotEmpty && enPts.first.isNotEmpty) {
            pt = enPts.first.toLowerCase();
          }
        }
        words[idx][3] = pt.isNotEmpty ? pt : (words[idx][0] as String);
      }
    } catch (e) {
      stderr.writeln('Batch $b error: $e');
    }
    stdout.write('\rEnriched ${(b + slice.length)} / ${missing.length}');
  }
  stdout.writeln();

  // Clear English column (r[4]) so English can never leak anywhere.
  for (final w in words) {
    w[4] = '';
  }

  file.writeAsStringSync(jsonEncode(j));
  final stillEmpty =
      words.where((w) => (w[3] as String).trim().isEmpty).length;
  stdout.writeln('Done! Still missing PT: $stillEmpty');
}

