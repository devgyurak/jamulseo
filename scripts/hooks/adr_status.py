#!/usr/bin/env python3
"""ADR 상태 판정 — **허용 목록** 방식. guard-protected.sh 가 호출한다.

변형을 하나씩 막는 금지 목록은 끝이 없다(4종을 막자 30종 가까이 새로 나왔다).
그래서 거꾸로 정한다: 상태 선언은 **정규 형식 한 줄**만 인정하고, 그 밖의 상태처럼 보이는 줄은
전부 판정 불가로 차단한다.

정규 형식 (docs/adr/0000-template.md):
    - **상태**: <값>[(→ADR-XXXX)] [<!-- 주석 -->]
    값: 제안 | 채택 | 대체됨 | 기각

"상태처럼 보이는 줄": 표시 문자(굵게·기울임·코드·목록·인용·표 구분자·이모지·보이지 않는 공백)를
걷어낸 뒤 상태 키(상태·status·state·승인·approval·결정)로 시작하고 구분자(: ： | = -)가 뒤따르는 줄.

사용: adr_status.py <파일> [<저장소 기준 경로>]
판정 범위 (3차 리뷰 — 본문 오탐과 머리말 밖 우회를 함께 해소):
  - ADR 파일(docs/adr/ 바로 아래의 .md, README 제외)만 판정한다. 그 밖은 'NONE'.
  - ADR 은 코드 펜스 밖에 정규 상태 줄이 **정확히 하나**, 그것도 **머리말**에 있어야 한다.
    없으면(상태 줄 삭제·상태 없는 새 ADR) 판정 불가.
  - "상태처럼 보이는 줄" 탐지는 머리말에만 넓게 적용한다 (본문의 표·예시·`결정:` 은 보지 않는다).
    본문에서는 상태 제목(`## 상태`)만 막는다.
출력: 정규 상태 값 한 단어, 'NONE'(ADR 이 아님), 또는 'INVALID <이유>' (종료 코드 0)
      파일을 읽지 못하면 종료 코드 2
"""
from __future__ import annotations

import re
import sys
import unicodedata

VALUES = ("제안", "채택", "대체됨", "기각")
CANONICAL = re.compile(
    r"^- \*\*상태\*\*: (제안|채택|대체됨|기각)(\(→ADR-\d{4}\))?[ \t]*(<!--(?:(?!-->).)*-->)?[ \t]*$"
)
# 상태 키는 어떤 구분자(표 포함)로든 선언으로 본다. 승인·결정은 이 프로젝트 표에 흔한 단어라
# 표 밖의 `키:` 형식일 때만 선언으로 본다.
KEYS = ("상태", "status", "state")
KEYS_COLON = ("승인", "approval", "approved", "결정", "decision")
INVISIBLE = dict.fromkeys(
    [0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF, 0x00AD], None
)


def looks_like_status(line: str) -> bool:
    t = unicodedata.normalize("NFKC", line).translate(INVISIBLE).casefold()
    # 표시 문자와 기호(이모지 포함)를 걷어낸다 — 글자·숫자·공백·구분자만 남긴다
    t = "".join(ch for ch in t if ch.isalnum() or ch.isspace() or ch in ":|=-")
    table_row = t.lstrip().startswith("|")
    t = t.lstrip(" \t|->")
    for key in KEYS:
        if t.startswith(key):
            rest = t[len(key):].lstrip()
            return rest[:1] in (":", "|", "=", "-")
    if not table_row:
        for key in KEYS_COLON:
            if t.startswith(key) and t[len(key):].lstrip()[:1] == ":":
                return True
    return False


STATUS_WORDS = ("상태", "status", "state")
STATUS_HEADING = re.compile(r"^#{1,6}\s*(adr\s*|현재\s*|문서\s*)?(상태|status|state)\s*$")
FENCE = re.compile(r"^\s*(```|~~~)")


def normalize(line: str) -> str:
    return unicodedata.normalize("NFKC", line).translate(INVISIBLE).casefold()


def is_adr_path(rel: str) -> bool:
    """docs/adr 바로 아래의 .md 중 README 가 아닌 것만 ADR 이다. 하위 폴더·README 는 판정하지 않는다."""
    r = normalize(rel)
    return bool(re.fullmatch(r"docs/adr/[^/]+\.md", r)) and r != "docs/adr/readme.md"


def outside_fences(lines: list[str]) -> list[tuple[int, str]]:
    out, fenced = [], False
    for i, ln in enumerate(lines):
        if FENCE.match(ln):
            fenced = not fenced
            continue
        if not fenced:
            out.append((i, ln))
    return out


def header_end(lines: list[str]) -> int:
    """머리말 구간의 끝 — 제목 뒤 첫 `---` 또는 첫 `## ` 제목 전까지."""
    for i, ln in enumerate(lines):
        if i > 0 and (ln.strip() == "---" or ln.startswith("## ")):
            return i
    return len(lines)


def header_status_like(line: str) -> bool:
    """머리말 안에서는 넓게 본다: 키(첫 콜론 앞)에 상태 낱말이 있거나, 상태 키로 시작하는 줄."""
    if looks_like_status(line):
        return True
    t = normalize(line)
    for sep in (":", "："):
        if sep in t:
            key = t.split(sep, 1)[0]
            return any(w in key for w in STATUS_WORDS)
    return False


def judge(text: str) -> str:
    lines = text.splitlines()
    body = outside_fences(lines)
    hend = header_end(lines)
    canonical = [(i, ln) for i, ln in body if CANONICAL.match(ln)]
    if not canonical:
        return "INVALID 정규 형식 상태 줄이 없습니다 (ADR 은 상태 줄이 정확히 하나여야 합니다)"
    if len(canonical) > 1:
        return f"INVALID 정규 형식 상태 줄이 {len(canonical)}개입니다"
    ci, cline = canonical[0]
    if ci >= hend:
        return "INVALID 상태 줄은 머리말(제목 뒤 첫 --- 전)에 있어야 합니다"
    for i, ln in body:
        if i < hend and i != ci and header_status_like(ln):
            return f"INVALID 머리말에 상태처럼 보이는 줄이 더 있습니다: {ln.strip()[:60]}"
        if STATUS_HEADING.match(normalize(ln).replace("*", "").strip()):
            return f"INVALID 상태 제목은 쓸 수 없습니다 (상태는 머리말의 정규 줄 하나로만): {ln.strip()[:60]}"
    return CANONICAL.match(cline).group(1)


def main() -> int:
    try:
        text = open(sys.argv[1], encoding="utf-8", errors="strict").read()
    except (IndexError, OSError, UnicodeDecodeError) as e:
        print(f"읽을 수 없음: {e}", file=sys.stderr)
        return 2
    rel = sys.argv[2] if len(sys.argv) > 2 else ""
    if rel and not is_adr_path(rel):
        print("NONE")
        return 0
    print(judge(text))
    return 0


if __name__ == "__main__":
    sys.exit(main())
