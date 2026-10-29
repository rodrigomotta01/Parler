// Parler design system: tokens + the only allowed components.
// Rules: .agents/skills/design-system/SKILL.md
import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Tokens. Never use raw colors/sizes in screens.
abstract final class T {
  static const bg = Color(0xFFFAF8F5);
  static const surface = Color(0xB8FFFFFF); // white @ 72%
  static const text = Color(0xFF1C1C1E);
  static const textMuted = Color(0xFF8E8E93);
  static const hairline = Color(0x0F000000); // black @ 6%

  static const lavender = Color(0xFFC9C3F5);
  static const peach = Color(0xFFFFD6BF);
  static const mint = Color(0xFFBFEBD9);
  static const sky = Color(0xFFC2DDF7);
  static const rose = Color(0xFFF7C6CF);
  static const butter = Color(0xFFFBEDB5);

  // Activity heatmap blue scale (none -> active -> goal met -> 2x goal).
  static const actNone = Color(0xFFEBEDF0);
  static const actSome = Color(0xFF60A5FA);
  static const actGoal = Color(0xFF2563EB);
  static const actHigh = Color(0xFF1D4ED8);

  static Color level(String l) => switch (l) {
        'A1' => mint,
        'A2' => sky,
        'B1' => butter,
        'B2' => peach,
        'C1' => rose,
        _ => lavender,
      };

  static const rSm = 10.0, rMd = 14.0, rLg = 20.0;
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 24.0, s6 = 32.0;
  static const fast = Duration(milliseconds: 200);
  static const curve = Curves.easeOutCubic;
  static const shadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8))
  ];

  static TextStyle _t(double size, int w, [Color c = text]) => TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        color: c,
        fontWeight: FontWeight.values[(w ~/ 100) - 1],
        fontVariations: [FontVariation.weight(w.toDouble())],
        letterSpacing: size >= 22 ? -0.5 : -0.1,
      );
  static final largeTitle = _t(34, 700);
  static final title = _t(22, 650);
  static final body = _t(17, 450);
  static final secondary = _t(15, 450, textMuted);
  static final caption = _t(13, 500, textMuted);

  static ThemeData theme() => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
            seedColor: lavender, surface: bg, brightness: Brightness.light),
        splashFactory: NoSplash.splashFactory,
        textTheme: TextTheme(bodyMedium: body),
      );
}

/// Translucent rounded card — the default container.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.color, this.padding});
  final Widget child;
  final Color? color;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(T.rLg)),
            boxShadow: T.shadow),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(T.rLg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: padding ?? const EdgeInsets.all(T.s4),
              decoration: BoxDecoration(
                color: color?.withValues(alpha: 0.55) ?? T.surface,
                borderRadius: BorderRadius.circular(T.rLg),
                border: Border.all(color: T.hairline, width: 0.5),
              ),
              child: child,
            ),
          ),
        ),
      );
}

/// The only button.
class PillButton extends StatelessWidget {
  const PillButton(this.label,
      {super.key, required this.onTap, this.color = T.lavender, this.icon});
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedOpacity(
            duration: T.fast,
            opacity: onTap == null ? 0.4 : 1,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: T.s4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(T.rMd),
                border: Border.all(color: T.hairline, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: T.text),
                    const SizedBox(width: T.s2),
                  ],
                  Flexible(
                      child: Text(label,
                          style: T.body.copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center)),
                ],
              ),
            ),
          ),
        ),
      );
}

/// CEFR level tag.
class LevelChip extends StatelessWidget {
  const LevelChip(this.level, {super.key});
  final String level;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: T.s2, vertical: 2),
        decoration: BoxDecoration(
            color: T.level(level), borderRadius: BorderRadius.circular(T.rSm)),
        child: Text(level, style: T.caption.copyWith(color: T.text)),
      );
}

/// Raycast-style search field.
class CommandBar extends StatelessWidget {
  const CommandBar({super.key, required this.onChanged, this.hint = 'Buscar'});
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: T.s3),
        child: TextField(
          onChanged: onChanged,
          style: T.body,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintStyle: T.body.copyWith(color: T.textMuted),
            icon: const Icon(CupertinoIcons.search, color: T.textMuted),
          ),
        ),
      );
}

/// Progress ring (streak / daily goal).
class StatRing extends StatelessWidget {
  const StatRing(
      {super.key, required this.value, required this.color, required this.center, this.size = 120});
  final double value;
  final Color color;
  final Widget center;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0, 1)),
          duration: T.fast * 3,
          curve: T.curve,
          builder: (_, v, _) => CustomPaint(
              painter: _Ring(v, color), child: Center(child: center)),
        ),
      );
}

class _Ring extends CustomPainter {
  _Ring(this.v, this.color);
  final double v;
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(6, 6, s.width - 12, s.height - 12);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    c.drawArc(r, 0, 2 * pi, false, p..color = color.withValues(alpha: 0.3));
    c.drawArc(r, -pi / 2, 2 * pi * v, false, p..color = color);
  }

  @override
  bool shouldRepaint(_Ring o) => o.v != v || o.color != color;
}

