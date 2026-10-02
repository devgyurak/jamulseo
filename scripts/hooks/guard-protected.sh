#!/usr/bin/env bash
# 보호 경로 판정 — **공통 구현의 진입점**. 모든 도구의 훅, .githooks/pre-commit, CI(check-protected-diff.sh)가 이것을 호출한다.
# 정책: scripts/hooks/protected.tsv (유일한 정의) · 판정: scripts/hooks/judge.py · 설명: .agents/APPROVAL.md
#
# 입력 (셋 중 하나):
#   1. 인자:  guard-protected.sh <경로> [<변경 후 내용 파일>]
#   2. stdin: 도구 JSON (file_path + content | new_string | old_string+new_string | edits | tool_input{...})
#   3. 환경:  JMS_CHANGE=A|M|D, JMS_NEW_CONTENT_FILE, JMS_OLD_CONTENT_FILE (변경 전 내용, 새 파일이면 빈 파일),
#             JMS_LOGICAL_PATH (Git 논리 경로), JMS_GUARD_ROOT (판정 기준 저장소 루트)
#
# 이 래퍼가 하는 일: 실경로·편집 결과 해석(resolve-edit.py) → 판정(judge.py). 어느 단계든 실패하면 차단 (fail-closed).
# 종료: 0 허용, 2 차단
set -uo pipefail
unset CDPATH
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="${JMS_GUARD_ROOT:-$(cd "$HERE/../.." && pwd -P)}"

arg_path="${1:-}"
arg_content="${2:-${JMS_NEW_CONTENT_FILE:-}}"
arg_previous="${JMS_OLD_CONTENT_FILE:-}"

ABS=""; RESULT=""; CHANGE="${JMS_CHANGE:-}"; RELS=""; OK=""
TMP_RESULT=""
cleanup() { [ -n "$TMP_RESULT" ] && rm -f "$TMP_RESULT"; }
trap cleanup EXIT

deny_infra() {
  printf '차단: 보호 경로 판정을 수행하지 못했습니다.\n\n%s\n\n' "$1" >&2
  printf '보호 검사가 실패했을 때는 허용하지 않습니다 (fail-closed). python3 (3.11+) 확인 → ./scripts/bootstrap.sh\n' >&2
  exit 2
}

command -v python3 >/dev/null 2>&1 || deny_infra 'python3 이 없어 경로·편집 결과를 해석할 수 없습니다.'
for f in resolve-edit.py judge.py adr_status.py protected.tsv; do
  [ -f "$HERE/$f" ] || deny_infra "판정기 구성 요소가 없습니다: $HERE/$f"
done
for content_file in "$arg_content" "$arg_previous"; do
  if [ -n "$content_file" ]; then
    [ -f "$content_file" ] && [ -r "$content_file" ] || deny_infra "내용 파일을 읽을 수 없습니다: $content_file"
  fi
done

if [ -n "$arg_path" ]; then
  resolver_out=$(python3 "$HERE/resolve-edit.py" --root "$ROOT" --path "$arg_path" --content-file "$arg_content" </dev/null 2>&1)
else
  resolver_out=$(python3 "$HERE/resolve-edit.py" --root "$ROOT" --content-file "$arg_content" 2>&1)
fi
resolver_rc=$?
[ "$resolver_rc" -eq 0 ] || deny_infra "해석기가 종료 코드 ${resolver_rc} 로 실패했습니다:

${resolver_out}"
eval "$resolver_out" || deny_infra '해석기 출력을 읽을 수 없습니다.'
TMP_RESULT="$RESULT"
[ "${OK:-}" = "1" ] || deny_infra "해석기 출력이 불완전합니다 (완료 표식 없음):

${resolver_out}"

# 유효한 입력인데 편집 대상이 없다 → 검사할 것이 없다 (허용). 해석 실패와는 다르다.
[ -n "$ABS" ] || exit 0

# 변경 전 내용: 명시적으로 받았으면 그것(HEAD·base), 아니면 디스크의 현재 파일(도구 편집 직전 상태).
old_file="$arg_previous"
if [ -z "$old_file" ] && [ -f "$ABS" ]; then old_file="$ABS"; fi
[ -z "$old_file" ] && [ -z "$CHANGE" ] && CHANGE=A

rels=$(printf '%s\n%s\n%s\n' "${JMS_LOGICAL_PATH:-}" "${ABS#"$ROOT"/}" "$RELS")
python3 "$HERE/judge.py" --rels "$rels" --change "${CHANGE:-M}" \
  ${old_file:+--old "$old_file"} ${RESULT:+--new "$RESULT"}
rc=$?
case "$rc" in
  0) exit 0 ;;
  2) exit 2 ;;
  *) deny_infra "판정기가 종료 코드 ${rc} 로 실패했습니다." ;;
esac
