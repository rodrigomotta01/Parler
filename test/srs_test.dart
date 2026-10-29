import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parler/db.dart';
import 'package:parler/screens/grammar.dart';
import 'package:parler/screens/listen.dart';
import 'package:parler/srs.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('streak: consecutive days, custom goal, freeze, gap breaks', () {
    final now = DateTime(2026, 10, 28, 22);
    const met = (reviews: goalReviews, listenSec: 0);
    const low = (reviews: 10, listenSec: 0);

    // Yesterday & day before met, today still pending -> streak = 2.
    expect(
      streak({'2026-10-27': met, '2026-10-26': met, '2026-10-28': low}, now),
      2,
    );
    // Custom lower goal (10 reviews) -> today also counts -> streak = 3.
    expect(
      streak(
        {'2026-10-27': met, '2026-10-26': met, '2026-10-28': low},
        now,
        goalRev: 10,
      ),
      3,
    );
    // Skipped 2026-10-27, but 2026-10-28 and 2026-10-26 met:
    // without freeze -> 1; with freeze -> 2.
    final withGap = {'2026-10-28': met, '2026-10-26': met};
    expect(streak(withGap, now, freeze: false), 1);
    expect(streak(withGap, now, freeze: true), 2);
  });

  test('FSRS: Good grows interval, Again resets', () {
    final t0 = DateTime.utc(2026, 10, 28, 12);
    var r = review(null, 42, Rating.good, t0);
    r = review(r.json, 42, Rating.good, r.due);
    final afterGood = r.due.difference(t0);
    expect(afterGood.inHours, greaterThanOrEqualTo(24));

    final afterAgain = review(r.json, 42, Rating.again, r.due);
    expect(afterAgain.due.difference(r.due).inMinutes, lessThan(30));
  });

  test('candidates: strips punctuation, elision and splits hyphens', () {
    expect(candidates("«L’homme,"), contains('homme'));
    expect(candidates("qu'est-ce"), ['est-ce', 'est']);
  });

  test('splitSentences: splits French paragraph into sentences cleanly', () {
    final sents = splitSentences(
      'Il est huit heures du matin à Paris. Le soleil brille doucement ! M. Hamel nous regarde.',
    );
    expect(sents, [
      'Il est huit heures du matin à Paris.',
      'Le soleil brille doucement !',
      'M. Hamel nous regarde.',
    ]);

    // Handles PDF missing spaces, semicolons, quotes, and dialogue attribution.
    final complex = splitSentences(
      '« Bonjour ! » dit-il.Il partit aussitôt ; la nuit tombait déjà.',
    );
    expect(complex, [
      '« Bonjour ! » dit-il.',
      'Il partit aussitôt ;',
      'la nuit tombait déjà.',
    ]);
  });

  test('parseEbookBytes: parses .epub with embedded image and .pdf document', () {
    // 1. EPUB with image + 2 paragraphs
    final arch = Archive();
    const opf = '''<?xml version="1.0"?>
<package><metadata><dc:title>Le Petit Prince</dc:title></metadata>
<manifest><item id="c1" href="chap1.xhtml"/></manifest>
<spine><itemref idref="c1"/></spine></package>''';
    const xhtml = '''<html><body><h1>Chapitre I</h1>
<img src="boa.png"/>
<p>Lorsque j’avais six ans j’ai vu une magnifique image.</p>
<p>C’était un serpent boa qui avalait un fauve.</p></body></html>''';
    final fakePng = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
    arch.addFile(ArchiveFile.bytes('OEBPS/content.opf', utf8.encode(opf)));
    arch.addFile(ArchiveFile.bytes('OEBPS/chap1.xhtml', utf8.encode(xhtml)));
    arch.addFile(ArchiveFile.bytes('OEBPS/boa.png', fakePng));
    final epubBytes = Uint8List.fromList(ZipEncoder().encode(arch));

    final (title, chaps) = parseEbookBytes('prince.epub', epubBytes);
    expect(title, 'Le Petit Prince');
    expect(chaps.length, 1);
    expect(chaps.first.title, 'Chapitre I');
    expect(chaps.first.paragraphs.first.startsWith('[[IMG:base64,'), isTrue);
    expect(chaps.first.paragraphs.length, 3);

    // 2. Real PDF generated in memory
    final pdf = PdfDocument();
    pdf.documentInformation.title = 'Conte Français PDF';
    pdf.pages.add().graphics.drawString(
          'Bonjour tout le monde. Il fait beau à Lyon.',
          PdfStandardFont(PdfFontFamily.helvetica, 12),
          bounds: const Rect.fromLTWH(0, 0, 400, 100),
        );
    final pdfBytes = Uint8List.fromList(pdf.saveSync());
    pdf.dispose();

    final (pdfTitle, pdfChaps) = parseEbookBytes('conte.pdf', pdfBytes);
    expect(pdfTitle, 'Conte Français PDF');
    expect(pdfChaps.isNotEmpty, isTrue);
    expect(
      pdfChaps.first.paragraphs.any((p) => p.contains('Bonjour tout le monde')),
      isTrue,
    );
  });

  test('bookPageInfo: calculates current page and total pages correctly', () {
    final UserBook book = (
      id: 1,
      title: 'Test Book',
      level: 'A1',
      chapters: [
        (
          title: 'Chap 1',
          paragraphs: [
            // 200 words -> ~ 2 pages
            List.filled(200, 'mot').join(' '),
          ],
        ),
      ],
      chapterIdx: 0,
      paraIdx: 0,
      sentIdx: 0,
      wordIdx: 0,
    );

    final (page, total) = bookPageInfo(book, 0, 0);
    expect(page, 1);
    expect(total, greaterThanOrEqualTo(2));
  });

  test('grammar: validates 7 core modules and interactive quiz answers', () {
    expect(grammarTopics.length, 7);
    for (final t in grammarTopics) {
      expect(t.id.isNotEmpty, isTrue);
      expect(t.title.isNotEmpty, isTrue);
      expect(t.sections.isNotEmpty, isTrue);
      expect(t.examples.isNotEmpty, isTrue);
      expect(t.exercises.isNotEmpty, isTrue);

      for (final ex in t.exercises) {
        expect(ex.explanation.isNotEmpty, isTrue);
        if (ex.type == ExerciseType.sentenceBuilder) {
          expect(ex.tokens.isNotEmpty, isTrue);
          expect(ex.solution is List<String>, isTrue);
        } else {
          expect(ex.options.isNotEmpty, isTrue);
          expect(ex.options.contains(ex.solution), isTrue);
        }
      }
    }
  });
}
