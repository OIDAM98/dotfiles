#!/bin/sh
# Helix formatter wrapper for sqruff.
# - sqruff exits 1 when unfixable lint issues remain (e.g. long lines) even though the
#   formatted SQL is on stdout, and Helix treats any non-zero exit as a failure.
# - sqruff prints its lint report to stderr, which Helix also treats as a failure.
# So: always exit 0, hide stderr, and fall back to the untouched input if sqruff
# produced nothing (so a crash can never empty the buffer).
tmp=$(mktemp) || exit 0
cat > "$tmp"
out=$(sqruff fix - < "$tmp" 2>/dev/null)
if [ -n "$out" ]; then printf '%s\n' "$out"; else cat "$tmp"; fi
rm -f "$tmp"
