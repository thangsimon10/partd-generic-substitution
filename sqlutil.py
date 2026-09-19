"""Split a .sql file into statements safely.

Two things break the naive split(';'):
  1. a -- comment containing a semicolon (good comments contain prose)
  2. a quoted identifier containing one - the Orange Book really does have a
     column called "DF;Route"
So this tracks single quotes AND double quotes, and strips comments first.
Comments stay in the file for the reader; they are only removed for splitting.
"""
import pathlib

def statements(path):
    raw = pathlib.Path(path).read_text()
    out, buf = [], []
    sq = dq = False          # inside '...' / "..."
    i, n = 0, len(raw)
    while i < n:
        ch = raw[i]
        if not sq and not dq and ch == '-' and i + 1 < n and raw[i+1] == '-':
            while i < n and raw[i] != '\n':
                i += 1
            continue
        if ch == "'" and not dq:
            sq = not sq
        elif ch == '"' and not sq:
            dq = not dq
        if ch == ';' and not sq and not dq:
            out.append(''.join(buf)); buf = []
        else:
            buf.append(ch)
        i += 1
    if ''.join(buf).strip():
        out.append(''.join(buf))
    return [s.strip() for s in out if s.strip()]

def run(con, path, params=None):
    for s in statements(path):
        if params and any(f"${k}" in s for k in params):
            con.execute(s, params)
        else:
            con.execute(s)
