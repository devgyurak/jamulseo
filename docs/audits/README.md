# 감사 기록

계약 레지스트리의 `manual` 단계(어셈블리 감사, dudect 기준 장비 측정, 재진입 없음 확인 등)의 **증거**가 여기 쌓인다.
`scripts/contract_check.py` 가 아래 머리말을 읽어 **지금도 유효한지** 판정한다.

- 이 디렉터리는 **새 파일 추가만** 가능하다 (scripts/hooks/protected.tsv). 다시 감사하면 새 파일을 쓴다 — 지난 기록은 형상관리 증거다
- 파일 이름: `<YYYY-MM-DD>-<조항 ID>-<짧은 주제>.md`
- 작성: 감사한 리뷰어(`ct-auditor` 등)가 직접 쓴다. 구현자가 대신 쓰거나 요약하지 않는다
- **한계**: 이 디렉터리는 에이전트가 새 파일을 쓸 수 있으므로, 구현 세션이 `verdict: pass` 를 직접 쓰는 것을 기계적으로 막지 못한다.
  PR 리뷰(`contract-auditor`, 사람)가 감사 기록의 작성자와 근거를 확인한다
- **`attested/`** 는 사람 전용 경로다 (scripts/hooks/protected.tsv). 레지스트리에서 `attest: human` 인 단계(현재 C1-08 dudect 기준 장비 측정)는
  여기 있는 기록만 증거로 인정한다. 사람이 `JMS_APPROVED_BY=<이름> git commit -s -S` 로 남긴다

## 최소 범위

레지스트리의 manual 단계에는 조항별 **최소 범위(`scope`)** 가 있다. 감사 파일의 `scope` 는 그것을 **포함**해야 한다
(같은 경로이거나 상위 디렉터리). 좁은 범위를 적어 코드가 바뀌어도 증거가 낡지 않게 하는 것을 막는다.
레지스트리의 `scope` 는 넓히는 것만 에이전트가 할 수 있고, 좁히는 것은 사람만 한다.

## 머리말 (필수)

```
---
contract: C1-09, C4-03          # 이 감사가 증거가 되는 조항 ID
toolchain: 1.98.1               # 감사 시점 rust-toolchain.toml channel — 바뀌면 무효
commit: <40자 SHA>               # 감사한 커밋 — HEAD 의 조상이어야 한다
scope: crates/jamulsoe-core/src build/baseline.toml   # 이 경로가 commit 이후 바뀌면 무효
target: x86_64-unknown-linux-gnu cpu=<기준선>
auditor: ct-auditor (세션) / 사람 이름
verdict: pass                   # pass 가 아니면 증거가 아니다
---
```

## 본문

- 감사한 함수 목록과 방법 (`./scripts/ct.sh --asm <함수>` 덤프 위치 등)
- 발견한 것, 판단 근거
- **확인하지 못한 것** (예: 검증 대상 CPU 실기 측정 없음, 레지스터 spill)
