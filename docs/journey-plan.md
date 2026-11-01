# Journey: Swift build plan

Source of truth for the look: `~/scratch/mockups/queens-journey/realm-template.html` (realm overview, province, solve animation). This plan maps each piece of it onto the existing app.

## What the code already gives us

- A realm is a board size (`Naming.realm(size)`: The Hamlets 7x7 to The Empire 11x11). `Route.realm(size)` opens `RealmView`, a 4-column grid of `PuzzleTile`s.
- **Each realm has 240 puzzles, not 120.** The mockup assumed 120. `Naming.puzzleName` already treats 121 to 240 as a second set with its own place words (`farPlaces`).
- Progress per puzzle is `PuzzleRecord.solvedOnce` in `ProgressStore`, synced through iCloud KVS. `firstUnsolved(size:)` is the current stop.
- The watercolour and pen look on the board comes from three stitchable shaders in `Board/Shaders.metal`: `washBleed` (edge bleed), `granulate` (pigment grain), `inkWobble` (ragged pen line). These are the Swift equivalents of the mockup's `wc` and `wob` SVG filters.
- Marks are already seeded hand-drawn shapes (`Crown(seed:)`, `InkCross(seed:)`), so seeded jitter is an existing idiom.
- Coronation layers use always-mounted `keyframeAnimator(trigger:)` with every delay in `Model/SolveTiming.swift`. The travel animation follows the same rule.
- No unit test target exists.

## Decisions (Jay took all three recommendations, 2026-11-01)

1. **240 stops per realm.** Recommended: 12 provinces of 20 on one vertically scrolling realm sheet. Provinces 1 to 6 are the near shore (set one), a sea crossing, then provinces 7 to 12 on the far shore (set two, which already has its own place names). Alternative: two separate sheets per realm.
2. **Palette and type.** The mockup is sepia ink `#4a3423` on `#f5ecd7` paper with IM Fell. The app is ink `#2a3446` on near-white with Young Serif. Recommended: add an `Atlas` token group to `Theme.swift` and bundle IM Fell (OFL), used only on the two map screens, because that is the style Jay picked; the board and Home stay as they are. Alternative: redraw the maps in the existing tokens (one look, but not the look that was picked).
3. **The puzzle grid.** Recommended: the province map replaces `RealmView`'s grid. VoiceOver gets the stops as a plain list of buttons, so nothing is lost.

## Data (phase 1, no UI)

`Model/Journey.swift`:
- `Province { realm: Int, index: Int, name: String, range: ClosedRange<Int> }`. `index = (number - 1) / 20`.
- 60 province names (5 realms x 12) in `Naming`, same storybook register as the puzzle names. Thornwick, Brackenmere, Saltreach, Hollowdeep, Emberfell and The Crown Isles become the first six for one realm.
- `StopState`: `.solved`, `.skipped` (unsolved with a solved puzzle after it), `.current` (first unsolved after the furthest solve, falling back to the first skipped), `.ahead`. Province state: `.finished` (all 20 solved, castle inked), `.visited` (behind the traveller with skips), `.current`, `.next`, `.uncharted`.
- `ProgressStore.journeySeen: [String: Int]` (per realm, saved in the progress file, not synced): the solved count the map last drew. When the store's count is higher on appear, the province view plays the travel animation once and updates it. This works whatever route the solve came from (Next puzzle, back button, the other device).
- `Layout`: deterministic stop positions per province from a seed (`size * 100 + index`), ported from the mockup's `xR(y)` road curve and 90pt bands. Pure functions, so they can be checked without UI.

## Drawing kit (phase 2)

New folder `Atlas/`. Port the mockup primitives to `Path` builders with a seeded generator (`SplitMix64`, seeded per feature so a hill keeps its shape):
- jittered polyline, pressure stroke (filled variable-width path), hatching
- hills, trees, marsh tufts, waves, castle (pencil and inked states), stop ring, red dashed road
- cartouche banner, compass, ship (reuse `CompassRose` where it fits)

Rendering: one `Canvas` per layer. Wash layer runs through `washBleed` + `granulate`; ink layer through `inkWobble`; pencil layer at pencil-grey opacity with no wobble. The static terrain for a province is rendered once into an image with `ImageRenderer` and cached per (realm, province, inked or pencil), because Canvas plus three shaders over a 1000pt-tall sheet is too slow to redraw during scroll. Dynamic parts (road reveal, seal, labels, castle bloom) stay live views on top.

