#!/usr/bin/env bash
# 경계 규약 (C5-01~04, C5-07, C5-10) — 판정은 lint_boundary.py 에 있다.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need python3
exec python3 "$ROOT/scripts/lint_boundary.py" --root "$ROOT" --boundary "$BOUNDARY_CRATES" --harness "$HARNESS_CRATES"
