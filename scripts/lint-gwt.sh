#!/usr/bin/env bash
# GWT 네이밍 — 모든 #[test]/#[proptest] 함수 이름은 given_<상태>_when_<행위>_then_<관측 가능한 기대>
#   ./scripts/lint-gwt.sh            전체
#   ./scripts/lint-gwt.sh --file F   파일 하나 (편집 후 훅)
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

files=()
if [ "${1:-}" = "--file" ]; then
  [ $# -ge 2 ] || die "--file 값이 필요합니다"
  files=("$2")
else
  while IFS= read -r f; do files+=("$f"); done < <(rust_sources)
fi
[ "${#files[@]}" -gt 0 ] || { ok "Rust 소스 없음"; exit 0; }

bad=$(awk '
  FNR==1 { p=0 }
  /^[[:space:]]*#\[(test|tokio::test|proptest)\]/ { p=1; next }
  p && /^[[:space:]]*#\[/ { next }                        # 다른 속성은 건너뛴다
  p && match($0, /fn[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/) {
    n = substr($0, RSTART+3, RLENGTH-3); gsub(/^[[:space:]]+/, "", n)
    if (n !~ /^given_.+_when_.+_then_.+$/) print FILENAME ":" FNR ": " n
    else if (n ~ /_then_(works|ok|success|passes|correct)$/) print FILENAME ":" FNR ": " n "  (then_ 뒤는 관측 가능한 결과)"
    p=0
  }' ${files[@]+"${files[@]}"})

if [ -n "$bad" ]; then
  printf 'GWT 네이밍 위반:\n%s\n형식: given_<상태>_when_<행위>_then_<관측 가능한 기대>\n' "$bad" >&2
  exit 1
fi
ok "GWT 네이밍 (${#files[@]}개 파일)"
