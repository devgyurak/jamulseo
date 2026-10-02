---
description: 상수 시간 검사 — ctgrind(CI), dudect(기준 장비), 비밀값 경로 어셈블리 덤프
argument-hint: --ctgrind | --dudect [--audit-out <파일>] | --asm <함수 경로>  [--target <이름>]
---

```
./scripts/ct.sh $ARGUMENTS
```

## 세 가지 모드

| 모드 | 조항 | 어디서 | 성격 |
|---|---|---|---|
| `--ctgrind` | C1-07 | Linux x86_64 어디서나 (CI 차단, 게이트 11) | **결정적** — 비밀값을 Valgrind 미정의로 표시하고 실행 |
| `--dudect` | C1-08 | **기준 장비만** (`build/baseline.toml` 의 `ct_host_model`, `JMS_CT_BASELINE_HOST=1`) — 마일스톤 종료 게이트 11b | 통계 — 한 번 실행, `--audit-out docs/audits/attested/<날짜>-C1-08-dudect.md` 로 기록. **사람이** 기준 장비에서 돌리고 승인 서명으로 커밋한다 |
| `--asm <함수>` | C1-09, C4-03 | 어디서나 | 판정 아님 — `ct-auditor` 가 읽고 감사 기록을 쓴다 |

`--target <이름>`: `sbox`, `aria-round`, `key-schedule`, `ghash`, `tag-eq`, `hmac-key`.
M3 부터는 두 측정 모두 `--via-so` 로 **검증 바이너리 `libjamulsoe.so` 를 거치는 대상**을 포함한다 (ct.sh 가 자동으로 넣는다).

## 이 검사의 의미

**증명이 아니라 회귀 탐지다.** 그래서 비밀값 경로를 바꾼 PR 은 결과와 상관없이 `ct-auditor` 가 어셈블리를 보고 `docs/audits/` 에 남긴다.
dudect 를 공유 CI 러너에서 돌리지 않는 이유: CPU 가 매번 달라 "검증 대상 CPU" 와 맞지 않고, 잡음으로 실패하면 "재실행 금지" 와 충돌한다.

## 실패했을 때

1. 어느 대상인지 확인한다 (`--target`)
2. `--asm` 으로 해당 함수의 어셈블리를 덤프해 조건 분기·비밀값 주소 접근·`div` 를 찾는다
3. 소스에서 원인(분기, 인덱싱, 단락 평가, value barrier 누락)을 고친다
4. 툴체인·기준선 변경이 원인이면 사람에게 알린다 (`rust-toolchain.toml`·`build/baseline.toml` 은 사람만 고친다)

## 하지 말 것

- 통과할 때까지 반복 실행하기 (dudect 는 기준 장비에서 정한 횟수로 한 번)
- `DUDECT_T_MAX` 를 올리자고 제안하기
- 누출 대상을 하네스 목록에서 빼기
