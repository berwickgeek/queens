# Queens

Offline Queens puzzle app for iPhone. SwiftUI, iOS 17, xcodegen (`app/project.yml`).

Before touching UI, read DESIGN.md and PATTERNS.md and reuse the exemplar files.

- Puzzles: `python3 tools/generate.py 120` writes `app/Queens/Resources/puzzles.json` (about 25 min, size 11 is most of it).
- Icon and colour assets: `python3 tools/make_assets.py`.
- Build: `cd app && xcodegen generate`, then build the Queens scheme in Xcode or with xcodebuild.
- Hints: `tools/hintcheck/run.sh` (needs swiftc) plays every puzzle from hints alone and must report 0 failures after any HintEngine change.
- Machine-specific build notes live in CLAUDE.local.md (gitignored).
