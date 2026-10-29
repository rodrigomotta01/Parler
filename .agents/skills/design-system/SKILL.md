---
name: design-system
description: Parler's visual design system (pastel, light, macOS/Raycast-inspired). MUST be followed whenever creating or editing any Flutter UI in this repo — screens, widgets, colors, spacing, typography, motion.
---

# Parler design system

Look: macOS Sonoma + Raycast. Light, airy, translucent surfaces, hairline borders,
generous whitespace, soft pastel accents. Calm, never loud.

All tokens and components live in **one file: `lib/ui.dart`**. Read it before touching UI.

## Hard rules

1. **No raw colors, sizes or durations in screens.** Always `T.*` (tokens). If a value is missing, add it to `T` first.
2. **Only these components** for structure: `GlassCard`, `PillButton`, `LevelChip`, `CommandBar`, `StatRing`. Need a new one? Add it to `lib/ui.dart`, document it here.
3. **Icons:** `CupertinoIcons` only.
4. **Shadows:** at most one soft shadow (`T.shadow`, 8% black, blur 24). No elevation stacks, no Material ripple-heavy widgets.
5. **Borders:** `T.hairline` 0.5 px. Corners: `T.rSm` 10 (chips), `T.rMd` 14 (buttons/inputs), `T.rLg` 20 (cards).
6. **Spacing:** 4-pt grid → `T.s1..T.s6` = 4, 8, 12, 16, 24, 32.
7. **Type:** Inter (bundled). Sizes: 34 large title (w700, tight -0.5), 22 title, 17 body, 15 secondary, 13 caption. Muted text = `T.textMuted`.
8. **Motion:** `T.fast` 200 ms + `Curves.easeOutCubic`. No bouncy springs.
9. **Light mode only** (by product decision).
10. **Accessibility:** tap targets ≥ 44 px; text on pastel always `T.text` (pastels are backgrounds, never text colors).

## Palette

| Token | Hex | Meaning |
|---|---|---|
| `bg` | `#FAF8F5` | app background |
| `surface` | `#FFFFFF` @ 72% + blur 20 | glass cards |
| `text` / `textMuted` | `#1C1C1E` / `#8E8E93` | text |
| `lavender` | `#C9C3F5` | primary, SRS |
| `peach` | `#FFD6BF` | streak 🔥 |
| `mint` | `#BFEBD9` | success / Easy |
| `sky` | `#C2DDF7` | podcasts / listening |
| `rose` | `#F7C6CF` | error / Again |
| `butter` | `#FBEDB5` | highlights |

CEFR colors (`T.level(String)`): A1 mint · A2 sky · B1 butter · B2 peach · C1 rose · C2 lavender.

## Components

- `GlassCard(child, {color})` — translucent rounded card, the default container.
- `PillButton(label, onTap, {color, icon})` — the only button. Pastel fill, dark text.
- `LevelChip(level)` — small rounded tag colored by CEFR level.
- `CommandBar(onChanged, {hint})` — Raycast-style search field (magnifier, glass, rMd).
- `StatRing(value 0..1, color, center)` — progress ring for streak / daily goal.

