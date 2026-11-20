# Crowns

Crowns: offline crown-placing logic puzzle (Queens genre) for iPhone. Internal names (target, folders, bundle id `cc.jaym.queens`) stay Queens so iCloud progress survives. SwiftUI, iOS 17, xcodegen (`app/project.yml`).

Before touching UI, read DESIGN.md and PATTERNS.md and reuse the exemplar files.

- Puzzles: `python3 tools/generate.py 120` writes `app/Queens/Resources/puzzles.json` (about 25 min, size 11 is most of it).
- More puzzles without disturbing progress: `python3 tools/generate.py --sets 2 7 8 9` appends two sets of 120 to sizes 7 to 9 with new ids (30 s). A size past 240 gets a second realm chart; give it 12 more province names in `Naming.swift`.
- Icon and colour assets: `python3 tools/make_assets.py`.
- Sounds: `python3 tools/make_sounds.py` writes the WAVs to `app/Queens/Resources/Sounds` (needs numpy, under a second).
- Build: `cd app && xcodegen generate`, then build the Queens scheme in Xcode or with xcodebuild.
- Hints: `tools/hintcheck/run.sh` (needs swiftc) plays every puzzle from hints alone and must report 0 failures after any HintEngine change.
- Machine-specific build notes live in CLAUDE.local.md (gitignored).
