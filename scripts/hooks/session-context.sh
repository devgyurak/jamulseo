#!/usr/bin/env bash
# 세션 컨텍스트 — **공통 구현**. 모든 도구가 이것을 출력한다 (stdout = 컨텍스트).
set -uo pipefail
unset CDPATH
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 0
stage=$(grep -m1 '^▶' docs/ROADMAP-STATUS.md 2>/dev/null | sed 's/^▶ *//')
pending=$(awk -F'|' '/^\| Q[0-9]+/ { if ($5 ~ /^[[:space:]]*$/) n++ } END { print n+0 }' docs/kcmvp/inquiries.md 2>/dev/null)

cat <<EOS
## jamulsoe 세션 컨텍스트

**현재 마일스톤**: ${stage:-미상} (docs/ROADMAP-STATUS.md)
**G1 대기 질문**: 답변 없는 시험기관 질문 ${pending:-?}건 (docs/kcmvp/inquiries.md)
→ G1 전에는 M0~M1 만 합니다. module·ffi 의 공개 API, exports.txt, 무결성 태그 방식을 확정하지 않습니다.

**작업 루프**: ① SPEC → ② HARNESS → ③ IMPL → ④ VERIFY → ⑤ REVIEW → ⑥ RECORD
가장 흔한 실패는 ②를 건너뛰고 ③으로 가는 것입니다 (R1). 계획서(docs/PLAN.md)가 정한 것은 다시 결정하지 않습니다.

**계약** (docs/CONTRACTS.md — 다른 모든 결정보다 상위):
- C1 상수 시간: 비밀값으로 분기·인덱싱·가변 지연 명령 금지. S-box 는 회로, GHASH 는 정수 곱셈, 태그 비교는 상수 시간
- C2 C ABI: 오류 시 무변경(I1), 인증 전 평문 없음(I2), NULL·길이·겹침·용량 검사를 출력 전에
- C3 모듈 상태: 승인 동작에서만 암호 서비스(I3), read lock → 상태 확인 → 연산
- C4 CSP 수명: 인벤토리 밖 사본 금지(I4), 키 스케줄은 &mut 출력, 할당 먼저
- C5 경계·형상: 경계 크레이트 외부 의존 0, ffi→module→core, unsafe 는 ffi 에만, export = exports.txt(I5)

**게이트**: ./scripts/verify.sh (--fast 는 개발 중). "미적용"·"실행 불가"는 통과가 아닙니다.
**사람 승인**: 채택 ADR, docs/PLAN.md, docs/CONTRACTS.md, exports.txt, include/jamulsoe.h, rust-toolchain.toml,
게이트·훅, 정답 벡터·코퍼스의 수정·삭제 (.agents/APPROVAL.md).
**추측 금지 (R10)**: 표준 판·연도, GVI 조항, 시험기관 답변을 지어내지 않습니다 → docs/kcmvp/inquiry-drafts.md
EOS
