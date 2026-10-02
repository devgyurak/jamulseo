#!/usr/bin/env python3
"""반패턴 경고 — **공통 구현**. 차단하지 않고 경고만 한다 (정당한 경우가 있다).

편집된 **조각**(Edit 의 new_string, Write 의 content)만 본다. 파일 전체를 보면 이미 있던 코드에 매번 경고가 난다.
경로에 따라 규칙이 다르다: 경계 크레이트(core·module·ffi)는 엄격하게, 경계 밖은 일부만.

입력: stdin 의 도구 JSON (Claude PostToolUse 는 tool_input 아래), 또는 인자 <경로> <내용 파일>
출력: 경고를 stderr 로
종료: 0 경고 없음 / 1 경고 있음  (2 는 쓰지 않는다 — 차단은 guard-protected 의 일이다)
"""
from __future__ import annotations

import json
import re
import sys

CORE = "crates/jamulsoe-core/"
MODULE = "crates/jamulsoe-module/"
FFI = "crates/jamulsoe-ffi/"
BOUNDARY = (CORE, MODULE, FFI)


def load() -> tuple[str, str]:
    if len(sys.argv) >= 3:
        with open(sys.argv[2], encoding="utf-8", errors="replace") as fh:
            return sys.argv[1], fh.read()
    raw = sys.stdin.read() if not sys.stdin.isatty() else ""
    if not raw.strip():
        return "", ""
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return "", ""
    if isinstance(payload.get("tool_input"), dict):
        payload = payload["tool_input"]
    path = payload.get("file_path") or payload.get("path") or ""
    parts: list[str] = []
    for key in ("content", "new_string", "new_source"):
        if isinstance(payload.get(key), str):
            parts.append(payload[key])
    for e in payload.get("edits") or []:
        if isinstance(e, dict) and isinstance(e.get("new_string"), str):
            parts.append(e["new_string"])
    return path, "\n".join(parts)


def rel_of(path: str) -> str:
    m = re.search(r"(crates/.*|tests/.*|fuzz/.*|tools/.*|\.cargo/.*|Cargo\.toml|build\.rs)$", path)
    return m.group(1) if m else path


def code_only(text: str) -> str:
    """주석 줄을 걷어낸다 (근거 주석 안의 단어로 경고가 나지 않게)."""
    return "\n".join(ln for ln in text.splitlines() if not ln.lstrip().startswith("//"))


