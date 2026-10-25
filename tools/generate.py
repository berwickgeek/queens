#!/usr/bin/env python3
"""Generate Queens puzzles for sizes 7 to 11.

Each puzzle: an N x N grid split into N connected regions with exactly one valid
placement of N queens (one per row, column and region, no two touching, including
diagonally). Every kept puzzle is solvable by the logic rules in `logic_solve`
without guessing; the rules it needed give the difficulty score.

Output: app/Queens/Resources/puzzles.json
"""
import json
import os
import random
import sys
from multiprocessing import Pool

DIRS4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


def random_solution(n, rng):
    """Random column-per-row placement with no two queens adjacent."""
    cols = []
    used = set()

    def bt(r):
        if r == n:
            return True
        opts = list(range(n))
        rng.shuffle(opts)
        for c in opts:
            if c in used:
                continue
            if r and abs(cols[-1] - c) <= 1:
                continue
            cols.append(c)
            used.add(c)
            if bt(r + 1):
                return True
            cols.pop()
            used.discard(c)
        return False

    bt(0)
    return cols


def grow_regions(n, sol, rng):
    """Flood-fill N regions from the queen cells with uneven growth rates."""
    grid = [[-1] * n for _ in range(n)]
    weights = [rng.uniform(0.3, 3.0) for _ in range(n)]
    for r, c in enumerate(sol):
        grid[r][c] = r
    unassigned = n * n - n
    while unassigned:
        reg = rng.choices(range(n), weights=weights)[0]
        frontier = []
        for r in range(n):
            for c in range(n):
                if grid[r][c] == reg:
                    for dr, dc in DIRS4:
                        rr, cc = r + dr, c + dc
                        if 0 <= rr < n and 0 <= cc < n and grid[rr][cc] == -1:
                            frontier.append((rr, cc))
        if not frontier:
            weights[reg] = 0.0001
            continue
        rr, cc = rng.choice(frontier)
        grid[rr][cc] = reg
        unassigned -= 1
    return grid


def solutions(n, grid, limit=2):
    """Count solutions up to `limit`. Returns list of solutions (column lists)."""
    found = []
    cols = [0] * n

    def bt(r, used_cols, used_regs, prev):
        if len(found) >= limit:
            return
        if r == n:
            found.append(cols[:])
            return
        row = grid[r]
        for c in range(n):
            if used_cols >> c & 1:
                continue
            if prev >= 0 and abs(prev - c) <= 1:
                continue
            g = row[c]
            if used_regs >> g & 1:
                continue
            cols[r] = c
            bt(r + 1, used_cols | 1 << c, used_regs | 1 << g, c)

    bt(0, 0, 0, -1)
    return found


def connected_without(n, grid, reg, cell):
    cells = [(r, c) for r in range(n) for c in range(n) if grid[r][c] == reg and (r, c) != cell]
    if not cells:
        return False
    seen = {cells[0]}
    stack = [cells[0]]
    cs = set(cells)
    while stack:
        r, c = stack.pop()
        for dr, dc in DIRS4:
            p = (r + dr, c + dc)
            if p in cs and p not in seen:
                seen.add(p)
                stack.append(p)
    return len(seen) == len(cells)


def make_unique(n, grid, sol, rng, max_iter=300):
    """Reassign cells until `sol` is the only solution."""
    queen_cells = {(r, c) for r, c in enumerate(sol)}
    for _ in range(max_iter):
        sols = solutions(n, grid, 2)
        others = [s for s in sols if s != sol]
        if not others:
            return grid
        alt = others[0]
        cand = [(r, c) for r, c in enumerate(alt) if (r, c) not in queen_cells]
        rng.shuffle(cand)
        moved = False
        for r, c in cand:
            reg = grid[r][c]
            neigh = set()
            for dr, dc in DIRS4:
                rr, cc = r + dr, c + dc
                if 0 <= rr < n and 0 <= cc < n and grid[rr][cc] != reg:
                    neigh.add(grid[rr][cc])
            if not neigh or not connected_without(n, grid, reg, (r, c)):
                continue
            grid[r][c] = rng.choice(sorted(neigh))
            moved = True
            break
        if not moved:
            return None
    return None


# ---------- logic solver (difficulty rating) ----------

def neighbours8(n, r, c):
    for dr in (-1, 0, 1):
        for dc in (-1, 0, 1):
            if dr or dc:
                rr, cc = r + dr, c + dc
                if 0 <= rr < n and 0 <= cc < n:
                    yield rr, cc


class State:
    def __init__(self, n, grid):
        self.n = n
        self.grid = grid
        self.cand = {(r, c) for r in range(n) for c in range(n)}
        self.queens = set()

    def units(self):
        n = self.n
        out = []
        for r in range(n):
            out.append(("row", r, {(r, c) for c in range(n)}))
        for c in range(n):
            out.append(("col", c, {(r, c) for r in range(n)}))
        for g in range(n):
            out.append(("reg", g, {(r, c) for r in range(n) for c in range(n) if self.grid[r][c] == g}))
        return out

    def place(self, cell):
        r, c = cell
        self.queens.add(cell)
        g = self.grid[r][c]
        kill = {x for x in self.cand if x[0] == r or x[1] == c or self.grid[x[0]][x[1]] == g}
        kill |= set(neighbours8(self.n, r, c))
        self.cand -= kill

    def ok(self, units):
        for _, _, cells in units:
            if not (cells & self.queens) and not (cells & self.cand):
                return False
        return True


