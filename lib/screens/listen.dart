import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

import '../db.dart';
import '../main.dart';
import '../srs.dart';
import '../ui.dart';
import 'review.dart';
import 'words.dart';

const rfiFeed =
    'https://www.rfi.fr/fr/podcasts/journal-fran%C3%A7ais-facile/podcast';

typedef Episode = ({String title, String audio, String link, String date});

final builtInBooks = <UserBook>[
  (
    id: -1,
    title: 'Un matin au café à Paris',
    level: 'A1',
    chapterIdx: 0,
    paraIdx: 0,
    sentIdx: 0,
    wordIdx: 0,
    chapters: [
      (
        title: 'Chapitre unique',
        paragraphs: [
          'Il est huit heures du matin à Paris. Le soleil brille doucement sur la rue calme.',
          'Marie entre dans une petite boulangerie près de chez elle. Elle commande un croissant chaud et un café au lait.',
          'Elle s’assoit à une table près de la fenêtre. Elle ouvre son journal et regarde les passants dans la rue.',
          'Le serveur lui apporte sa tasse fumante avec un grand sourire. Il lui souhaite une très bonne journée avant son travail.',
        ],
      ),
    ],
  ),
  (
    id: -2,
    title: 'Une lettre de Provence',
    level: 'A2',
    chapterIdx: 0,
    paraIdx: 0,
    sentIdx: 0,
    wordIdx: 0,
    chapters: [
      (
        title: 'Chapitre unique',
        paragraphs: [
          'Cet été, nous avons décidé de passer nos vacances en Provence. Nous logeons dans un petit village entouré de collines.',
          'Chaque matin, nous marchons jusqu’au marché du village. Nous achetons des fruits frais, du fromage de chèvre et du pain chaud.',
          'L’après-midi, l’air sent bon la lavande sous le soleil. Les cigales chantent dans les oliviers pendant des heures.',
          'Le soir, les habitants se retrouvent sur la place centrale. Tout le monde discute gaiement et joue à la pétanque.',
        ],
      ),
    ],
  ),
  (
    id: -3,
    title: 'La Dernière Classe — Alphonse Daudet',
    level: 'B1',
    chapterIdx: 0,
    paraIdx: 0,
    sentIdx: 0,
    wordIdx: 0,
    chapters: [
      (
        title: 'Extrait',
        paragraphs: [
          'Ce matin-là, j’étais très en retard pour aller à l’école. J’avais grand-peur d’être grondé par M. Hamel.',
          'Il faisait si chaud, si clair ! On entendait les merles siffler à la lisière du bois.',
          'En entrant dans la classe, j’ai remarqué un calme extraordinaire : tout le village était assis en silence au fond de la salle.',
          'Monsieur Hamel nous a parlé avec émotion de la langue française. Il disait que c’était la plus belle langue du monde, la plus claire et la plus solide.',
        ],
      ),
    ],
  ),
  (
    id: -4,
    title: 'Le Horla — Guy de Maupassant',
    level: 'B2',
    chapterIdx: 0,
    paraIdx: 0,
    sentIdx: 0,
    wordIdx: 0,
    chapters: [
      (
        title: 'Journal — 8 mai',
        paragraphs: [
          'Quelle journée admirable ! J’ai passé toute la matinée étendu sur l’herbe, devant ma maison, sous l’énorme platane qui la couvre et l’abrite.',
          'J’aime ce pays profondément, et j’aime y vivre. J’y ai mes racines, ces délicates racines qui attachent un homme à la terre de ses aïeux.',
          'Au loin, la Seine coulait lentement vers Rouen. Le fleuve semblait large et paisible sous la lumière dorée du matin.',
        ],
      ),
    ],
  ),
];

/// Computes (currentPage, totalPages) based on cumulative words (~160 words per book page).
(int, int) bookPageInfo(UserBook b, int chapIdx, int paraIdx) {
  var totalWords = 0;
  var curWords = 0;
  for (var c = 0; c < b.chapters.length; c++) {
    final paras = b.chapters[c].paragraphs;
    for (var p = 0; p < paras.length; p++) {
      if (paras[p].startsWith('[[')) continue;
      final wordsInPara = paras[p].split(RegExp(r'\s+')).length;
      if (c < chapIdx || (c == chapIdx && p < paraIdx)) {
        curWords += wordsInPara;
      }
      totalWords += wordsInPara;
    }
  }
  const wordsPerPage = 160;
  final totalPages = max(1, (totalWords / wordsPerPage).ceil());
  final curPage = ((curWords / wordsPerPage).floor() + 1).clamp(1, totalPages);
  return (curPage, totalPages);
}

final _abbrevEndRe =
    RegExp(r'\b(?:M|Mr|Mme|Mlle|Dr|St|cf|etc)\.$', caseSensitive: false);
final _sentTermRe = RegExp(
  r'([.!?…;]+(?:\s*["”’»)\]])*)(\s+|(?=[A-ZÀ-ÖØ-ÞŒ«"“—–]))',
);

/// Splits a paragraph into individual French sentences while keeping image markers intact.
List<String> splitSentences(String para) {
  final raw = para.replaceAll(RegExp(r'[\u00A0\u202F\t]+'), ' ').trim();
  if (raw.isEmpty) return const [];
  if (raw.startsWith('[[IMG:')) return [raw];

  final out = <String>[];
  for (final line in raw.split(RegExp(r'\r?\n+'))) {
    // Split dialogue turns inside a single line (e.g. "Bonjour. — Salut !").
    for (final turn
        in line.split(RegExp(r'\s+(?=[—–]\s*[A-ZÀ-ÖØ-ÞŒ«"])'))) {
      final clean = turn.trim();
      if (clean.isEmpty) continue;
      var start = 0;
      for (final m in _sentTermRe.allMatches(clean)) {
        final punctEnd = m.start + m.group(1)!.length;
        final cand = clean.substring(start, punctEnd).trim();
        if (cand.isEmpty || _abbrevEndRe.hasMatch(cand)) continue;
        // Keep dialogue attribution attached (e.g. « Bonjour ! » dit-il.).
        if (cand.endsWith('»') && m.end < clean.length) {
          final nextCh = clean.substring(m.end, m.end + 1);
          if (RegExp(r'[a-zà-öø-ÿ]').hasMatch(nextCh)) continue;
        }
        _pushClause(out, cand);
        start = m.end;
      }
      if (start < clean.length) {
        final rem = clean.substring(start).trim();
        if (rem.isNotEmpty) _pushClause(out, rem);
      }
    }
  }
  return out.isEmpty ? [raw] : out;
}

void _pushClause(List<String> out, String s) {
  if (s.length > 65 && s.contains(': ')) {
    final idx = s.indexOf(': ');
    if (idx >= 22 && s.length - idx >= 18) {
      out.add(s.substring(0, idx + 1).trim());
      out.add(s.substring(idx + 2).trim());
      return;
    }
  }
  out.add(s);
}

