#!/usr/bin/env bash
# 어댑터 정합성 검사 — "단일 원천" 선언이 실제 파일과 일치하는가
# **링크가 존재한다는 것은 도구가 실제로 로드한다는 뜻이 아니다.** (마지막 절 참고)
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

step "생성물 ↔ 원천 드리프트"
if "$ROOT/scripts/sync-agents.sh" --check >/dev/null 2>&1; then
  ok "생성물이 .agents/ 와 일치"
else
  fail "드리프트 감지 — ./scripts/sync-agents.sh --check 로 확인"
fi

step "symlink 해석"
broken=0; linked=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if [ -e "$f" ]; then linked=$((linked+1)); else fail "끊어진 symlink: $f → $(readlink "$f")"; broken=$((broken+1)); fi
done < <(find .claude .cursor .opencode .codex -type l 2>/dev/null)
[ "$broken" -eq 0 ] && ok "symlink ${linked}개 전부 해석됨"

step "규칙 조건부 로딩 메타데이터"
for f in .agents/rules/*.md; do
  n=$(basename "$f" .md)
  has_paths=$(grep -c '^paths:' "$f" || true)
  has_globs=$(grep -c '^globs:' "$f" || true)
  always=$(grep -c '^alwaysApply: true' "$f" || true)
  if [ "$always" -gt 0 ]; then
    [ "$has_paths" -eq 0 ] && ok "$(printf '%-14s 항상 적용' "$n")" || fail "$n: alwaysApply 인데 paths 가 있습니다 (모순)"
  elif [ "$has_paths" -gt 0 ] && [ "$has_globs" -gt 0 ]; then
    ok "$(printf '%-14s 조건부 (paths=Claude, globs=Cursor)' "$n")"
  else
    fail "$n: 조건부 규칙인데 paths 또는 globs 가 없습니다 (paths 가 없으면 Claude 가 시작부터 전부 로드)"
  fi
done

step "공통 로직 위치"
leak=$(grep -rln '\.claude/hooks' .opencode .cursor .codex .pi .githooks 2>/dev/null || true)
if [ -n "$leak" ]; then
  fail "다른 도구가 .claude/ 를 참조합니다:"; printf '%s\n' "$leak" | sed 's/^/      /'
else
  ok "공통 검사는 scripts/hooks/ 에 있고 도구는 어댑터만"
fi
fat=0
for f in .claude/hooks/*.sh .cursor/hooks/*.sh; do
  [ -f "$f" ] || continue
  lines=$(grep -vcE '^\s*(#|$)' "$f" || true)
  if [ "$lines" -gt 6 ]; then warn "$(printf '%-36s 실행 줄 %d개 — 로직이 들어갔는지 확인' "$f" "$lines")"; fat=$((fat+1)); fi
done
[ "$fat" -eq 0 ] && ok "훅 어댑터가 전부 얇음"

step "보호 정책 ↔ 도구 권한 (scripts/hooks/protected.tsv ↔ .claude/settings.json)"
# 판정의 원천은 protected.tsv 하나다. Claude 의 Edit 거부 규칙은 그 human 항목을 빠짐없이 덮어야 한다
# (훅이 먼저 막지만, 권한 거부는 훅이 꺼져도 남는 두 번째 그물이다).
if python3 - <<'PY'
import json, sys
deny = set(json.load(open(".claude/settings.json"))["permissions"]["deny"])
miss = []
for ln in open("scripts/hooks/protected.tsv", encoding="utf-8"):
    if not ln.strip() or ln.startswith("#"):
        continue
    pat, kind, _ = ln.rstrip("\n").split("\t")
    if kind != "human":
        continue
    rule = "Edit(./" + (pat[:-1] + "**" if pat.endswith("*") else pat) + ")"
    if rule not in deny:
        miss.append(rule)
for m in miss:
    print("  ✗ .claude/settings.json deny 에 없음:", m, file=sys.stderr)
sys.exit(1 if miss else 0)
PY
then ok "human 항목이 전부 Edit 거부 규칙으로 덮임"; else fail "도구 권한이 보호 정책보다 좁습니다"; fi
if grep -q 'Bash(./scripts/\*' .claude/settings.json; then
  fail ".claude/settings.json 에 scripts/* 와일드카드 허용이 있습니다 — 스크립트 이름별로 나열하세요"
else
  ok "스크립트 실행 허용이 이름별로 나열됨"
fi

printf '\n%s━━━ 자동 검사로는 확인할 수 없는 것 — 도구별 실세션에서 직접 확인하세요%s\n' "$Y" "$N"
cat <<'EOS'

  claude-code
    □ /context 에 AGENTS.md 가 보이는가 (CLAUDE.md 의 @AGENTS.md)
    □ crates/jamulsoe-core/ 의 파일을 읽었을 때 crypto-core 규칙이 들어오는가 (조건부 로딩)
    □ /agents 에 역할 13개, / 에 jms-* 명령 12개가 보이는가
    □ docs/CONTRACTS.md 편집이 PreToolUse 훅으로 차단되는가
    □ 경계 크레이트에 .unwrap() 을 쓰면 PostToolUse 경고가 에이전트에게 돌아오는가

  codex
    □ .codex/agents/*.toml 의 서브에이전트가 목록에 뜨는가
    □ sandbox_mode = read-only 역할이 실제로 쓰기를 막는가

  cursor
    □ .cursor/rules/*.mdc 가 symlink 여도 인식되는가  ← 확장자(.mdc)와 대상(.md)이 다름
    □ .cursor/hooks.json 의 이벤트 이름이 현재 버전과 맞는가

  opencode
    □ .opencode/agent/*.md 13개가 인식되는가
    □ plugin 의 tool.execute.before 가 보호 경로를 차단하는가

  pi
    □ AGENTS.md 를 읽는가 / .pi/config.toml 의 키 이름이 실제 스키마와 맞는가

  확인 결과는 .agents/COMPATIBILITY.md 의 "검증 기록" 표에 날짜와 버전을 남기세요.
EOS
finish
