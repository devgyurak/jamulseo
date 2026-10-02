#!/usr/bin/env python3
"""편집 요청을 해석해 '변경 후 파일 전체 내용'과 '실경로'를 낸다.

guard-protected.sh 가 정책을 판정하려면 다음 둘이 필요하다:

  1. **실경로**  — 파일 자체가 symlink 여도 대상까지 따라가야 한다.
                   (`alias.md -> docs/CONTRACTS.md` 가 통과하던 버그)
  2. **편집 결과** — `new_string` 조각만 보면 안 된다.
                   (`old_string:"제안" / new_string:"채택"` 가 통과하던 버그)
                   현재 내용에 편집을 적용한 **전체 결과**로 판정해야 한다.

입력: stdin 의 도구 JSON, 또는 --path 인자
출력: stdout 에 `KEY=값` 줄 (셸에서 eval 하기 좋게 작은따옴표로 감쌈)
        ABS       실경로 (symlink 해석 완료). 편집 대상이 없으면 빈 값
        RESULT    변경 후 전체 내용을 담은 임시 파일 경로 (없으면 빈 값)
        CHANGE    A(신규) | M(수정) | D(삭제) | ''(미상)
        RELS      판정할 상대 경로 후보들 (줄바꿈 구분). 문자열이 아니라 **파일 정체성**으로 구한다:
                    - 저장소 루트 기준, 각 경로 요소를 디스크의 실제 이름으로 치환 (대소문자·ſ·NFD 변형)
                    - 가장 가까운 git 작업 트리(worktree·형제 클론) 루트 기준
                    - 위 둘을 NFKC + casefold 한 것 (아직 없는 파일의 변형 이름)
        OK        '1' — **정상 완료 표식**

`OK` 가 없거나 종료 코드가 0이 아니면 호출자는 **차단**한다 (fail-closed).
보호 검사가 실패했을 때 허용으로 빠지면 보호가 없는 것과 같다.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
import unicodedata


def sh_quote(value: str) -> str:
    return "'" + value.replace("'", "'\\''") + "'"


def bail(message: str) -> "NoReturn":  # type: ignore[valid-type]
    """해석 실패. 종료 코드 2 로 끝내 호출자의 차단 경로로 보낸다.

    **입력을 해석하지 못한 것과 '대상이 없는 것'을 구분해야 한다.**
    파싱 실패를 빈 객체로 넘기면 "편집 대상 없음 → 허용" 이 되어,
    잘린 JSON 하나로 모든 보호가 무력화된다.
    """
    print(f"해석 실패: {message}", file=sys.stderr)
    sys.exit(2)


def parse_payload(raw: str) -> dict:
    """도구 JSON 을 해석한다. 해석하지 못하면 bail() 로 차단 경로에 넘긴다."""
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        # 도구가 로그 등으로 감싼 경우가 있어, 가장 바깥 객체만 한 번 더 시도한다.
        start, end = raw.find("{"), raw.rfind("}")
        if start < 0 or end <= start:
            bail(f"JSON 을 해석할 수 없습니다 ({exc}). 입력이 잘렸을 수 있습니다.")
        try:
            parsed = json.loads(raw[start : end + 1])
        except json.JSONDecodeError as exc2:
            bail(f"JSON 을 해석할 수 없습니다 ({exc2}).")

    if not isinstance(parsed, dict):
        bail(f"최상위가 객체가 아닙니다 ({type(parsed).__name__}).")
    return parsed


def true_rel(abs_path: str, base: str) -> str:
    """base 아래 abs_path 의 상대 경로를 **디스크의 실제 이름**으로 만든다.

    대소문자를 구분하지 않거나 유니코드를 정규화하는 파일 시스템(APFS 등)에서는
    docs/contracts.md · docs/CONTRACTſ.md 가 docs/CONTRACTS.md 를 가리킨다.
    문자열 비교로는 끝없는 변형을 따라갈 수 없으므로, 존재하는 요소는 같은 파일(inode)인
    디렉터리 항목의 이름으로 바꾼다. 없는 요소는 그대로 둔다.
    """
    try:
        rel = os.path.relpath(abs_path, base)
    except ValueError:
        return ""
    if rel.startswith(".."):
        return ""
    cur, parts = base, []
    for comp in rel.split(os.sep):
        cand = os.path.join(cur, comp)
        name = comp
        if os.path.lexists(cand):
            try:
                for entry in os.listdir(cur):
                    if entry == comp:
                        break
                    if os.path.samefile(os.path.join(cur, entry), cand):
                        name = entry
                        break
            except OSError:
                pass
        parts.append(name)
        cur = os.path.join(cur, name)
    return "/".join(parts)


def git_root_of(path: str) -> str:
    """path 에서 가장 가까운 git 작업 트리 루트 (.git 디렉터리 또는 파일). 없으면 빈 값."""
    cur = os.path.dirname(path)
    while True:
        if os.path.lexists(os.path.join(cur, ".git")):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            return ""
        cur = parent


def fold(rel: str) -> str:
    return unicodedata.normalize("NFKC", rel).casefold()


def apply_edit(current: str, payload: dict) -> str | None:
    """편집을 적용한 '변경 후 전체 내용'을 돌려준다. 판정 불가면 None."""
    # Write 계열: 내용 전체가 주어진다
    for key in ("content", "new_content", "text"):
        if isinstance(payload.get(key), str):
            return payload[key]

    # NotebookEdit: 셀 조각만 주어진다 — 현재 내용과 함께 본다
    if isinstance(payload.get("new_source"), str) and "new_string" not in payload:
        return current + "\n" + payload["new_source"]

    old = payload.get("old_string")
    new = payload.get("new_string")

    if isinstance(old, str) and isinstance(new, str):
        if old == "":
            # 빈 old_string = 신규 생성 관례
            return new
        count = -1 if payload.get("replace_all") else 1
        if old not in current:
            # 적용할 수 없는 편집. 조각만으로는 판정할 수 없으므로
            # 보수적으로 "현재 + 조각" 을 함께 본다.
            return current + "\n" + new
        return current.replace(old, new, count) if count > 0 else current.replace(old, new)

    # new_string 만 있는 경우 (부분 갱신) — 현재 내용과 함께 본다
    if isinstance(new, str):
        return current + "\n" + new

    # edits: [{old_string, new_string}, ...] 형태
    edits = payload.get("edits")
    if isinstance(edits, list):
        result = current
        for e in edits:
            if not isinstance(e, dict):
                continue
            o, n = e.get("old_string"), e.get("new_string")
            if isinstance(o, str) and isinstance(n, str):
                count = -1 if e.get("replace_all") else 1
                result = result.replace(o, n, count) if count > 0 else result.replace(o, n)
        return result

    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--path", default="")
    ap.add_argument("--root", default=".")
    ap.add_argument("--content-file", default="")
    args = ap.parse_args()

    payload: dict = {}
    if not args.path and not sys.stdin.isatty():
        raw = sys.stdin.read()
        if raw.strip():
            payload = parse_payload(raw)   # 실패하면 여기서 종료(2)한다

    if isinstance(payload.get("tool_input"), dict):
        payload = payload["tool_input"]

    # NotebookEdit 은 notebook_path 로 대상을 준다 (훅 매처에 있는데 해석기가 읽지 않던 누락)
    path = args.path or payload.get("file_path") or payload.get("notebook_path") or payload.get("path") or ""
    if not path:
        # **유효한 입력인데 편집 대상이 없는 경우**다 (해석 실패와 구분된다).
        # 검사할 것이 없으므로 성공 표식을 내고 끝낸다.
        print("ABS=''")
        print("RESULT=''")
        print("CHANGE=''")
        print("RELS=''")
        print("OK='1'")
        return 0

    root = os.path.realpath(args.root)
    abs_path = path if os.path.isabs(path) else os.path.join(root, path)
    # 파일 자체가 symlink 여도 대상까지 따라간다. 없는 파일도 안전하게 정규화된다.
    abs_path = os.path.realpath(abs_path)

    existed = os.path.isfile(abs_path)
    current = ""
    if existed:
        try:
            current = open(abs_path, encoding="utf-8", errors="replace").read()
        except OSError:
            current = ""

    result_text: str | None = None
    if args.content_file and os.path.isfile(args.content_file):
        result_text = open(args.content_file, encoding="utf-8", errors="replace").read()
    elif payload:
        result_text = apply_edit(current, payload)

    result_path = ""
    if result_text is not None:
        fd, result_path = tempfile.mkstemp(prefix="jms-guard-", suffix=".txt")
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(result_text)

    change = os.environ.get("JMS_CHANGE", "")
    if not change:
        change = "M" if existed else "A"

    print(f"ABS={sh_quote(abs_path)}")
    print(f"RESULT={sh_quote(result_path)}")
    print(f"CHANGE={sh_quote(change)}")

    rels: list[str] = []
    for base in (root, git_root_of(abs_path)):
        if base:
            r = true_rel(abs_path, os.path.realpath(base))
            if r:
                rels += [r, fold(r)]
    print(f"RELS={sh_quote(chr(10).join(dict.fromkeys(rels)))}")
    # 마지막 줄의 성공 표식. 이것이 없으면 호출자는 **차단**한다 (fail-closed).
    print("OK='1'")
    return 0


if __name__ == "__main__":
    sys.exit(main())
