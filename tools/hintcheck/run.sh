#!/bin/bash
# Runs on the Mac (needs swiftc). Extracts the Puzzle struct without PuzzleLibrary's Bundle lookup.
set -e
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
sed '/^final class PuzzleLibrary/,$d' app/Queens/Model/Puzzle.swift > "$tmp/Puzzle.swift"
sed -i '' 's/var name: String.*//' "$tmp/Puzzle.swift" 2>/dev/null || sed -i 's/var name: String.*//' "$tmp/Puzzle.swift"
swiftc -O -o "$tmp/hintcheck" tools/hintcheck/main.swift "$tmp/Puzzle.swift" app/Queens/Model/HintEngine.swift
"$tmp/hintcheck" app/Queens/Resources/puzzles.json
