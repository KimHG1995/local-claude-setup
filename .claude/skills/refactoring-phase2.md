# 2단계 리팩토링 가이드 (프론트엔드 협의 필수)

> **참조 가이드 (Guide)** — 슬래시 커맨드가 아니다.
> 프론트 협의가 완료된 모듈에서 응답 구조 표준화 작업 시 직접 언급해서 사용한다.
> 1단계 완료 후 이 가이드를 적용하는 순서를 따른다.

## ⚠️ 전제 조건

이 단계는 **API 응답 형식이 바뀐다**. 반드시 다음을 확인한 후 진행:

- [ ] 프론트엔드 팀(또는 모바일 팀)과 변경 대상 API 응답 형식 사전 협의 완료
- [ ] 해당 API를 사용하는 클라이언트 코드 수정 일정 확정
- [ ] 스테이지 환경에서 클라이언트와 통합 테스트 예정

## 응답 형식 변화

### Before (현재 레거시 응답)
```json
{ "id": 1, "name": "..." }
```

### After (표준화 응답 — wrapped: true)
```json
{
  "success": true,
  "data": { "id": 1, "name": "..." },
  "meta": { "traceId": "...", "timestamp": "..." }
}
```

### After (페이지네이션 — paged: true)
```json
{
  "success": true,
  "data": {
    "items": [...],
    "page": 1, "size": 10,
    "totalCount": 100, "totalPages": 10, "hasNext": true
  },
  "meta": { ... }
}
```

## 적용 방법 (1단계 완료 후)

### 1. 컨트롤러에 Filter + Interceptor opt-in

```ts
import { StandardErrorFilter } from 'src/common/filters/standard-error.filter';
import { ResponseTransformInterceptor } from 'src/common/interceptors/response-transform.interceptor';

@UseFilters(StandardErrorFilter)
@UseInterceptors(ResponseTransformInterceptor)
@Controller('api/some')
export class SomeController {}
```

### 2. @ApiEndpoint에 wrapped/paged 옵션 추가

```ts
// 단건/배열
response: { type: SomeResponse, wrapped: true }
response: { type: SomeResponse, isArray: true, wrapped: true }

// 페이지네이션
response: { type: SomeResponse, paged: true }
```

### 3. 페이지네이션 서비스 반환 형식

```ts
import { buildPageData } from 'src/common/utils/pagination.util';

async list(query): Promise<ApiPageData<SomeResponse>> {
  const [items, totalCount] = await this.repo.findAndCount(query);
  const dtos = items.map(SomeMapper.toDto);
  return buildPageData(dtos, totalCount, query.page, query.countPerPage);
}
```

### 4. Module providers에 StandardErrorFilter 등록

```ts
@Module({
  providers: [SomeService, StandardErrorFilter],
})
export class SomeModule {}
```

### 5. 에러 throw 표준 패턴

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

## 관련 파일

- `src/common/filters/standard-error.filter.ts`
- `src/common/interceptors/response-transform.interceptor.ts`
- `src/common/dto/api-response.dto.ts`
- `src/common/utils/pagination.util.ts`
- `src/modules/notice/notice.controller.ts` ← 적용 예시
