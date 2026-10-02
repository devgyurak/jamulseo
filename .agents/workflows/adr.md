---
description: ⑥ RECORD — ADR 을 정리하고 사람 승인 대기 상태로 만든다
argument-hint: <ADR 번호 | 주제>
---

대상: **$ARGUMENTS**

## 절차

1. `docs/adr/NNNN-*.md` 가 필수 섹션을 전부 갖췄는지 확인:
   - 맥락 / 고려한 선택지(**최소 3개**) / 결정 / 근거 / 기각한 것과 이유
   - **건드리는 계약** / **만드는 새 반례** / **KCMVP 영향** / 검증 방법 / 되돌리는 비용
2. 새 반례가 `tests/contracts/registry.json` 에 등록되었는지 확인 (`./scripts/contract-check.sh`)
3. KCMVP 영향이 있으면 `kcmvp-writer` 로 `docs/kcmvp/` 초안에 반영할 문구를 정리한다
4. `docs/ROADMAP-STATUS.md` 갱신
5. 참고 자료가 있었다면 `docs/provenance.md` 기록 확인

## 그다음

> ⚠️ **상태를 `제안`에서 `채택`으로 바꾸는 것은 사람이 한다 (R4).**
> 에이전트는 여기서 멈추고, 무엇이 승인 대기 중인지 요약해 보고한다.

계약(`docs/CONTRACTS.md`)·계획서(`docs/PLAN.md`)가 바뀌어야 한다면 그것도 사람 승인 대상이다.
변경 절차는 `docs/CONTRACTS.md` 맨 아래 "계약 변경 절차"를 따른다.
