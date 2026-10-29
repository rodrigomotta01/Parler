import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../db.dart';
import '../main.dart';
import '../srs.dart';
import '../ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final today = store.today;
          final s = store.streakDays;
          final gRev = store.goalRev;
          final gMin = store.goalListenMin;
          return ListView(
            padding: const EdgeInsets.fromLTRB(T.s4, T.s4, T.s4, 120),
            children: [
              Row(children: [
                Expanded(child: Text('Hoje', style: T.largeTitle)),
                IconButton(
                  tooltip: 'Ajustes',
                  icon: const Icon(CupertinoIcons.slider_horizontal_3,
                      color: T.text),
                  onPressed: () => _settings(context),
                ),
              ]),
              const SizedBox(height: T.s4),
              GlassCard(
                padding: const EdgeInsets.all(T.s5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ring('Ofensiva', store.todayMet ? 1 : 0, T.peach, '🔥',
                        '$s ${s == 1 ? 'dia' : 'dias'}'),
                    _ring(
                        'Meta diária',
                        store.todayProgress,
                        T.lavender,
                        '${today?.reviews ?? 0}/$gRev',
                        '${(today?.listenSec ?? 0) ~/ 60}/$gMin min'),
                  ],
                ),
              ),
              const SizedBox(height: T.s3),
              GestureDetector(
                onTap: () => _settings(context),
                child: Text(
                  store.todayMet
                      ? 'Meta de hoje cumprida. Bravo !'
                      : 'Meta: $gRev revisões ou $gMin min de áudio (toque para alterar).',
                  style: T.secondary,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: T.s5),
              Row(children: [
                Expanded(
                  child: PillButton('Revisar',
                      icon: CupertinoIcons.rectangle_stack,
                      onTap: () => Shell.tab.value = 1),
                ),
                const SizedBox(width: T.s3),
                Expanded(
                  child: PillButton('Ouvir / Ler',
                      icon: CupertinoIcons.headphones,
                      color: T.sky,
                      onTap: () => Shell.tab.value = 2),
                ),
              ]),
              const SizedBox(height: T.s5),
              Row(children: [
                Expanded(child: Text('Atividade diária', style: T.title)),
                Text(
                  '${store.days.values.where((d) => metGoal(d, goalRev: gRev, goalSec: store.goalSec)).length} metas batidas',
                  style: T.caption,
                ),
              ]),
              const SizedBox(height: T.s3),
              GlassCard(child: _githubContributionsHeatmap(store.days)),
            ],
          );
        },
      );

  Widget _ring(String label, double v, Color c, String big, String small) =>
      Column(children: [
        StatRing(
          value: v,
          color: c,
          center: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(big, style: T.title),
            Text(small, style: T.caption),
          ]),
        ),
        const SizedBox(height: T.s2),
        Text(label, style: T.secondary),
      ]);

  /// GitHub-style daily contributions heatmap (12 weeks, weekdays label on left, months on top).
  Widget _githubContributionsHeatmap(Map<String, Day> days) {
    final now = DateTime.now();
    final todayKey = dayKey(now);
    // 12 weeks = 84 days. Start on Monday.
    final start =
        DateTime(now.year, now.month, now.day - 83 - (now.weekday - 1));

    String monthLabel(int m) => switch (m) {
          1 => 'Jan',
          2 => 'Fev',
          3 => 'Mar',
          4 => 'Abr',
          5 => 'Mai',
          6 => 'Jun',
          7 => 'Jul',
          8 => 'Ago',
          9 => 'Set',
          10 => 'Out',
          11 => 'Nov',
          _ => 'Dez',
        };

    final selected = _selectedDay;
    final selectedDayData = selected != null ? days[dayKey(selected)] : null;
    final selectedMet = selected != null &&
        metGoal(selectedDayData,
            goalRev: store.goalRev, goalSec: store.goalSec);

    return LayoutBuilder(builder: (_, c) {
      const leftPad = 26.0;
      final availableWidth = c.maxWidth - leftPad;
      final size = (availableWidth - 11 * 3.5) / 12;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month labels row
          Row(children: [
            const SizedBox(width: leftPad),
            for (var w = 0; w < 12; w++)
              SizedBox(
                width: size + (w < 11 ? 3.5 : 0),
                child: Builder(builder: (_) {
                  final colDate =
                      DateTime(start.year, start.month, start.day + w * 7);
                  // Show month label on first week or when month changes
                  final show = w == 0 ||
                      colDate.month !=
                          DateTime(start.year, start.month,
                                  start.day + (w - 1) * 7)
                              .month;
                  return show
                      ? Text(monthLabel(colDate.month),
                          style: const TextStyle(
                              fontSize: 10,
                              color: T.textMuted,
                              fontWeight: FontWeight.w600))
                      : const SizedBox.shrink();
                }),
              ),
          ]),
          const SizedBox(height: 4),

          // Main matrix: Weekdays on left + 12 week columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weekday labels
              SizedBox(
                width: leftPad,
                height: 7 * (size + 3.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Seg',
                        style: TextStyle(fontSize: 9, color: T.textMuted)),
                    Text('Qua',
                        style: TextStyle(fontSize: 9, color: T.textMuted)),
                    Text('Sex',
                        style: TextStyle(fontSize: 9, color: T.textMuted)),
                    Text('Dom',
                        style: TextStyle(fontSize: 9, color: T.textMuted)),
                  ],
                ),
              ),

              // 12 columns
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var w = 0; w < 12; w++)
                      Column(children: [
                        for (var d = 0; d < 7; d++)
                          Builder(builder: (_) {
                            final day = DateTime(start.year, start.month,
                                start.day + w * 7 + d);
                            final k = dayKey(day);
                            final a = days[k];
                            final isFuture = day.isAfter(now);
                            final isToday = k == todayKey;
                            final isSel = selected != null && dayKey(selected) == k;
                            final isMet = metGoal(a,
                                goalRev: store.goalRev,
                                goalSec: store.goalSec);
                            final revs = a?.reviews ?? 0;
                            final mins = (a?.listenSec ?? 0) ~/ 60;
                            final isDouble = revs >= store.goalRev * 2 ||
                                (a?.listenSec ?? 0) >= store.goalSec * 2;

                            // GitHub contribution color scale
                            final color = isFuture
                                ? Colors.transparent
                                : isDouble
                                    ? const Color(0xFF216E39) // Deep green (2x goal)
                                    : isMet
                                        ? const Color(0xFF2DA44E) // Bright GitHub green (Met goal)
                                        : (revs > 0 || mins > 0)
                                            ? const Color(0xFF9BE9A8) // Light green (some study)
                                            : const Color(0xFFEBEDF0); // Light neutral gray

                            return GestureDetector(
                              onTap: isFuture
                                  ? null
                                  : () => setState(() => _selectedDay = day),
                              child: Container(
                                width: size,
                                height: size,
                                margin: const EdgeInsets.only(bottom: 3.5),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(3),
                                  border: isToday
                                      ? Border.all(
                                          color: const Color(0xFF1C1C1E),
                                          width: 1.5)
                                      : (isSel
                                          ? Border.all(
                                              color: T.lavender, width: 1.5)
                                          : null),
                                ),
                              ),
                            );
                          }),
                      ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: T.s3),

          // Selected day details or prompt
          Container(
            padding: const EdgeInsets.symmetric(horizontal: T.s3, vertical: T.s2),
            decoration: BoxDecoration(
              color: T.bg,
              borderRadius: BorderRadius.circular(T.rSm),
              border: Border.all(color: T.hairline, width: 0.5),
            ),
            child: Row(children: [
              if (selected != null) ...[
                Icon(
                  selectedMet
                      ? CupertinoIcons.checkmark_seal_fill
                      : CupertinoIcons.circle,
                  size: 16,
                  color: selectedMet
                      ? const Color(0xFF2DA44E)
                      : T.textMuted,
                ),
                const SizedBox(width: T.s2),
                Expanded(
                  child: Text(
                    '${selected.day.toString().padLeft(2, '0')}/${selected.month.toString().padLeft(2, '0')}: '
                    '${selectedDayData?.reviews ?? 0} revisões, '
                    '${(selectedDayData?.listenSec ?? 0) ~/ 60} min — '
                    '${selectedMet ? 'Meta concluída 🎉' : 'Meta não atingida'}',
                    style: T.caption.copyWith(color: T.text),
                  ),
                ),
              ] else
                Expanded(
                  child: Text(
                    'Toque num quadrado para ver o histórico do dia.',
                    style: T.caption,
                  ),
                ),
              // Legend
              Row(children: [
                Text('Menos', style: TextStyle(fontSize: 9, color: T.textMuted)),
                const SizedBox(width: 3),
                _legendSquare(const Color(0xFFEBEDF0)),
                _legendSquare(const Color(0xFF9BE9A8)),
                _legendSquare(const Color(0xFF2DA44E)),
                _legendSquare(const Color(0xFF216E39)),
                const SizedBox(width: 3),
                Text('Mais', style: TextStyle(fontSize: 9, color: T.textMuted)),
              ]),
            ]),
          ),
        ],
      );
    });
  }

  Widget _legendSquare(Color c) => Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(1.5)),
      );

  void _settings(BuildContext context) => showModalBottomSheet(
        context: context,
        backgroundColor: T.bg,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => ListenableBuilder(
          listenable: store,
          builder: (_, _) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(T.s4, 0, T.s4, T.s5),
              children: [
                Text('Ajustes e Metas', style: T.title),
                const SizedBox(height: T.s4),
                Text('Nível das palavras novas', style: T.secondary),
                const SizedBox(height: T.s2),
                Wrap(spacing: T.s2, children: [
                  for (final l in levels)
                    ChoiceChip(
                      label: Text(l),
                      selected: store.level == l,
                      selectedColor: T.level(l),
                      onSelected: (_) => store.set('level', l),
                    ),
                ]),
                const SizedBox(height: T.s4),
                _stepper('Meta diária (revisões)', store.goalRev, 5, 100, 5,
                    (v) => store.set('goalRev', '$v')),
                _stepper('Meta diária (min de áudio)', store.goalListenMin, 5,
                    60, 5, (v) => store.set('goalListenMin', '$v')),
                _stepper('Palavras novas por dia', store.newPerDay, 0, 50, 5,
                    (v) => store.set('newPerDay', '$v')),
                _stepper('Lembrete diário (hora)', store.reminderHour, 0, 23, 1,
                    (v) async {
                  await store.set('reminderHour', '$v');
                  scheduleReminder();
                }),
                const SizedBox(height: T.s2),
                Row(children: [
                  Expanded(
                      child: Text('Congelamento de ofensiva (1x/sem)',
                          style: T.body)),
                  CupertinoSwitch(
                    value: store.freeze,
                    activeTrackColor: T.lavender,
                    onChanged: (v) => store.set('freeze', '$v'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );

  Widget _stepper(String label, int v, int min, int max, int step,
          ValueChanged<int> set) =>
      Row(children: [
        Expanded(child: Text(label, style: T.body)),
        IconButton(
            tooltip: 'Menos',
            icon: const Icon(CupertinoIcons.minus_circle),
            onPressed: v - step < min ? null : () => set(v - step)),
        SizedBox(
            width: 36,
            child: Text('$v', style: T.body, textAlign: TextAlign.center)),
        IconButton(
            tooltip: 'Mais',
            icon: const Icon(CupertinoIcons.plus_circle),
            onPressed: v + step > max ? null : () => set(v + step)),
      ]);
}
