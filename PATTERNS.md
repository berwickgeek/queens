# Patterns

Reuse these before writing anything new. Tokens live in `app/Queens/Theme/Theme.swift` only.

| Pattern | Exemplar | Notes |
|---|---|---|
| Card (white, 18pt radius, 1pt border) | `Views/HomeView.swift` RealmCard | Dark ink variant: ContinueCard |
| Pill button | `Views/Components.swift` PillButtonStyle | `prominent: true` for the one primary action |
| Difficulty | `Views/Components.swift` TierDots | |
| Puzzle thumbnail | `Views/Components.swift` MiniBoard | Canvas, no shaders |
| Board | `Board/BoardView.swift` | Wash, pencil grid, ink borders, marks, in that z-order |
| Celebration banner | `Views/Components.swift` SolvedBanner / Ribbon | |
| Grid tile | `Views/RealmView.swift` PuzzleTile | |
| Haptic per action | `Model/Haptics.swift` | One haptic per user action, same frame as the visual |

## New patterns log

(none yet)
