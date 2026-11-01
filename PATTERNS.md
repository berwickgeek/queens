# Patterns

Reuse these before writing anything new. Tokens live in `app/Queens/Theme/Theme.swift` only.

| Pattern | Exemplar | Notes |
|---|---|---|
| Card (white, 18pt radius, 1pt border) | `Views/HomeView.swift` RealmCard | Dark ink variant: ContinueCard |
| Pill button | `Views/Components.swift` PillButtonStyle | `prominent: true` for the one primary action |
| Crown tally | `Views/Components.swift` CrownTally | One pencil outline per kingdom, inked as crowns go down; game header |
| Difficulty | `Views/Components.swift` TierDots | |
| Puzzle thumbnail | `Views/Components.swift` MiniBoard | Canvas, no shaders. Used by ContinueCard; realm cards use ProvinceCrop |
| Map thumbnail | `Atlas/ProvinceCrop.swift` ProvinceCrop | A clipped window onto the live province sheet, not a separate drawing. Reuse it for any small map view |
| Board | `Board/BoardView.swift` | Wash, pencil grid, ink borders, marks, in that z-order |
| Celebration banner | `Views/Components.swift` SolvedBanner / Ribbon | Gold crown stamp on top |
| Solve celebration | `Board/BoardView.swift` SparkleBurst, Sheen, InkLayer gilding | Every delay comes from `Model/SolveTiming.swift` so haptics and visuals land together |
| Coronation (after gilding) | `Board/Coronation.swift` RoyalRoad, KingdomRipple, Lanterns, CrownGlints | Keep each layer always mounted and drive it with `keyframeAnimator(trigger:)`; a layer inserted with the new trigger value never animates |
| Placement feedback | `Board/Coronation.swift` InkDrop, KingdomSeal | InkDrop: `GameModel.placeTrigger` / `lastPlaced`, `strength` is the share of crowns placed. KingdomSeal: `sealTrigger` / `lastSealed`, only from forward moves (tap, end of drag), never undo, clear or pin return |
| Rare coronation | `Model/SolveTiming.swift` Flourish, `Board/Coronation.swift` Lanterns(flourish:), Comet | `Flourish.draw()` on each solve; DEBUG launch arg `-flourish festival` or `-flourish comet` forces one |
| Screen background | `Views/Components.swift` PaperBackground | Every screen; `contours:` 0.05 on the game screen so the board stays loudest |
| Pressable card or tile | `Views/Components.swift` PressableStyle | Use for NavigationLinks that look like cards |
| Wax seal | `Views/Components.swift` WaxSeal / StampedSeal | `wax` tokens only here; `gilt: true` for a new best |
| Clue (stepped hint) | `Model/HintEngine.swift`, `Board/BoardView.swift` Spotlight / GhostCross | Same rules as `tools/generate.py`; `tools/hintcheck/run.sh` (on the Mac) must report 0 failures after any change |
| Haptic and sound per action | `Model/Haptics.swift`, `tools/make_sounds.py` | One haptic per user action, same frame as the visual. Sounds go in the same pattern via `sound(_:at:volume:)`; add new ones to `make_sounds.py` and rerun it |
| Wide screens (iPad, landscape) | `Views/HomeView.swift`, `Views/RealmMapView.swift`, `Views/GameView.swift` | Lists: `.frame(maxWidth: 640).frame(maxWidth: .infinity)`. Game: `wide` (regular by regular size class) puts the board beside a 380pt column |
| Pin (save point) | `Model/GameModel.swift` setPin (also re-pins) / returnToPin, `Views/GameView.swift` pinButton | Marks that differ from the pin render at `Theme.pencilMark` in MarkView |
| Atlas drawing (journey maps) | `Atlas/AtlasSketch.swift`, `Atlas/AtlasFeatures.swift`, `Atlas/AtlasCanvas.swift` | Build an `AtlasDrawing` with `AtlasSketch` (terrain, roads, stops, castles, furniture), paint it with `AtlasCanvas`; `AtlasSheet` for half inked, half pencil. Geometry in `Atlas/AtlasGeometry.swift` is Foundation only and unit tested. A pencil and an inked sketch from one seed must consume the RNG identically |
| Atlas gallery (DEBUG) | `Views/AtlasGalleryView.swift` | Launch arg `-atlasGallery YES`; every Atlas drawing on one screen with build times, for comparing against the mockup shots |
| Realm map | `Views/RealmMapView.swift`, `Atlas/RealmSheet.swift`, `Atlas/RealmGeometry.swift` | Terrain (ink and pencil) cached per realm and built off the main thread; road, names and castles drawn live from progress. Clear NavigationLink bands over the sheet carry the taps and the accessibility labels. The sheet opens on the current band with `.defaultScrollAnchor` (a fraction of the sheet height), because `scrollTo` cannot find ids on views placed with `.position` inside a GeometryReader. Geometry is Foundation only and unit tested |
| Province map | `Views/ProvinceMapView.swift`, `Atlas/ProvinceSheet.swift`, `Atlas/ProvinceGeometry.swift` | Same split as the realm map: terrain cached per province off the main thread, road, stops and castle live. A clear 44pt NavigationLink per stop carries the tap and the accessibility label; the sheet opens on the leg's end or the current stop with `.defaultScrollAnchor`, as on the realm map |
| Travel (journey animation) | `Atlas/Travel.swift`, `ProvinceSheet.pieces`, `Travel` in `Model/SolveTiming.swift` | The live sheet leaves out the leg (`live(travelling:)`); `TravelOverlay` draws those pieces from the same per-piece seeds and moves them on one `keyframeAnimator` clock, so its last frame matches the plain sheet and the overlay can be removed without a jump. Mount with trigger 0, bump a frame later. Haptics read the same `Travel` windows |
| Slim map card | `Views/RealmMapView.swift` SlimMapCard(caption:puzzle:) | Paper capsule in `.safeAreaInset(edge: .bottom)` with an ink Continue capsule; used on both maps instead of ContinueCard, each passing its own caption |
| Daily limit and unlock | `Model/Unlock.swift`, `Views/LimitCard.swift`, gate in `Views/GameView.swift` `locked` | StoreKit 2 non-consumable `cc.jaym.queens.unlock`; `app/Queens.storekit` drives the simulator. Only fresh starts and Play again are gated, never hints, Pin or a puzzle under way. DEBUG launch arg `-dailyLimit YES` forces the card |
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
- Atlas drawing kit (pen and pencil sketching, watercolour washes on paper, wax seal stops, castles, IM Fell place names) and its DEBUG gallery, because the journey maps need terrain, roads and castles nothing in the app draws.
- Realm map (one scrolling sheet of twelve province bands, inked to the traveller) and the slim map card, because the full ContinueCard hides a province band.
- Province map (twenty named stops to a castle) in place of the puzzle grid, so every puzzle is a place on the journey; the grid tile pattern is retired.
- Journey travel (the seal walks the last leg on the province map, ink creeps up, the new name is written on) and "To the map" on a solved puzzle, because playing a puzzle should move the traveller across the map.
- Province crop on the Home realm cards in place of the first unsolved puzzle's mini board, so Home shows where the traveller is on the journey.
- Daily limit (five solves a day after the first ten) and a one-time unlock, because Jay chose a free tier plus one purchase over ads or paid hints.
