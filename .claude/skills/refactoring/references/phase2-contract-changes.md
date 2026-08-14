# 2단계 — 계약 변경 (프론트엔드 협의 필수)

`refactoring` 스킬에서 2단계로 판단됐을 때만 읽는다. **API 응답 형식이 실제로 바뀐다.**

## ⚠️ 진행 전 확인

아래 세 가지가 확인되지 않았으면 코드를 쓰지 않고 먼저 사용자에게 확인받는다.

- [ ] 프론트엔드(또는 모바일) 팀과 변경 대상 API 응답 형식 사전 협의가 끝났는가?
- [ ] 해당 API를 쓰는 클라이언트 코드 수정 일정이 잡혀 있는가?
- [ ] 스테이지 환경에서 클라이언트와 통합 테스트가 예정돼 있는가?

세 개 중 하나라도 불확실하면, 1단계까지만 적용하고 2단계는 "협의 후 진행" 항목으로 보고만 한다.

## 생성 규칙

1. **1단계가 먼저 끝나 있어야 한다.** DTO/Mapper 분리 없이 바로 Filter·Interceptor를 얹지 않는다.
2. **컨트롤러 단위로 opt-in한다.** 모듈 전체에 전역 적용하지 않고, 협의가 끝난 컨트롤러에만 `@UseFilters`/`@UseInterceptors`를 건다.
3. **`StandardErrorFilter`는 Module `providers`에 등록한다.** 등록을 빠뜨리면 필터가 조용히 무시된다.
4. **페이지네이션 응답은 `buildPageData` 유틸을 거친다.** 직접 `{ items, page, ... }` 객체를 조립하지 않는다 — 필드명이 모듈마다 갈라지는 원인이다.
5. **에러는 상황에 따라 두 형태 중 하나로 던진다.** 프론트가 code 기반 분기를 하지 않는 단순 케이스는 `HttpException`, code 분기가 필요하면 `CommonException`.

## Anti-pattern

- ❌ 프론트 협의 없이 `ResponseTransformInterceptor`부터 걸어두고 "다음 스프린트에 얘기하면 되지"라고 미루는 것 — 이 순간 이미 기존 클라이언트가 깨진다.
- ❌ 페이지네이션 응답을 컨트롤러마다 직접 조립하는 것 — `totalPages`/`hasNext` 계산이 모듈마다 미묘하게 달라진다.
- ❌ `StandardErrorFilter`를 컨트롤러 데코레이터로만 걸고 Module `providers` 등록을 빠뜨리는 것 — 타입체크는 통과하지만 런타임에 필터가 적용되지 않는다.
- ❌ 1단계와 2단계를 같은 커밋에 섞는 것 — 계약이 바뀐 지점을 리뷰어가 diff에서 즉시 찾을 수 있어야 한다.

## Template

### 응답 형식 변화

```json
// Before (레거시 응답)
{ "id": 1, "name": "..." }

// After — wrapped: true
{
  "success": true,
  "data": { "id": 1, "name": "..." },
  "meta": { "traceId": "...", "timestamp": "..." }
}

// After — paged: true
{
  "success": true,
  "data": {
    "items": [ ... ],
    "page": 1, "size": 10,
    "totalCount": 100, "totalPages": 10, "hasNext": true
  },
  "meta": { ... }
}
```

### 컨트롤러 opt-in

```ts
import { StandardErrorFilter } from 'src/common/filters/standard-error.filter';
import { ResponseTransformInterceptor } from 'src/common/interceptors/response-transform.interceptor';

@UseFilters(StandardErrorFilter)
@UseInterceptors(ResponseTransformInterceptor)
@Controller('api/some')
export class SomeController {}
```

### `@ApiEndpoint` 옵션

```ts
// 단건/배열
response: { type: SomeResponse, wrapped: true }
response: { type: SomeResponse, isArray: true, wrapped: true }

// 페이지네이션
response: { type: SomeResponse, paged: true }
```

### 페이지네이션 서비스 반환

```ts
import { buildPageData } from 'src/common/utils/pagination.util';

async list(query): Promise<ApiPageData<SomeResponse>> {
  const [items, totalCount] = await this.repo.findAndCount(query);
  const dtos = items.map(SomeMapper.toDto);
  return buildPageData(dtos, totalCount, query.page, query.countPerPage);
}
```

### Module 등록

```ts
@Module({
  providers: [SomeService, StandardErrorFilter],
})
export class SomeModule {}
```

### 에러 throw

```ts
// HTTP status 기반 자동 code 생성
throw new HttpException('이미 등록된 항목입니다.', HttpStatus.BAD_REQUEST);

// 프론트에서 code 기반 분기 시
throw new CommonException({
  CODE: 'SOME_ALREADY_EXISTS',
  MESSAGE: '이미 등록된 항목입니다.',
  STATUS: HttpStatus.BAD_REQUEST,
});
```

## Example

`notice` 모듈이 적용 예시다 — `src/modules/notice/notice.controller.ts`에서 `StandardErrorFilter` + `ResponseTransformInterceptor`를 opt-in으로 걸고, 목록 API는 `paged: true`로 전환했다. 전환 전 프론트와 응답 스키마를 문서로 먼저 공유하고, 스테이지에서 클라이언트 통합 테스트를 거친 뒤 배포했다.

## 관련 파일

- `src/common/filters/standard-error.filter.ts`
- `src/common/interceptors/response-transform.interceptor.ts`
- `src/common/dto/api-response.dto.ts`
- `src/common/utils/pagination.util.ts`
- `src/modules/notice/notice.controller.ts` ← 적용 예시

## 검증 스크립트

```bash
bash .claude/skills/refactoring/scripts/validate.sh <module-path>
```

typecheck·test·lint를 돌린 뒤에도, 이 단계는 **스테이지 환경에서 클라이언트와의 통합 테스트**가 실질적인 완료 조건이다. 스크립트 통과만으로 완료로 보고하지 않는다.
