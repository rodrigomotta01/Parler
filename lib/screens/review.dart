import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../db.dart';
import '../main.dart';
import '../srs.dart';
import '../ui.dart';

final tts = FlutterTts()
  ..setLanguage('fr-FR')
  ..setSpeechRate(0.45);

Future<void> speakFr(String text, {bool slow = false}) async {
  await tts.setSpeechRate(slow ? 0.30 : 0.45);
  await tts.speak(text);
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _mode = 0; // 0 = Cartas (FSRS), 1 = Ditado, 2 = Áudio, 3 = Frases (Cloze)
  List<Word>? _queue;
  bool _revealed = false;
  Map<Rating, DateTime> _preview = {};
  int _done = 0;

  @override
  void initState() {
    super.initState();
    store.queue().then((q) {
      setState(() => _queue = q);
      _show();
    });
  }

  Future<void> _show() async {
    if (_queue == null || _queue!.isEmpty) return;
    final w = _queue!.first;
    speakFr(w.lemma);
    final p = await store.preview(w);
    if (mounted) {
      setState(() {
        _preview = p;
        _revealed = false;
      });
    }
  }

  Future<void> _rate(Rating r) async {
    final w = _queue!.removeAt(0);
    final due = await store.rate(w, r);
    // Short relearning steps come back in this same session.
    if (due.isBefore(DateTime.now().add(const Duration(minutes: 20)))) {
      _queue!.add(w);
    }
    setState(() => _done++);
    _show();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(T.s4, T.s4, T.s4, 110),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text('Revisar', style: T.largeTitle)),
            if (_mode == 0 && _queue != null)
              Text('${_queue!.length} na fila', style: T.secondary),
          ]),
          const SizedBox(height: T.s3),
          Row(children: [
            for (final (i, label) in [
              (0, 'Cartas'),
              (1, 'Ditado'),
              (2, 'Áudio'),
              (3, 'Frases'),
            ])
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 3 ? T.s2 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _mode = i),
                    child: AnimatedContainer(
                      duration: T.fast,
                      padding: const EdgeInsets.symmetric(vertical: T.s2),
                      decoration: BoxDecoration(
                        color: _mode == i ? T.lavender : T.surface,
                        borderRadius: BorderRadius.circular(T.rMd),
                        border: Border.all(color: T.hairline, width: 0.5),
                      ),
                      child: Text(label,
                          style: T.body.copyWith(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: T.s4),
          Expanded(
            child: switch (_mode) {
              0 => _cardsView(),
              1 => const _DictationChallenge(),
              2 => const _ListeningQuiz(),
              _ => const _ClozeChallenge(),
            },
          ),
        ]),
      );

  Widget _cardsView() {
    final q = _queue;
    if (q == null) return const Center(child: CupertinoActivityIndicator());
    if (q.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎉', style: TextStyle(fontSize: 56)),
          const SizedBox(height: T.s3),
          Text('Tudo revisado', style: T.title),
          const SizedBox(height: T.s2),
          Text(
              _done > 0
                  ? '$_done revisões nesta sessão. Pratique Ditado, Áudio, Frases ou leia um Ebook.'
                  : 'Nada para revisar agora.',
              style: T.secondary,
              textAlign: TextAlign.center),
          const SizedBox(height: T.s5),
          PillButton('Praticar Frases',
              icon: CupertinoIcons.text_quote,
              onTap: () => setState(() => _mode = 3)),
        ]),
      );
    }
    final w = q.first;
    final isNew = !store.cardIds.contains(w.id);
    return Column(children: [
      Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _revealed = true),
          child: GlassCard(
            padding: const EdgeInsets.all(T.s5),
            child: SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                child: Column(children: [
                  Row(children: [
                    LevelChip(w.level),
                    const SizedBox(width: T.s2),
                    if (isNew) Text('nova', style: T.caption),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Ouvir devagar',
                      icon: const Icon(CupertinoIcons.tortoise, color: T.text),
                      onPressed: () => speakFr(w.lemma, slow: true),
                    ),
                    IconButton(
                      tooltip: 'Ouvir',
                      icon: const Icon(CupertinoIcons.speaker_2, color: T.text),
                      onPressed: () => speakFr(w.lemma),
                    ),
                  ]),
                  const SizedBox(height: T.s4),
                  Text(w.lemma,
                      style: T.largeTitle.copyWith(fontSize: 40),
                      textAlign: TextAlign.center),
                  if (w.ipa.isNotEmpty) Text(w.ipa, style: T.secondary),
                  const SizedBox(height: T.s4),
                  AnimatedSwitcher(
                    duration: T.fast,
                    child: _revealed
                        ? WordDetails(w, key: ValueKey(w.id))
                        : Text('Toque para ver o significado e exemplo',
                            style: T.caption),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: T.s4),
      AnimatedOpacity(
        duration: T.fast,
        opacity: _revealed ? 1 : 0,
        child: IgnorePointer(
          ignoring: !_revealed,
          child: Row(children: [
            for (final (r, label, color) in const [
              (Rating.again, 'De novo', T.rose),
              (Rating.hard, 'Difícil', T.peach),
              (Rating.good, 'Bom', T.lavender),
              (Rating.easy, 'Fácil', T.mint),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: T.s1),
                  child: _RateButton(
                    label: label,
                    sub: _preview[r] == null
                        ? ''
                        : interval(_preview[r]!, DateTime.now()),
                    color: color,
                    onTap: () => _rate(r),
                  ),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton(
      {required this.label,
      required this.sub,
      required this.color,
      required this.onTap});
  final String label, sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$label, próxima em $sub',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: T.s3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(T.rMd),
              border: Border.all(color: T.hairline, width: 0.5),
            ),
            child: Column(children: [
              Text(label,
                  style: T.body
                      .copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
              Text(sub, style: T.caption.copyWith(color: T.text)),
            ]),
          ),
        ),
      );
}

/// Meaning (100% PT-BR) + Bilingual Description (PT-BR + FR) + Bilingual Example (FR + PT-BR).
class WordDetails extends StatelessWidget {
  const WordDetails(this.w, {super.key});
  final Word w;

  Widget _highlightFrench(String ex) {
    final spans = <TextSpan>[];
    final parts = RegExp(r"([a-zA-ZÀ-ÖØ-öø-ÿ'-]+|[^a-zA-ZÀ-ÖØ-öø-ÿ'-]+)").allMatches(ex);
    for (final m in parts) {
      final t = m.group(0)!;
      final clean = t.toLowerCase();
      final isMatch = clean == w.lemma.toLowerCase() ||
          store.vocab.lookup(clean)?.id == w.id ||
          (clean.length >= 4 && clean.startsWith(w.lemma.toLowerCase().substring(0, min(w.lemma.length, 4))));
      spans.add(TextSpan(
        text: t,
        style: TextStyle(
          fontStyle: FontStyle.italic,
          fontWeight: isMatch ? FontWeight.w800 : FontWeight.w400,
          color: T.text,
          backgroundColor: isMatch ? T.butter : null,
        ),
      ));
    }
    return Text.rich(
      TextSpan(children: [
        const TextSpan(text: '« ', style: TextStyle(fontStyle: FontStyle.italic)),
        ...spans,
        const TextSpan(text: ' »', style: TextStyle(fontStyle: FontStyle.italic)),
      ]),
      textAlign: TextAlign.center,
      style: T.body,
    );
  }

  Widget _highlightPortuguese(String pt) {
    final stems = w.gloss
        .toLowerCase()
        .split(RegExp(r'[,;/]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .expand((s) => s.split(' '))
        .map((s) => s.replaceAll(RegExp(r'[^a-zA-ZÀ-ÖØ-öø-ÿ]'), ''))
        .where((s) => s.length >= 3)
        .map((s) => s.substring(0, min(s.length, 4)))
        .toSet();

    final spans = <TextSpan>[];
    final parts = RegExp(r"([a-zA-ZÀ-ÖØ-öø-ÿ'-]+|[^a-zA-ZÀ-ÖØ-öø-ÿ'-]+)").allMatches(pt);
    for (final m in parts) {
      final t = m.group(0)!;
      final clean = t.toLowerCase();
      final isMatch = stems.any((stem) => clean.startsWith(stem));
      spans.add(TextSpan(
        text: t,
        style: TextStyle(
          fontWeight: isMatch ? FontWeight.w800 : FontWeight.w400,
          color: T.text,
          backgroundColor: isMatch ? T.butter : null,
        ),
      ));
    }
    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.center,
      style: T.secondary.copyWith(color: T.text),
    );
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(w.gloss, style: T.title, textAlign: TextAlign.center),
        if (w.def.isNotEmpty && w.def != w.gloss) ...[
          const SizedBox(height: T.s2),
          FutureBuilder<String>(
            future: store.translate(w.def),
            builder: (_, snap) {
              final defPt = snap.data ?? '';
              return Column(children: [
                if (defPt.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: T.s1),
                    child: Text(
                      defPt,
                      style: T.secondary.copyWith(color: T.text),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Text(
                  'FR · ${w.def}',
                  style: T.caption.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ]);
            },
          ),
        ],
        if (w.ex.isNotEmpty) ...[
          const SizedBox(height: T.s4),
          GestureDetector(
            onTap: () => speakFr(w.ex),
            child: Container(
              padding: const EdgeInsets.all(T.s3),
              decoration: BoxDecoration(
                color: T.lavender.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(T.rMd),
                border: Border.all(color: T.hairline, width: 0.5),
              ),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.speaker_2,
                        size: 16, color: T.textMuted),
                    const SizedBox(width: T.s1),
                    Text('Exemplo em francês (toque para ouvir)',
                        style: T.caption),
                  ],
                ),
                const SizedBox(height: T.s2),
                _highlightFrench(w.ex),
                FutureBuilder<String>(
                  future: store.translate(w.ex),
                  builder: (_, snap) {
                    final pt = snap.data ?? '';
                    if (pt.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: T.s2),
                      child: _highlightPortuguese(pt),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ]);
}

/// Audio Challenge 1: Dictation (Dictée).
class _DictationChallenge extends StatefulWidget {
  const _DictationChallenge();

  @override
  State<_DictationChallenge> createState() => _DictationChallengeState();
}

class _DictationChallengeState extends State<_DictationChallenge> {
  final _ctrl = TextEditingController();
  final _rng = Random();
  late Word _w;
  bool? _ok;

  @override
  void initState() {
    super.initState();
    _next();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    final pool = store.vocab.words
        .where((w) => w.level == store.level && w.pt.isNotEmpty)
        .toList();
    _w = pool[_rng.nextInt(pool.length)];
    _ctrl.clear();
    _ok = null;
    setState(() {});
    speakFr(_w.lemma);
  }

  void _check() {
    if (_ok != null) {
      _next();
      return;
    }
    final ok = _ctrl.text.trim().toLowerCase() == _w.lemma.toLowerCase();
    store.addReview(1);
    setState(() => _ok = ok);
  }

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(T.s5),
        child: SingleChildScrollView(
          child: Column(children: [
            Row(children: [
              LevelChip(_w.level),
              const SizedBox(width: T.s2),
              Text('Ditado em francês', style: T.caption),
              const Spacer(),
              IconButton(
                tooltip: 'Ouvir devagar',
                icon: const Icon(CupertinoIcons.tortoise, color: T.text),
                onPressed: () => speakFr(_w.lemma, slow: true),
              ),
              IconButton(
                tooltip: 'Ouvir normal',
                icon: const Icon(CupertinoIcons.speaker_2, color: T.text),
                onPressed: () => speakFr(_w.lemma),
              ),
            ]),
            const SizedBox(height: T.s4),
            Text('Ouça a palavra e digite em francês:', style: T.secondary),
            const SizedBox(height: T.s3),
            TextField(
              controller: _ctrl,
              autocorrect: false,
              textAlign: TextAlign.center,
              style: T.title,
              onSubmitted: (_) => _check(),
              decoration: InputDecoration(
                hintText: 'Digite aqui…',
                filled: true,
                fillColor: T.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(T.rMd),
                  borderSide: const BorderSide(color: T.hairline),
                ),
              ),
            ),
            const SizedBox(height: T.s4),
            if (_ok != null) ...[
              Container(
                padding: const EdgeInsets.all(T.s3),
                decoration: BoxDecoration(
                  color: _ok! ? T.mint : T.rose,
                  borderRadius: BorderRadius.circular(T.rMd),
                ),
                child: Column(children: [
                  Text(_ok! ? 'Correto! 🎉' : 'Resposta: ${_w.lemma}',
                      style: T.title),
                  if (_w.ipa.isNotEmpty) Text(_w.ipa, style: T.secondary),
                  const SizedBox(height: T.s2),
                  WordDetails(_w),
                ]),
              ),
              const SizedBox(height: T.s4),
            ],
            SizedBox(
              width: double.infinity,
              child: PillButton(
                _ok == null ? 'Verificar' : 'Próxima palavra',
                color: _ok == null ? T.lavender : T.mint,
                onTap: _check,
              ),
            ),
          ]),
        ),
      );
}

/// Audio Challenge 2: Oral Comprehension Quiz.
class _ListeningQuiz extends StatefulWidget {
  const _ListeningQuiz();

  @override
  State<_ListeningQuiz> createState() => _ListeningQuizState();
}

class _ListeningQuizState extends State<_ListeningQuiz> {
  final _rng = Random();
  late Word _target;
  late List<Word> _options;
  int? _picked;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    final pool = store.vocab.words
        .where((w) => w.level == store.level && w.pt.isNotEmpty)
        .toList();
    _target = pool[_rng.nextInt(pool.length)];
    final opts = <Word>{_target};
    while (opts.length < 4) {
      opts.add(pool[_rng.nextInt(pool.length)]);
    }
    _options = opts.toList()..shuffle(_rng);
    _picked = null;
    setState(() {});
    speakFr(_target.ex.isNotEmpty ? _target.ex : _target.lemma);
  }

  @override
  Widget build(BuildContext context) {
    final phrase = _target.ex.isNotEmpty ? _target.ex : _target.lemma;
    return GlassCard(
      padding: const EdgeInsets.all(T.s5),
      child: SingleChildScrollView(
        child: Column(children: [
          Row(children: [
            LevelChip(_target.level),
            const SizedBox(width: T.s2),
            Text('Compreensão oral', style: T.caption),
            const Spacer(),
            IconButton(
              tooltip: 'Ouvir devagar',
              icon: const Icon(CupertinoIcons.tortoise, color: T.text),
              onPressed: () => speakFr(phrase, slow: true),
            ),
            IconButton(
              tooltip: 'Ouvir novamente',
              icon: const Icon(CupertinoIcons.speaker_2, color: T.text),
              onPressed: () => speakFr(phrase),
            ),
          ]),
          const SizedBox(height: T.s3),
          Text('Qual palavra/significado você ouviu?', style: T.secondary),
          const SizedBox(height: T.s3),
          for (final (i, opt) in _options.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: T.s2),
              child: SizedBox(
                width: double.infinity,
                child: PillButton(
                  '${opt.lemma} — ${opt.gloss}',
                  color: _picked == null
                      ? T.sky.withValues(alpha: 0.5)
                      : (opt == _target
                          ? T.mint
                          : (_picked == i ? T.rose : T.surface)),
                  onTap: _picked != null
                      ? null
                      : () {
                          store.addReview(1);
                          setState(() => _picked = i);
                        },
                ),
              ),
            ),
          if (_picked != null) ...[
            const SizedBox(height: T.s3),
            WordDetails(_target),
            const SizedBox(height: T.s4),
            SizedBox(
              width: double.infinity,
              child: PillButton('Próximo áudio',
                  color: T.lavender, onTap: _next),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Pre-Phase 3 Challenge 3: Cloze / Fill-in-the-blank in real French sentences.
class _ClozeChallenge extends StatefulWidget {
  const _ClozeChallenge();

  @override
  State<_ClozeChallenge> createState() => _ClozeChallengeState();
}

class _ClozeChallengeState extends State<_ClozeChallenge> {
  final _rng = Random();
  late Word _target;
  late String _masked;
  late List<Word> _options;
  int? _picked;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    final pool = store.vocab.words
        .where((w) =>
            w.level == store.level &&
            w.ex.isNotEmpty &&
            w.ex.toLowerCase().contains(w.lemma.toLowerCase()))
        .toList();
    final activePool = pool.isNotEmpty
        ? pool
        : store.vocab.words.where((w) => w.ex.isNotEmpty).toList();
    _target = activePool[_rng.nextInt(activePool.length)];
    final re = RegExp(RegExp.escape(_target.lemma), caseSensitive: false);
    _masked = _target.ex.replaceFirst(re, '______');
    final opts = <Word>{_target};
    while (opts.length < 4) {
      opts.add(activePool[_rng.nextInt(activePool.length)]);
    }
    _options = opts.toList()..shuffle(_rng);
    _picked = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(T.s5),
        child: SingleChildScrollView(
          child: Column(children: [
            Row(children: [
              LevelChip(_target.level),
              const SizedBox(width: T.s2),
              Text('Completar frase', style: T.caption),
              const Spacer(),
              IconButton(
                tooltip: 'Ouvir frase completa',
                icon: const Icon(CupertinoIcons.speaker_2, color: T.text),
                onPressed: () => speakFr(_target.ex),
              ),
            ]),
            const SizedBox(height: T.s3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(T.s3),
              decoration: BoxDecoration(
                color: T.lavender.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(T.rMd),
                border: Border.all(color: T.hairline, width: 0.5),
              ),
              child: Column(children: [
                Text(
                  '« ${_picked == null ? _masked : _target.ex} »',
                  style: T.body
                      .copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                FutureBuilder<String>(
                  future: store.translate(_target.ex),
                  builder: (_, snap) {
                    final pt = snap.data ?? '';
                    if (pt.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: T.s2),
                      child: Text(pt,
                          style: T.secondary, textAlign: TextAlign.center),
                    );
                  },
                ),
              ]),
            ),
            const SizedBox(height: T.s3),
            Text('Dica (PT-BR): ${_target.gloss}', style: T.caption),
            const SizedBox(height: T.s3),
            for (final (i, opt) in _options.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: T.s2),
                child: SizedBox(
                  width: double.infinity,
                  child: PillButton(
                    opt.lemma,
                    color: _picked == null
                        ? T.sky.withValues(alpha: 0.5)
                        : (opt == _target
                            ? T.mint
                            : (_picked == i ? T.rose : T.surface)),
                    onTap: _picked != null
                        ? null
                        : () {
                            store.addReview(1);
                            speakFr(_target.ex);
                            setState(() => _picked = i);
                          },
                  ),
                ),
              ),
            if (_picked != null) ...[
              const SizedBox(height: T.s3),
              WordDetails(_target),
              const SizedBox(height: T.s4),
              SizedBox(
                width: double.infinity,
                child: PillButton('Próxima frase',
                    color: T.lavender, onTap: _next),
              ),
            ],
          ]),
        ),
      );
}
