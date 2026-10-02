#!/usr/bin/env bash
# 도구별 어댑터를 **단일 원천에서 생성한다**.
#
#   .agents/roles/*.md      →  .claude/agents/*.md  .opencode/agent/*.md  .codex/agents/*.toml
#   .agents/rules/*.md      →  .claude/rules/*.md (symlink)  .cursor/rules/<order>-*.mdc (symlink)
#   .agents/workflows/*.md  →  .claude/commands/jms-*.md (symlink)  .cursor/commands/*.md (symlink)
#                              .opencode/command/*.md (symlink)
#
# 형식이 같으면 **상대 symlink**, 다르면 **생성**한다.
# 생성물은 절대 직접 수정하지 않는다 — `--check` 가 드리프트를 잡는다.
#
#   ./scripts/sync-agents.sh          생성·갱신
#   ./scripts/sync-agents.sh --check  드리프트만 검사 (CI, pre-commit)
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

GEN_HEADER="이 파일은 scripts/sync-agents.sh 가 .agents/ 에서 생성했습니다. 직접 수정하지 마세요."
EXPECTED_GENERATED=""

fm() {  # fm <file> <key> — frontmatter 단일 값
  awk -v k="$2" '
    NR==1 && /^---$/ {inside=1; next}
    inside && /^---$/ {exit}
    inside && $0 ~ "^" k ":" { sub("^" k ":[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }
  ' "$1"
}
fm_list() {  # fm_list <file> <key> — YAML 리스트를 공백 구분으로
  awk -v k="$2" '
    NR==1 && /^---$/ {inside=1; next}
    inside && /^---$/ {exit}
    inside && $0 ~ "^" k ":" {grab=1; next}
    grab && /^  - / { sub(/^  - /, ""); gsub(/^"|"$/, ""); printf "%s ", $0; next }
    grab && /^[a-z_]+:/ {exit}
  ' "$1"
}
body() { awk 'NR==1 && /^---$/ {inside=1; next} inside && /^---$/ {inside=0; started=1; next} started' "$1"; }
toml_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

emit() {  # emit <target> <content>
  local target="$1" content="$2"
  EXPECTED_GENERATED="${EXPECTED_GENERATED}${target}
"
  mkdir -p "$(dirname "$target")"
  if [ "$CHECK" = 1 ]; then
    if [ ! -f "$target" ]; then fail "누락: $target"; return; fi
    if ! printf '%s' "$content" | diff -q - "$target" >/dev/null 2>&1; then
      fail "드리프트: $target"
      info "→ ./scripts/sync-agents.sh 를 실행해 동기화하세요"
    fi
  else
    printf '%s' "$content" > "$target"
  fi
}

link() {  # link <target> <source> — 상대 symlink
  local target="$1" source="$2"
  mkdir -p "$(dirname "$target")"
  local depth rel
  depth=$(printf '%s' "$(dirname "$target")" | awk -F/ '{print NF}')
  rel=""; for _ in $(seq 1 "$depth"); do rel="../$rel"; done
  rel="${rel}${source}"
  if [ "$CHECK" = 1 ]; then
    if [ ! -L "$target" ]; then fail "symlink 아님: $target"; return; fi
    if [ ! -e "$target" ]; then fail "끊어진 symlink: $target → $(readlink "$target")"; return; fi
    local actual; actual=$(readlink "$target")
    [ "$actual" = "$rel" ] || fail "symlink 대상 불일치: $target → $actual (기대 $rel)"
  else
    rm -f "$target"
    ln -s "$rel" "$target"
  fi
}

# ── 1. 역할 → 도구별 에이전트 (형식이 달라 생성) ────────────────
step "역할 → 도구별 에이전트"
n=0
for f in .agents/roles/*.md; do
  [ -f "$f" ] || continue
  name=$(fm "$f" name); descr=$(fm "$f" description)
  model=$(fm "$f" model); effort=$(fm "$f" reasoning_effort)
  sandbox=$(fm "$f" sandbox); tools=$(fm "$f" tools)
  fresh=$(fm "$f" fresh_session); forbid=$(fm_list "$f" forbid_read)
  [ -n "$name" ] && [ -n "$descr" ] || { fail "$f: name/description 없음"; continue; }
  [ "$name" = "$(basename "$f" .md)" ] || { fail "$f: name($name) 이 파일 이름과 다릅니다"; continue; }
  b=$(body "$f")

  guard=""
  if [ -n "$forbid" ]; then
    guard="> 🚫 **읽지 않는 경로**: $(printf '%s' "$forbid" | sed 's/ $//; s/ /, /g')
> 새 세션으로 시작하고, 구현 대화 이력을 넘겨받지 않습니다 (.agents/INDEPENDENCE.md).

"
  elif [ "$fresh" = "true" ]; then
    guard="> 🚫 **구현 세션과 분리된 새 세션에서 실행합니다** (AGENTS.md R3, .agents/INDEPENDENCE.md).

"
  fi
  footer="전체 정의: \`.agents/roles/${name}.md\` · 공통 규칙: \`AGENTS.md\` · 계약: \`docs/CONTRACTS.md\`"

  # Claude Code
  emit ".claude/agents/${name}.md" "---
name: ${name}
description: ${descr}
tools: ${tools}
model: ${model}
---

<!-- ${GEN_HEADER} -->

${guard}${b}

---
${footer}
"

  # opencode — 셸 허용 여부는 역할의 tools 목록을 따른다. read-only 역할에 무조건 bash 를 주면
  # 셸로 쓰기가 가능해져 sandbox 선언이 무의미해진다.
  case ", ${tools}," in *", Bash,"*) obash=true ;; *) obash=false ;; esac
  if [ "$sandbox" = "read-only" ]; then owrite=false; else owrite=true; fi
  emit ".opencode/agent/${name}.md" "---
description: ${descr}
mode: subagent
tools:
  write: ${owrite}
  edit: ${owrite}
  bash: ${obash}
---

<!-- ${GEN_HEADER} -->

${guard}${b}

---
${footer}
"

  # Codex (.codex/agents/*.toml — name/description/developer_instructions 필수)
  emit ".codex/agents/${name}.toml" "# ${GEN_HEADER}
name = \"$(printf '%s' "$name" | tr '-' '_')\"
description = \"$(toml_escape "$descr")\"
model_reasoning_effort = \"${effort}\"
sandbox_mode = \"${sandbox}\"
developer_instructions = '''
${guard}${b}

${footer}
'''
"
  n=$((n+1))
done
[ "$FAILURES" -eq 0 ] && ok "역할 ${n}개 → claude / opencode / codex"

for generated in .claude/agents/*.md .opencode/agent/*.md .codex/agents/*.toml; do
  [ -f "$generated" ] || continue
  grep -Fq "$GEN_HEADER" "$generated" || continue
  if ! printf '%s' "$EXPECTED_GENERATED" | grep -Fxq "$generated"; then
    if [ "$CHECK" = 1 ]; then fail "원천 없는 생성물: $generated"
    else rm -- "$generated"; info "원천 없는 생성물 제거: $generated"; fi
  fi
done

# ── 2. 규칙 → symlink (형식 호환: md + frontmatter) ─────────────
step "규칙 → symlink"
m=0
for f in .agents/rules/*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .md); order=$(fm "$f" order)
  [ -n "$order" ] || { fail "$f: order 없음"; continue; }
  link ".claude/rules/${name}.md"            ".agents/rules/${name}.md"
  link ".cursor/rules/${order}-${name}.mdc"  ".agents/rules/${name}.md"
  m=$((m+1))
done
[ "$FAILURES" -eq 0 ] && ok "규칙 ${m}개 → .claude/rules (paths) / .cursor/rules (globs)"

# ── 3. 워크플로 명령 → symlink ──────────────────────────────────
step "워크플로 명령 → symlink"
w=0
for f in .agents/workflows/*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .md)
  link ".claude/commands/jms-${name}.md" ".agents/workflows/${name}.md"
  link ".cursor/commands/${name}.md"     ".agents/workflows/${name}.md"
  link ".opencode/command/${name}.md"    ".agents/workflows/${name}.md"
  w=$((w+1))
done
[ "$FAILURES" -eq 0 ] && ok "명령 ${w}개 → claude / cursor / opencode"

# ── 4. 원천 없는 symlink ────────────────────────────────────────
for l in .claude/rules/*.md .cursor/rules/*.mdc .claude/commands/*.md .cursor/commands/*.md .opencode/command/*.md; do
  [ -L "$l" ] || continue
  if [ ! -e "$l" ]; then
    if [ "$CHECK" = 1 ]; then fail "원천 없는 symlink: $l"; else rm -- "$l"; info "원천 없는 symlink 제거: $l"; fi
  fi
done

if [ "$CHECK" = 1 ] && [ "$FAILURES" -gt 0 ]; then
  printf '\n%s생성물이 원천과 어긋났습니다. .agents/ 를 고치고 sync-agents.sh 를 실행하세요.%s\n' "$Y" "$N"
fi
finish
