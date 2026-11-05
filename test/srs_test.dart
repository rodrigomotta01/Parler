import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parler/db.dart';
import 'package:parler/main.dart';
import 'package:parler/screens/grammar.dart';
import 'package:parler/screens/listen.dart';
import 'package:parler/srs.dart';
import 'package:parler/ui.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class _FakeStore extends ChangeNotifier implements Store {
  @override
  String? cachedTranslation(String fr) => 'Tradução simulada para: $fr';
  @override
  Future<String> translate(String fr) async => 'Tradução simulada para: $fr';
  @override
  Set<int> get cardIds => const {};
  @override
  String get level => 'B1';
  @override
  Vocab get vocab => Vocab(const {'words': [], 'forms': {}});
  @override
  Map<String, String> get settings => const {};
  @override
  List<UserBook> get ebooks => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  test('streak: consecutive days, custom goal, freeze, gap breaks', () {
    final now = DateTime(2026, 10, 28, 22);
    // Legacy days (bothSince not set) can meet goal with reviews OR listenSec:
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

  test('metGoal and goalProgress: respects both flag and bothSince cutoff', () {
    const fullRev = (reviews: goalReviews, listenSec: 0);
    const fullLis = (reviews: 0, listenSec: goalListenSec);
    const bothDone = (reviews: goalReviews, listenSec: goalListenSec);
    const halfBoth = (reviews: 10, listenSec: 300);

    // Legacy (either OR):
    expect(metGoal(fullRev, both: false), isTrue);
    expect(metGoal(fullLis, both: false), isTrue);
    expect(goalProgress(fullRev, both: false), 1.0);

    // New rule (both AND):
    expect(metGoal(fullRev, both: true), isFalse);
    expect(metGoal(fullLis, both: true), isFalse);
    expect(metGoal(bothDone, both: true), isTrue);
    expect(goalProgress(halfBoth, both: true), closeTo(0.5, 0.01));
    expect(goalProgress(fullRev, both: true), closeTo(0.5, 0.01));

    // Streak with bothSince:
    final now = DateTime(2026, 11, 4);
    // Prior to bothSince, fullRev counted; on/after bothSince, bothDone is required:
    final acts = {
      '2026-11-02': fullRev,
      '2026-11-03': fullRev,
      '2026-11-04': bothDone,
    };
    // If bothSince is '2026-11-04', then 11-02 and 11-03 are legacy OK -> streak = 3
    expect(streak(acts, now, bothSince: '2026-11-04'), 3);
    // If bothSince was active since '2026-11-02', 11-03 didn't meet both -> streak = 1 (today only)
    expect(streak(acts, now, bothSince: '2026-11-02'), 1);
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

  test('splitSentences: long sentence is chunked so translation stays close', () {
    const long = 'Au loin, la Seine coulait lentement vers Rouen, large et paisible '
        'sous la lumière dorée du matin, tandis que les oiseaux chantaient '
        'dans les grands arbres du jardin et que le vent se levait doucement.';
    final chunks = splitSentences(long);
    expect(chunks.length, greaterThan(2));
    expect(chunks.every((c) => c.split(' ').length <= 22), isTrue);
    expect(chunks.join(' '), long);
  });

  test('naturalSentences: groups visual chunks into full sentences for continuous TTS', () {
    const long = 'Au loin, la Seine coulait lentement vers Rouen, large et paisible '
        'sous la lumière dorée du matin, tandis que les oiseaux chantaient '
        'dans les grands arbres du jardin et que le vent se levait doucement.';
    final chunks = splitSentences(long);
    final nat = naturalSentences(long);

    // Visually split into > 2 chunks, but spoken as 1 continuous natural sentence
    expect(chunks.length, greaterThan(2));
    expect(nat.length, 1);
    expect(nat[0].fullText, long);
    expect(nat[0].chunkIndices, [for (var i = 0; i < chunks.length; i++) i]);

    // Multiple sentences in a paragraph
    const multi = 'Aujourd\'hui, maman est morte. Ou peut-être hier, je ne sais pas.';
    final multiNat = naturalSentences(multi);
    final multiChunks = splitSentences(multi);
    expect(multiNat.length, 2);
    expect(multiNat[0].fullText, 'Aujourd\'hui, maman est morte.');
    expect(multiNat[1].fullText, 'Ou peut-être hier, je ne sais pas.');
    expect(multiNat.expand((n) => n.chunkIndices).toList(), [for (var i = 0; i < multiChunks.length; i++) i]);
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
            List.filled(160, 'mot').join(' '),
            List.filled(100, 'mot').join(' '),
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

  test('ttsJoin: prevents floating punctuation before ! ? : ; and aligns token spans', () {
    final words = ['«', 'Bonjour', '!', 'Comment', 'allez-vous', '?', '»'];
    final joined = ttsJoin(words);
    // ! and ? are glued to previous tokens, « has space after, » glued to preceding punctuation
    expect(joined.$1, '« Bonjour! Comment allez-vous?»');
    expect(joined.$2.length, words.length);
    for (var i = 0; i < words.length; i++) {
      final span = joined.$2[i];
      final extracted = joined.$1.substring(span.$1, span.$2);
      expect(extracted, words[i]);
    }
  });

  test('pageStarts: chunks book paragraphs into virtual pages', () {
    final UserBook book = (
      id: 1,
      title: 'Virtual Pages Book',
      level: 'A1',
      chapters: [
        (
          title: 'Chap 1',
          paragraphs: [
            List.filled(100, 'mot').join(' '), // 100 words (page 1)
            List.filled(100, 'mot').join(' '), // +100 words -> 200 words >= 160 threshold (starts page 2 on next)
            List.filled(50, 'mot').join(' '),  // page 2
          ],
        ),
        (
          title: 'Chap 2',
          paragraphs: [
            List.filled(50, 'mot').join(' '),
          ],
        ),
      ],
      chapterIdx: 0,
      paraIdx: 0,
      sentIdx: 0,
      wordIdx: 0,
    );

    final starts = pageStarts(book);
    expect(starts.isNotEmpty, isTrue);
    expect(starts.first.$1, 0);
    expect(starts.first.$2, 0);
    expect(starts.length, greaterThanOrEqualTo(2));
  });

  test('pageStarts: PDF with [[PDFPAGE:i]] markers matches exact 1:1 real PDF pages', () {
    final UserBook pdfBook = (
      id: 2,
      title: 'Original Document.pdf',
      level: 'B1',
      chapters: [
        (
          title: 'Páginas 1–3',
          paragraphs: [
            '[[PDFPAGE:0]]',
            'Texte de la page 1 du PDF.',
            '[[PDFPAGE:1]]',
            'Texte de la page 2 du PDF.',
            'Texte additionnel de la page 2.',
            '[[PDFPAGE:2]]',
            'Texte de la page 3 du PDF finale.',
          ],
        ),
      ],
      chapterIdx: 0,
      paraIdx: 0,
      sentIdx: 0,
      wordIdx: 0,
    );

    final starts = pageStarts(pdfBook);
    expect(starts.length, 3);
    expect(starts[0], (0, 0)); // Page 1 starts at [[PDFPAGE:0]]
    expect(starts[1], (0, 2)); // Page 2 starts at [[PDFPAGE:1]]
    expect(starts[2], (0, 5)); // Page 3 starts at [[PDFPAGE:2]]

    // bookPageInfo returns exact corresponding PDF page:
    expect(bookPageInfo(pdfBook, 0, 0), (1, 3));
    expect(bookPageInfo(pdfBook, 0, 1), (1, 3));
    expect(bookPageInfo(pdfBook, 0, 3), (2, 3));
    expect(bookPageInfo(pdfBook, 0, 4), (2, 3));
    expect(bookPageInfo(pdfBook, 0, 6), (3, 3));
  });

  test('grammar: validates 14 modules, exercises, and conjDrill generator', () {
    expect(grammarTopics.length, 14);
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

    // Dynamic conjugation drill
    final drillExercises = conjDrill(['etre', 'avoir', 'aller', 'faire'], 8);
    expect(drillExercises.length, 8);
    for (final ex in drillExercises) {
      expect(ex.options.contains(ex.solution), isTrue);
      expect(ex.hint, isNotNull);
      expect(ex.hint!.contains('Tabela de'), isTrue);
    }

    final drillTopic = conjDrillTopic(n: 5);
    expect(drillTopic.id.startsWith('drill_conj_'), isTrue);
    expect(drillTopic.exercises.length, 5);
  });

  testWidgets('Moto Edge 70 Fusion: zero text clipped at top during reading, auto-scroll and reset', (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: 52 * 3, bottom: 24 * 3);
    addTearDown(tester.view.reset);

    try {
      store = _FakeStore();
    } catch (_) {}

    final book = (
      id: -99,
      title: 'Le Petit Prince — Antoine de Saint-Exupéry',
      level: 'B1',
      chapterIdx: 0,
      paraIdx: 0,
      sentIdx: 0,
      wordIdx: 0,
      chapters: [
        (
          title: 'Chapitre I',
          paragraphs: [
            'Lorsque j’avais six ans j’ai vu, une fois, une magnifique image, dans un livre sur la Forêt Vierge qui s’appelait Histoires Vécues. Ça représentait un serpent boa qui avalait un fauve. Voilà la copie du dessin.',
            'On disait dans le livre : Les serpents boas avalent leur proie tout entière, sans la mâcher. Ensuite ils ne peuvent plus bouger et ils dorment pendant les six mois de leur digestion.',
            'J’ai alors beaucoup réfléchi sur les aventures de la jungle et, à mon tour, j’ai réussi, avec un crayon de couleur, à tracer mon premier dessin. Mon dessin numéro 1. Il était comme ça.',
            'J’ai montré mon chef-d’œuvre aux grandes personnes et je leur ai demandé si mon dessin leur faisait peur. Elles m’ont répondu : Pourquoi un chapeau ferait-il peur ?',
            'Mon dessin ne représentait pas un chapeau. Il représentait un serpent boa qui digérait un éléphant. J’ai alors dessiné l’intérieur du serpent boa, afin que les grandes personnes puissent comprendre.',
          ],
        ),
        (
          title: 'Chapitre II',
          paragraphs: ['Deuxième chapitre.'],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(theme: T.theme(), home: StoryScreen(book)));
    await tester.pumpAndSettle();

    final listFinder = find.byType(ListView);
    expect(listFinder, findsOneWidget);
    final listBox = tester.renderObject<RenderBox>(listFinder);
    expect(listBox.size.height, greaterThan(500));

    final firstParaFinder = find.byType(BilingualParagraph).first;
    final firstParaBox = tester.renderObject<RenderBox>(firstParaFinder);
    final initTop = firstParaBox.localToGlobal(Offset.zero, ancestor: listBox).dy;
    // Offset accounts for the top Page 1 marker header:
    expect(initTop, equals(75.0));

    for (var step = 1; step <= 12; step++) {
      await tester.tap(find.byTooltip('Avançar próxima frase'));
      await tester.pumpAndSettle();

      final paraWidgets = tester.renderObjectList<RenderBox>(find.byType(BilingualParagraph));
      for (final pBox in paraWidgets) {
        if (!pBox.hasSize) continue;
        final top = pBox.localToGlobal(Offset.zero, ancestor: listBox).dy;
        final bot = top + pBox.size.height;
        final isSlicedAtTop = top < 0.0 && bot > 0.0;
        expect(isSlicedAtTop, isFalse,
            reason: 'Paragraph card is sliced at top: top=$top, bot=$bot on step $step');
      }
    }

    await tester.tap(find.text('Início ↺'));
    await tester.pumpAndSettle();

    final resetParaBox = tester.renderObject<RenderBox>(firstParaFinder);
    final resetTop = resetParaBox.localToGlobal(Offset.zero, ancestor: listBox).dy;
    expect(resetTop, equals(75.0));

    for (var step = 1; step <= 10; step++) {
      await tester.tap(find.byTooltip('Avançar próxima frase'));
      await tester.pumpAndSettle();

      final paraWidgets = tester.renderObjectList<RenderBox>(find.byType(BilingualParagraph));
      for (final pBox in paraWidgets) {
        if (!pBox.hasSize) continue;
        final top = pBox.localToGlobal(Offset.zero, ancestor: listBox).dy;
        final bot = top + pBox.size.height;
        final isSlicedAtTop = top < 0.0 && bot > 0.0;
        expect(isSlicedAtTop, isFalse,
            reason: 'Paragraph card is sliced at top on second pass step $step: top=$top, bot=$bot');
      }
    }
  });
}
