# Patterns

Reuse these before writing anything new. Tokens live in `app/Queens/Theme/Theme.swift` only.

| Pattern | Exemplar | Notes |
|---|---|---|
| Card (white, 18pt radius, 1pt border) | `Views/HomeView.swift` RealmCard | Dark ink variant: ContinueCard |
| Pill button | `Views/Components.swift` PillButtonStyle | `prominent: true` for the one primary action |
| Difficulty | `Views/Components.swift` TierDots | |
| Puzzle thumbnail | `Views/Components.swift` MiniBoard | Canvas, no shaders |
| Board | `Board/BoardView.swift` | Wash, pencil grid, ink borders, marks, in that z-order |
| Celebration banner | `Views/Components.swift` SolvedBanner / Ribbon | Gold crown stamp on top |
| Solve celebration | `Board/BoardView.swift` SparkleBurst, Sheen, InkLayer gilding | Every delay comes from `Model/SolveTiming.swift` so haptics and visuals land together |
| Grid tile | `Views/RealmView.swift` PuzzleTile | |
| Clue (stepped hint) | `Model/HintEngine.swift`, `Board/BoardView.swift` Spotlight / GhostCross | Same rules as `tools/generate.py`; `tools/hintcheck/run.sh` (on the Mac) must report 0 failures after any change |
| Haptic per action | `Model/Haptics.swift` | One haptic per user action, same frame as the visual |

## New patterns log

- Solve celebration (gold gilding, star bursts, sheen, stamp) with `SolveTiming` as the shared clock, because Jay asked for a bigger reward on solve.
- Stepped clues with a spotlight, because Jay wanted hints that teach (which rows or colours to study) rather than naming a crown cell.
