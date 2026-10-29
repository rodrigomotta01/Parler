import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../db.dart';
import '../main.dart';
import '../ui.dart';
import 'review.dart';

class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key});

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  String _q = '';
  String _level = store.level;

  List<Word> get _results {
    final words = store.vocab.words;
    if (_q.isEmpty) {
      if (_level == 'SAVED') {
        return words.where((w) => store.cardIds.contains(w.id)).toList();
      }
      return words.where((w) => w.level == _level).toList();
    }
    final q = _q.toLowerCase();
    final hit = store.vocab.lookup(q); // exact / inflected form first
    return [
      ?hit,
      ...words.where((w) =>
          w != hit &&
          (w.lemma.toLowerCase().startsWith(q) ||
              w.pt.toLowerCase().contains(q))),
    ].take(60).toList();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final rs = _results;
          return CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(T.s4),
              sliver: SliverList.list(children: [
                Text('Palavras', style: T.largeTitle),
                const SizedBox(height: T.s4),
                CommandBar(
                    hint: 'Buscar em francês ou português',
                    onChanged: (v) => setState(() => _q = v.trim())),
                const SizedBox(height: T.s4),
                if (_q.isEmpty)
                  SizedBox(
                    height: 64,
                    child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _savedTile(),
                          for (final l in levels) _levelTile(l),
                        ]),
                  ),
              ]),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(T.s4, 0, T.s4, 120),
              sliver: rs.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(T.s5),
                        child: Text(
                          _level == 'SAVED'
                              ? 'Nenhuma palavra salva ainda. Toque em palavras nos podcasts/ebooks ou adicione abaixo.'
                              : 'Nenhuma palavra encontrada.',
                          style: T.secondary,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : SliverList.builder(
                      itemCount: rs.length,
                      itemBuilder: (_, i) => _row(context, rs[i]),
                    ),
            ),
          ]);
        },
      );

  Widget _savedTile() => Padding(
        padding: const EdgeInsets.only(right: T.s2),
        child: GestureDetector(
          onTap: () => setState(() => _level = 'SAVED'),
          child: AnimatedContainer(
            duration: T.fast,
            width: 112,
            padding: const EdgeInsets.all(T.s2),
            decoration: BoxDecoration(
              color: _level == 'SAVED' ? T.lavender : T.surface,
              borderRadius: BorderRadius.circular(T.rMd),
              border: Border.all(color: T.hairline, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('★ Baralho',
                    style: T.body.copyWith(fontWeight: FontWeight.w600)),
                Text('${store.cardIds.length} salvas', style: T.caption),
              ],
            ),
          ),
        ),
      );

  Widget _levelTile(String l) => Padding(
        padding: const EdgeInsets.only(right: T.s2),
        child: GestureDetector(
          onTap: () => setState(() => _level = l),
          child: AnimatedContainer(
            duration: T.fast,
            width: 88,
            padding: const EdgeInsets.all(T.s2),
            decoration: BoxDecoration(
              color: _level == l ? T.level(l) : T.surface,
              borderRadius: BorderRadius.circular(T.rMd),
              border: Border.all(color: T.hairline, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l, style: T.body.copyWith(fontWeight: FontWeight.w600)),
                Text('${(store.learned(l) * 100).round()}% visto',
                    style: T.caption),
              ],
            ),
          ),
        ),
      );

  Widget _row(BuildContext context, Word w) => InkWell(
        onTap: () => showWordSheet(context, w),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: T.s3),
          decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: T.hairline, width: 0.5))),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.lemma,
                      style: T.body.copyWith(fontWeight: FontWeight.w600)),
                  Text(w.gloss,
                      style: T.secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (store.cardIds.contains(w.id))
              const Padding(
                padding: EdgeInsets.only(right: T.s2),
                child: Icon(CupertinoIcons.checkmark_circle_fill,
                    size: 18, color: T.mint),
              ),
            LevelChip(w.level),
          ]),
        ),
      );
}

/// Bottom sheet for a word: meaning, audio, save/remove in deck.
Future<void> showWordSheet(BuildContext context, Word w,
    {String source = 'manual'}) {
  speakFr(w.lemma);
  return showModalBottomSheet(
    context: context,
    backgroundColor: T.bg,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final saved = store.cardIds.contains(w.id);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(T.s5, 0, T.s5, T.s5),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                LevelChip(w.level),
                const SizedBox(width: T.s2),
                Text(w.pos, style: T.caption),
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
              Text(w.lemma, style: T.largeTitle),
              if (w.ipa.isNotEmpty) Text(w.ipa, style: T.secondary),
              const SizedBox(height: T.s4),
              Flexible(child: SingleChildScrollView(child: WordDetails(w))),
              const SizedBox(height: T.s5),
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  saved
                      ? 'No baralho (toque para remover)'
                      : 'Adicionar ao baralho',
                  icon: saved
                      ? CupertinoIcons.checkmark_alt
                      : CupertinoIcons.plus,
                  color: saved ? T.mint : T.lavender,
                  onTap: () =>
                      saved ? store.removeCard(w) : store.save(w, source),
                ),
              ),
            ]),
          ),
        );
      },
    ),
  );
}
