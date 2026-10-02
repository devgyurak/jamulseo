---
description: ABI·심볼 회귀 — cbindgen 헤더 diff, nm -D 와 exports.txt 비교, C 예제 빌드·실행
---

```
./scripts/abi-check.sh
```

## 무엇을 확인하는가

| 검사 | 기준 | 실패 의미 |
|---|---|---|
| 헤더 | cbindgen 생성 결과 = `include/jamulsoe.h` | 공개 시그니처·상수가 바뀌었다 |
| 심볼 | `nm -D --defined-only libjamulsoe.so` = `exports.txt` | export 가 늘거나 줄었다 (I5) |
| C 예제 | `tests/c/` 가 헤더로 빌드되고 실행된다 | 헤더와 실제 동작이 어긋난다 |

심볼 비교는 Linux(ELF)에서만 의미가 있다. 다른 플랫폼은 **실행 불가**.

## 실패했을 때

- **의도하지 않은 변경**이면 코드를 되돌린다 (예: `pub fn` 에 `#[no_mangle]` 이 붙음, 의존 크레이트의 심볼이 새어 나옴)
- **의도한 변경**이면 멈추고 사람에게 묻는다. `include/jamulsoe.h`·`exports.txt` 는 보호 경로다.
  G1 이후의 공개 인터페이스 변경은 보안정책문서·설계서 변경이고, `kcmvp/v1` 이후에는 재검증 사유다

## 하지 말 것

- `exports.txt`·헤더를 생성 결과에 맞춰 고쳐서 통과시키기
- 심볼을 숨기려고 링커 스크립트·버전 스크립트를 몰래 바꾸기 (빌드 설정 변경은 `build-engineer` + 리뷰)
