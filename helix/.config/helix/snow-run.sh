#!/bin/sh
# Run SQL on Snowflake with `snow sql` and save the results under
# /tmp/snow-results/. The path to open goes into /tmp/snow-results/.last.
#
# Usage:
#   snow-run.sh <file.sql>                      run the whole file
#   snow-run.sh --selection <buffer_name>       SQL from stdin (a Helix selection)
#   snow-run.sh --statement <file.sql> <line>   the statement around <line> (1-based)
#   snow-run.sh --background <file.sql>         whole file, no terminal timer; sends a
#                                               macOS notification when it finishes
#
# Foreground runs show a live "running" line on the bottom row of the terminal.
# The query runs once (as JSON); both formats are rendered from that run:
#   <name>_result.txt  always: every result set as a grid (first 1000 rows each),
#                      plus status lines and errors
#   <name>_result.csv  also, when the LAST statement returned data rows (full set)
# .last points at the .csv when it exists (data came back), otherwise the .txt.
# <name> gets a _selection / _statement suffix for those modes.
# Set SNOW_RUN_NO_NOTIFY=1 to skip the notification.
#
# Nothing account-specific lives in this file. Connection, role and warehouse come
# from the snow CLI's default connection (~/.snowflake/connections.toml) unless you
# override them in ~/.config/snow-run/env (per machine, git-ignored; copy
# snow-run.env.example from this folder), e.g.:
#   SNOW_RUN_CONNECTION=default
#   SNOW_RUN_ROLE=MY_ROLE
#   SNOW_RUN_WAREHOUSE=MY_WH
# (or set the same variables in the environment, or point SNOW_RUN_CONF elsewhere).

dir=/tmp/snow-results
mkdir -p "$dir"

conf="${SNOW_RUN_CONF:-$HOME/.config/snow-run/env}"
[ -r "$conf" ] && . "$conf"
extra=""
[ -n "$SNOW_RUN_CONNECTION" ] && extra="$extra --connection $SNOW_RUN_CONNECTION"
[ -n "$SNOW_RUN_ROLE" ] && extra="$extra --role $SNOW_RUN_ROLE"
[ -n "$SNOW_RUN_WAREHOUSE" ] && extra="$extra --warehouse $SNOW_RUN_WAREHOUSE"

bg=""
if [ "$1" = "--background" ]; then bg=1; shift; fi

nothing() { # $1 = message
  printf -- '-- %s\n' "$1" > "$dir/${label}_result.txt"
  printf '%s\n' "$dir/${label}_result.txt" > "$dir/.last"
  rm -f "$f"
  exit 0
}

case "$1" in
  --selection)
    [ -n "$2" ] || { echo "usage: snow-run.sh --selection <buffer_name>" >&2; exit 2; }
    label="$(basename "$2" .sql)_selection"
    f="$dir/.$label.sql"
    cat > "$f"
    # Helix always has a 1-character selection; that means nothing was selected.
    [ "$(tr -d '[:space:]' < "$f" | wc -c)" -le 1 ] && nothing "Nothing selected. Select the SQL to run, then try again."
    tmpf=1
    ;;
  --statement)
    [ -n "$2" ] && [ -n "$3" ] || { echo "usage: snow-run.sh --statement <file.sql> <line>" >&2; exit 2; }
    label="$(basename "$2" .sql)_statement"
    f="$dir/.$label.sql"
    python3 - "$2" "$3" > "$f" <<'PY'
import sys

src = open(sys.argv[1], errors="replace").read()
line = int(sys.argv[2])
n = len(src)

# Split on ';' that are outside comments, quotes and $$ blocks.
chunks, start, code, i = [], 0, False, 0
while i < n:
    c = src[i]
    if src.startswith("--", i) or src.startswith("//", i):
        j = src.find("\n", i)
        i = n if j < 0 else j
    elif src.startswith("/*", i):
        j = src.find("*/", i + 2)
        i = n if j < 0 else j + 2
    elif c in ("'", '"'):
        i += 1
        while i < n:
            if c == "'" and src[i] == "\\":
                i += 2
                continue
            if src[i] == c:
                if src[i + 1:i + 2] == c:
                    i += 2
                    continue
                break
            i += 1
        i += 1
        code = True
    elif src.startswith("$$", i):
        j = src.find("$$", i + 2)
        i = n if j < 0 else j + 2
        code = True
    elif c == ";":
        chunks.append((start, i + 1, code))
        start, code, i = i + 1, False, i + 1
    else:
        if not c.isspace():
            code = True
        i += 1
if start < n:
    chunks.append((start, n, code))

found = []
for s, e, has_code in chunks:
    text = src[s:e]
    if not text.strip():
        continue
    fs = s + len(text) - len(text.lstrip())
    first = src.count("\n", 0, fs) + 1
    last = src.count("\n", 0, max(e - 1, fs)) + 1
    found.append((first, last, text.strip(), has_code))

