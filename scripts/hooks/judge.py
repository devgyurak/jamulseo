#!/usr/bin/env python3
"""보호 경로 판정 — guard-protected.sh 가 해석을 마친 입력으로 호출한다.

정책은 scripts/hooks/protected.tsv 하나에만 있다.

판정 모드:
  judge.py --rels <줄바꿈 구분 후보> --change A|M|D [--old <변경 전 파일>] [--new <변경 후 파일>]
    종료 0 허용 / 2 차단 (사유는 stderr) / 3 판정 실패 (호출자는 차단한다)
분류 모드:
  judge.py --classify <경로>     → 종류(human|new-only|append|registry|adr|free)를 stdout 에

변경 전 내용이 **없으면** 새 파일이다. 변경 후 내용이 없으면(삭제가 아니라) 판정할 수 없으므로 차단한다.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import adr_status  # noqa: E402

POLICY = os.path.join(HERE, "protected.tsv")
ADR_FINAL = ("채택", "대체됨", "기각")
ACK_RE = re.compile(r"^- \*\*방향 확인\*\*:(.*)$", re.M)
ACK_PENDING = "대기"


class Deny(Exception):
    pass


def fold(s: str) -> str:
    return unicodedata.normalize("NFKC", s).casefold()


def load_policy() -> list[tuple[str, str, str]]:
    rows = []
    with open(POLICY, encoding="utf-8") as fh:
        for ln in fh:
            if not ln.strip() or ln.startswith("#"):
                continue
            parts = ln.rstrip("\n").split("\t")
            if len(parts) != 3 or parts[1] not in ("human", "new-only", "append", "registry", "adr"):
                raise ValueError(f"protected.tsv 형식 오류: {ln.rstrip()}")
            rows.append((fold(parts[0]), parts[1], parts[2]))
    return rows


def classify(rel: str, policy) -> tuple[str, str]:
    r = fold(rel.removeprefix("./"))
    for pat, kind, why in policy:
        if fnmatch.fnmatchcase(r, pat):
            return kind, why
    return "free", ""


def read(path: str | None) -> str | None:
    if not path:
        return None
    with open(path, encoding="utf-8", errors="strict") as fh:
        return fh.read()


# ── 종류별 판정 ─────────────────────────────────────────────────────
def judge_new_only(change, old, new, why):
    if change == "A" and old is None:
        return
    raise Deny(why)


def judge_append(change, old, new, why):
    if change == "D":
        raise Deny(why)
    if old is None:
        return
    if new is None:
        raise Deny(why + " (변경 결과를 판정할 수 없음)")
    o, n = old.splitlines(), new.splitlines()
    if n[: len(o)] != o:
        raise Deny(why + "\n기존 줄이 그대로 앞에 있고 새 줄은 끝에만 붙어야 합니다.")


def ack_value(text: str) -> str | None:
    """머리말(제목 뒤 첫 --- 또는 ## 전)의 방향 확인 값. 머리말에 정규 줄이 정확히 하나여야 한다.

    없으면 None. 머리말에 '방향 확인' 이 들어간 줄이 둘 이상이거나 정규 형식이 아니면 Deny
    (두 번째 줄을 덧붙여 사람이 읽는 값과 판정 값이 갈리지 않게).
    """
    lines = text.splitlines()
    end = adr_status.header_end(lines)
    header = [ln for _, ln in adr_status.outside_fences(lines[:end])]
    hits = [ln for ln in header if "방향 확인" in unicodedata.normalize("NFKC", ln)]
    if not hits:
        return None
    if len(hits) > 1:
        raise Deny("ADR 머리말에 '방향 확인' 줄이 둘 이상입니다. 정확히 하나여야 합니다.")
    m = ACK_RE.match(hits[0])
    if not m:
        raise Deny(f"'방향 확인' 줄이 정규 형식이 아닙니다: {hits[0].strip()[:60]}\n정규 형식:  - **방향 확인**: 대기")
    return re.sub(r"<!--.*?-->", "", m.group(1)).strip()


def judge_adr(rel, change, old, new, why):
    if not adr_status.is_adr_path(rel):
        return  # README 등
    if change == "D":
        raise Deny("ADR 은 삭제하지 않습니다. 기각도 기록으로 남깁니다 (docs/adr/README.md).")
    cur = adr_status.judge(old) if old and old.strip() else ""
    if cur.startswith("INVALID"):
        raise Deny("변경 전 ADR 의 상태 표기가 정규 형식이 아니라 판정할 수 없습니다.\n" + cur[8:])
    if cur in ADR_FINAL:
        raise Deny(f"상태가 '{cur}' 인 ADR 은 수정할 수 없습니다. 바꿔야 하면 새 ADR 로 대체하세요.")
    if new is None:
        raise Deny("변경 결과를 판정할 수 없습니다.")
    nxt = adr_status.judge(new)
    if nxt.startswith("INVALID"):
        raise Deny("ADR 상태 표기가 정규 형식이 아닙니다: " + nxt[8:]
                   + "\n정규 형식:  - **상태**: 제안   (값: 제안 | 채택 | 대체됨(→ADR-XXXX) | 기각)")
    if nxt in ADR_FINAL:
        raise Deny(f"ADR 상태를 '{cur or '(새 파일)'}' → '{nxt}' 로 바꾸려 합니다. "
                   "채택·대체·기각 선언은 사람만 할 수 있습니다 (.agents/APPROVAL.md).")
    a_old = ack_value(old) if old else None
    a_new = ack_value(new)
    if old is None or not (old or "").strip():
        if a_new not in (None, ACK_PENDING):
            raise Deny("새 ADR 의 '방향 확인' 은 '대기' 여야 합니다. 방향 확인은 사람만 채웁니다.")
    elif a_new != a_old:
        raise Deny("ADR 의 '방향 확인' 필드는 사람만 고칩니다 (② HARNESS 진입 조건, .agents/WORKFLOW.md ①′).")


def _stages(entry: dict) -> list[dict]:
    st = entry.get("stages")
    if not isinstance(st, list):
        raise Deny(f"{entry.get('id')}: stages 가 배열이 아닙니다")
    return st


def judge_registry(change, old, new, why):
    if change == "D" or old is None:
        raise Deny("계약 레지스트리의 생성·삭제는 사람만 합니다.")
    if new is None:
        raise Deny("변경 결과를 판정할 수 없습니다.")
    try:
        o, n = json.loads(old), json.loads(new)
        oe = {e["id"]: e for e in o["entries"]}
        ne_list = n["entries"]
        ne = {e["id"]: e for e in ne_list}
    except (ValueError, KeyError, TypeError) as exc:
        raise Deny(f"레지스트리를 해석할 수 없습니다 ({exc}) — 판정 불가는 차단합니다.")
    if len(ne) != len(ne_list):
        raise Deny("레지스트리에 중복 ID 가 생깁니다.")
    for eid, oentry in oe.items():
        if eid not in ne:
            raise Deny(f"{eid}: 레지스트리 항목 삭제는 사람만 합니다.")
        os_, ns_ = _stages(oentry), _stages(ne[eid])
        if len(os_) != len(ns_):
            raise Deny(f"{eid}: 단계(stages) 수 변경은 사람만 합니다.")
        for a, b in zip(os_, ns_):
            if a.get("milestone") != b.get("milestone"):
                raise Deny(f"{eid}: 마일스톤 변경({a.get('milestone')} → {b.get('milestone')})은 사람만 합니다.")
            if a.get("check") != b.get("check"):
                raise Deny(f"{eid}: 검사 종류 변경({a.get('check')} → {b.get('check')})은 사람만 합니다.")
            ta, tb = a.get("test") or [], b.get("test") or []
            ta = [ta] if isinstance(ta, str) else ta
            tb = [tb] if isinstance(tb, str) else tb
            missing = [t for t in ta if t not in tb]
            if missing:
                raise Deny(f"{eid}: 연결된 테스트 제거({', '.join(missing)})는 사람만 합니다.")
            if (a.get("evidence") or "").strip() and not (b.get("evidence") or "").strip():
                raise Deny(f"{eid}: evidence 를 비우는 것은 사람만 합니다.")
            sa, sb = a.get("scope") or [], b.get("scope") or []
            narrowed = [x for x in sa if x not in sb]
            if narrowed:
                raise Deny(f"{eid}: 감사 최소 범위(scope) 축소({', '.join(narrowed)})는 사람만 합니다.")
            if a.get("attest") != b.get("attest"):
                raise Deny(f"{eid}: attest 변경은 사람만 합니다.")
            extra = set(b) - {"milestone", "check", "test", "evidence", "scope", "attest"}
            if extra:
                raise Deny(f"{eid}: 알 수 없는 필드 {sorted(extra)}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--classify")
    ap.add_argument("--rels", default="")
    ap.add_argument("--change", default="")
    ap.add_argument("--old")
    ap.add_argument("--new")
    a = ap.parse_args()
    try:
        policy = load_policy()
    except (OSError, ValueError) as exc:
        print(f"정책을 읽을 수 없습니다: {exc}", file=sys.stderr)
        return 3

    if a.classify is not None:
        print(classify(a.classify, policy)[0])
        return 0

    try:
        old = read(a.old) if a.old and os.path.getsize(a.old) > 0 else None
        if a.old and a.change in ("M", "D") and old is None:
            old = ""  # 빈 기존 파일
        new = read(a.new) if a.new else None
    except (OSError, UnicodeDecodeError) as exc:
        print(f"내용을 읽을 수 없습니다: {exc}", file=sys.stderr)
        return 3
    if a.change == "A":
        old = None

    for rel in [r for r in a.rels.split("\n") if r]:
        kind, why = classify(rel, policy)
        try:
            if kind == "free":
                continue
            if kind == "human":
                raise Deny(why)
            if kind == "new-only":
                judge_new_only(a.change, old, new, why)
            elif kind == "append":
                judge_append(a.change, old, new, why)
            elif kind == "adr":
                judge_adr(rel, a.change, old, new, why)
            elif kind == "registry":
                judge_registry(a.change, old, new, why)
        except Deny as d:
            print(f"차단: {rel}\n\n{d}\n", file=sys.stderr)
            print("에이전트는 이 변경을 할 수 없습니다 (AGENTS.md R4, .agents/APPROVAL.md).", file=sys.stderr)
            print("필요하면 이유를 정리해 사람에게 요청하고 멈추세요.", file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