def logic_solve(n, grid):
    """Apply rules in order of difficulty. Returns (solved, max_tier, steps)."""
    st = State(n, grid)
    units = st.units()
    max_tier = 0
    steps = 0

    def open_units():
        return [(k, i, cells & st.cand) for k, i, cells in units if not (cells & st.queens)]

    while len(st.queens) < n:
        progressed = False
        # Tier 1: a unit with a single candidate.
        for k, i, cs in open_units():
            if len(cs) == 1:
                st.place(next(iter(cs)))
                max_tier = max(max_tier, 1)
                steps += 1
                progressed = True
                break
            if not cs:
                return False, max_tier, steps
        if progressed:
            continue
        # Tier 2: a unit's candidates all lie in one other unit -> clear the rest of it.
        ou = open_units()
        for k, i, cs in ou:
            for k2, i2, cells2 in units:
                if k2 == k or (cells2 & st.queens):
                    continue
                if cs <= cells2:
                    kill = (cells2 & st.cand) - cs
                    if kill:
                        st.cand -= kill
                        max_tier = max(max_tier, 2)
                        steps += 1
                        progressed = True
                        break
            if progressed:
                break
        if progressed:
            continue
        # Tier 3: cells that would wipe out a unit if a queen went there.
        for cell in sorted(st.cand):
            r, c = cell
            g = grid[r][c]
            hit = {x for x in st.cand if x[0] == r or x[1] == c or grid[x[0]][x[1]] == g}
            hit |= set(neighbours8(n, r, c))
            hit.add(cell)
            bad = False
            for k, i, cs in ou:
                if cell in cs:
                    continue
                if cs and cs <= hit:
                    bad = True
                    break
            if bad:
                st.cand.discard(cell)
                max_tier = max(max_tier, 3)
                steps += 1
                progressed = True
                break
        if progressed:
            continue
        # Tier 4: k regions confined to k rows (or cols) -> clear those rows of other regions.
        regs = [(i, cs) for k, i, cs in ou if k == "reg"]
        for axis in (0, 1):
            for size in range(2, 5):
                found = _confined(regs, axis, size)
                if found:
                    lines, members = found
                    kill = {x for x in st.cand if x[axis] in lines and grid[x[0]][x[1]] not in members}
                    if kill:
                        st.cand -= kill
                        max_tier = max(max_tier, 4)
                        steps += 1
                        progressed = True
                        break
            if progressed:
                break
        if progressed:
            continue
        # Tier 5: one-step lookahead. Place a queen tentatively, run tiers 1-2; contradiction -> eliminate.
        for cell in sorted(st.cand):
            if _contradicts(n, grid, st, cell, units):
                st.cand.discard(cell)
                max_tier = max(max_tier, 5)
                steps += 1
                progressed = True
                break
        if not progressed:
            return False, max_tier, steps
    return True, max_tier, steps


def _confined(regs, axis, size):
    from itertools import combinations
    small = [(i, {x[axis] for x in cs}) for i, cs in regs if 1 < len({x[axis] for x in cs}) <= size]
    for combo in combinations(small, size):
        lines = set().union(*(l for _, l in combo))
        if len(lines) == size:
            return lines, {i for i, _ in combo}
    return None


def _contradicts(n, grid, st, cell, units):
    t = State(n, grid)
    t.cand = set(st.cand)
    t.queens = set(st.queens)
    t.place(cell)
    for _ in range(n * 3):
        if not t.ok(units):
            return True
        if len(t.queens) == n:
            return False
        moved = False
        for k, i, cells in units:
            if cells & t.queens:
                continue
            cs = cells & t.cand
            if len(cs) == 1:
                t.place(next(iter(cs)))
                moved = True
                break
        if not moved:
            return False
    return not t.ok(units)


def score(n, tier, steps):
    return tier * 100 + steps


def make_one(args):
    n, seed = args
    rng = random.Random(seed)
    for _ in range(200):
        sol = random_solution(n, rng)
        grid = grow_regions(n, sol, rng)
        grid = make_unique(n, grid, sol, rng)
        if grid is None:
            continue
        solved, tier, steps = logic_solve(n, grid)
        if not solved:
            continue
        return {
            "size": n,
            "regions": "".join("abcdefghijk"[g] for row in grid for g in row),
            "solution": sol,
            "tier": tier,
            "score": score(n, tier, steps),
        }
    return None


def main():
    per_size = int(sys.argv[1]) if len(sys.argv) > 1 else 120
    out = {}
    with Pool(os.cpu_count()) as pool:
        for n in range(7, 12):
            # Over-generate so the set spans a range of difficulty.
            jobs = [(n, n * 1_000_000 + i) for i in range(int(per_size * 1.6))]
            got = [p for p in pool.map(make_one, jobs, chunksize=4) if p]
            seen = set()
            uniq = []
            for p in got:
                if p["regions"] not in seen:
                    seen.add(p["regions"])
                    uniq.append(p)
            uniq.sort(key=lambda p: p["score"])
            # Keep an even spread from easiest to hardest.
            if len(uniq) > per_size:
                step = len(uniq) / per_size
                uniq = [uniq[int(i * step)] for i in range(per_size)]
            for i, p in enumerate(uniq):
                p["id"] = f"{n}-{i + 1:03d}"
            out[str(n)] = uniq
            tiers = {}
            for p in uniq:
                tiers[p["tier"]] = tiers.get(p["tier"], 0) + 1
            print(f"size {n}: {len(uniq)} puzzles, tiers {dict(sorted(tiers.items()))}", flush=True)
    dest = os.path.join(os.path.dirname(__file__), "..", "app", "Queens", "Resources", "puzzles.json")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "w") as f:
        json.dump(out, f, separators=(",", ":"))
    print("wrote", os.path.abspath(dest))


if __name__ == "__main__":
    main()
