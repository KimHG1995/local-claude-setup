---
name: refactoring
description: 기존 모듈의 리팩토링, DTO, 검증, Swagger 정리, 요청, 응답 구조 변경, 1단계/2단계 분류가 필요한 작업에 사용한다.
---

# refactoring

## 유형 판단

아래 중 하나라도 "예"면 **2단계**, 전부 "아니오"면 **1단계**다. 애매하면 사용자에게 확인한다.

- 응답 body의 필드, 구조, 래핑이 바뀌는가? (`wrapped`/`paged` 등)
- 요청의 허용, 거부, 필수값, 기본값, 형변환 또는 HTTP 상태가 바뀌는가?
- 에러 응답 형식이 바뀌는가? (`StandardErrorFilter` 등)
- 이 API를 쓰는 클라이언트 코드가 함께 바뀌어야 하는가?

해당 참조 **하나만** 읽는다.

- 1단계(요청, 응답 계약 유지) → [`references/phase1-safe-changes.md`](references/phase1-safe-changes.md)
- 2단계(계약 변경, 사전 협의 필수) → [`references/phase2-contract-changes.md`](references/phase2-contract-changes.md)

## 범위 규칙

- **전면 리팩토링 금지** — 수정 대상 모듈/API 안에서만.
- 1단계와 2단계가 섞여 있으면 1단계만 적용하고, 2단계 대상은 "프론트 협의 후 진행"으로 보고만 한다.
