---
description: 검증 하네스 규칙 — 오라클 독립성, 상수 시간 하네스
paths:
  - "crates/jamulsoe-oracle/**"
  - "crates/jamulsoe-ct/**"
globs:
  - "crates/jamulsoe-oracle/**"
  - "crates/jamulsoe-ct/**"
alwaysApply: false
order: 250
---

# 규칙: 검증 하네스

적용: `crates/jamulsoe-{oracle,ct}/**` · 전문: `docs/TESTING.md`, `.agents/INDEPENDENCE.md`

두 크레이트 모두 **경계 밖**이다 (`publish = false`). 경계 크레이트의 `[dependencies]` 에 들어가지 않는다.

## `jamulsoe-oracle` — 독립 참조 모델

🚫 **경계 크레이트에 의존하지 않고, 그 `src/` 를 읽지 않는다.** `scripts/lint-boundary.sh` 가 의존을 차단한다.

- **최적화하지 않는다.** 테이블 S-box, 바이트 단위 확산층, 비트 단위 GF(2^128) 곱셈, 교과서식 SHA-256
- 상수 시간이 아니어도 된다. 대신 **읽고 표준과 대조하기 쉬워야** 한다
- 구현과 **다른 표현**을 고른다 — 같은 표현이면 같은 실수를 공유한다
- 오라클 자신을 정답 벡터로 먼저 검증한다
- 구현과 다르면 **누가 맞는지 판단하지 않는다.** 입력과 함께 "해석이 갈렸다"고 보고

## `jamulsoe-ct` — 상수 시간 하네스

`scripts/ct.sh` 가 부르는 인터페이스를 지킨다:

| 바이너리 | 하는 일 | 어디서 | 종료 코드 |
|---|---|---|---|
| `ctgrind [--target T] [--via-so <.so>]` | 비밀값을 Valgrind 미정의로 표시하고 대상 실행. **결정적** | CI 차단 게이트 (C1-07) | 0 / 1 |
| `dudect [--target T] [--via-so <.so>] --max-t <값> --measurements <N>` | 고정 vs 무작위 입력 타이밍 t-검정 | **기준 장비**, 마일스톤 종료 (C1-08) | 0 통과 / 1 누출 의심 |

- `--via-so`: M3 부터 필수. 하네스에 링크된 코어가 아니라 **검증 바이너리 `libjamulsoe.so` 를 `dlopen` 해 C ABI 로** 측정하는 대상을 포함한다
- dudect 는 공유 CI 러너에서 돌리지 않는다. CPU 가 매번 달라 C1 의 "검증 대상 CPU" 와 맞지 않고, 잡음 실패는 "재실행 금지" 와 충돌한다

- 대상: ARIA S-box 회로·라운드, 키 스케줄, GHASH 곱셈, 태그 비교, HMAC 키 처리
- 측정은 **릴리스 프로파일·기준 CPU 플래그**로. 디버그 빌드 측정은 의미가 없다
- 임계(`DUDECT_T_MAX`)는 `scripts/_common.sh` 에만 있다. 하네스에 하드코딩하지 않는다
- 통과는 "이 측정에서 못 찾았다"일 뿐이다. 보고에 측정 횟수·CPU·툴체인을 남긴다
- 하네스 자체가 누출을 잡는지 **일부러 새는 대상**(테이블 조회 S-box)으로 확인하는 자기 시험을 둔다