Ink and pencil split: both cached images are stacked; the inked one is masked by a rectangle whose top edge is a blurred, wobbled boundary at the current stop's y. Moving that boundary is the inking animation (the mockup's `mInk`/`mSk` masks and `.shift` translate).

New pattern: Atlas drawing kit, because the maps need terrain, roads and castles that nothing in the app draws today.

## Realm screen (phase 3)

`Views/RealmMapView.swift`, replacing the grid at `Route.realm(size)`:
- Scrolling sheet of 12 province bands, cartouche with the realm name and "a realm in twelve provinces", compass, ship on the sea crossing.
- Finished provinces inked with their castle; the current one inked up to the current stop; the rest pencilled, labelled "next" or "Uncharted".
- Slim pill card pinned to the bottom ("No. 38 · Brackenmere", puzzle name, Continue). New pattern: slim map card, because the full `ContinueCard` hides a province band; it reuses `ContinueCard`'s content and `PillButtonStyle`.
- Tap a province: `Route.province(size, index)` (new case in `Route`, handled in `RootView`).
- Scrolls to the current province on appear, same as `RealmView` does with `ScrollViewReader`.

## Province screen (phase 4)

`Views/ProvinceMapView.swift`:
- 20 stops on the road, names from `Puzzle.name`, current stop with the wax seal (`WaxSeal`, wax tokens stay confined to it), castle at the end.
- Tap a stop: `Route.puzzle(id)`. Ahead stops are tappable too, as the grid is today; skipped stops show an open ring.
- Each stop is an accessibility button: "Puzzle 38, The Umber Moor, current".
- `RootView`'s restore path becomes `[.realm, .province, .puzzle]` so Back from a resumed game lands on the map.

## Travel animation (phase 5)

`Atlas/Travel.swift`, timings in a `Travel` enum in `Model/SolveTiming.swift` (from the mockup, total about 3s):

| ms | layer |
|---|---|
| 200 to 900 | castle blooms at the old stop (only when a province finishes) |
| 600 to 1700 | seal travels the road; red dash revealed behind it |
| 900 to 2600 | ink boundary moves up to the new stop |
| 1500 to 1900 | "Uncharted" fades |
| 1800 | card updates to the new puzzle |
| 1900 to 2900 | new name is written on (clip reveal) |

- Always-mounted layers driven by `keyframeAnimator(trigger:)`, per the Coronation rule.
- Haptics and sound through `Haptics` in the same pattern as the royal road: a light footstep per road segment, a bell when the name finishes; finishing a province gets the heavy seal press and a bell chord.
- Reduce Motion: jump to the end state, no footsteps, card cross-fades.
- After a solve, GameView's "Next puzzle" stays. Add "To the map" beside it, which pops to the province so the travel plays. Next puzzle still bumps `lastSeenSolved` the next time the map appears, so the animation plays then.

## Home (phase 6, optional)

`RealmCard` swaps `MiniBoard` for a small crop of the realm's current province image from the cache. Progress bar and "x of 240 crowned" stay.

## Order and size

| PR | Contents | Notes |
|---|---|---|
| 1 | Journey model, province names, `lastSeenSolved`, layout functions | No UI change. Add a small `QueensTests` target for state and layout |
| 2 | Atlas kit + IM Fell + Atlas tokens, a DEBUG-only gallery screen | Compare against mockup screenshots |
| 3 | Realm screen + `Route.province` | Grid stays reachable behind a DEBUG flag until 4 lands |
| 4 | Province screen, grid removed, restore path | |
| 5 | Travel animation, haptics, sound | `make_sounds.py` if a new bell is needed |
| 6 | Home card thumbnail | |

Each PR: simulator build on the Mac, `simctl io screenshot` of the new screen next to the mockup PNG, and DESIGN.md (Signature Components, Motion table) plus PATTERNS.md (new patterns log) updated in the same PR. The hint checker is not affected (no HintEngine change).

## Risks

- Performance of three shaders over a tall sheet: mitigated by the `ImageRenderer` cache; measure on Moses Beacon in PR 2.
- Cache invalidation is never needed: terrain depends only on the seed, so cache files can be generated on first view and kept in Caches.
- Blocked on the Mac: it has been offline since before this plan, and `feat/pin-rewind` is also still unbuilt.