List<String> sentenceWords(String sent) =>
    sent.split(' ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

String _encodeImageToken(Uint8List bytes, {String? mediaDir, String tag = 'img'}) {
  if (mediaDir != null && mediaDir.isNotEmpty) {
    try {
      final f = File(p.join(mediaDir,
          '${tag}_${DateTime.now().microsecondsSinceEpoch}_${bytes.length}.png'));
      f.writeAsBytesSync(bytes);
      return '[[IMG:${f.path}]]';
    } catch (_) {}
  }
  return '[[IMG:base64,${base64Encode(bytes)}]]';
}

/// Parses `.epub`, `.pdf`, or `.txt`/`.md` bytes into `(bookTitle, chapters)`.
(String, List<Chapter>) parseEbookBytes(String fileName, Uint8List bytes,
    {String? mediaDir}) {
  final defaultTitle = p.basenameWithoutExtension(fileName);
  final lower = fileName.toLowerCase();

  // 1. PDF format (%PDF magic header or .pdf extension).
  final isPdf = (bytes.length > 4 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46) ||
      lower.endsWith('.pdf');
  if (isPdf) {
    try {
      final doc = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(doc);
      final count = doc.pages.count;
      var bookTitle = doc.documentInformation.title.trim();
      if (bookTitle.isEmpty) bookTitle = defaultTitle;

      final chapters = <Chapter>[];
      const pagesPerChap = 5;
      for (var start = 0; start < count; start += pagesPerChap) {
        final end = (start + pagesPerChap - 1).clamp(0, count - 1);
        final paras = <String>[];
        for (var i = start; i <= end; i++) {
          paras.add('[[PDFPAGE:$i]]');
          final rawPage =
              extractor.extractText(startPageIndex: i, endPageIndex: i);
          // Reflow broken single newlines inside sentences while keeping paragraph breaks.
          final reflowed = rawPage
              .replaceAll('\r\n', '\n')
              .replaceAll(
                  RegExp(r'(?<![.!?…:\n])\n(?=[a-zà-öø-ÿ«"—–])'), ' ');
          for (final block in reflowed.split(RegExp(r'\n\s*\n|\n'))) {
            final clean = block.replaceAll(RegExp(r'\s+'), ' ').trim();
            if (clean.length > 1) paras.add(clean);
          }
        }
        if (paras.isNotEmpty) {
          chapters.add((
            title: count <= pagesPerChap
                ? 'Documento completo'
                : 'Páginas ${start + 1}–${end + 1}',
            paragraphs: paras,
          ));
        }
      }
      doc.dispose();
      if (chapters.isNotEmpty) return (bookTitle, chapters);
    } catch (_) {}
  }

  // 2. EPUB format (PK zip header or .epub extension).
  final isZip =
      bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B; // 'PK'
  if (isZip || lower.endsWith('.epub')) {
    try {
      final arch = ZipDecoder().decodeBytes(bytes);
      final byPath = <String, ArchiveFile>{
        for (final f in arch.files)
          if (f.isFile) f.name.replaceAll('\\', '/'): f
      };
      final opfEntry = arch.files
          .where((f) => f.isFile && f.name.toLowerCase().endsWith('.opf'))
          .firstOrNull;
      var bookTitle = defaultTitle;
      final htmlPaths = <String>[];

      if (opfEntry != null) {
        final opfDir = p.posix.dirname(opfEntry.name.replaceAll('\\', '/'));
        final opfText = utf8.decode(opfEntry.readBytes() ?? Uint8List(0),
            allowMalformed: true);
        final titleMatch = RegExp(
                r'<(?:dc:)?title[^>]*>([^<]+)</(?:dc:)?title>',
                caseSensitive: false)
            .firstMatch(opfText);
        if (titleMatch != null && titleMatch.group(1)!.trim().isNotEmpty) {
          bookTitle = titleMatch.group(1)!.trim();
        }
        final manifest = <String, String>{};
        for (final m in RegExp(r'<item\b([^>]+)>', caseSensitive: false)
            .allMatches(opfText)) {
          final attrs = m.group(1)!;
          final id = RegExp(r'\bid="([^"]+)"').firstMatch(attrs)?.group(1);
          final href = RegExp(r'\bhref="([^"]+)"').firstMatch(attrs)?.group(1);
          if (id != null && href != null) {
            manifest[id] = opfDir == '.'
                ? Uri.decodeFull(href)
                : p.posix.normalize('$opfDir/${Uri.decodeFull(href)}');
          }
        }
        for (final m in RegExp(r'<itemref\b([^>]+)>', caseSensitive: false)
            .allMatches(opfText)) {
          final idref =
              RegExp(r'\bidref="([^"]+)"').firstMatch(m.group(1)!)?.group(1);
          final target = idref == null ? null : manifest[idref];
          if (target != null && byPath.containsKey(target)) {
            htmlPaths.add(target);
          }
        }
      }

      if (htmlPaths.isEmpty) {
        htmlPaths.addAll(byPath.keys.where((k) =>
            k.endsWith('.xhtml') || k.endsWith('.html') || k.endsWith('.htm')));
      }

      ArchiveFile? resolveImg(String chapDir, String rawSrc) {
        final cleanSrc = Uri.decodeFull(rawSrc.split('#').first);
        final norm = chapDir == '.'
            ? cleanSrc
            : p.posix.normalize('$chapDir/$cleanSrc');
        if (byPath[norm] case final hit?) return hit;
        final base = p.posix.basename(cleanSrc);
        return arch.files
            .where((f) => f.isFile && p.posix.basename(f.name) == base)
            .firstOrNull;
      }

      final chapters = <Chapter>[];
      for (final path in htmlPaths) {
        final f = byPath[path];
        if (f == null) continue;
        final chapDir = p.posix.dirname(path);
        final doc = html.parse(
            utf8.decode(f.readBytes() ?? Uint8List(0), allowMalformed: true));
        final h = doc
            .querySelector('h1, h2, h3, title')
            ?.text
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final paras = <String>[];
        final seenImgs = <String>{};

        for (final el in doc.querySelectorAll('p, img, image')) {
          final tag = el.localName?.toLowerCase();
          if (tag == 'img' || tag == 'image') {
            final src = el.attributes['src'] ??
                el.attributes['href'] ??
                el.attributes['xlink:href'];
            if (src != null && seenImgs.add(src)) {
              final imgFile = resolveImg(chapDir, src);
              final imgBytes = imgFile?.readBytes();
              if (imgBytes != null && imgBytes.isNotEmpty) {
                paras.add(
                    _encodeImageToken(imgBytes, mediaDir: mediaDir, tag: 'epub'));
              }
            }
          } else if (tag == 'p') {
            for (final img in el.querySelectorAll('img, image')) {
              final src = img.attributes['src'] ??
                  img.attributes['href'] ??
                  img.attributes['xlink:href'];
              if (src != null && seenImgs.add(src)) {
                final imgFile = resolveImg(chapDir, src);
                final imgBytes = imgFile?.readBytes();
                if (imgBytes != null && imgBytes.isNotEmpty) {
                  paras.add(_encodeImageToken(imgBytes,
                      mediaDir: mediaDir, tag: 'epub'));
                }
              }
            }
            for (final br in el.querySelectorAll('br')) {
              br.replaceWith(html.parseFragment('\n'));
            }
            final t = el.text
                .replaceAll(RegExp(r'[ \t\u00A0\u202F]+'), ' ')
                .replaceAll(RegExp(r' *\n *'), '\n')
                .trim();
            if (t.length > 1) paras.add(t);
          }
        }

        if (paras.isNotEmpty) {
          chapters.add((
            title: (h != null && h.isNotEmpty)
                ? h
                : 'Capítulo ${chapters.length + 1}',
            paragraphs: paras,
          ));
        }
      }
      if (chapters.isNotEmpty) return (bookTitle, chapters);
    } catch (_) {
      // Fall back to plain text below if malformed archive.
    }
  }

  // 3. Plain text (.txt / .md) fallback.
  final raw = utf8.decode(bytes, allowMalformed: true);
  final paras = raw
      .split(RegExp(r'\r?\n+'))
      .map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final chapters = <Chapter>[];
  for (var i = 0; i < paras.length; i += 25) {
    chapters.add((
      title: 'Parte ${(i ~/ 25) + 1}',
      paragraphs: paras.sublist(i, (i + 25).clamp(0, paras.length)),
    ));
  }
  return (
    defaultTitle,
    chapters.isEmpty
        ? [(title: 'Capítulo 1', paragraphs: ['(Arquivo vazio)'])]
        : chapters
  );
}

/// Renders PDF page snapshots using Android's native PdfRenderer (`pdfx`) and replaces
/// `[[PDFPAGE:i]]` markers with real `[[IMG:/path/to/page.png]]` tokens.
Future<List<Chapter>> hydratePdfImages(
    Uint8List pdfBytes, List<Chapter> chapters, String mediaDir) async {
  try {
    final doc = await pdfx.PdfDocument.openData(pdfBytes);
    final out = <Chapter>[];
    for (final c in chapters) {
      final newParas = <String>[];
      for (final para in c.paragraphs) {
        final m = RegExp(r'^\[\[PDFPAGE:(\d+)\]\]$').firstMatch(para);
        if (m != null) {
          final pageZero = int.parse(m.group(1)!);
          // Render up to first 30 pages automatically to keep import snappy.
          if (pageZero < 30 && pageZero < doc.pagesCount) {
            final page = await doc.getPage(pageZero + 1);
            final img = await page.render(
              width: page.width * 1.5,
              height: page.height * 1.5,
              format: pdfx.PdfPageImageFormat.png,
            );
            await page.close();
            if (img != null && img.bytes.isNotEmpty) {
              newParas.add(
                  _encodeImageToken(img.bytes, mediaDir: mediaDir, tag: 'pdf'));
            }
          }
        } else {
          newParas.add(para);
        }
      }
      out.add((
        title: c.title,
        paragraphs:
            newParas.isEmpty ? ['(Página sem texto extraível)'] : newParas,
      ));
    }
    await doc.close();
    return out;
  } catch (_) {
    // Strip unrendered [[PDFPAGE:i]] tokens if native renderer is unavailable.
    return [
      for (final c in chapters)
        (
          title: c.title,
          paragraphs: [
            for (final p in c.paragraphs)
              if (!p.startsWith('[[PDFPAGE:')) p
          ],
        )
    ];
  }
}

Future<(String, List<Episode>)> fetchFeed(String url) async {
  final res = await http.get(Uri.parse(url));
  if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
  final doc = XmlDocument.parse(res.body);
  String txt(XmlElement e, String tag) =>
      e.findElements(tag).firstOrNull?.innerText.trim() ?? '';
  final channel = doc.findAllElements('channel').first;
  return (
    txt(channel, 'title'),
    [
      for (final i in doc.findAllElements('item'))
        if (i.findElements('enclosure').firstOrNull?.getAttribute('url')
            case final audio?)
          (
            title: txt(i, 'title'),
            audio: audio,
            link: txt(i, 'link'),
            date: txt(i, 'pubDate').split(' ').skip(1).take(3).join(' '),
          )
    ]
  );
}

/// RFI "Journal en français facile": the transcript lives on
/// francaisfacile.rfi.fr under a headline slug; match it by the date prefix.
// ponytail: HTML scraping, breaks if RFI changes markup; then show audio only.
Future<List<String>> rfiTranscript(String link) async {
  final date = RegExp(r'/(\d{8})-').firstMatch(link)?.group(1);
  if (date == null) return [];
  const base = 'https://francaisfacile.rfi.fr';
  const list = '$base/fr/podcasts/journal-en-fran%C3%A7ais-facile/';
  final href =
      RegExp('href="(/fr/podcasts/journal-en-fran[^"/]*/$date-[^"]+)"');
  for (final page in [list, '${list}2/', '${list}3/']) {
    final m = href.firstMatch((await http.get(Uri.parse(page))).body);
    if (m == null) continue;
    final doc =
        html.parse((await http.get(Uri.parse('$base${m.group(1)}'))).body);
    return [
      for (final p
          in doc.querySelectorAll('.m-transcription .m-box-expand__content p'))
        if (p.text.replaceAll(RegExp(r'\s+'), ' ').trim() case final t
            when t.isNotEmpty)
          t
    ];
  }
  return [];
}

class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key});

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  int _section = 0; // 0 = Podcasts, 1 = Leitura (Contos/Ebooks/PDFs)
  String _feed = rfiFeed;
  Future<(String, List<Episode>)>? _data;

  @override
  void initState() {
    super.initState();
    _load(rfiFeed);
  }

  void _load(String f) => setState(() {
        _feed = f;
        _data = fetchFeed(f);
      });

  Future<void> _addFeed() async {
    final c = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: T.bg,
        title: Text('Adicionar podcast', style: T.title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'URL do RSS (https://…)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Adicionar')),
        ],
      ),
    );
    final uri = Uri.tryParse(url ?? '');
    if (uri == null || !uri.isScheme('https') && !uri.isScheme('http')) return;
    await store.set('feeds', [...store.feeds, uri.toString()].join('\n'));
    _load(uri.toString());
  }

  Future<void> _pickEbookFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'pdf', 'txt', 'md'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    final bytes = f.bytes ??
        (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (bytes == null) return;
    var (title, chapters) =
        parseEbookBytes(f.name, bytes, mediaDir: store.mediaDir);
    if (f.name.toLowerCase().endsWith('.pdf') ||
        (bytes.length > 4 && bytes[0] == 0x25 && bytes[1] == 0x50)) {
      chapters = await hydratePdfImages(bytes, chapters, store.mediaDir);
    }
    final saved = await store.addEbook(title, store.level, chapters);
    if (!mounted) return;
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => StoryScreen(saved)),
    );
  }

  Future<void> _openCustomText() async {
    final titleCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: T.bg,
        title: Text('Salvar texto ou capítulo', style: T.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration:
                  const InputDecoration(hintText: 'Título (opcional)'),
            ),
            const SizedBox(height: T.s2),
            TextField(
              controller: textCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                  hintText: 'Cole aqui qualquer trecho, artigo ou capítulo…'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar e Ler')),
        ],
      ),
    );
    final text = textCtrl.text.trim();
    if (ok != true || text.isEmpty) return;
    final title = titleCtrl.text.trim().isEmpty
        ? 'Texto personalizado'
        : titleCtrl.text.trim();
    final (_, chapters) = parseEbookBytes(
        '$title.txt', Uint8List.fromList(utf8.encode(text)),
        mediaDir: store.mediaDir);
    final saved = await store.addEbook(title, store.level, chapters);
    if (!mounted) return;
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => StoryScreen(saved)),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final feeds = [rfiFeed, ...store.feeds];
          return ListView(
            padding: const EdgeInsets.fromLTRB(T.s4, T.s4, T.s4, 120),
            children: [
              Row(children: [
                Expanded(
                    child: Text(_section == 0 ? 'Ouvir' : 'Leitura',
                        style: T.largeTitle)),
                IconButton(
                  tooltip: _section == 0
                      ? 'Adicionar podcast'
                      : 'Anexar livro (.epub / .pdf / .txt)',
                  icon: const Icon(CupertinoIcons.plus_circle, color: T.text),
                  onPressed: _section == 0 ? _addFeed : _pickEbookFile,
                ),
              ]),
              const SizedBox(height: T.s3),
              Row(children: [
                for (final (i, label) in [
                  (0, 'Podcasts'),
                  (1, 'Livros / PDFs')
                ])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 0 ? T.s2 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _section = i),
                        child: AnimatedContainer(
                          duration: T.fast,
                          padding: const EdgeInsets.symmetric(vertical: T.s2),
                          decoration: BoxDecoration(
                            color: _section == i ? T.sky : T.surface,
                            borderRadius: BorderRadius.circular(T.rMd),
                            border: Border.all(color: T.hairline, width: 0.5),
                          ),
                          child: Text(label,
                              style: T.body.copyWith(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: T.s4),
              if (_section == 1)
                ..._storiesList(context)
              else ...[
                if (feeds.length > 1) ...[
                  Wrap(spacing: T.s2, runSpacing: T.s2, children: [
                    for (final f in feeds)
                      GestureDetector(
                        onLongPress: f == rfiFeed
                            ? null
                            : () async {
                                await store.set(
                                    'feeds',
                                    store.feeds
                                        .where((x) => x != f)
                                        .join('\n'));
                                _load(rfiFeed);
                              },
                        child: ChoiceChip(
                          label: Text(
                              f == rfiFeed ? 'RFI facile' : Uri.parse(f).host),
                          selected: _feed == f,
                          selectedColor: T.sky,
                          onSelected: (_) => _load(f),
                        ),
                      ),
                  ]),
                  Text('Segure um podcast para removê-lo.', style: T.caption),
                  const SizedBox(height: T.s3),
                ],
                FutureBuilder(
                  future: _data,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return GlassCard(
                        color: T.rose,
                        child: Column(children: [
                          Text('Não foi possível carregar o podcast.',
                              style: T.body),
                          const SizedBox(height: T.s3),
                          PillButton('Tentar de novo',
                              onTap: () => _load(_feed)),
                        ]),
                      );
                    }
                    if (!snap.hasData) {
                      return const Padding(
                          padding: EdgeInsets.all(T.s6),
                          child: CupertinoActivityIndicator());
                    }
                    final (title, eps) = snap.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: T.title),
                        const SizedBox(height: T.s3),
                        for (final e in eps.take(30))
                          Padding(
                            padding: const EdgeInsets.only(bottom: T.s3),
                            child: GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                      builder: (_) => EpisodeScreen(e))),
                              child: GlassCard(
                                child: Row(children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                        color: T.sky,
                                        borderRadius:
                                            BorderRadius.circular(T.rMd)),
                                    child: const Icon(CupertinoIcons.play_fill,
                                        color: T.text),
                                  ),
                                  const SizedBox(width: T.s3),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(e.title,
                                            style: T.body.copyWith(
                                                fontWeight: FontWeight.w600),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        Text(e.date, style: T.caption),
                                      ],
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          );
        },
      );

  List<Widget> _storiesList(BuildContext context) => [
        Row(children: [
          Expanded(
            child: PillButton(
              'Anexar (.epub / .pdf / .txt)',
              icon: CupertinoIcons.book,
              color: T.lavender,
              onTap: _pickEbookFile,
            ),
          ),
          const SizedBox(width: T.s2),
          PillButton(
            'Colar',
            icon: CupertinoIcons.doc_on_clipboard,
            color: T.sky,
            onTap: _openCustomText,
          ),
        ]),
        const SizedBox(height: T.s4),
        if (store.ebooks.isNotEmpty) ...[
          Text('Meus Livros, PDFs e Textos', style: T.title),
          const SizedBox(height: T.s2),
          for (final b in store.ebooks)
            Builder(builder: (_) {
              final (pCur, pTot) = bookPageInfo(b, b.chapterIdx, b.paraIdx);
              return Padding(
                padding: const EdgeInsets.only(bottom: T.s3),
                child: GestureDetector(
                  onTap: () => Navigator.push(context,
                      CupertinoPageRoute(builder: (_) => StoryScreen(b))),
                  child: GlassCard(
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: T.lavender,
                          borderRadius: BorderRadius.circular(T.rSm),
                        ),
                        child: const Icon(CupertinoIcons.book_fill,
                            size: 20, color: T.text),
                      ),
                      const SizedBox(width: T.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.title,
                                style:
                                    T.body.copyWith(fontWeight: FontWeight.w600)),
                            Text(
                                'Página $pCur de $pTot · Cap. ${b.chapterIdx + 1}/${b.chapters.length}',
                                style: T.caption),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remover livro',
                        icon: const Icon(CupertinoIcons.trash,
                            size: 18, color: T.textMuted),
                        onPressed: () => store.deleteEbook(b.id),
                      ),
                    ]),
                  ),
                ),
              );
            }),
          const SizedBox(height: T.s3),
        ],
        Text('Contos e textos graduados (FR + PT-BR)', style: T.title),
        const SizedBox(height: T.s2),
        Text(
            'Cada frase possui sua tradução em português colada logo abaixo. Acompanhe a leitura com realce de áudio estilo letra de música.',
            style: T.secondary),
        const SizedBox(height: T.s3),
        for (final s in builtInBooks)
          Builder(builder: (_) {
            final (_, pTot) = bookPageInfo(s, 0, 0);
            return Padding(
              padding: const EdgeInsets.only(bottom: T.s3),
              child: GestureDetector(
                onTap: () => Navigator.push(
                    context, CupertinoPageRoute(builder: (_) => StoryScreen(s))),
                child: GlassCard(
                  child: Row(children: [
                    LevelChip(s.level),
                    const SizedBox(width: T.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title,
                              style:
                                  T.body.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                              '$pTot ${pTot == 1 ? 'página' : 'páginas'} · Frase a frase + Áudio',
                              style: T.caption),
                        ],
                      ),
                    ),
                    const Icon(CupertinoIcons.chevron_right, color: T.textMuted),
                  ]),
                ),
              ),
            );
          }),
      ];
}

