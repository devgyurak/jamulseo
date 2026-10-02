---
description: KCMVP 제출물 초안·출처 기록 규칙 — 과장 금지, 근거 필수
paths:
  - "docs/kcmvp/**"
  - "docs/provenance.md"
globs:
  - "docs/kcmvp/**"
  - "docs/provenance.md"
alwaysApply: false
order: 270
---

# 규칙: KCMVP 제출물 초안 · 출처

적용: `docs/kcmvp/**`, `docs/provenance.md` · 근거: 계획서 §KCMVP 요건 매핑, KS X ISO/IEC 19790·24759, GVI

## 절대 규칙

1. **"검증됨·인증됨·검증필" 금지.** 검증서 번호가 나오기 전까지 사실이 아니다
2. **코드·테스트가 증명하는 것만 쓴다.** 주장마다 근거(파일, 테스트 이름, 레지스트리 ID)를 단다
3. **문서가 코드보다 많이 약속하면 문서를 줄인다**
4. **한계를 숨기지 않는다** — 레지스터·컴파일러 사본, 64비트 곱셈 상수 시간 가정, 무결성 시험의 한계, 할당자 abort·OOM killer
5. **표준 판·연도, GVI 조항, 시험기관 해석은 원문을 확인한 것만.** 아니면 "확인 필요 (inquiries.md Q_)"
6. **`docs/kcmvp/inquiries.md` 는 사람만 고친다.** 에이전트는 질문 초안을 보고에 쓰거나 `docs/kcmvp/inquiry-drafts.md` 에 추가한다

## `docs/provenance.md` 항목 형식

| 자료 | 출처 | 저자·문서 | 라이선스 | 확보일 | SHA-256 | 쓰임 |
|---|---|---|---|---|---|---|

"쓰임"은 셋 중 하나: **설계 참고** / **테스트 오라클** / **코드 차용 없음 확인**.
코드 차용은 R9 위반이므로 이 표에 "차용"이 나오면 안 된다.
