#!/usr/bin/env python3
import re, sys, os

SAFE = re.compile(r'^\s*(#|extern\b|/\*|\*|//|$)')

def parse(rej):
    hunks, cur = [], None
    for ln in open(rej, encoding='utf-8', errors='surrogateescape').read().split('\n'):
        if ln.startswith('@@'):
            cur = []; hunks.append(cur)
        elif cur is not None and ln[:1] in (' ', '+', '-'):
            cur.append((ln[0], ln[1:]))
    return hunks

def runs_of(hunk):
    """yield (preceding_context_lines, added_lines) for every contiguous '+' run"""
    ctx, i, out = [], 0, []
    while i < len(hunk):
        t, s = hunk[i]
        if t == ' ':
            ctx.append(s); i += 1
        else:
            add = []
            while i < len(hunk) and hunk[i][0] == '+':
                add.append(hunk[i][1]); i += 1
            out.append((list(ctx), add))
            ctx = []
    return out

def find_unique(lines, seq):
    n = len(seq)
    hits = [k for k in range(len(lines) - n + 1) if lines[k:k+n] == seq]
    return hits

def main(rej):
    target = rej[:-4]
    hunks = parse(rej)
    if not hunks:
        return 1
    for h in hunks:
        if any(t == '-' for t, _ in h):
            print(f"-- recover: {rej}: hunk removes lines, not recoverable", file=sys.stderr); return 1
        if any(not SAFE.match(s) for t, s in h if t == '+'):
            print(f"-- recover: {rej}: hunk adds code (not only declarations), not recoverable", file=sys.stderr); return 1
    lines = open(target, encoding='utf-8', errors='surrogateescape').read().split('\n')
    for h in hunks:
        carry = []
        for ctx, add in runs_of(h):
            carry = (carry + ctx)[-3:] if ctx else carry
            nonblank = [a for a in add if a.strip()]
            if all(a in lines for a in nonblank):
                print(f"-- recover: {target}: addition already present, skipped")
                continue
            placed = False
            for take in (3, 2, 1):
                seq = carry[-take:]
                if len(seq) < take or not any(s.strip() for s in seq):
                    continue
                hits = find_unique(lines, seq)
                if len(hits) == 1:
                    pos = hits[0] + take
                    lines[pos:pos] = add
                    carry = carry + add
                    carry = carry[-3:]
                    placed = True
                    break
                if len(hits) > 1:
                    break
            if not placed:
                print(f"-- recover: {target}: no unique anchor for an addition", file=sys.stderr); return 1
    open(target, 'w', encoding='utf-8', errors='surrogateescape').write('\n'.join(lines))
    os.remove(rej)
    print(f"-- recover: applied addition-only hunk(s) to {target}")
    return 0

sys.exit(main(sys.argv[1]))
