#!/usr/bin/env bash
# GitHub 저장소 보호 설정 적용 — 사람이 실행한다 (docs/RELEASE.md, docs/research/2026-10-03.md §4).
#
#   ./.github/rulesets/apply.sh            무엇을 바꿀지 보여 주기만 한다
#   ./.github/rulesets/apply.sh --apply    실제로 적용한다
#
# 브랜치 모델 (docs/RELEASE.md): 작업 브랜치 → develop(통합, 기본) → main(릴리스) → 서명 태그
# 같은 이름의 규칙셋이 있으면 갱신(PUT)하고, 없으면 만든다(POST).
#
# 적용하는 것:
#   1. 저장소: 기본 브랜치 develop, 머지 커밋만 (스쿼시·리베이스 끔), 브랜치 최신화 버튼 허용, 머지 후 브랜치 삭제
#   2. 규칙셋 develop.json — develop: 삭제·force push 금지, 서명 필수, PR 필수(승인 0 — 승인 증거는 서명), 머지 커밋만,
#                            필수 체크 2개(보호 경로 판정 + 게이트), 머지 전 최신화. 우회 없음
#   3. 규칙셋 main.json    — main(릴리스): 위와 같다. PR 출처(develop·hotfix/*)는 protected.yml 이 검사한다.
#                            원격 main 이 없으면 건너뛴다 — 첫 릴리스로 main 을 만든 뒤 다시 실행한다
#                            (먼저 걸면 "PR 필수" 때문에 main 을 만드는 push 가 막힌다)
#   4. 규칙셋 kcmvp.json   — kcmvp/**: 위와 같고 필수 체크는 보호 경로 판정만
#
# 적용하지 않는 것 (UI 에서 사람이):
#   - Actions 의 pull_request_target 허용 — 공개 저장소는 2026-11-02 부터 기본 차단 (Settings → Actions → General)
#   - 서명 키 등록 (Settings → SSH and GPG keys → New SSH key, Key type: Signing Key)
set -euo pipefail
REPO="devgyurak/jamulseo"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLY=0; [ "${1:-}" = "--apply" ] && APPLY=1

login=$(gh api user --jq .login)
[ "$login" = devgyurak ] || { echo "gh 계정이 devgyurak 이 아닙니다 ($login)"; exit 1; }
[ "$(gh api "repos/$REPO" --jq .permissions.admin)" = true ] || { echo "$REPO 관리자 권한이 없습니다"; exit 1; }
gh api "repos/$REPO/branches/develop" >/dev/null 2>&1 || { echo "원격 develop 이 없습니다."; exit 1; }
SETS="develop.json kcmvp.json"
if gh api "repos/$REPO/branches/main" >/dev/null 2>&1; then SETS="$SETS main.json"
else echo "▲ 원격 main 이 아직 없어 main.json 은 건너뜁니다 (첫 릴리스 뒤 다시 실행)"; fi

echo "▶ 저장소 머지 설정 (현재)"
gh api "repos/$REPO" --jq '"  default=\(.default_branch) merge=\(.allow_merge_commit) squash=\(.allow_squash_merge) rebase=\(.allow_rebase_merge) update_branch=\(.allow_update_branch) delete_branch=\(.delete_branch_on_merge)"'
echo "  → default=develop merge=true squash=false rebase=false update_branch=true delete_branch=true"

existing=$(gh api "repos/$REPO/rulesets" --jq 'map({(.name): .id}) | add // {}')
for f in $SETS; do
  name=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "$HERE/$f")
  id=$(printf '%s' "$existing" | python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1], ""))' "$name")
  echo "▶ 규칙셋 $name ($f) — ${id:+갱신 id=$id}${id:-새로 만듦}"
done

if [ "$APPLY" != 1 ]; then echo; echo "확인만 했습니다. 적용하려면 --apply 를 붙이세요."; exit 0; fi

gh api -X PATCH "repos/$REPO" -f default_branch=develop -F allow_merge_commit=true -F allow_squash_merge=false -F allow_rebase_merge=false \
  -F allow_update_branch=true -F delete_branch_on_merge=true >/dev/null
echo "✓ 머지 설정"
for f in $SETS; do
  name=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "$HERE/$f")
  id=$(printf '%s' "$existing" | python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1], ""))' "$name")
  if [ -n "$id" ]; then gh api -X PUT "repos/$REPO/rulesets/$id" --input "$HERE/$f" >/dev/null
  else gh api -X POST "repos/$REPO/rulesets" --input "$HERE/$f" >/dev/null; fi
  echo "✓ 규칙셋 $name"
done
echo
echo "남은 UI 작업: Actions 에서 pull_request_target 허용(2026-11-02 전), 서명 키 등록"
echo "integration_id(15368) 때문에 거부되면, 워크플로가 한 번 돈 뒤 다시 실행하세요 (GitHub: 앱이 최근 체크를 제출했어야 함)."
