---
version: alpha
name: Queens
description: An offline Queens puzzle game for one player (Jay) on iPhone, styled as a hand-drawn storybook map.
authority: design-skill
scope: app
takeover_date: null
colors:
  primary: "#2a3446"
  on-primary: "#fbfcfd"
  surface: "#fbfcfd"
  surface-sunken: "#f1f3f6"
  border: "#d9dee6"
  on-surface: "#2a3446"
  on-surface-muted: "#5a6578"
  heading: "#2a3446"
  pencil: "#2a344647"
  error: "#b8322a"
  success: "#2f7d4f"
  gold: "#d49a2a"
  gold-deep: "#8a5a12"
  wax: "#9c2f3c"
  wax-deep: "#6e1f2a"
  on-semantic: "#ffffff"
  region-1: "#a8cbe0"
  region-2: "#f2c58a"
  region-3: "#b9d9a3"
  region-4: "#e9a9a1"
  region-5: "#cbb8de"
  region-6: "#f1e28f"
  region-7: "#9ed1c6"
  region-8: "#e6b8cf"
  region-9: "#c9c48a"
  region-10: "#f4b98c"
  region-11: "#b4c1e3"
typography:
  display-lg: { fontFamily: Young Serif, fontSize: 34px, fontWeight: 400, lineHeight: 1.1 }
  headline-md: { fontFamily: Young Serif, fontSize: 28px, fontWeight: 400, lineHeight: 1.15 }
  headline-sm: { fontFamily: Young Serif, fontSize: 20px, fontWeight: 400, lineHeight: 1.2 }
  body-md: { fontFamily: Nunito Sans, fontSize: 16px, fontWeight: 400, lineHeight: 1.45 }
  body-sm: { fontFamily: Nunito Sans, fontSize: 14px, fontWeight: 400, lineHeight: 1.4 }
  label-md: { fontFamily: Nunito Sans, fontSize: 15px, fontWeight: 700, lineHeight: 1.2 }
  timer: { fontFamily: Nunito Sans, fontSize: 15px, fontWeight: 700, lineHeight: 1.2, fontFeature: "'tnum' 1" }
rounded: { sm: 6px, md: 12px, lg: 20px, full: 9999px }
spacing: { xs: 4px, sm: 8px, md: 16px, lg: 24px, xl: 32px }
motion: { press: 120ms, mark: 180ms, wash: 450ms, banner: 700ms, spring: "spring(duration 0.4, bounce 0.2)" }
components:
  button-outline: { backgroundColor: "{colors.surface}", textColor: "{colors.on-surface}", rounded: "{rounded.full}", typography: "{typography.label-md}", height: 52px }
  button-primary: { backgroundColor: "{colors.primary}", textColor: "{colors.on-primary}", rounded: "{rounded.full}", typography: "{typography.label-md}", height: 52px }
  realm-card: { backgroundColor: "{colors.surface}", textColor: "{colors.on-surface}", rounded: "{rounded.lg}" }
  puzzle-tile: { backgroundColor: "{colors.surface-sunken}", textColor: "{colors.on-surface-muted}", rounded: "{rounded.sm}" }
  clash-mark: { backgroundColor: "{colors.surface}", textColor: "{colors.error}" }
  solved-tick: { backgroundColor: "{colors.surface}", textColor: "{colors.success}" }
---

# Queens design system

## Overview
Storybook map. Each puzzle is a small hand-drawn map: regions are kingdoms painted in soft watercolour, borders are wobbly ink, and a fine pencil grid shows every row and column. Queens are crowns. Tone: whimsical, calm, tactile. Density is low: one board per screen, nothing competing with it.

The person is Jay, playing one-handed on his iPhone in short sessions, picking up where he left off. The board is the only thing that matters on the game screen; everything else is quiet and sits at the bottom within thumb reach.

The memorable element is the board itself: watercolour washes that deepen as kingdoms receive their queen, under a pencil grid and inked borders.

