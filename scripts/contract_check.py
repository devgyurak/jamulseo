#!/usr/bin/env python3
"""계약 레지스트리 역방향 검사 (docs/TESTING.md §6, tests/contracts/README.md).

1. docs/CONTRACTS.md 의 모든 조항 ID 가 레지스트리에 정확히 한 번 있고, 그 반대도 같다
2. 각 항목의 stages 마일스톤 집합 = CONTRACTS.md 의 그 조항 마일스톤 열에 적힌 마일스톤 집합
   (레지스트리만 고쳐서 마일스톤을 미룰 수 없다 — CONTRACTS.md 는 사람만 고친다)
3. 마일스톤 ≤ 현재인 단계 — 판정 모드가 둘이다:

   머지 판정 (기본, 매 CI): 증분 작업이 가능해야 한다. **아직 연결되지 않은** 단계는 "대기".
     **이미 연결된** 증거는 반드시 유효해야 한다 (판정기가 연결 제거를 막으므로 후퇴가 생기지 않는다):
   - test    → 연결된 각 이름이 실행 목록에 있고 #[ignore] 가 아니다
   - manual  → 연결된 감사 파일의 형식·조항·verdict·scope 포함·attest 경로가 맞다
               (툴체인 변경·감사 뒤 코드 변경으로 낡은 것은 경고 — 종료 판정에서 실패)
   종료 판정 (--exit, verify.sh --milestone): 전부 요구한다.
   - test    → test 가 비어 있지 않고 위 조건
   - gate:X  → scripts/X.sh 가 있고 scripts/verify.sh 에 등록되어 있다 (두 모드 모두)
   - manual  → 위 조건 + 툴체인이 현재와 같고, commit 이 HEAD 의 조상이며 그 뒤 scope 가 바뀌지 않았다
   - policy  → evidence 파일이 존재한다 (절차 문서. 가장 약한 증거임을 명시한다, 두 모드 모두)
   manual 단계의 `scope`(레지스트리)는 감사가 반드시 덮어야 하는 최소 경로다. 감사 파일의 scope 가 그것을 포함해야 한다.
   `attest: human` 단계는 docs/audits/attested/ (사람 전용 경로) 의 기록만 인정한다.
4. 이후 마일스톤 단계는 "대기"로 센다 (통과 아님)
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    tomllib = None

ROW_RE = re.compile(r"^\|\s*(C[1-5]-\d{2})\s*\|(.*)\|\s*$", re.M)
MS_RE = re.compile(r"\bM(\d)\b")


def ms(v: str) -> int:
    m = re.fullmatch(r"M(\d)", v or "")
    if not m:
        raise ValueError(f"잘못된 마일스톤: {v!r}")
    return int(m.group(1))


def contract_milestones(text: str) -> dict[str, list[int]]:
    out: dict[str, list[int]] = {}
    for cid, rest in ROW_RE.findall(text):
        last = rest.split("|")[-1]
        out[cid] = sorted({int(x) for x in MS_RE.findall(last)})
    return out


def names(listing: str | None) -> set[str] | None:
    if listing is None:
        return None
    s: set[str] = set()
    for line in Path(listing).read_text(encoding="utf-8", errors="replace").splitlines():
        if line.endswith(": test"):
            s.add(line[: -len(": test")].split("::")[-1])
    return s


def git(root: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)


def frontmatter(path: Path) -> dict[str, str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    out = {}
    for ln in lines[1:]:
        if ln.strip() == "---":
            break
        if ":" in ln:
            k, v = ln.split(":", 1)
            out[k.strip()] = v.strip()
    return out


def covers(audit_scope: list[str], required: list[str]) -> list[str]:
    """required 중 audit_scope 의 어떤 경로(같거나 상위 디렉터리)로도 덮이지 않는 것."""
    def norm(x: str) -> str:
        return x.strip().rstrip("/")
    a = [norm(x) for x in audit_scope]
    return [r for r in required if not any(norm(r) == x or norm(r).startswith(x + "/") for x in a)]


def check_audit_static(root: Path, cid: str, stage: dict, evidence: str) -> tuple[str | None, dict]:
    """감사 파일 자체의 유효성 (두 모드 공통)."""
    p = (root / evidence).resolve()
    base = "docs/audits/attested" if stage.get("attest") == "human" else "docs/audits"
    audits = (root / base).resolve()
    if not str(p).startswith(str(audits) + "/") or not p.is_file():
        return f"evidence 는 {base}/ 의 감사 파일이어야 합니다: {evidence!r}", {}
    fm = frontmatter(p)
    for k in ("contract", "toolchain", "commit", "scope", "verdict"):
        if not fm.get(k):
            return f"{evidence}: 머리말에 {k} 가 없습니다 (docs/audits/README.md)", fm
    if cid not in re.split(r"[,\s]+", fm["contract"]):
        return f"{evidence}: contract 에 {cid} 가 없습니다", fm
    if fm["verdict"] != "pass":
        return f"{evidence}: verdict 가 pass 가 아닙니다 ({fm['verdict']})", fm
    missing = covers(fm["scope"].split(), stage.get("scope") or [])
    if missing:
        return f"{evidence}: 감사 scope 가 레지스트리의 최소 범위를 덮지 않습니다 — 빠짐: {' '.join(missing)}", fm
    return None, fm


def check_audit(root: Path, cid: str, evidence: str, toolchain: str | None) -> str | None:
    """감사 이후 변화로 낡았는가 (종료 판정에서 실패, 머지 판정에서 경고)."""
    p = (root / evidence).resolve()
    fm = frontmatter(p)
    if toolchain is None:
        return "rust-toolchain.toml 이 없어 감사의 툴체인을 대조할 수 없습니다"
    if fm["toolchain"] != toolchain:
        return f"{evidence}: 감사 툴체인 {fm['toolchain']} ≠ 현재 {toolchain} — 다시 감사해야 합니다"
    c = fm["commit"]
    if git(root, "merge-base", "--is-ancestor", c, "HEAD").returncode != 0:
        return f"{evidence}: commit {c} 이 HEAD 의 조상이 아닙니다"
    scope = fm["scope"].split()
    if git(root, "diff", "--quiet", c, "HEAD", "--", *scope).returncode != 0:
        return f"{evidence}: 감사 뒤 scope({' '.join(scope)})가 바뀌었습니다 — 다시 감사해야 합니다"
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--milestone", required=True)
    ap.add_argument("--listing", help="cargo test -- --list --format terse 출력")
    ap.add_argument("--ignored", help="cargo test -- --list --format terse --ignored 출력")
    ap.add_argument("--exit", action="store_true", help="마일스톤 종료 판정 — 미연결 단계와 낡은 감사도 실패")
    a = ap.parse_args()
    root = Path(a.root)
    cur = ms(a.milestone)
    errors: list[str] = []

    want = contract_milestones((root / "docs/CONTRACTS.md").read_text(encoding="utf-8"))
    try:
        entries = json.loads((root / "tests/contracts/registry.json").read_text(encoding="utf-8"))["entries"]
    except (OSError, ValueError, KeyError) as exc:
        print(f"  ✗ 레지스트리를 읽을 수 없습니다: {exc}", file=sys.stderr)
        return 1

    ids = [e.get("id") for e in entries]
    for i in sorted(set(want) - set(ids)):
        errors.append(f"{i}: docs/CONTRACTS.md 에 있지만 레지스트리에 없습니다")
    for i in sorted(set(ids) - set(want)):
        errors.append(f"{i}: 레지스트리에 있지만 docs/CONTRACTS.md 에 없습니다")
    for i in sorted({x for x in ids if ids.count(x) > 1}):
        errors.append(f"{i}: 레지스트리에 중복")

    listed, ignored = names(a.listing), names(a.ignored) or set()
    toolchain = None
    tc = root / "rust-toolchain.toml"
    if tc.exists() and tomllib:
        toolchain = str(tomllib.loads(tc.read_text(encoding="utf-8")).get("toolchain", {}).get("channel", "")) or None
    verify_sh = (root / "scripts/verify.sh").read_text(encoding="utf-8")

    required = pending = 0
    warnings: list[str] = []
    for e in entries:
        cid = e.get("id", "?")
        stages = e.get("stages") or []
        try:
            got = sorted(ms(s.get("milestone", "")) for s in stages)
        except ValueError as exc:
            errors.append(f"{cid}: {exc}")
            continue
        if cid in want and got != want[cid]:
            errors.append(f"{cid}: 마일스톤 {['M%d' % x for x in got]} ≠ docs/CONTRACTS.md {['M%d' % x for x in want[cid]]}")
        for s in stages:
            m, check = ms(s["milestone"]), s.get("check", "")
            if m > cur:
                pending += 1
                continue
            tag = f"{cid}@{s['milestone']}"
            tests = s.get("test") or []
            tests = [tests] if isinstance(tests, str) else tests
            ev = (s.get("evidence") or "").strip()
            unlinked = (check == "test" and not tests) or (check == "manual" and not ev)
            if unlinked and not a.exit:
                pending += 1     # 머지 판정: 아직 연결 안 된 단계는 대기 (종료 판정에서 요구)
                continue
            required += 1
            if check == "test":
                if not tests:
                    errors.append(f"{tag}: 연결된 테스트가 없습니다")
                elif listed is None:
                    errors.append(f"{tag}: 테스트 목록을 얻을 수 없습니다 (워크스페이스·cargo 없음)")
                for t in tests if listed is not None else []:
                    fn = t.split("::")[-1]
                    if fn not in listed:
                        errors.append(f"{tag}: 테스트 {t} 가 실행 목록에 없습니다")
                    elif fn in ignored:
                        errors.append(f"{tag}: 테스트 {t} 가 #[ignore] 입니다 — 실행되지 않는 테스트는 증거가 아닙니다")
            elif check.startswith("gate:"):
                g = check.split(":", 1)[1]
                if not (root / "scripts" / f"{g}.sh").exists():
                    errors.append(f"{tag}: 게이트 스크립트 scripts/{g}.sh 가 없습니다")
                elif f"scripts/{g}.sh" not in verify_sh:
                    errors.append(f"{tag}: scripts/{g}.sh 가 verify.sh 에 등록되어 있지 않습니다")
            elif check == "manual":
                if not ev:
                    errors.append(f"{tag}: 감사 기록이 없습니다 (docs/audits/)")
                    continue
                err, _ = check_audit_static(root, cid, s, ev)
                if err:
                    errors.append(f"{tag}: {err}")
                    continue
                stale = check_audit(root, cid, ev, toolchain)
                if stale:
                    (errors if a.exit else warnings).append(f"{tag}: {stale}")
            elif check == "policy":
                ev = (s.get("evidence") or "").strip()
                if not ev or not (root / ev).is_file():
                    errors.append(f"{tag}: policy evidence 파일이 없습니다: {ev!r}")
            else:
                errors.append(f"{tag}: 알 수 없는 check {check!r}")

    mode = "종료 판정" if a.exit else "머지 판정 (미연결 단계는 대기)"
    print(f"  [{mode}] 조항 {len(want)}개 · 검사한 단계 {required}개 · 대기 {pending}개 (대기는 통과로 세지 않음)")
    for w in warnings:
        print(f"  ▲ {w} — 종료 판정에서 실패합니다. 다시 감사하세요")
    for err in errors:
        print(f"  ✗ {err}", file=sys.stderr)
    if not errors:
        print("  ✓ 필수 단계 전부 검사에 연결됨" if a.exit else "  ✓ 연결된 증거가 전부 유효 (미연결 단계는 대기 — 마일스톤 종료 판정에서 요구)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
