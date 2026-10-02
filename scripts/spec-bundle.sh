#!/usr/bin/env bash
# 명세 전용 작업 묶음 — 구현을 보지 않아야 하는 역할용 (.agents/INDEPENDENCE.md 2겹)
#
#   ./scripts/spec-bundle.sh --for oracle-author   → target/spec-bundle/
#   ./scripts/spec-bundle.sh --for spec-redteam --out target/redteam
#
# ⚠️ 출력 디렉터리를 지운다. 그래서 target/ 아래, 그리고 이 스크립트가 만든 묶음만 지운다.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

MARKER=".jms-spec-bundle"
ROLE=""; OUT="target/spec-bundle"; FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --for)   [ $# -ge 2 ] || die "--for 값이 필요합니다"; ROLE="$2"; shift 2 ;;
    --out)   [ $# -ge 2 ] || die "--out 값이 필요합니다"; OUT="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    *) die "알 수 없는 옵션: $1" ;;
  esac
done

case "$OUT" in /*) die "--out 은 저장소 상대 경로여야 합니다: $OUT" ;; *..*) die "--out 에 '..' 을 쓸 수 없습니다" ;; esac
mkdir -p "$ROOT/target"
parent=$(dirname "$ROOT/$OUT"); mkdir -p "$parent"
norm_out="$(cd "$parent" && pwd -P)/$(basename "$OUT")"
real_root="$(cd "$ROOT" && pwd -P)"
case "$norm_out" in "$real_root"/target/*) ;; *) die "--out 은 target/ 아래여야 합니다 (정규화: $norm_out)" ;; esac

if [ -e "$norm_out" ]; then
  [ -d "$norm_out" ] || die "$OUT 이 디렉터리가 아닙니다."
  [ -f "$norm_out/$MARKER" ] || [ "$FORCE" = 1 ] || die "$OUT 이 이미 있고 spec-bundle 이 만든 것이 아닙니다 ($MARKER 없음)."
  rm -rf "${norm_out:?}"
fi

step "명세 전용 묶음 생성"
mkdir -p "$norm_out"
: > "$norm_out/$MARKER"

copy() { [ -e "$1" ] || return 0; mkdir -p "$norm_out/$(dirname "$1")"; cp -R "$1" "$norm_out/$1"; }

# 공통: 계획서·계약·테스트 전략·ADR·규약 (원본은 읽기만)
for p in AGENTS.md docs/PLAN.md docs/CONTRACTS.md docs/TESTING.md docs/adr docs/kcmvp/inquiries.md; do copy "$p"; done
# 공개 인터페이스 (구현 아님)
copy include/jamulsoe.h
copy exports.txt
# 표준 원문 — 모델 기억이 아니라 원문으로 쓰게 한다 (R10). local/ 은 재배포 불가 원문(KS X 등, git 제외)
copy docs/standards
# 오라클은 정답 벡터로 자신을 검증한다
case "$ROLE" in oracle-author) copy tests/vectors ;; esac

if [ -n "$ROLE" ]; then
  [ -f ".agents/roles/${ROLE}.md" ] || die "알 수 없는 역할: $ROLE"
  copy ".agents/roles/${ROLE}.md"
  copy .agents/INDEPENDENCE.md
fi

cat > "$norm_out/README.md" <<EOS
# 명세 전용 작업 묶음

역할: ${ROLE:-(미지정)}

## 여기 있는 것
계획서(동결본), 계약 C1~C5, 테스트 전략, ADR, 시험기관 문의 기록, **표준 원문(docs/standards/)**, 공개 헤더(있으면)$( [ "$ROLE" = oracle-author ] && printf ', 정답 벡터' )

## 여기 **없는** 것 — 의도적입니다
경계 크레이트 구현 (\`crates/jamulsoe-core\`·\`-module\`·\`-ffi\` 의 \`src/\`), 기존 하네스 구현

## 규칙
이 묶음으로 설계하세요. 구현 디렉터리를 열지 마세요.
상수(S-box, CK, 초기값 등)는 **표준 원문에서 옮기고 출처(문서·절·쪽)를 주석으로** 남기세요. 기억으로 쓰지 않습니다.
표준 원문이 묶음에 없으면 멈추고 보고하세요 (KS X 원문은 사람이 docs/standards/local/ 에 둡니다).
명세가 모호하면 **모호하다고 보고**하세요. 임의로 정하면 찾아야 할 것을 덮습니다.
EOS

ok "생성: $OUT (파일 $(find "$norm_out" -type f | wc -l | tr -d ' ')개)"
info "근거: .agents/INDEPENDENCE.md"
finish
