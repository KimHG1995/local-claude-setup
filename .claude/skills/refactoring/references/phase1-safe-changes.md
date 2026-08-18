# 1단계 — 안전한 정리 (프론트엔드 영향 없음)

`refactoring` 스킬에서 1단계로 판단됐을 때만 읽는다. 응답 형식은 바뀌지 않는다는 전제 위에서만 아래 항목을 적용한다.

기능 구현·버그 수정과 **함께 자연스럽게** 적용하는 것이지, 리팩토링 자체가 목적인 별도 작업을 임의로 벌이지 않는다. 범위를 넓히려면 먼저 확인받는다.

## 생성 규칙

1. **Swagger 데코레이터는 `@ApiEndpoint`로 통일한다.** 레거시 `@ApiOperation` + `@ApiResponse` 조합을 새로 추가하지 않는다.
2. **Entity를 Swagger response type으로 직접 쓰지 않는다.** `dto/` 폴더에 Response DTO를 분리하고 Mapper로 변환한다.
3. **Request DTO에 `class-validator`를 추가하는 것은 해당 엔드포인트에 이미 검증 로직이 있을 때만 허용한다.** (수동 `if` 검증, 기존 `validateDTO` 호출 등) 검증이 아예 없던 엔드포인트에 새로 추가하면 지금까지 통과하던 요청이 400이 되어 그 자체로 프론트 영향이 생긴다 — 이건 1단계가 아니라 2단계다.
4. **`@StandardCommonValidationPipe` / `@StandardStrictValidationPipe` 전환도 3번과 같은 전제를 따른다.** 기존 검증을 파이프로 옮기는 것만 1단계다.
5. **Enum은 모듈 범위 안에서만 `as const`로 옮긴다.** 다른 모듈이 참조하는 공유 enum은 범위 밖이다.

## Anti-pattern

- ❌ 검증 로직이 없던 필드에 `class-validator`를 새로 추가하고 "그냥 안전한 리팩토링"이라고 부르는 것 — 400 응답이 새로 생기는 순간 계약 변경이다.
- ❌ DTO 분리를 하면서 필드명·타입까지 같이 바꾸는 것 — 분리와 재설계를 한 커밋에 섞으면 리뷰에서 무엇이 실제 동작 변경인지 구분할 수 없다.
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

### 기존 수동 검증 → class-validator 이동

```ts
// ❌ Before — 서비스에서 수동 검증
if (!payload.id) throw new HttpException('id 필수', HttpStatus.BAD_REQUEST);
if (typeof payload.count !== 'number') throw ...;

// ✅ After — 같은 규칙을 DTO 데코레이터로
export class SomeRequestDto {
  @IsNotEmpty()
  @Type(() => Number)
  @IsInt()
  id: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  count?: number;
}
```

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

`notice` 모듈에서 레거시 `@ApiOperation`/`@ApiResponse`를 `@ApiEndpoint`로 옮기고, `NoticeEntity`를 직접 반환하던 응답을 `NoticeResponse` DTO + Mapper로 분리한 커밋이 참고 사례다. 응답 JSON 구조(필드명·중첩 구조)는 이전과 동일했고, 타입 선언과 Swagger 문서만 정리됐다.

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
