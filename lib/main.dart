import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'db.dart';
import 'screens/home.dart';
import 'screens/grammar.dart';
import 'screens/listen.dart';
import 'screens/review.dart';
import 'screens/words.dart';
import 'ui.dart';

late final Store store;
final _notifs = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  store = await Store.open();
  runApp(const ParlerApp());
  scheduleReminder(); // after first frame; failures must not block the app
}

/// Daily local reminder at [Store.reminderHour].
// ponytail: fires even if today's goal is already met; skip-when-met needs a
// one-shot schedule re-armed on each app open.
Future<void> scheduleReminder() async {
  try {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(
        tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    await _notifs.initialize(
        settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    await _notifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, store.reminderHour);
    if (at.isBefore(now)) at = at.add(const Duration(days: 1));
    await _notifs.cancelAll();
    await _notifs.zonedSchedule(
      id: 0,
      title: 'Hora do francês 🇫🇷',
      body: 'Mantenha sua ofensiva: algumas revisões ou um episódio.',
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('daily', 'Lembrete diário')),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  } catch (e) {
    debugPrint('reminder: $e');
  }
}

class ParlerApp extends StatelessWidget {
  const ParlerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Parler',
        debugShowCheckedModeBanner: false,
        theme: T.theme(),
        home: ListenableBuilder(
          listenable: store,
          builder: (_, _) =>
              store.onboarded ? const Shell() : const LevelPicker(),
        ),
      );
}

class Shell extends StatelessWidget {
  const Shell({super.key});
  static final tab = ValueNotifier(0);

  static const _tabs = [
    (CupertinoIcons.sun_max, 'Hoje'),
    (CupertinoIcons.rectangle_stack, 'Revisar'),
    (CupertinoIcons.headphones, 'Ouvir'),
    (CupertinoIcons.lightbulb, 'Gramática'),
    (CupertinoIcons.book, 'Palavras'),
  ];

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: tab,
        builder: (_, i, _) => Scaffold(
          extendBody: true,
          body: SafeArea(
            bottom: false,
            child: IndexedStack(index: i, children: [
              const HomeScreen(),
              // Rebuilt on each visit so the queue is fresh.
              i == 1 ? const ReviewScreen() : const SizedBox(),
              const ListenScreen(),
              const GrammarScreen(),
              const WordsScreen(),
            ]),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(T.s4, 0, T.s4, T.s3),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: T.s2),
              child: Row(children: [
                for (final (j, (icon, label)) in _tabs.indexed)
                  Expanded(
                    child: Semantics(
                      selected: i == j,
                      button: true,
                      label: label,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => tab.value = j,
                        child: AnimatedContainer(
                          duration: T.fast,
                          curve: T.curve,
                          margin: const EdgeInsets.symmetric(horizontal: T.s1),
                          padding: const EdgeInsets.symmetric(vertical: T.s2),
                          decoration: BoxDecoration(
                            color: i == j ? T.lavender : null,
                            borderRadius: BorderRadius.circular(T.rMd),
                          ),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(icon, size: 22, color: T.text),
                            Text(label, style: T.caption.copyWith(color: T.text)),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
}

/// First launch: choose starting CEFR level.
class LevelPicker extends StatelessWidget {
  const LevelPicker({super.key});

  static const desc = {
    'A1': 'Começando do zero',
    'A2': 'Frases do dia a dia',
    'B1': 'Me viro em conversas',
    'B2': 'Entendo notícias e séries',
    'C1': 'Fluente, quero refinar',
    'C2': 'Quase nativo',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(T.s5), children: [
            Text('Bonjour 👋', style: T.largeTitle),
            const SizedBox(height: T.s2),
            Text('Qual é o seu nível de francês?', style: T.secondary),
            const SizedBox(height: T.s5),
            for (final l in levels)
              Padding(
                padding: const EdgeInsets.only(bottom: T.s3),
                child: GestureDetector(
                  onTap: () => store.set('level', l),
                  child: GlassCard(
                    color: T.level(l),
                    child: Row(children: [
                      Text(l, style: T.title),
                      const SizedBox(width: T.s4),
                      Expanded(child: Text(desc[l]!, style: T.body)),
                      const Icon(CupertinoIcons.chevron_right, color: T.textMuted),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      );
}

