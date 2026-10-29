// Pure logic (no Flutter): streak, FSRS wrapper, word normalization.
import 'dart:convert';

import 'package:fsrs/fsrs.dart' as fsrs;

export 'package:fsrs/fsrs.dart' show Rating;

const goalReviews = 20;
const goalListenSec = 10 * 60;

/// Local calendar day key, e.g. 2026-10-28. Local (not UTC) so the streak
/// doesn't roll over at 21h in Brasília.
String dayKey(DateTime t) {
  final l = t.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

typedef Day = ({int reviews, int listenSec});

bool metGoal(Day? d,
        {int goalRev = goalReviews, int goalSec = goalListenSec}) =>
    d != null && (d.reviews >= goalRev || d.listenSec >= goalSec);

double goalProgress(Day? d,
        {int goalRev = goalReviews, int goalSec = goalListenSec}) =>
    d == null
        ? 0
        : [
            d.reviews / (goalRev < 1 ? 1 : goalRev),
            d.listenSec / (goalSec < 1 ? 1 : goalSec),
          ].reduce((a, b) => a > b ? a : b).clamp(0, 1).toDouble();

/// Consecutive days meeting the goal, ending today. Today not met yet does
/// not break the streak (you still have until midnight). When [freeze] is true,
/// up to 1 missed day per 7-day window is forgiven if the previous day met the goal.
int streak(
  Map<String, Day> days,
  DateTime now, {
  int goalRev = goalReviews,
  int goalSec = goalListenSec,
  bool freeze = false,
}) {
  bool met(DateTime dt) =>
      metGoal(days[dayKey(dt)], goalRev: goalRev, goalSec: goalSec);
  final l = now.toLocal();
  var d = DateTime(l.year, l.month, l.day);
  if (!met(d)) d = DateTime(d.year, d.month, d.day - 1);
  var n = 0;
  var lastFreeze = -99;
  var step = 0;
  while (true) {
    if (met(d)) {
      n++;
    } else if (freeze &&
        step - lastFreeze >= 7 &&
        met(DateTime(d.year, d.month, d.day - 1))) {
      lastFreeze = step;
    } else {
      break;
    }
    step++;
    d = DateTime(d.year, d.month, d.day - 1); // DST/month-safe
  }
  return n;
}

final _scheduler = fsrs.Scheduler();

/// Reviews a card (stored as JSON). Null json = brand-new card.
({String json, DateTime due}) review(
    String? json, int wordId, fsrs.Rating r, DateTime now) {
  final card = json == null
      ? fsrs.Card(cardId: wordId, due: now.toUtc())
      : fsrs.Card.fromMap(jsonDecode(json) as Map<String, dynamic>);
  final next = _scheduler.reviewCard(card, r, reviewDateTime: now.toUtc()).card;
  return (json: jsonEncode(next.toMap()), due: next.due);
}

/// Human interval until next due, for the rating buttons ("10 min", "3 d").
String interval(DateTime due, DateTime now) {
  final m = due.difference(now).inMinutes;
  if (m < 60) return '${m < 1 ? 1 : m} min';
  if (m < 60 * 24) return '${m ~/ 60} h';
  final d = m ~/ (60 * 24);
  return d < 30 ? '$d d' : (d < 365 ? '${d ~/ 30} m' : '${d ~/ 365} a');
}

final _elision = RegExp(
    r"^(?:jusqu|lorsqu|puisqu|quoiqu|qu|[ldjmtsnc])['’]",
    caseSensitive: false);
final _edges = RegExp(r"^[^\p{L}]+|[^\p{L}]+$", unicode: true);

/// "L’homme," -> "homme". Returns candidates to try in a dictionary.
List<String> candidates(String raw) {
  final w = raw.replaceAll(_edges, '').toLowerCase().replaceFirst(_elision, '');
  return [w, if (w.contains('-')) w.split('-').first];
}

/// Splits text into word / non-word tokens (keeps everything, for rendering).
final wordRe = RegExp(r"[\p{L}'’-]+", unicode: true);
