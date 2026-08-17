#!/usr/bin/env bash
# {{T_REPO_EVALS_INTRO}}
set -u

passed=0
failed=0
ok() { printf 'PASS %s\n' "$1"; passed=$((passed + 1)); }
ko() { printf 'FAIL %s\n' "$1"; failed=$((failed + 1)); }
ev() { printf '     | %s\n' "$1"; }

# {{T_REPO_EVALS_SLOT}}

printf '{{T_REPO_EVALS_SUMMARY}}\n' "$passed" "$failed"
[ "$failed" = "0" ]