## Colors
### Brand & Accent
`primary` (ink, #2a3446) is the only accent. It draws borders, crowns, titles and the filled button. Contrast on `surface`: 12.0:1.

### Surface
`surface` (#fbfcfd, paper) is the page. `surface-sunken` backs unplayed puzzle tiles. `border` outlines cards. Every screen sits on `PaperBackground`: paper run through the granulation shader, with faint contour lines (7% ink, 5% on the game screen) curling in from the top right and bottom left corners like hills on a map.

### Text
`on-surface` for body and titles, `on-surface-muted` (#5a6578, 5.7:1 on paper) for secondary text and crosses.

### Semantic
`error` marks clashing queens (red crown plus a shake, never colour alone: the haptic and the motion carry it too). `success` is the solved tick in the picker, always paired with the best time.

### Region palette
Eleven watercolour pigments, `region-1` to `region-11`, assigned by region letter (a to k). Unclaimed kingdoms paint at 78% strength; a kingdom with a queen paints at 100%. Crosses and crowns are ink on top, so contrast comes from the ink, not the pigment.

## Typography
### Font Family
Young Serif (OFL, bundled) for titles and puzzle names. Nunito Sans (OFL, bundled as static 400/700/800 instances) for everything else. Fallback: system serif and SF Pro.

### Hierarchy
| Token | Size | Use |
|---|---|---|
| display-lg | 34 | Home title |
| headline-md | 28 | Puzzle name on the game screen |
| headline-sm | 20 | Realm names, banner |
| body-md | 16 | Body |
| body-sm | 14 | Captions, tile labels |
| label-md | 15 bold | Buttons |
| timer | 15 bold, tabular | Timer and best times |

### Principles
Sentence case everywhere. Puzzle names are generated storybook names ("The Marsh of Eight"). Times always use tabular numerals.

## Layout
### Spacing System
4pt base: 4, 8, 16, 24, 32.

### Grid & Container
Board fills the width minus 18pt each side, centred under the title. Controls are a row of three pill buttons (Undo, Clear, Hint) with the pin button (or Return to pin and Re-pin side by side) centred under them, above the home indicator. On iPad (landscape only), Home and realm content is capped at a 640pt centred column, and the game screen puts the board on the left with the title, clue or ribbon, and controls in a 380pt column on the right.

### Whitespace Philosophy
Paper shows around the board. No cards on the game screen.

## Elevation & Depth
Flat. No shadows except the solved banner, which floats over the board with one soft shadow.

## Shapes
Pills for buttons, 20pt radius for realm cards, 6pt for puzzle tiles. The board itself is square-cornered (a map sheet).

## Components
### Buttons
`button-outline`: 1.5pt ink outline on paper, used for Undo, Clear, Hint. `button-primary`: ink fill, used once per screen (Next puzzle on the banner).

### Cards & Containers
`realm-card`: one per board size on Home, with the realm name, size, and progress (crowned of total) as a thin ink bar.

### Navigation
System NavigationStack. Home, then realm (puzzle grid), then game.

### Pills, Tags, and Chips
Difficulty shows as 1 to 5 small ink dots on each puzzle tile.

### Signature Components
**Board.** Layers, bottom to top:
1. Watercolour wash: each cell filled with its region pigment, run through a noise distortion shader so edges bleed, plus a pigment granulation shader.
2. Pencil grid: 0.5pt line at 28% ink between every cell.
3. Ink borders: 2.6pt (2.2pt above 8x8) where neighbouring cells are in different regions, 3.6pt outer frame, both through a gentle wobble shader (`inkWobble`).
4. Marks: crosses (muted serif ×) and crowns (ink).

**Solved banner.** A ribbon that unfurls under the board with "Crowned in 3:12" (the time counts up from 0:00 on a fresh solve) and the best time, flanked by two small stars when it is a new best. A `wax` seal pressed with a gold crown drops onto it with a squash and a few flecks of wax. Play again and Next puzzle fade in once the ribbon is down.

**Compass rose.** Beside the Home title: a dashed ring draws in and the needle swings, overshoots and settles.

**Pin.** One save point per game. "Pin this board" saves the marks as they stand; the button then becomes two, "Return to pin" and "Re-pin" (both disabled until the board changes). Re-pin replaces the pin with the board as it stands, inking the pencilled marks, so a guess that held up becomes the new save point. Marks made since the pin are pencilled in at 45% strength (`Theme.pencilMark`), so a guess being tested is visible at a glance; a clashing crown stays full strength. Return to pin restores the pinned board and lifts the pin, so the next guess can be pinned again; Undo brings the abandoned guess back. Solving or Play again drops the pin. The pin is saved with the attempt and syncs with it.

**Crown tally.** Under the puzzle name on the game screen: one small crown per kingdom, drawn as a pencil outline and inked with a spring as each crown is placed (gold once the board is solved), then the timer and difficulty dots. VoiceOver reads it as "3 of 7 crowned".

**Clues.** Hint gives a clue, not an answer, in up to three steps: where to look (the rows, columns or kingdoms involved stay bright, the rest of the board fades under paper at 62%), then why, then which cells (faint pulsing crosses for cells to dot, a dashed outline for a crown or a cell to test). The button reads More while a clue has another step. Kingdoms are named by colour (`Theme.regionNames`), rows and columns are counted from the top left.

**Gilding.** On solve the crowns turn `gold` (with a `gold-deep` outline) row by row, each with a small burst of four-point stars, then a light sheen sweeps the board and a thin gold line appears inside the outer frame. Then the coronation (`Board/Coronation.swift`): a dotted `gold-deep` royal road is drawn crown to crown from the top row down, with a spinning star at its head; as it reaches each crown, a ring of light washes through that crown's kingdom; when it reaches the last crown, the kingdom comes alive: any crosses clear, a cottage pops up and puffs smoke, a sheep hops across a field, two birds fly over, and a small green dragon flies in, loops the board and lands beside the last crown, sending it a heart. Inhabitants are cartoon shapes with flat fills and a soft `ink` outline. The cottage, sheep and dragon stay on a finished board, drawn at rest. Afterwards, while the board stays gilded, one crown at a time catches the light with a small glint every 1.7s. Gold appears only on a solved board.

## Do's and Don'ts
### Do
- Keep the board the largest thing on screen.
- Pair every error with haptic and motion as well as colour.
- Use generated storybook names for puzzles and realms.
### Don't
- No dark mode.
- No confetti or score popups. Celebrations stay inside the map metaphor.
- Do not animate crosses; they are placed dozens of times per puzzle.

## Motion
| Event | Motion | Haptic |
|---|---|---|
| Cross placed | none (frequency rule) | soft light tap |
| Queen placed | crown scales 0.6 to 1 with spring; a ring of ink spreads from the cell over 500ms; kingdom wash deepens over 450ms | full-strength thud with a short rumble tail |
| Clash | clashing crowns turn red and shake 3 times over 300ms | two sharp knocks then a gritty buzz |
| Solve | after 450ms each row of crowns bounces and turns gold with a star burst (70ms stagger); then board pulses to 1.04, sheen sweeps, gold frame line fades in; 500ms later the royal road travels crown to crown (90ms a leg) with a kingdom ripple at each; 150ms later the inhabitants come out (the dragon lands 2.5s after); ribbon unfurls with the time counting up; wax seal stamps 750ms later | one tap per row rising in strength, a swelling rumble on the finale, seven sparkle ticks, a light footstep per crown on the road, three light hops for the sheep, a soft thump as the dragon lands, a heavy press for the seal. All times from `Model/SolveTiming.swift` |
| Undo | undo arrow bounces down | selection tick |
| Pin, Return to pin, Re-pin | pin bounces down; pencilled marks fade over 250ms on return | selection tick |
| Hint | lightbulb bounces; clue text slides up and fades in, the old one slides out | none |
| Home appears | cards rise 14pt and fade in, 60ms apart; progress bars fill from empty | none |
| Card or tile pressed | scales to 0.97 | none |

Reduce Motion: no shake or bounce; crowns and banner fade in. The road, ripples, glints and ink drop are not drawn; the inhabitants appear at rest without moving; the seal fades in rather than drops; Home cards fade without rising.

## States
| State | Rule |
|---|---|
| Hover | Not applicable (touch only) |
| Focus | System focus for VoiceOver; each cell labelled "Row 3, column F, Marsh kingdom, queen" |
| Disabled | Undo disabled at 40% opacity when there is nothing to undo; Pin when the board is blank; Return to pin and Re-pin until the board differs from the pin |
| Loading | Puzzles load from the bundle at launch, under 100ms; no spinner |
| Empty | Never empty: every realm ships with 120 puzzles |
| Error | Clashing queens shown red with shake and haptic; no blocking dialogs |
