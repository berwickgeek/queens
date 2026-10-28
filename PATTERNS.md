# Patterns

Reuse these before writing anything new. Tokens live in `app/Queens/Theme/Theme.swift` only.

| Pattern | Exemplar | Notes |
|---|---|---|
| Card (white, 18pt radius, 1pt border) | `Views/HomeView.swift` RealmCard | Dark ink variant: ContinueCard |
| Pill button | `Views/Components.swift` PillButtonStyle | `prominent: true` for the one primary action |
| Crown tally | `Views/Components.swift` CrownTally | One pencil outline per kingdom, inked as crowns go down; game header |
| Difficulty | `Views/Components.swift` TierDots | |
| Puzzle thumbnail | `Views/Components.swift` MiniBoard | Canvas, no shaders |
| Board | `Board/BoardView.swift` | Wash, pencil grid, ink borders, marks, in that z-order |
| Celebration banner | `Views/Components.swift` SolvedBanner / Ribbon | Gold crown stamp on top |
| Solve celebration | `Board/BoardView.swift` SparkleBurst, Sheen, InkLayer gilding | Every delay comes from `Model/SolveTiming.swift` so haptics and visuals land together |
| Coronation (after gilding) | `Board/Coronation.swift` RoyalRoad, KingdomRipple, Lanterns, CrownGlints | Keep each layer always mounted and drive it with `keyframeAnimator(trigger:)`; a layer inserted with the new trigger value never animates |
| Placement feedback | `Board/Coronation.swift` InkDrop, KingdomSeal | InkDrop: `GameModel.placeTrigger` / `lastPlaced`, `strength` is the share of crowns placed. KingdomSeal: `sealTrigger` / `lastSealed`, only from forward moves (tap, end of drag), never undo, clear or pin return |
| Rare coronation | `Model/SolveTiming.swift` Flourish, `Board/Coronation.swift` Lanterns(flourish:), Comet | `Flourish.draw()` on each solve; DEBUG launch arg `-flourish festival` or `-flourish comet` forces one |
| Screen background | `Views/Components.swift` PaperBackground | Every screen; `contours:` 0.05 on the game screen so the board stays loudest |
| Pressable card or tile | `Views/Components.swift` PressableStyle | Use for NavigationLinks that look like cards |
| Wax seal | `Views/Components.swift` WaxSeal / StampedSeal | `wax` tokens only here; `gilt: true` for a new best |
| Grid tile | `Views/RealmView.swift` PuzzleTile | Small gold crown in the corner once solved |
| Clue (stepped hint) | `Model/HintEngine.swift`, `Board/BoardView.swift` Spotlight / GhostCross | Same rules as `tools/generate.py`; `tools/hintcheck/run.sh` (on the Mac) must report 0 failures after any change |
| Haptic and sound per action | `Model/Haptics.swift`, `tools/make_sounds.py` | One haptic per user action, same frame as the visual. Sounds go in the same pattern via `sound(_:at:volume:)`; add new ones to `make_sounds.py` and rerun it |
| Wide screens (iPad, landscape) | `Views/HomeView.swift`, `Views/RealmView.swift`, `Views/GameView.swift` | Lists: `.frame(maxWidth: 640).frame(maxWidth: .infinity)`. Game: `wide` (regular by regular size class) puts the board beside a 380pt column |
| Pin (save point) | `Model/GameModel.swift` setPin (also re-pins) / returnToPin, `Views/GameView.swift` pinButton | Marks that differ from the pin render at `Theme.pencilMark` in MarkView |
| Progress sync | `Model/ProgressStore.swift` | Local file first, mirrored to iCloud key-value store as one `p.<id>` key per puzzle; merge with `PuzzleRecord.merged`. Writes batch for 2s and flush on background; pull on foreground |

## New patterns log

- Solve celebration (gold gilding, star bursts, sheen, stamp) with `SolveTiming` as the shared clock, because Jay asked for a bigger reward on solve.
- Coronation (royal road, kingdom ripple, lanterns, glints), wax seal with count-up, paper background with contours, compass rose, ink drop on placement, pressable cards, because Jay asked for a more elaborate reward on completion and more polish across the app.
- Native iPad layout (640pt column cap) and iCloud key-value progress sync, because Jay plays on an iPhone and an iPad and wants one set of progress.
- Stepped clues with a spotlight, because Jay wanted hints that teach (which rows or colours to study) rather than naming a crown cell.
- Pin (one save point per game, marks since it pencilled in), because Jay wanted to save a board, test a guess and roll back.
- Crown tally in the game header in place of "3 of 7 crowned", because Jay wanted to see progress as small crowns.
- Rising stakes per crown, kingdom-finished shine, gilt seal for a new best, rare festival and shooting-star coronations, and the wood and bell sound set, because Jay asked to lean on reward psychology (anticipation, goal gradient, variable reward) and add sound.
- Hand-drawn crowns and crosses (`InkCross`, seeded `Crown`, ink wobble on the marks layer), because Jay wanted the marks to look hand drawn like the borders.
