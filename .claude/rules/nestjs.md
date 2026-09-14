---
paths:
  - "src/**/*.ts"
---

# NestJS 레이어와 경계

> **이 파일은 예시다.** NestJS, TypeORM 0.2.x, class-validator를 쓰는 프로젝트를 기준으로 썼다. 다른 스택에 얹는다면 **통째로 다시 쓴다.** 파일 이름도 그 스택에 맞게 바꾸고, `paths`도 그 프로젝트 구조에 맞춘다.
>
> 가져갈 것은 문장이 아니라 **무엇을 적는가**다. 레이어마다 무엇을 소유하는지, 신뢰경계가 어디인지, 외부 호출에서 무엇을 정해두는지. 그 자리를 채우는 도구 이름만 바뀐다.

`paths`가 걸려 있어 `src/` 아래 `.ts` 파일을 **Read할 때만** 로드된다. 적용 조건과 subagent 상속 문제는 [`code-quality.md`](code-quality.md) 머리와 같다.

관심사는 프레임워크와 무관하지만 그것을 무엇으로 해결하는지는 스택마다 다르다. 그래서 [`minimal-coding.md`](minimal-coding.md)는 "신뢰경계에서 검증한다"까지만 적고, 그 수단을 특정하는 일은 이 파일이 맡는다.

## 레이어가 소유하는 것

| 레이어 | 소유 | 하지 않는 것 |
| --- | --- | --- |
| Controller | HTTP 입출력, 신뢰경계 검증 | 비즈니스 로직 |
| Service | 비즈니스 orchestration, 포함/제외 정책 결정, transaction 경계, Mapper 호출 | 직접 SQL |
| Repository | 영속화, 쿼리 | 비즈니스 판단, DTO 반환 |
| Mapper | Entity에서 DTO로 변환 | 정책 결정 |

- Repository 반환 타입은 Entity, `Entity[]`, `[Entity[], number]`다. DTO를 반환하지 않는다.
- Repository에 DTO를 그대로 넘기지 않는다. Service가 필요한 값만 뽑아 전달한다.
- Mapper에 옵션이 필요하면 Service가 결정해 인자로 넘긴다. Mapper 안에서 정책을 정하지 않는다.
- **transaction 경계는 Service가 소유한다.** Repository가 자기 transaction을 열지 않는다. 한 흐름 안에서 transaction 방식을 혼용하지 않는다.

## 신뢰경계에서 검증한다

[`minimal-coding.md`](minimal-coding.md)가 정의한 신뢰경계는 이 저장소에서 **HTTP 요청이 Controller로 들어오는 지점**이다. 검증은 그 자리에서 한 번 하고, 안쪽 Service끼리의 호출에서 같은 검증을 반복하지 않는다.

이 저장소의 검증 수단은 **class-validator 데코레이터**와 `src/common/decorator/validation-pipe.decorator.ts`의 파이프다.

- Request DTO에 class-validator 데코레이터를 붙인다.
- GET 쿼리는 `@StandardCommonValidationPipe()`, POST body는 `@StandardStrictValidationPipe()`를 쓴다.
- 쿼리 파라미터 boolean은 `@Transform`과 `boolean | string` 타입을 유지한다.

**요청의 허용, 거부, 필수값, 형변환, 기본값 또는 오류 응답이 바뀌면 계약 변경이다.** 검증이 없던 곳에 추가하거나 기존 검증을 데코레이터로 옮길 때 모두 전후 입력을 비교한다. 동등성을 확인한 이동만 1단계이고, 나머지는 `refactoring` 스킬의 2단계로 다룬다.

## 응답

- Entity를 Swagger `@ApiResponse` type으로 직접 쓰지 않는다. 순환 참조 위험이 있고 내부 스키마가 그대로 노출된다. Response DTO를 분리한다.
- Swagger는 `@ApiEndpoint`로 통일한다. 레거시 `@ApiOperation`과 `@ApiResponse` 조합을 새로 추가하지 않는다.
- 외부에서 DTO를 import할 때는 barrel export(`./dto`)를 통한다.
- 응답 형식(래핑, 페이지네이션)을 바꾸는 것은 계약 변경이다. `refactoring` 스킬 2단계로 다룬다.

## 영속화

- **TypeORM 0.2.x API만 쓴다.** DataSource(0.3+) API를 쓰지 않는다.
- Entity 스키마 변경은 마이그레이션 판단이 먼저다. `entity-migration` 스킬이 그 판단을 맡는다.
- 이미 적용된 마이그레이션 파일을 직접 고치지 않는다.

## 외부 호출

- **외부 API 호출에는 timeout을 명시한다.** 기본값에 맡기지 않는다.
- **retry는 idempotency가 보장된 operation에만 건다.** 보장되지 않는 호출에 retry를 걸면 중복 실행이 된다.
- **DB 변경과 외부 API 호출이 한 흐름에 섞이면 실패 순서를 명시한다.** 어느 쪽이 먼저 성공하고 뒤가 실패했을 때 무엇이 남는지 적는다. 적을 수 없으면 순서를 바꾸거나 보상 경로를 만든다.
- 대량 처리 API는 최대 처리량과 메모리 사용을 확인한다. 전건을 한 번에 메모리에 올리지 않는다.

## 네이밍

- Controller 메서드는 `getList`, `getOne`, `create`, `update`, `delete`를 따른다.
- Service 메서드 접두사는 의미에 맞게 쓴다. `get`과 `find`, `create`와 `add`, `delete`와 `remove`를 구분한다.
- `doXxx`, `manageXxx`, `getXxxData`, 그리고 이벤트 핸들러가 아닌 `handleXxx`를 쓰지 않는다.
- 리네이밍하면 호출하는 Controller와 Service도 같이 고친다.

## 한국어 도메인 용어

- 한국어 비즈니스 용어를 임의로 영어로 옮기지 않는다. 기존 표기를 그대로 쓴다.
- 사용자에게 보이는 에러 메시지는 한국어로 쓴다.