def check(path: str, text: str) -> list[str]:
    rel = rel_of(path)
    out: list[str] = []
    in_boundary = rel.startswith(BOUNDARY)
    is_rs = rel.endswith(".rs")
    is_test = "/tests/" in rel or rel.startswith("tests/") or "#[cfg(test)]" in text
    code = code_only(text)

    is_build_cfg = rel.endswith(("Cargo.toml", "build.rs")) or "/.cargo/" in path or rel.startswith((".cargo/", "build/"))
    if is_build_cfg and "target-cpu=native" in text.replace(" ", ""):
        out.append("target-cpu=native 금지: CPU 기준선을 명시적으로 고정합니다 (C5-10, .agents/rules/build.md).")

    if rel.endswith("Cargo.toml") and rel.startswith(BOUNDARY) and re.search(r"^\s*\[(build-)?dependencies\]", text, re.M):
        out.append("경계 크레이트 의존성 변경: 외부 크레이트는 금지입니다 (R8, C5-01). lint-boundary 가 판정합니다.")

    if not is_rs:
        return out

    if "#[ignore" in code:
        out.append("#[ignore] 추가: 이유 주석 없이는 금지입니다. 테스트를 고치거나 사람에게 물으세요.")
    if re.search(r"#\[allow\(", code):
        out.append("#[allow(...)] 추가: 근거 주석이 필요합니다. 경고를 끄지 말고 고치세요.")

    if not in_boundary:
        return out

    # ── 경계 크레이트 ────────────────────────────────────────────
    if re.search(r"\bunsafe\b", code) and not rel.startswith(FFI):
        out.append("unsafe 는 jamulsoe-ffi 에만 허용됩니다 (R6). core·module 은 forbid(unsafe_code).")
    if rel.startswith(FFI) and re.search(r"\bunsafe\s*\{", code) and "SAFETY:" not in text:
        out.append("unsafe 블록에 // SAFETY: 근거가 없습니다 (R6). 어느 사전 검사 단계가 정당화하는지 적으세요.")

    if rel.startswith(CORE) and re.search(r"\b(std::|extern\s+crate\s+(std|alloc)|alloc::|Vec<|Box<|String\b)", code):
        out.append("jamulsoe-core 는 no_std·힙 없음입니다 (std/alloc/Vec/Box/String 금지).")

    if not is_test and re.search(r"\.(unwrap|expect)\s*\(|\b(panic|unreachable|todo|unimplemented)!\s*\(", code):
        out.append("경계 안 패닉 경로: unwrap/expect/panic!/todo! 금지. panic = \"abort\" 라 호스트 프로세스가 죽습니다 (C2-16).")

    if re.search(r"\bas\s+(u8|u16|u32|i32|usize)\b", code):
        out.append("`as` 변환 감지: 축소 변환이면 try_from 을 쓰세요 (docs/RUST-GUIDE.md §3).")

    if re.search(r"derive\([^)]*\b(Clone|Copy|Debug)\b", code) and re.search(r"(Key|Secret|Round|Ghash|Csp|Hmac|Ipad|Opad)", code):
        out.append("비밀값 타입에 Clone/Copy/Debug 를 붙이려는 것 같습니다 (C4-02). 비밀값 타입은 복제·출력 불가여야 합니다.")

    if re.search(r"\b(SBOX|S1|S2|SB\d?|INV_S\w*|TABLE|T[0-9])\s*\[[^\]]*\bas\s+usize", code):
        out.append("테이블 인덱싱으로 S-box·곱셈을 계산하는 것 같습니다 (C1-01/02). 비밀값 인덱싱은 캐시 타이밍으로 샙니다.")

    if re.search(r"(tag|mac|digest)\w*\s*(==|!=)|(==|!=)\s*&?\w*(tag|mac|digest)", code, re.I):
        out.append("태그·MAC 을 ==/!= 로 비교하는 것 같습니다 (C1-03). 상수 시간 비교 헬퍼를 쓰세요.")

    if re.search(r"\b(key|secret|round_key|rk|ks|keystream|h_key)\w*\s*(\[[^\]]*\])?\s*(==|!=|<|>)", code, re.I) and re.search(r"\bif\b|\bmatch\b|\bwhile\b", code):
        out.append("비밀값으로 분기하는 것 같습니다 (R7, C1). 마스크 선택과 value barrier 를 쓰세요.")

    if rel.startswith(FFI):
        if "Box::new" in code:
            out.append("Box::new 대신 std::alloc::alloc + NULL 검사로 할당합니다 (NOMEM 계약, C2-15).")
        if re.search(r"\boffset_from\b|\bsub_ptr\b", code):
            out.append("offset_from/sub_ptr 금지: 서로 다른 allocation 이면 UB 입니다. addr() 정수로 비교하세요 (C2-11).")
        if re.search(r"\bptr::write\s*\(|\.write\s*\(\s*\w*(ctx|aead|state)", code):
            out.append("ptr::write 로 컨텍스트를 옮기면 비밀값 사본이 스택에 남습니다 (C4-05). 최종 위치에 직접 계산하세요.")
        if "from_raw_parts" in code:
            out.append("from_raw_parts: NULL·길이·상한·겹침 검사를 **전부 통과한 뒤**에만 만드세요. NULL 은 길이 0 이어도 UB 입니다 (C2-04).")
        if re.search(r"jamulsoe_core::", code):
            out.append("ffi 가 core 를 직접 부르면 상태 검사(C3)를 우회합니다. module 을 거치세요 (C5-02).")

    return out


def main() -> int:
    path, text = load()
    if not path or not text:
        return 0
    warnings = check(path, text)
    if not warnings:
        return 0
    print(f"⚠ 반패턴 경고 ({rel_of(path)}) — 오탐이면 근거를 대고 넘어가세요:", file=sys.stderr)
    for w in warnings:
        print(f"  - {w}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
