#!/usr/bin/env bash
# 서버 측 판정 (CI) — base..head 의 각 커밋을 검사한다.
#   1. 모든 커밋에 Signed-off-by: (DCO)
#   2. 보호 경로 변경이 있는 커밋은:
#        - Approved-by: <이름> 의 이름이 .github/APPROVERS 에 있고
#        - 커밋이 그 승인자의 키로 서명되어 있어야 한다 (git verify-commit, .github/allowed_signers)
#
#   ./scripts/check-protected-diff.sh <base> <head> [<result>]
#     push: <before> <after>                       — 결과 트리 = after, 기준 트리 = before
#     PR  : <base sha> <head sha> <merge 결과>       — 결과 = refs/pull/N/merge, 기준 = 결과의 첫 부모
#
#   3. **순 변경** — 기준 트리와 결과 트리 사이에서 보호 경로의 내용이 달라졌으면, 범위 안의 승인·서명된 커밋이
#      그 파일을 **바로 그 내용으로 만든** 적이 있어야 한다. 커밋별 검사만으로는 머지에서 한쪽 부모의 옛 버전을
#      고르는 것(결합 diff 가 비어 아무 커밋에도 걸리지 않는다)으로 승인된 게이트 강화를 되돌릴 수 있었다.
#
# 머지 방식은 **머지 커밋만** 허용한다 (docs/RELEASE.md). 스쿼시·리베이스 머지는 승인자 서명을 지우고
# (GitHub 의 web-flow 서명이 남는다 — 승인자 키가 아니므로 이 검사에서 실패한다) 감사 기록의 commit 을 HEAD 의 조상이 아니게 만든다.
#
# 판정기(scripts/hooks/*)·승인자 목록·허용 서명자는 **base 시점**의 것을 쓴다. 같은 PR 안에서 그것들을 무를 수 없다.
# CI 는 이 스크립트 자체도 base 브랜치의 것을 실행한다 (.github/workflows/protected.yml, pull_request_target).
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need python3
[ $# -eq 2 ] || [ $# -eq 3 ] || die "사용: check-protected-diff.sh <base> <head> [<result>]"
BASE="$1"; HEAD_REF="$2"
if [ $# -eq 3 ]; then
  RESULT="$3"
  git rev-parse -q --verify "$RESULT^{commit}" >/dev/null || die "머지 결과($RESULT)를 구할 수 없습니다 — 충돌이 있으면 해결한 뒤 다시"
  [ "$(git rev-parse "$RESULT^2" 2>/dev/null)" = "$(git rev-parse "$HEAD_REF")" ] \
    || die "머지 결과($RESULT)의 둘째 부모가 head 가 아닙니다 — 낡은 머지 결과입니다. 다시 실행하세요"
  NET_BASE=$(git rev-parse "$RESULT^1")
else
  RESULT="$HEAD_REF"; NET_BASE="$BASE"
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/jms-protected.XXXXXX"); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/judge/scripts/hooks"

# base 시점 파일을 꺼낸다. base 에 없으면(판정기를 처음 들여오는 PR) head 의 것을 쓰고 알린다.
from_base() {  # from_base <경로> <저장 위치>
  if git show "$BASE:$1" > "$2" 2>/dev/null; then return 0; fi
  warn "base 에 $1 이 없습니다 — head 의 것을 씁니다 (도입 PR 은 사람이 직접 검토)"
  git show "$HEAD_REF:$1" > "$2" 2>/dev/null
}

step "판정기·승인자 목록 준비 (base: $(git rev-parse --short "$BASE"))"
for f in guard-protected.sh resolve-edit.py adr_status.py judge.py protected.tsv; do
  from_base "scripts/hooks/$f" "$tmp/judge/scripts/hooks/$f" || die "판정기를 읽을 수 없습니다: $f"
done
chmod +x "$tmp/judge/scripts/hooks/"*
GUARD="$tmp/judge/scripts/hooks/guard-protected.sh"
from_base .github/APPROVERS "$tmp/approvers" || : > "$tmp/approvers"
from_base .github/allowed_signers "$tmp/allowed_signers" || : > "$tmp/allowed_signers"

approver_email() {  # approver_email <이름> → 이메일 (목록에 없으면 실패)
  awk -v n="$1" -F'\t' '!/^#/ && NF>=2 && $1==n {print $2; found=1} END {exit !found}' "$tmp/approvers"
}

step "커밋별 검사"
commits=$(git rev-list --reverse "$BASE..$HEAD_REF") || die "커밋 목록을 읽을 수 없습니다"
[ -n "$commits" ] || { ok "검사할 커밋 없음"; finish; }
empty_tree=$(git hash-object -t tree /dev/null)

# changed_files <커밋> <첫 부모|빈 트리> — "상태\0경로\0" 를 낸다.
# 머지 커밋은 **모든 부모와 다른 파일만** 판정한다 (git diff-tree -c). 승인된 PR 을 그대로 머지하거나
# main 을 PR 브랜치에 머지해 넣은 커밋은 판정 대상이 없고, 머지 커밋에서 따로 고친 보호 파일(evil merge)만 걸린다.
changed_files() {
  local c="$1" p1="$2" n st f
  n=$(git rev-list --parents -n 1 "$c" | wc -w)
  if [ "$n" -le 2 ]; then
    git diff-tree -r -z --no-commit-id --name-status --no-renames "$p1" "$c"
    return
  fi
  git diff-tree -r -c -z --no-commit-id --name-only "$c" | while IFS= read -r -d '' f; do
    if git cat-file -e "$c:$f" 2>/dev/null; then
      if git cat-file -e "$p1:$f" 2>/dev/null; then st=M; else st=A; fi
    else st=D; fi
    printf '%s\0%s\0' "$st" "$f"
  done
}

# judge_change <커밋|트리 기준> <결과 커밋> <파일> <상태> — 0 허용 / 1 보호 경로 판정에 걸림
judge_change() {
  local from="$1" to="$2" file="$3" ch="$4" old="$tmp/old" new="$tmp/new" newarg=""
  : > "$old"; : > "$new"
  [ "$ch" != A ] && { git show "$from:$file" > "$old" 2>/dev/null || : > "$old"; }
  if [ "$ch" != D ]; then git show "$to:$file" > "$new" || die "내용을 읽을 수 없습니다: $to:$file"; newarg="$new"; fi
  JMS_GUARD_ROOT="$ROOT" JMS_LOGICAL_PATH="$file" JMS_CHANGE="$ch" \
    JMS_OLD_CONTENT_FILE="$old" JMS_NEW_CONTENT_FILE="$newarg" "$GUARD" "$file" >/dev/null 2>&1
}

# approval <커밋> — 승인 트레일러 + 목록의 승인자 + 그 승인자 키의 유효한 서명이면 0. 아니면 사유를 stdout 에.
approval() {
  local c="$1" msg approver email sig
  msg=$(git log -1 --format=%B "$c")
  approver=$(printf '%s\n' "$msg" | sed -n 's/^Approved-by: *\(.*\)$/\1/p' | head -1)
  [ -n "$approver" ] || { echo "Approved-by 가 없습니다"; return 1; }
  email=$(approver_email "$approver") || { echo "승인자 '$approver' 가 .github/APPROVERS (base) 에 없습니다"; return 1; }
  grep -Eq '^[^#[:space:]]' "$tmp/allowed_signers" \
    || { echo ".github/allowed_signers (base) 가 비어 있어 서명을 확인할 수 없습니다 — 트레일러만으로는 승인 증거가 아닙니다"; return 1; }
  sig=$(git -c gpg.ssh.allowedSignersFile="$tmp/allowed_signers" log -1 --format='%G?|%GS' "$c" 2>/dev/null)
  if [ "${sig%%|*}" != G ] || [ "${sig#*|}" != "$email" ]; then
    echo "승인자 $approver <$email> 의 유효한 서명이 아닙니다 (서명 상태: ${sig:-없음})"; return 1
  fi
  echo "승인자 $approver, 서명 확인"
}

for c in $commits; do
  short=$(git rev-parse --short "$c"); msg=$(git log -1 --format=%B "$c")
  subject=$(printf '%s' "$msg" | head -1)
  parent="$c^"; git rev-parse -q --verify "$parent" >/dev/null || parent="$empty_tree"
  # DCO: 기여한 내용이 있는 커밋에만. 내용을 바꾸지 않은 머지 커밋(결합 diff 가 빈 것 — GitHub 의 머지 버튼 등)은 제외한다.
  nparents=$(( $(git rev-list --parents -n 1 "$c" | wc -w) - 1 ))
  if [ "$nparents" -le 1 ] || [ -n "$(changed_files "$c" "$parent" | tr -d '\0')" ]; then
    printf '%s\n' "$msg" | grep -qE '^Signed-off-by: .+ <.+>$' || fail "$short: Signed-off-by 없음 (DCO) — $subject"
  fi
  blocked=""
  while IFS= read -r -d '' status && IFS= read -r -d '' file; do
    case "$status" in A) ch=A ;; D) ch=D ;; *) ch=M ;; esac
    judge_change "$parent" "$c" "$file" "$ch" || blocked="${blocked}${file} "
  done < <(changed_files "$c" "$parent")
  [ -n "$blocked" ] || continue
  if why=$(approval "$c"); then ok "$short: 보호 경로 변경 — $why ($blocked)"
  else fail "$short: 보호 경로 변경 — $why — $blocked"; fi
