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
                Expanded(child: Text('Calendário de atividade', style: T.title)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: T.s2, vertical: 3),
                  decoration: BoxDecoration(
                    color: T.sky,
                    borderRadius: BorderRadius.circular(T.rSm),
                  ),
                  child: Text(
                    '${store.days.values.where((d) => d.reviews > 0 || d.listenSec > 0).length} dias ativos',
                    style: T.caption.copyWith(
                        color: T.text, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
              const SizedBox(height: T.s3),
              GlassCard(
                padding: const EdgeInsets.all(T.s4),
                child: _activityCalendar(store.days),
              ),
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

  /// Expanded 5-week common calendar view (Seg..Dom columns x 5 week rows, blue scale, live Today).
  Widget _activityCalendar(Map<String, Day> days) {
    final now = DateTime.now();
    final todayUtc = DateTime.utc(now.year, now.month, now.day);
    final todayKey = dayKey(todayUtc);

    final thisMonday =
        todayUtc.subtract(Duration(days: todayUtc.weekday - 1));
    const numWeeks = 5;
    final start =
        thisMonday.subtract(const Duration(days: (numWeeks - 1) * 7));

    final inspected = _selectedDay ?? todayUtc;
    final inspectedKey = dayKey(inspected);
    final inspectedData = days[inspectedKey];
    final inRevs = inspectedData?.reviews ?? 0;
    final inSecs = inspectedData?.listenSec ?? 0;
    final inActive = inRevs > 0 || inSecs > 0;
    final inMet =
        metGoal(inspectedData, goalRev: store.goalRev, goalSec: store.goalSec);
    final isInspectingToday = inspectedKey == todayKey;

    String fmtListen(int s) =>
        s == 0 ? '0 min' : (s < 60 ? '${s}s' : '${s ~/ 60} min');

    String monthName(int m) => switch (m) {
          1 => 'Janeiro',
          2 => 'Fevereiro',
          3 => 'Março',
          4 => 'Abril',
          5 => 'Maio',
          6 => 'Junho',
          7 => 'Julho',
          8 => 'Agosto',
          9 => 'Setembro',
          10 => 'Outubro',
          11 => 'Novembro',
          _ => 'Dezembro',
        };

    const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final periodLabel = start.month == todayUtc.month
        ? '${monthName(todayUtc.month)} ${todayUtc.year}'
        : '${monthName(start.month)} – ${monthName(todayUtc.month)} ${todayUtc.year}';

    final metCount = days.entries.where((e) {
      return metGoal(e.value, goalRev: store.goalRev, goalSec: store.goalSec);
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Calendar top bar: Month range + total goals met
        Row(children: [
          const Icon(CupertinoIcons.calendar, size: 17, color: T.text),
          const SizedBox(width: T.s2),
          Expanded(
            child: Text(
              periodLabel,
              style: T.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$metCount ${metCount == 1 ? 'meta batida' : 'metas batidas'}',
            style: T.caption,
          ),
        ]),
        const SizedBox(height: T.s3),

        // 7 Weekday column headers (Seg Ter Qua Qui Sex Sáb Dom)
        Row(children: [
          for (final label in weekdays)
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: T.caption.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
        ]),
        const SizedBox(height: T.s2),

        // 5 Weeks x 7 Weekday columns (standard calendar layout)
        for (var w = 0; w < numWeeks; w++)
          Padding(
            padding: EdgeInsets.only(bottom: w < numWeeks - 1 ? 6 : 0),
            child: Row(children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Builder(builder: (_) {
                      final day = start.add(Duration(days: w * 7 + d));
                      final k = dayKey(day);
                      final a = days[k];
                      final isFuture = day.isAfter(todayUtc);
                      final isToday = k == todayKey;
                      final isSel = k == inspectedKey;
                      final revs = a?.reviews ?? 0;
                      final secs = a?.listenSec ?? 0;
                      final hasActivity = revs > 0 || secs > 0;
                      final isMet = metGoal(a,
                          goalRev: store.goalRev, goalSec: store.goalSec);
                      final isDouble = revs >= store.goalRev * 2 ||
                          secs >= store.goalSec * 2;

                      final bgColor = isFuture
                          ? T.hairline
                          : isDouble
                              ? T.actHigh
                              : isMet
                                  ? T.actGoal
                                  : hasActivity
                                      ? T.actSome
                                      : T.actNone;

                      final fgColor = isFuture
                          ? T.textMuted.withValues(alpha: 0.45)
                          : (isMet || isDouble ? T.onAccent : T.text);

                      return GestureDetector(
                        onTap: isFuture
                            ? null
                            : () => setState(() => _selectedDay = day),
                        child: Container(
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(T.rSm),
                            border: isToday
                                ? Border.all(color: T.text, width: 2)
                                : (isSel
                                    ? Border.all(color: T.actGoal, width: 1.5)
                                    : null),
                          ),
                          child: Text(
                            '${day.day}',
                            style: T.caption.copyWith(
                              color: fgColor,
                              fontWeight: isToday || hasActivity
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
            ]),
          ),

        const SizedBox(height: T.s3),
        const Divider(height: 1, thickness: 0.5, color: T.hairline),
        const SizedBox(height: T.s3),

        // Expanded selected day summary + blue legend
        Container(
          padding: const EdgeInsets.all(T.s3),
          decoration: BoxDecoration(
            color: T.bg,
            borderRadius: BorderRadius.circular(T.rMd),
            border: Border.all(color: T.hairline, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                  inMet
                      ? CupertinoIcons.checkmark_seal_fill
                      : (inActive
                          ? CupertinoIcons.flame_fill
                          : CupertinoIcons.circle),
                  size: 18,
                  color: inMet
                      ? T.actGoal
                      : (inActive ? T.actSome : T.textMuted),
                ),
                const SizedBox(width: T.s2),
                Expanded(
                  child: Text(
                    isInspectingToday
                        ? 'Hoje (${weekdays[inspected.weekday - 1]}, ${inspected.day.toString().padLeft(2, '0')}/${inspected.month.toString().padLeft(2, '0')})'
                        : '${weekdays[inspected.weekday - 1]}, ${inspected.day.toString().padLeft(2, '0')}/${inspected.month.toString().padLeft(2, '0')}',
                    style:
                        T.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  inMet
                      ? 'Meta concluída ✓'
                      : (inActive ? 'Em progresso' : 'Sem atividade'),
                  style: T.caption.copyWith(
                    color: inMet ? T.actGoal : T.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
              const SizedBox(height: T.s2),
              Row(children: [
                Expanded(
                  child: Text(
                    '$inRevs revisões · ${fmtListen(inSecs)} de áudio',
                    style: T.secondary.copyWith(fontSize: 14),
                  ),
                ),
                Row(children: [
                  Text('Menos', style: T.caption.copyWith(fontSize: 11)),
                  const SizedBox(width: 4),
                  _legendSquare(T.actNone),
                  _legendSquare(T.actSome),
                  _legendSquare(T.actGoal),
                  _legendSquare(T.actHigh),
                  const SizedBox(width: 4),
                  Text('Mais', style: T.caption.copyWith(fontSize: 11)),
                ]),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendSquare(Color c) => Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(2.5)),
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
