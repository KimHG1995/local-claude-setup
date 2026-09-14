# 1단계 — 안전한 정리 (프론트엔드 영향 없음)

`refactoring` 스킬에서 1단계로 판단됐을 때만 읽는다. 요청의 허용, 거부, 형변환, 기본값, HTTP 상태와 응답 형식이 유지된다는 전제 위에서만 아래 항목을 적용한다.

기능 구현, 버그 수정과 **함께 자연스럽게** 적용하는 것이지, 리팩토링 자체가 목적인 별도 작업을 임의로 벌이지 않는다. 범위를 넓히려면 먼저 확인받는다.

## 생성 규칙

1. **Swagger 데코레이터는 `@ApiEndpoint`로 통일한다.** 레거시 `@ApiOperation` + `@ApiResponse` 조합을 새로 추가하지 않는다.
2. **Entity를 Swagger response type으로 직접 쓰지 않는다.** `dto/` 폴더에 Response DTO를 분리하고 Mapper로 변환한다.
3. **검증 이동은 기존 검증과 동등한 경우에만 1단계다.** 기존 검증이 있다는 사실만으로 충분하지 않다. 누락, `null`, `0`, 소수, 문자열 숫자, 정상값의 허용, 거부와 변환 결과를 전후 비교한다. 오류 상태, 본문까지 유지되는지 확인한다. 새 검증, 필수값 완화, 정수 제한, 자동 형변환은 2단계다.
4. **`@StandardCommonValidationPipe` / `@StandardStrictValidationPipe` 전환도 3번과 같은 전제를 따른다.** `transform`, `whitelist`, 누락 필드 처리와 오류 변환 설정까지 확인한다. 동등성을 입증하지 못하면 기존 검증을 유지한다.
5. **Enum은 모듈 범위 안에서만 `as const`로 옮긴다.** 다른 모듈이 참조하는 공유 enum은 범위 밖이다.

## Anti-pattern

- ❌ 검증 로직이 없던 필드에 `class-validator`를 새로 추가하고 "그냥 안전한 리팩토링"이라고 부르는 것 — 400 응답이 새로 생기는 순간 계약 변경이다.
- ❌ DTO 분리를 하면서 필드명, 타입까지 같이 바꾸는 것 — 분리와 재설계를 한 커밋에 섞으면 리뷰에서 무엇이 실제 동작 변경인지 구분할 수 없다.
- ❌ "하는 김에" 옆 엔드포인트까지 `@ApiEndpoint`로 정리하는 것 — 수정 대상 모듈 범위를 벗어난 정리는 1단계 규칙이 아니라 범위 위반이다.

## Template

### Swagger 데코레이터 교체

```ts
// ❌ Before
@ApiOperation({ summary: '목록 조회' })
@ApiResponse({ status: 200, type: SomeEntity })
@ApiResponse({ status: 400, description: 'Bad Request' })

// ✅ After
@ApiEndpoint({
  summary: '목록 조회',
  response: { type: SomeResponse },
})
```

### Response DTO 디렉터리 구조

```
src/modules/{module}/
  dto/
    shared/
      {module}-base.response.ts
    endpoints/
      /{endpoint}/
        request.ts
        response.ts
    index.ts   ← barrel export
```

### 기존 검증의 동등성 확인

```ts
// 기존 검증: 숫자 타입이면 소수도 허용하고, 누락과 null은 거부한다.
if (typeof payload.count !== 'number') {
  throw new HttpException('count는 숫자여야 합니다', HttpStatus.BAD_REQUEST);
}
```

이를 `@IsOptional()` + `@Type(() => Number)` + `@IsInt()`로 옮기면 다음처럼 달라진다. `@Type` 변환이 실행되는 파이프를 전제로 한다.

| count 입력 | 기존 검증 | 변경안 | 분류 |
| --- | --- | --- | --- |
| 누락 / `null` | 거부 | 허용 | 필수값 완화 |
| `1.5` | 허용 | 거부 | 정수 제한 |
| `'2'` | 거부 | 숫자 `2`로 변환 후 허용 | 입력 형변환 |
| `0` / `2` | 허용 | 허용 | 이 사례만으로 동등성을 입증할 수 없음 |

**이 변경안은 2단계다.** 1단계 작업에서는 기존 검증을 유지하고, 검증 이동이 필요하면 위 경계값과 기존 오류 응답을 고정한 회귀 테스트로 동등성을 먼저 확인한다. 특정 데코레이터 조합을 모든 수동 검증의 대체물로 사용하지 않는다.

쿼리 파라미터 boolean은 `@Transform` + `boolean | string` 타입을 유지한다 (ValidationPipe가 없는 경로이므로).

### 검증 파이프 전환

```ts
// GET 쿼리 — 미존재 필드 허용
@StandardCommonValidationPipe()
async getList(@Query() query: ListRequest) {}

// POST body — 불필요 필드 차단
@StandardStrictValidationPipe()
async create(@Body() payload: CreatePayload) {}
```

`src/common/decorator/validation-pipe.decorator.ts` 참조.

### Enum → as const

```ts
export const SomeStatus = { 활성: '활성', 비활성: '비활성' } as const;
export type SomeStatus = (typeof SomeStatus)[keyof typeof SomeStatus];
```

## Example

`notice` 모듈에서 레거시 `@ApiOperation`/`@ApiResponse`를 `@ApiEndpoint`로 옮기고, `NoticeEntity`를 직접 반환하던 응답을 `NoticeResponse` DTO + Mapper로 분리한 커밋이 참고 사례다. 응답 JSON 구조(필드명, 중첩 구조)는 이전과 동일했고, 타입 선언과 Swagger 문서만 정리됐다.

## 제외 항목 (2단계로 분리)

- `@UseFilters(StandardErrorFilter)` — 에러 응답 형식 변경
- `@UseInterceptors(ResponseTransformInterceptor)` — 성공 응답 형식 변경
- `@ApiEndpoint`의 `wrapped: true` / `paged: true` 옵션

위 항목은 프론트엔드 응답 파싱 코드가 함께 바뀌어야 하므로 [`phase2-contract-changes.md`](phase2-contract-changes.md)에서 다룬다.

## 검증 스크립트

```bash
bash .claude/skills/refactoring/scripts/validate.sh <module-path>
```

내부적으로 `yarn typecheck` → `yarn test <module-path>`(생략 가능) → `yarn lint` 순서로 실행하고, 하나라도 실패하면 로그를 남기고 비정상 종료한다.

## 완료 후

적용한 유형과 검증 스크립트 결과를 한 줄로 요약해 보고한다. 2단계 대상을 발견했지만 이번에 적용하지 않았다면 그것도 함께 알린다.
