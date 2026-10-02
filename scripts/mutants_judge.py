#!/usr/bin/env python3
"""cargo-mutants 결과 판정 — 면제 목록 밖의 살아남은 뮤턴트가 0 이어야 한다.

면제 목록 tests/mutants/exempt.toml (사람만 고친다):
    [[exempt]]
    crate = "jamulsoe-core"
    mutant = "정규식 — missed.txt 한 줄에서 위치(:줄:열:)를 뺀 문자열에 search"
    reason = "왜 테스트로 관측할 수 없는가 (동치 뮤턴트, Drop 제로화 등)"
    approved_by = "승인한 사람"

면제 항목이 아무 뮤턴트에도 맞지 않으면 경고한다 (낡은 면제는 지운다).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import tomllib
from pathlib import Path

LOC = re.compile(r":\d+:\d+:")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--crate", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--exempt", required=True)
    ap.add_argument("--incremental", action="store_true")
    a = ap.parse_args()
    out = Path(a.out)

    d = json.loads((out / "outcomes.json").read_text(encoding="utf-8"))
    total = d.get("total_mutants", 0)
    print(f"    전체 {total} · 잡힘 {d.get('caught', 0)} · 살아남음 {d.get('missed', 0)} · "
          f"시간초과 {d.get('timeout', 0)} · 무효 {d.get('unviable', 0)}")
    if total == 0 and not a.incremental:
        print("    ✗ 뮤턴트 0개 — 아무것도 시험하지 않았습니다", file=sys.stderr)
        return 1

    rules = []
    ep = Path(a.exempt)
    if ep.exists():
        for i, r in enumerate(tomllib.loads(ep.read_text(encoding="utf-8")).get("exempt", [])):
            if r.get("crate") != a.crate:
                continue
            if not all(str(r.get(k, "")).strip() for k in ("mutant", "reason", "approved_by")):
                print(f"    ✗ 면제 항목 {i}: mutant·reason·approved_by 가 모두 있어야 합니다", file=sys.stderr)
                return 1
            rules.append([re.compile(r["mutant"]), r, 0])

    missed_file = out / "missed.txt"
    missed = [ln for ln in missed_file.read_text(encoding="utf-8").splitlines() if ln.strip()] if missed_file.exists() else []
    bad = []
    for ln in missed:
        key = LOC.sub(":", ln)
        hit = next((r for r in rules if r[0].search(key)), None)
        if hit:
            hit[2] += 1
        else:
            bad.append(ln)
    for rx, r, n in rules:
        if n:
            print(f"    · 면제 {n}건: {r['mutant']} — {r['reason']} (승인 {r['approved_by']})")
        elif not a.incremental:
            print(f"    ▲ 쓰이지 않는 면제: {r['mutant']} — 낡았으면 사람이 지웁니다")
    for ln in bad:
        print(f"    ✗ 살아남음: {ln}", file=sys.stderr)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
