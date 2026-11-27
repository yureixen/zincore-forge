#!/usr/bin/env python3
import os
import re
import sys

DECL = re.compile(r'^\s*(#|extern\b|/\*|\*|//|$)')
CODE_TRIES = [(3, 3), (3, 2), (3, 1), (3, 0), (2, 2), (2, 1), (1, 2)]
DECL_TRIES = CODE_TRIES + [(2, 0), (1, 1), (1, 0), (0, 3), (0, 2), (0, 1)]


def parse(rej):
    hunks, cur = [], None
    with open(rej, encoding='utf-8', errors='surrogateescape') as f:
        for ln in f.read().split('\n'):
            if ln.startswith('@@'):
                cur = []
                hunks.append(cur)
            elif cur is not None and ln[:1] in (' ', '+', '-'):
                cur.append((ln[0], ln[1:]))
    return hunks


def runs_of(hunk):
    """yield (context_before, added_lines, context_after) for every contiguous '+' run"""
    out, ctx, i = [], [], 0
    while i < len(hunk):
        t, s = hunk[i]
        if t == ' ':
            ctx.append(s)
            i += 1
            continue
        add = []
        while i < len(hunk) and hunk[i][0] == '+':
            add.append(hunk[i][1])
            i += 1
        after, j = [], i
        while j < len(hunk) and hunk[j][0] == ' ' and len(after) < 3:
            after.append(hunk[j][1])
            j += 1
        out.append((ctx, add, after))
        ctx = []
    return out


def find(lines, seq):
    n = len(seq)
    return [k for k in range(len(lines) - n + 1) if lines[k:k + n] == seq]


def place(lines, before, add, after):
    """insert add into lines in place; return True when placed"""
    tries = DECL_TRIES if all(DECL.match(a) for a in add) else CODE_TRIES
    for nb, na in tries:
        if len(before) < nb or len(after) < na:
            continue
        seq = (before[-nb:] if nb else []) + after[:na]
        if not any(s.strip() for s in seq):
            continue
        hits = find(lines, seq)
        if len(hits) == 1:
            pos = hits[0] + nb
            lines[pos:pos] = add
            return True
    return False


def main(rej):
    target = rej[:-4]
    hunks = parse(rej)
    if not hunks:
        return 1
    for h in hunks:
        if any(t == '-' for t, _ in h):
            print(f"-- recover: {rej}: hunk removes lines, not recoverable", file=sys.stderr)
            return 1
    with open(target, encoding='utf-8', errors='surrogateescape') as f:
        lines = f.read().split('\n')
    for h in hunks:
        carry = []
        for ctx, add, after in runs_of(h):
            carry = (carry + ctx)[-3:] if ctx else carry
            if find(lines, add):
                print(f"-- recover: {target}: addition already present, skipped")
                carry = (carry + add)[-3:]
                continue
            if not place(lines, carry, add, after):
                print(f"-- recover: {target}: no unique anchor for an addition", file=sys.stderr)
                return 1
            carry = (carry + add)[-3:]
    tmp = target + '.recover'
    with open(tmp, 'w', encoding='utf-8', errors='surrogateescape') as f:
        f.write('\n'.join(lines))
    os.replace(tmp, target)
    os.remove(rej)
    print(f"-- recover: applied addition-only hunk(s) to {target}")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
