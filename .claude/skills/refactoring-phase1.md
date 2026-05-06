# 1단계 리팩토링 가이드 (프론트엔드 영향 없음 · 즉시 적용 가능)

> **참조 가이드 (Guide)** — 슬래시 커맨드가 아니다.
> 리팩토링 작업 시 "1단계 리팩토링 가이드 참고해서 진행해줘"처럼 대화 중 직접 언급하거나,
> `/new-feature` 커맨드 실행 시 리팩토링 단계 판단 기준으로 참조된다.

## 적용 조건

모듈을 수정하는 작업(버그 수정·기능 추가)과 함께 **자연스럽게** 적용한다.
전면 리팩토링 금지 — 수정 대상 모듈/API 범위 안에서만.

## 포함 항목 (안전 — 응답 형식 불변)

### 1. Swagger 데코레이터 → @ApiEndpoint 교체

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

- `src/swagger/decorators/api-endpoint.decorator.ts` 사용
- Entity를 `@ApiResponse` type으로 직접 쓰는 경우 → Response DTO 분리 후 교체

### 2. Response DTO 분리 (Entity → DTO)

- Entity를 Swagger response type으로 쓰면 순환 참조 위험
- `dto/` 폴더에 Response DTO 신규 생성
- Mapper 패턴으로 변환: `Object.assign(new ResponseDto(), plain)`

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

### 3. Request DTO class-validator 추가 (기존 검증 로직 존재 시에만)

**전제 조건**: 해당 엔드포인트에 이미 검증 로직이 있는 경우에만 적용.
검증이 없는 엔드포인트에 새로 추가하면 기존에 통과하던 요청이 400이 되어 프론트 영향 발생.

**적용 가능한 경우** — 아래 패턴이 이미 존재할 때:

```ts
// 서비스/레포에서 수동 검증 중인 경우
if (!payload.id) throw new HttpException('id 필수', HttpStatus.BAD_REQUEST);
if (typeof payload.count !== 'number') throw ...;

// 기존 validateDTO 유틸 호출 중인 경우
validateDTO(SomeDto, payload);
```

이런 경우, 동일한 규칙을 DTO의 `class-validator` 데코레이터로 이동:

```ts
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

쿼리 파라미터 boolean은 `@Transform` + `boolean | string` 타입 유지 (ValidationPipe 없으므로).

### 4. @StandardCommonValidationPipe / @StandardStrictValidationPipe (기존 검증 존재 시에만)

**전제 조건**: 위 3번과 동일 — 기존에 검증하던 엔드포인트를 파이프로 전환할 때만.
기존 검증 없는 엔드포인트에 새로 파이프를 추가하는 것은 **2단계 또는 별도 작업**으로 분리.

```ts
// GET 쿼리: 미존재 필드 허용 (기존 검증을 파이프로 대체)
@StandardCommonValidationPipe()
async getList(@Query() query: ListRequest) {}

// POST body: 불필요 필드 차단 (기존 validateDTO를 파이프로 대체)
@StandardStrictValidationPipe()
async create(@Body() payload: CreatePayload) {}
```

- `src/common/decorator/validation-pipe.decorator.ts`

### 5. Enum → as const 마이그레이션 (해당 모듈만)

```ts
export const SomeStatus = { 활성: '활성', 비활성: '비활성' } as const;
export type SomeStatus = typeof SomeStatus[keyof typeof SomeStatus];
```

## 제외 항목 (2단계로 분리)

- `@UseFilters(StandardErrorFilter)` — 에러 응답 형식 변경
- `@UseInterceptors(ResponseTransformInterceptor)` — 성공 응답 형식 변경
- `@ApiEndpoint` 의 `wrapped: true` / `paged: true` 옵션

위 항목은 **프론트엔드 응답 파싱 코드가 함께 바뀌어야** 하므로 2단계에서 처리.

## 검증 순서

1. `yarn typecheck` — 타입 에러 없음
2. `yarn test <module>` — 기존 테스트 통과
3. `yarn lint` — 린트 통과