done

# ── 순 변경: 기준 트리 → 결과 트리 ─────────────────────────────────
step "순 변경 ($(git rev-parse --short "$NET_BASE") → $(git rev-parse --short "$RESULT"))"
approved=""
for c in $(git rev-list "$NET_BASE..$HEAD_REF"); do approval "$c" >/dev/null && approved="$approved $c"; done
blob() { git rev-parse -q --verify "$1:$2" 2>/dev/null || echo absent; }
net=0
while IFS= read -r -d '' status && IFS= read -r -d '' file; do
  case "$status" in A) ch=A ;; D) ch=D ;; *) ch=M ;; esac
  judge_change "$NET_BASE" "$RESULT" "$file" "$ch" && continue
  net=$((net+1)); want=$(blob "$RESULT" "$file"); made=""
  for c in $approved; do
    p1="$c^"; git rev-parse -q --verify "$p1" >/dev/null || p1="$empty_tree"
    if [ "$(blob "$c" "$file")" = "$want" ] && [ "$(blob "$p1" "$file")" != "$want" ]; then made="$c"; break; fi
  done
  if [ -n "$made" ]; then
    ok "$file: 결과 내용을 만든 승인 커밋 $(git rev-parse --short "$made")"
  else
    fail "$file: 기준 대비 바뀌었는데, 그 결과 내용($( [ "$want" = absent ] && echo 삭제 || echo "${want:0:10}"))을 만든 승인·서명 커밋이 범위에 없습니다 — 머지로 옛 버전을 고른 경우 등"
  fi
done < <(git diff -z --name-status --no-renames "$NET_BASE" "$RESULT")
[ "$net" -gt 0 ] || ok "보호 경로의 순 변경 없음"
finish
