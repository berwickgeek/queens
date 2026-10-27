# Queens

An offline Queens puzzle game for iPhone, written in SwiftUI.

Each puzzle is an N by N grid split into N coloured kingdoms. Place one crown in every row, every column and every kingdom, with no two crowns touching, not even diagonally.

- 1,200 puzzles, 240 at each size from 7×7 to 11×11, every one with a unique solution. The first 120 per size run easy to hard; 121 to 240 are a second set of medium (tier 3) puzzles.
- Tap to cross a cell, tap again to crown it, drag to cross many at once.
- Stepped hints that teach the deduction instead of giving away the answer: "these three kingdoms fit inside rows 2 to 4, so dot everything else in those rows".
- Progress, timers and best times saved on device. No network, no accounts, no tracking.
- Light storybook look with haptics and a gilded finish when you solve a board.

## Build

Needs Xcode 15 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
cd app
xcodegen generate
open Queens.xcodeproj
```

To run on your own device, change `DEVELOPMENT_TEAM` and `PRODUCT_BUNDLE_IDENTIFIER` in `app/project.yml` to your own team and bundle id, then regenerate.

## Puzzles

`tools/generate.py` builds the puzzle set. Every puzzle it keeps has exactly one solution and can be solved by logic alone; the tier comes from the hardest rule needed.

```sh
python3 tools/generate.py 120   # writes app/Queens/Resources/puzzles.json, about 25 minutes
python3 tools/generate.py --extend 120 3   # appends 120 tier-3 puzzles per size, keeping existing ids
```

`tools/make_assets.py` regenerates the app icon and colour assets.

## Hints

`app/Queens/Model/HintEngine.swift` finds the easiest next deduction from the player's current marks, in this order: a kingdom, row or column down to one cell; a unit whose open cells all sit in one line; k kingdoms confined to k rows or columns; a cell whose crown would leave a kingdom empty; and finally a short forcing chain that ends in a contradiction.

`tools/hintcheck/run.sh` (needs `swiftc`) plays all 1,200 puzzles using only hints and checks that none get stuck or place a wrong mark.

## Licence

Code is MIT, see [LICENSE](LICENSE). The bundled fonts, Nunito Sans and Young Serif, are under the SIL Open Font License; their licence texts are in `app/Queens/Resources/Fonts/`.