pick = next((x for x in found if x[0] <= line <= x[1]), None)
if pick is None:  # on a blank line: prefer the statement above, else the one below
    above = [x for x in found if x[1] < line]
    below = [x for x in found if x[0] > line]
    pick = above[-1] if above else (below[0] if below else None)
if pick and pick[3]:
    print(pick[2])
PY
    [ -s "$f" ] || nothing "No SQL statement found at line $3."
    tmpf=1
    ;;
  *)
    f="$1"
    [ -n "$f" ] || { echo "usage: snow-run.sh <file.sql> | --selection <buffer_name> | --statement <file.sql> <line> | --background <file.sql>" >&2; exit 2; }
    label=$(basename "$f" .sql)
    tmpf=""
    ;;
esac

name="$label"
base="$dir/${name}_result"
json="$dir/.$name.json"
err="$dir/.$name.err"

status() { [ -n "$bg" ] || { printf '\033[s\033[999;1H\033[K%s\033[u' "$1" > /dev/tty; } 2>/dev/null; }

snow sql --silent --format json $extra -f "$f" < /dev/null > "$json" 2> "$err" &
pid=$!

s=0
while kill -0 "$pid" 2>/dev/null; do
  status "$(printf '  Running %s on Snowflake... %02d:%02d' "$name" $((s / 60)) $((s % 60)))"
  sleep 1
  s=$((s + 1))
done
wait "$pid"
code=$?
status ""

rm -f "$base.txt" "$base.csv"
target=$(python3 - "$json" "$err" "$code" "$base" <<'PY'
import csv, json, sys

jf, ef, code, base = sys.argv[1:5]
raw = open(jf, errors="replace").read()
err = open(ef, errors="replace").read().strip()
code = int(code)
CAP = 1000

# One statement -> a flat array of row objects. Several statements -> an array
# of those arrays. A failed run leaves truncated JSON, so try closing it.
sets, bad = [], False
if raw.strip():
    val = None
    for tail in ("", "]", "\n]"):
        try:
            val = json.loads(raw + tail)
            break
        except ValueError:
            continue
    if val is None:
        bad = True
    elif val and all(isinstance(x, list) for x in val):
        sets = val
    elif val:
        sets = [val]

def cell(v):
    return "NULL" if v is None else str(v)

def grid(rows):
    cols = list(rows[0].keys())
    body = [[cell(r.get(c)) for c in cols] for r in rows[:CAP]]
    w = [max(len(str(c)), *(len(b[k]) for b in body)) for k, c in enumerate(cols)]
    line = "+" + "+".join("-" * (x + 2) for x in w) + "+"
    fmt = lambda vals: "| " + " | ".join(str(v).ljust(w[k]) for k, v in enumerate(vals)) + " |"
    out = [line, fmt(cols), line] + [fmt(b) for b in body] + [line]
    return "\n".join(out)

def is_status(rows):
    return len(rows) == 1 and list(rows[0].keys()) == ["status"]

parts = []
for n, rows in enumerate(sets, 1):
    if not isinstance(rows, list) or not rows:
        parts.append(f"-- result {n}/{len(sets)}: 0 rows")
    elif is_status(rows):
        parts.append(f"-- result {n}/{len(sets)}: " + cell(rows[0]["status"]))
    else:
        extra = f" (showing first {CAP}; full set in the .csv)" if len(rows) > CAP else ""
        parts.append(f"-- result {n}/{len(sets)}: {len(rows)} rows{extra}\n" + grid(rows))
if bad:
    parts.append("-- could not parse snow output as JSON; raw output:\n" + raw)
if err:
    parts.append("-- snow reported:\n" + err)
elif code != 0:
    parts.append(f"-- snow exited with code {code}")
if not parts:
    parts.append("-- no output")
open(base + ".txt", "w").write("\n\n".join(parts) + "\n")

last = sets[-1] if sets else None
if code == 0 and not bad and isinstance(last, list) and last and not is_status(last):
    cols = list(last[0].keys())
    with open(base + ".csv", "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(cols)
        for r in last:
            w.writerow(["" if r.get(c) is None else r.get(c) for c in cols])
    print(base + ".csv")
else:
    print(base + ".txt")
PY
)
rm -f "$json" "$err"
[ -n "$tmpf" ] && rm -f "$f"
printf '%s\n' "$target" > "$dir/.last"

if [ -n "$bg" ]; then
  mins=$((s / 60)); secs=$((s % 60))
  if [ "$code" -eq 0 ]; then verb="finished"; else verb="FAILED"; fi
  msg=$(printf '%s %s in %02d:%02d' "$name" "$verb" "$mins" "$secs" | tr -d '"\\')
  file=$(basename "$target")
  if [ -z "$SNOW_RUN_NO_NOTIFY" ] && command -v osascript > /dev/null 2>&1; then
    osascript -e "display notification \"$file\" with title \"Snowflake: $msg\"" > /dev/null 2>&1
  fi
  printf '%s -> %s (space n o to open)\n' "$msg" "$target"
fi
exit 0