typedef PlayCursor = ({int para, int sent, int word, bool playing});

/// Stable per-sentence translation widget: reads synchronous cache first so
/// rebuilds never collapse/expand layout height.
class _SentenceTranslation extends StatefulWidget {
  const _SentenceTranslation(this.sent);
  final String sent;

  @override
  State<_SentenceTranslation> createState() => _SentenceTranslationState();
}

class _SentenceTranslationState extends State<_SentenceTranslation> {
  String? _pt;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _syncOrFetch();
  }

  @override
  void didUpdateWidget(covariant _SentenceTranslation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sent != widget.sent) _syncOrFetch();
  }

  void _syncOrFetch() {
    final hit = store.cachedTranslation(widget.sent);
    if (hit != null && hit.isNotEmpty) {
      _pt = hit;
      _loading = false;
    } else {
      _pt = null;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final res = await store.translate(widget.sent);
    if (!mounted) return;
    setState(() {
      _pt = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pt = _pt ?? store.cachedTranslation(widget.sent);
    if (pt != null && pt.isNotEmpty) {
      return Text(pt, style: T.secondary.copyWith(height: 1.35));
    }
    if (_loading) {
      return Text('Traduzindo frase…', style: T.caption);
    }
    return GestureDetector(
      onTap: _fetch,
      child: Text('Toque para traduzir em PT-BR', style: T.caption),
    );
  }
}

/// Interactive paragraph section:
/// - Renders inline book images (`[[IMG:...]]`) with pinch-to-zoom on tap.
/// - Groups sentences of a paragraph inside one section, displaying the PT-BR translation
///   immediately below each individual French sentence.
/// - Constant-geometry Spotify Lyrics word highlighting (zero layout reflow / scroll jitter).
class BilingualParagraph extends StatefulWidget {
  const BilingualParagraph(
    this.text, {
    super.key,
    required this.onTapWord,
    this.onLongPressWord,
    this.showAudio = false,
    this.activeSentIdx,
    this.activeWordIdx,
    this.isPlaying = false,
    this.hidePt = false,
    this.onTapSentenceAudio,
    this.keyPrefix,
  });
  final String text;
  final ValueChanged<String> onTapWord;
  final void Function(int sentIdx, int wordIdx)? onLongPressWord;
  final bool showAudio;
  final int? activeSentIdx;
  final int? activeWordIdx;
  final bool isPlaying;
  final bool hidePt;
  final ValueChanged<int>? onTapSentenceAudio;
  final String? keyPrefix;

  @override
  State<BilingualParagraph> createState() => _BilingualParagraphState();
}

class _BilingualParagraphState extends State<BilingualParagraph> {
  final _revealedSents = <int>{};

  @override
  Widget build(BuildContext context) {
    if (widget.text.startsWith('[[IMG:')) {
      return _buildImage(
          context, widget.text.substring(6, widget.text.length - 2));
    }
    if (widget.text.startsWith('[[PDFPAGE:')) {
      return const SizedBox.shrink();
    }

    final sentences = splitSentences(widget.text);
    final hasCursor = widget.activeSentIdx != null;

    return Container(
      margin: const EdgeInsets.only(bottom: T.s4),
      padding: const EdgeInsets.all(T.s3),
      decoration: BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.circular(T.rMd),
        border: Border.all(
          color: hasCursor ? T.lavender : T.hairline,
          width: hasCursor ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (sIdx, sent) in sentences.indexed) ...[
            if (sIdx > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: T.s2),
                child: Divider(height: 1, thickness: 0.5, color: T.hairline),
              ),
            Container(
              key: widget.keyPrefix != null
                  ? GlobalObjectKey('${widget.keyPrefix}_$sIdx')
                  : null,
              child: _buildSentenceBlock(sIdx, sent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context, String spec) {
    Widget imgWidget;
    if (spec.startsWith('base64,')) {
      final bytes = base64Decode(spec.substring(7));
      imgWidget = Image.memory(bytes, fit: BoxFit.contain);
    } else {
      final file = File(spec);
      if (!file.existsSync()) return const SizedBox.shrink();
      imgWidget = Image.file(file, fit: BoxFit.contain);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: T.s4),
      child: GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(T.s2),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(T.rMd),
                    child: imgWidget,
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: T.surface),
                  icon: const Icon(CupertinoIcons.xmark, color: T.text),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: T.surface,
            borderRadius: BorderRadius.circular(T.rMd),
            border: Border.all(color: T.hairline, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: SizedBox(width: double.infinity, child: imgWidget),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: T.s3, vertical: T.s1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.zoom_in,
                        size: 14, color: T.textMuted),
                    const SizedBox(width: T.s1),
                    Text('Ilustração do livro (toque para ampliar)',
                        style: T.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSentenceBlock(int sIdx, String sent) {
    final isCurrent = widget.activeSentIdx == sIdx;
    final showPt = !widget.hidePt || _revealedSents.contains(sIdx);
    final words = sentenceWords(sent);
    final curWord = isCurrent ? widget.activeWordIdx : null;

    // Constant padding across active/inactive states prevents line-wrap reflow!
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: T.s2, vertical: 6),
      decoration: isCurrent
          ? BoxDecoration(
              color: T.lavender
                  .withValues(alpha: widget.isPlaying ? 0.28 : 0.14),
              borderRadius: BorderRadius.circular(T.rSm),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showAudio)
                Padding(
                  padding: const EdgeInsets.only(right: T.s2, top: 4),
                  child: GestureDetector(
                    onTap: () {
                      if (widget.onTapSentenceAudio != null) {
                        widget.onTapSentenceAudio!(sIdx);
                      } else {
                        speakFr(sent);
                      }
                    },
                    child: Icon(
                      isCurrent && widget.isPlaying
                          ? CupertinoIcons.speaker_2_fill
                          : (isCurrent
                              ? CupertinoIcons.pause_circle
                              : CupertinoIcons.speaker_2),
                      size: 18,
                      color: isCurrent ? T.text : T.textMuted,
                    ),
                  ),
                ),
              Expanded(
                child: Wrap(children: [
                  for (final (wIdx, t) in words.indexed)
                    _spotifyWord(t, sIdx, wIdx, curWord, isCurrent),
                ]),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
                left: widget.showAudio ? 26 : 0, top: 4),
            child: !showPt
                ? GestureDetector(
                    onTap: () => setState(() => _revealedSents.add(sIdx)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: T.s2, vertical: 2),
                      decoration: BoxDecoration(
                        color: T.sky.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(T.rSm),
                      ),
                      child: Text('Toque para revelar a tradução PT-BR',
                          style: T.caption),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.only(left: T.s2),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: T.lavender, width: 2),
                      ),
                    ),
                    child: _SentenceTranslation(sent),
                  ),
          ),
        ],
      ),
    );
  }

  /// Constant-geometry Spotify Lyrics word renderer:
  /// Fixed padding & fontWeight so speaking a word never changes its width or wraps lines!
  Widget _spotifyWord(
      String t, int sIdx, int wIdx, int? curWordIdx, bool isCurrent) {
    final w = wordRe.hasMatch(t) ? store.vocab.lookup(t) : null;
    final saved = w != null && store.cardIds.contains(w.id);

    final isExactSpoken = isCurrent && curWordIdx != null && curWordIdx == wIdx;
    final isUpcoming = isCurrent && curWordIdx != null && wIdx > curWordIdx;

    final textColor = isUpcoming ? T.textMuted : T.text;

    return GestureDetector(
      onTap: wordRe.hasMatch(t) ? () => widget.onTapWord(t) : null,
      onLongPress: widget.onLongPressWord != null
          ? () => widget.onLongPressWord!(sIdx, wIdx)
          : null,
      child: Container(
        margin: const EdgeInsets.only(right: 3, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: isExactSpoken
            ? BoxDecoration(
                color: T.lavender,
                borderRadius: BorderRadius.circular(4),
              )
            : (saved
                ? BoxDecoration(
                    color: T.butter.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null),
        child: Text(
          t,
          style: T.body.copyWith(
            height: 1.5,
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

void tapWordInContext(BuildContext context, String token, String source) {
  final w = store.vocab.lookup(token);
  if (w == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 1),
        content: Text('“${candidates(token).first}” não está no dicionário')));
    return;
  }
  showWordSheet(context, w, source: source);
}

class StoryScreen extends StatefulWidget {
  const StoryScreen(this.b, {super.key});
  final UserBook b;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final _scrollCtrl = ScrollController();
  late final ValueNotifier<PlayCursor> _cursor;
  late int _chap;
  bool _hidePt = false;
  bool _userDragging = false;
  double _rate = 0.45; // 0.30 = 0.75x, 0.45 = 1.0x, 0.58 = 1.25x
  int _runId = 0;
  Timer? _fallbackWordTimer;
  bool _nativeProgressSeen = false;
  int _ttsWordOffset = 0;

  int get _paraIdx => _cursor.value.para;
  int get _sentIdx => _cursor.value.sent;
  int get _wordIdx => _cursor.value.word;
  bool get _playing => _cursor.value.playing;

  void _updateCursor({int? para, int? sent, int? word, bool? playing}) {
    _cursor.value = (
      para: para ?? _cursor.value.para,
      sent: sent ?? _cursor.value.sent,
      word: word ?? _cursor.value.word,
      playing: playing ?? _cursor.value.playing,
    );
  }

  @override
  void initState() {
    super.initState();
    _chap = widget.b.chapterIdx.clamp(0, widget.b.chapters.length - 1);
    final maxP =
        (widget.b.chapters[_chap].paragraphs.length - 1).clamp(0, 999999);
    final initP = widget.b.paraIdx.clamp(0, maxP);
    final sents = splitSentences(widget.b.chapters[_chap].paragraphs[initP]);
    final initS = widget.b.sentIdx.clamp(0, (sents.length - 1).clamp(0, 9999));
    final words =
        initS < sents.length ? sentenceWords(sents[initS]) : <String>[];
    final initW = widget.b.wordIdx.clamp(0, (words.length - 1).clamp(0, 9999));

    _cursor = ValueNotifier((
      para: initP,
      sent: initS,
      word: initW,
      playing: false,
    ));

    _setupTtsProgress();
  }

  void _setupTtsProgress() {
    tts.setProgressHandler(
        (String text, int startOffset, int endOffset, String word) {
      if (!mounted || !_playing) return;
      // Native Android TTS progress works: cancel simulated fallback immediately!
      _nativeProgressSeen = true;
      _fallbackWordTimer?.cancel();

      final paras = widget.b.chapters[_chap].paragraphs;
      if (_paraIdx >= paras.length) return;
      final sents = splitSentences(paras[_paraIdx]);
      if (_sentIdx >= sents.length) return;
      final words = sentenceWords(sents[_sentIdx]);

      var charAcc = 0;
      final effectiveStart = startOffset + _ttsWordOffset;
      for (var t = 0; t < words.length; t++) {
        final tokLen = words[t].length;
        if (effectiveStart >= charAcc && effectiveStart <= charAcc + tokLen) {
          if (t > _wordIdx || (t == 0 && _wordIdx == 0)) {
            _updateCursor(word: t);
          }
          break;
        }
        charAcc += tokLen + 1;
      }
    });
  }

  @override
  void dispose() {
    _runId++;
    _fallbackWordTimer?.cancel();
    tts.setProgressHandler((_, _, _, _) {});
    tts.stop();
    if (widget.b.id > 0) {
      store.updateEbookProgress(
          widget.b.id, _chap, _paraIdx, _sentIdx, _wordIdx, true);
    }
    _scrollCtrl.dispose();
    _cursor.dispose();
    super.dispose();
  }

  Future<void> _saveCursor({bool notify = false}) async {
    if (widget.b.id > 0) {
      await store.updateEbookProgress(
          widget.b.id, _chap, _paraIdx, _sentIdx, _wordIdx, notify);
    }
  }

  /// Calm auto-scroll: ONLY scrolls when the active sentence approaches the bottom/top
  /// edge of the screen, never when it's already comfortably visible or while user drags.
  void _scrollToCurrent({bool force = false}) {
    if (_userDragging && !force) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = GlobalObjectKey('s_${_chap}_${_paraIdx}_$_sentIdx');
      final ctx = key.currentContext;
      if (ctx == null) {
        if (_paraIdx == 0 && _sentIdx == 0 && _scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(0,
              duration: T.fast, curve: T.curve);
        }
        return;
      }
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final scrollable = Scrollable.maybeOf(ctx);
      final vpBox = scrollable?.context.findRenderObject() as RenderBox?;
      if (vpBox != null && vpBox.hasSize && !force) {
        final topInVp = box.localToGlobal(Offset.zero, ancestor: vpBox).dy;
        final botInVp = topInVp + box.size.height;
        final vpH = vpBox.size.height;
        // Already comfortably visible in viewport -> keep page completely still!
        if (topInVp >= vpH * 0.08 && botInVp <= vpH * 0.80) return;
      }
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.20,
        duration: const Duration(milliseconds: 350),
        curve: T.curve,
      );
    });
  }

  Future<void> _pauseAudio() async {
    _runId++;
    _fallbackWordTimer?.cancel();
    if (mounted) _updateCursor(playing: false);
    await tts.stop();
    await _saveCursor(notify: true);
  }

  Future<void> _setChapter(int idx) async {
    await _pauseAudio();
    setState(() => _chap = idx);
    _updateCursor(para: 0, sent: 0, word: 0, playing: false);
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    await _saveCursor(notify: true);
  }

  Future<void> _playFromCurrent() async {
    final myRun = ++_runId;
    _updateCursor(playing: true);
    final paras = widget.b.chapters[_chap].paragraphs;
    await tts.setLanguage('fr-FR');
    await tts.awaitSpeakCompletion(true);

    for (var p = _paraIdx; p < paras.length; p++) {
      if (!mounted || _runId != myRun || !_playing) return;
      if (paras[p].startsWith('[[IMG:') || paras[p].startsWith('[[PDFPAGE:')) {
        continue;
      }
      final sents = splitSentences(paras[p]);
      if (sents.isEmpty) continue;
      final startS = (p == _paraIdx) ? _sentIdx.clamp(0, sents.length - 1) : 0;

      for (var s = startS; s < sents.length; s++) {
        if (!mounted || _runId != myRun || !_playing) return;
        final words = sentenceWords(sents[s]);
        if (words.isEmpty) continue;
        var startW = (p == _paraIdx && s == _sentIdx)
            ? _wordIdx.clamp(0, words.length - 1)
            : 0;

        var speakText = words.skip(startW).join(' ');
        // If paused at trailing punctuation, restart sentence cleanly or skip empty punctuation.
        if (!wordRe.hasMatch(speakText)) {
          if (startW > 0 && wordRe.hasMatch(sents[s])) {
            startW = 0;
            speakText = sents[s];
          } else {
            continue;
          }
        }

        _updateCursor(para: p, sent: s, word: startW, playing: true);
        await _saveCursor(notify: false);
        _scrollToCurrent();

        _ttsWordOffset = words.take(startW).join(' ').length;
        if (_ttsWordOffset > 0) _ttsWordOffset += 1;

        _fallbackWordTimer?.cancel();
        _nativeProgressSeen = false;
        final msPerWord = (_rate == 0.30 ? 550 : (_rate == 0.58 ? 280 : 380));
        var simulatedWord = startW;
        _fallbackWordTimer =
            Timer.periodic(Duration(milliseconds: msPerWord), (tm) {
          if (!mounted || _runId != myRun || !_playing || _nativeProgressSeen) {
            tm.cancel();
            return;
          }
          if (++simulatedWord < words.length) {
            _updateCursor(word: simulatedWord);
          } else {
            tm.cancel();
          }
        });

        final started = DateTime.now();
        await tts.setSpeechRate(_rate);
        await tts.speak(speakText);
        _fallbackWordTimer?.cancel();

        if (!mounted || _runId != myRun || !_playing) return;
        final sec = DateTime.now().difference(started).inSeconds.clamp(1, 45);
        await store.addListen(sec);

        _updateCursor(word: 0);
      }
    }

    if (mounted && _runId == myRun) {
      _updateCursor(playing: false, word: 0);
      await _saveCursor(notify: true);
    }
  }

  Future<void> _togglePlayPause() async {
    if (_playing) {
      await _pauseAudio();
    } else {
      await _playFromCurrent();
    }
  }

  Future<void> _seekTo(int pIdx, int sIdx,
      {int wIdx = 0, bool autoPlay = true}) async {
    _runId++;
    _fallbackWordTimer?.cancel();
    await tts.stop();
    _updateCursor(para: pIdx, sent: sIdx, word: wIdx, playing: false);
    await _saveCursor(notify: !autoPlay);
    _scrollToCurrent(force: !autoPlay);
    if (autoPlay) {
      await _playFromCurrent();
    }
  }

  Future<void> _stepSentence(int delta) async {
    final wasPlaying = _playing;
    _runId++;
    _fallbackWordTimer?.cancel();
    await tts.stop();
    final paras = widget.b.chapters[_chap].paragraphs;
    var p = _paraIdx;
    var s = _sentIdx + delta;

    while (true) {
      final sents = splitSentences(paras[p]);
      final isMedia =
          paras[p].startsWith('[[IMG:') || paras[p].startsWith('[[PDFPAGE:');
      if (!isMedia && s >= 0 && s < sents.length) {
        break;
      }
      if (delta < 0) {
        if (p <= 0) {
          p = 0;
          s = 0;
          break;
        }
        p--;
        final prevSents = splitSentences(paras[p]);
        s = prevSents.length - 1;
      } else {
        if (p >= paras.length - 1) {
          p = paras.length - 1;
          s = (splitSentences(paras[p]).length - 1).clamp(0, 999);
          break;
        }
        p++;
        s = 0;
      }
    }

    _updateCursor(para: p, sent: s, word: 0, playing: false);
    await _saveCursor(notify: !wasPlaying);
    _scrollToCurrent(force: true);
    if (wasPlaying) {
      await _playFromCurrent();
    } else {
      final sents = splitSentences(paras[p]);
      if (s < sents.length && !sents[s].startsWith('[[IMG:')) {
        await tts.setLanguage('fr-FR');
        await tts.setSpeechRate(_rate);
        await tts.speak(sents[s]);
      }
    }
  }

  void _showChapterVocab(BuildContext context) {
    final paras = widget.b.chapters[_chap].paragraphs;
    final found = <int, Word>{};
    for (final p in paras) {
      if (p.startsWith('[[')) continue;
      for (final m in wordRe.allMatches(p)) {
        final w = store.vocab.lookup(m.group(0)!);
        if (w != null) found[w.id] = w;
      }
    }
    final words = found.values.toList()
      ..sort((a, b) =>
          levels.indexOf(b.level).compareTo(levels.indexOf(a.level)));

    showModalBottomSheet(
      context: context,
      backgroundColor: T.bg,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final unsaved =
                words.where((w) => !store.cardIds.contains(w.id)).toList();
            return Padding(
              padding: const EdgeInsets.fromLTRB(T.s4, 0, T.s4, T.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Vocabulário do capítulo', style: T.title),
                          Text(
                              '${words.length} palavras identificadas · ${unsaved.length} novas',
                              style: T.caption),
                        ],
                      ),
                    ),
                    if (unsaved.isNotEmpty)
                      PillButton(
                        '+ Salvar nível ${store.level}',
                        color: T.lavender,
                        onTap: () async {
                          for (final w in unsaved
                              .where((w) => w.level == store.level)
                              .take(15)) {
                            await store.save(w, 'ebook');
                          }
                        },
                      ),
                  ]),
                  const SizedBox(height: T.s3),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: words.length,
                      itemBuilder: (_, i) {
                        final w = words[i];
                        final saved = store.cardIds.contains(w.id);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(w.lemma,
                              style:
                                  T.body.copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text(w.gloss,
                              style: T.secondary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LevelChip(w.level),
                              const SizedBox(width: T.s2),
                              IconButton(
                                icon: Icon(
                                  saved
                                      ? CupertinoIcons.checkmark_circle_fill
                                      : CupertinoIcons.plus_circle,
                                  color: saved ? T.mint : T.text,
                                ),
                                onPressed: () => saved
                                    ? store.removeCard(w)
                                    : store.save(w, 'ebook'),
                              ),
                            ],
                          ),
                          onTap: () =>
                              showWordSheet(context, w, source: 'ebook'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.b.chapters[_chap];
    final multi = widget.b.chapters.length > 1;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: T.bg,
        surfaceTintColor: Colors.transparent,
        title: Row(children: [
          LevelChip(widget.b.level),
          const SizedBox(width: T.s2),
          Expanded(
              child: Text(widget.b.title,
                  style: T.secondary, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(
            tooltip: _hidePt
                ? 'Mostrar todas as traduções PT-BR'
                : 'Modo imersão: ocultar PT-BR até tocar',
            icon: Icon(
              _hidePt ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
              color: T.text,
            ),
            onPressed: () => setState(() => _hidePt = !_hidePt),
          ),
          IconButton(
            tooltip: 'Vocabulário deste capítulo',
            icon: const Icon(CupertinoIcons.sparkles, color: T.text),
            onPressed: () => _showChapterVocab(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: (n) {
                _userDragging = n.direction != ScrollDirection.idle;
                return false;
              },
              child: ListView.builder(
                controller: _scrollCtrl,
                scrollCacheExtent: const ScrollCacheExtent.pixels(700),
                padding: const EdgeInsets.all(T.s4),
                itemCount: chapter.paragraphs.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.b.title, style: T.title),
                        if (multi) ...[
                          const SizedBox(height: T.s3),
                          GlassCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: T.s3, vertical: T.s2),
                            child: Row(children: [
                              IconButton(
                                icon: const Icon(CupertinoIcons.chevron_left,
                                    size: 18),
                                onPressed: _chap > 0
                                    ? () => _setChapter(_chap - 1)
                                    : null,
                              ),
                              Expanded(
                                child: Text(
                                  'Cap. ${_chap + 1}/${widget.b.chapters.length} · ${chapter.title}',
                                  style: T.body.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(CupertinoIcons.chevron_right,
                                    size: 18),
                                onPressed: _chap < widget.b.chapters.length - 1
                                    ? () => _setChapter(_chap + 1)
                                    : null,
                              ),
                            ]),
                          ),
                        ],
                        const SizedBox(height: T.s2),
                        Text(
                          'Tradução PT-BR abaixo de cada frase · Segure numa palavra para tocar a partir dela.',
                          style: T.caption,
                        ),
                        const SizedBox(height: T.s4),
                      ],
                    );
                  }
                  final i = index - 1;
                  final para = chapter.paragraphs[i];
                  return ValueListenableBuilder<PlayCursor>(
                    valueListenable: _cursor,
                    builder: (context, cur, _) {
                      final active = cur.para == i;
                      return BilingualParagraph(
                        para,
                        showAudio: true,
                        keyPrefix: 's_${_chap}_$i',
                        activeSentIdx: active ? cur.sent : null,
                        activeWordIdx: active ? cur.word : null,
                        isPlaying: active && cur.playing,
                        hidePt: _hidePt,
                        onTapSentenceAudio: (sIdx) =>
                            _seekTo(i, sIdx, autoPlay: true),
                        onLongPressWord: (sIdx, wIdx) =>
                            _seekTo(i, sIdx, wIdx: wIdx, autoPlay: true),
                        onTapWord: (t) async {
                          if (_playing) await _pauseAudio();
                          if (context.mounted) {
                            tapWordInContext(context, t, 'story');
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(T.s4, T.s2, T.s4, T.s3),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: T.s3, vertical: T.s2),
              child: ValueListenableBuilder<PlayCursor>(
                valueListenable: _cursor,
                builder: (_, cur, _) {
                  final (curPage, totalPages) =
                      bookPageInfo(widget.b, _chap, cur.para);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            'Página $curPage de $totalPages',
                            style: T.body.copyWith(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _seekTo(0, 0, autoPlay: false),
                          child: Text('Início ↺', style: T.caption),
                        ),
                      ]),
                      const SizedBox(height: T.s1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            tooltip: 'Voltar frase anterior',
                            icon: const Icon(CupertinoIcons.backward_end_fill,
                                color: T.text),
                            onPressed: () => _stepSentence(-1),
                          ),
                          IconButton.filled(
                            tooltip: cur.playing
                                ? 'Pausar nesta palavra'
                                : 'Continuar de onde parou',
                            style: IconButton.styleFrom(
                                backgroundColor:
                                    cur.playing ? T.rose : T.lavender),
                            iconSize: 28,
                            icon: Icon(
                              cur.playing
                                  ? CupertinoIcons.pause_fill
                                  : CupertinoIcons.play_fill,
                              color: T.text,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                          IconButton(
                            tooltip: 'Avançar próxima frase',
                            icon: const Icon(CupertinoIcons.forward_end_fill,
                                color: T.text),
                            onPressed: () => _stepSentence(1),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _rate = _rate == 0.45
                                  ? 0.58
                                  : (_rate == 0.58 ? 0.30 : 0.45);
                            }),
                            child: Text(
                              _rate == 0.30
                                  ? '0.75x 🐢'
                                  : (_rate == 0.58 ? '1.25x' : '1.0x'),
                              style: T.body.copyWith(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EpisodeScreen extends StatefulWidget {
  const EpisodeScreen(this.e, {super.key});
  final Episode e;

  @override
  State<EpisodeScreen> createState() => _EpisodeScreenState();
}

class _EpisodeScreenState extends State<EpisodeScreen> {
  final _player = AudioPlayer();
  late final Timer _tick;
  late final Future<List<String>> _transcript;
  double _speed = 1;

  @override
  void initState() {
    super.initState();
    _player.setUrl(widget.e.audio).then((_) => _player.play()).catchError((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao carregar o áudio.')));
      }
      return null;
    });
    // Listening time counts toward the daily goal.
    _tick = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_player.playing) store.addListen(10);
    });
    _transcript = widget.e.link.contains('rfi.fr')
        ? rfiTranscript(widget.e.link).catchError((_) => <String>[])
        : Future.value(<String>[]);
  }

  @override
  void dispose() {
    _tick.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: T.bg,
          surfaceTintColor: Colors.transparent,
          title: Text(widget.e.date, style: T.secondary),
        ),
        body: Column(children: [
          Expanded(
            child: FutureBuilder(
              future: _transcript,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                final ps = snap.data!;
                return ListenableBuilder(
                  listenable: store,
                  builder: (context, _) => ListView.builder(
                    padding: const EdgeInsets.all(T.s4),
                    itemCount: ps.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: T.s4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.e.title, style: T.title),
                              const SizedBox(height: T.s2),
                              Text(
                                  ps.isEmpty
                                      ? 'Sem transcrição para este episódio.'
                                      : 'Toque numa palavra para salvar · Tradução PT-BR após cada frase.',
                                  style: T.caption),
                            ],
                          ),
                        );
                      }
                      return BilingualParagraph(
                        ps[i - 1],
                        onTapWord: (t) =>
                            tapWordInContext(context, t, 'podcast'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(T.s4),
            child: GlassCard(child: _controls()),
          ),
        ]),
      );

  Widget _controls() => StreamBuilder(
        stream: _player.positionStream,
        builder: (_, _) {
          final pos = _player.position;
          final dur = _player.duration ?? Duration.zero;
          String fmt(Duration d) =>
              '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Slider(
              value: pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble(),
              max: dur.inMilliseconds.toDouble().clamp(1, double.infinity),
              activeColor: T.lavender,
              inactiveColor: T.hairline,
              onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
            ),
            Row(children: [
              Text(fmt(pos), style: T.caption),
              const Spacer(),
              IconButton(
                tooltip: 'Voltar 10 segundos',
                icon: const Icon(CupertinoIcons.gobackward_10, color: T.text),
                onPressed: () =>
                    _player.seek(pos - const Duration(seconds: 10)),
              ),
              IconButton.filled(
                tooltip: _player.playing ? 'Pausar' : 'Tocar',
                style: IconButton.styleFrom(backgroundColor: T.lavender),
                iconSize: 32,
                icon: Icon(
                    _player.playing
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    color: T.text),
                onPressed: () => setState(
                    () => _player.playing ? _player.pause() : _player.play()),
              ),
              IconButton(
                tooltip: 'Velocidade',
                icon: Text('${_speed}x',
                    style: T.body.copyWith(fontWeight: FontWeight.w600)),
                onPressed: () {
                  _speed = _speed == 1 ? 1.25 : (_speed == 1.25 ? 0.75 : 1);
                  _player.setSpeed(_speed);
                  setState(() {});
                },
              ),
              const Spacer(),
              Text(fmt(dur), style: T.caption),
            ]),
          ]);
        },
      );
}
