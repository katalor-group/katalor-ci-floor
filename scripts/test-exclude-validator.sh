#!/usr/bin/env bash
# Self-test for the exclude_paths_file validator in weekly-full-history-sweep.yml. It extracts the step's own `run:` block
# (by step id) and executes THAT, so the code under test is the code that ships, not a copy. Needs yq and bash.
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
wf="$here/.github/workflows/weekly-full-history-sweep.yml"
body="$(yq '.jobs.sweep.steps[] | select(.id == "validate_exclude") | .run' "$wf")"
[ -n "$body" ] || { echo "validator step not found"; exit 2; }

work="$(cd -P "$(mktemp -d)" && pwd -P)"; trap 'rm -rf "$work" "${ext:-}"' EXIT
cd "$work"; mkdir -p .github sub
failures=0
run() { EXCLUDE_FILE="$1" WORKSPACE="$work" bash -c "$body" >"$work/out.txt" 2>&1; }
expect_pass() { if run "$2"; then echo "ok   $1"; else echo "FAIL $1 (expected accept)"; cat out.txt; failures=$((failures+1)); fi; }
# A refusal only counts if the validator itself rejected it (its ::error annotation), not some incidental shell error.
expect_fail() {
  if run "$2"; then echo "FAIL $1 (expected refusal)"; failures=$((failures+1))
  elif grep -q 'exclude_paths_file rejected' out.txt; then echo "ok   $1 (refused)"
  else echo "FAIL $1 (failed, but not by the validator)"; cat out.txt; failures=$((failures+1)); fi
}

printf '%s\n' '^services/portal/shared/a-b_c\.test\.ts$' '' '^x/y\.z$' > good.txt
expect_pass "anchored literal paths, blank line allowed" good.txt
grep -q 'services/portal/shared/a-b_c' out.txt && echo "ok   file printed in full" || { echo "FAIL file not printed"; failures=$((failures+1)); }

printf '%s\n' '^src/.*$' > wild.txt;               expect_fail "wildcard .*" wild.txt
printf '%s\n' '^src/.+$' > plus.txt;               expect_fail "wildcard .+" plus.txt
printf '%s\n' '^src/*$' > star.txt;                expect_fail "bare *" star.txt
printf '%s\n' '^src/[a-z]+$' > class.txt;          expect_fail "character class" class.txt
printf '%s\n' '^a$|^b$' > alt.txt;                 expect_fail "alternation" alt.txt
printf '%s\n' '^src/a.test.ts$' > dot.txt;         expect_fail "unescaped dot" dot.txt
printf '%s\n' 'src/a\.ts$' > noanchor1.txt;       expect_fail "no leading ^" noanchor1.txt
printf '%s\n' '^src/a\.ts' > noanchor2.txt;        expect_fail "no trailing \$" noanchor2.txt
printf '%s\n' '# comment' > comment.txt;           expect_fail "comment line" comment.txt
printf '%s\n' '^src/a\.ts$' > ok1.txt; ln -s ok1.txt link.txt; expect_fail "symlink" link.txt
ext="$(mktemp -d)"; printf '%s\n' '^src/a\.ts$' > "$ext/real.txt"; ln -s "$ext" sub/dirlink; expect_fail "symlinked directory component" sub/dirlink/real.txt
expect_fail "path with .." sub/../good.txt
expect_fail "absolute path" "$work/good.txt"
expect_fail "space in path" "good .txt"
expect_fail "missing file" nope.txt
expect_fail "directory" sub
expect_fail "leading dash" -good.txt
for i in $(seq 1 21); do printf '^f%s\\.ts$\n' "$i"; done > l21.txt; expect_fail "21 lines" l21.txt
head -20 l21.txt > l20.txt;                        expect_pass "20 lines" l20.txt

[ "$failures" -eq 0 ] && echo "all validator cases behaved" || { echo "$failures case(s) wrong"; exit 1; }
