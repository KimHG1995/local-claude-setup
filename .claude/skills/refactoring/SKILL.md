---
name: refactoring
description: 기존 모듈을 수정하면서 리팩토링을 함께 적용할지 판단한다. 변경이 프론트엔드 영향 없는 안전한 정리(1단계)인지, 응답 계약이 바뀌는 변경(2단계)인지 가른 뒤 해당 유형의 규칙·안티패턴·템플릿만 불러온다. "리팩토링해줘", "DTO 정리해줘", "Swagger 정리", "응답 구조 표준화", "1단계/2단계 리팩토링" 같은 요청에 사용한다.
---

# refactoring

## 유형 판단

아래 중 하나라도 "예"면 **2단계**, 전부 "아니오"면 **1단계**다. 애매하면 사용자에게 확인한다.

- 응답 body의 필드·구조·래핑이 바뀌는가? (`wrapped`/`paged` 등)
- 에러 응답 형식이 바뀌는가? (`StandardErrorFilter` 등)
- 이 API를 쓰는 클라이언트 코드가 함께 바뀌어야 하는가?

해당 참조 **하나만** 읽는다.

- 1단계(안전, 프론트 영향 없음) → [`references/phase1-safe-changes.md`](references/phase1-safe-changes.md)
- 2단계(계약 변경, 사전 협의 필수) → [`references/phase2-contract-changes.md`](references/phase2-contract-changes.md)

## 범위 규칙

- **전면 리팩토링 금지** — 수정 대상 모듈/API 안에서만.
- 1·2단계가 섞여 있으면 1단계만 적용하고, 2단계 대상은 "프론트 협의 후 진행"으로 보고만 한다.
