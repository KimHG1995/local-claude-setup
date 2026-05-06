현재 브랜치의 변경사항을 아래 체크리스트 기준으로 리뷰하라.
`git diff master...HEAD` 로 전체 변경 파일을 먼저 파악한 후, 파일별로 검토한다.

## 아키텍처 규칙 (coderabbit.yaml 기준)

### Controller

- [ ] HTTP 입출력만 담당하는가? (비즈니스 로직 없음)
- [ ] Request는 DTO + class-validator로 검증하는가?
- [ ] Response는 Entity 직접 반환이 아닌 Response DTO인가?
- [ ] `@ApiEndpoint` 데코레이터를 사용하는가? (레거시 `@ApiOperation` + `@ApiResponse` 조합 금지)

### Service

- [ ] Repository 결과(Entity)를 받아 Mapper로 DTO 변환을 담당하는가?
- [ ] 포함/제외 정책 결정이 Service에서 이루어지는가?
- [ ] Repository에 직접 DTO를 전달하지 않는가?

### Repository

- [ ] TypeORM 0.2.x 기준 API만 사용하는가? (DataSource 0.3+ 금지)
- [ ] 반환 타입이 Entity / Entity[] / [Entity[], number]인가? (DTO 반환 금지)
- [ ] 트랜잭션 방식이 혼용되지 않는가?

### DTO

- [ ] Entity를 Swagger `@ApiResponse` type으로 직접 사용하지 않는가?
- [ ] Request DTO에 `class-validator` 데코레이터가 붙어 있는가?
- [ ] 외부에서 DTO import 시 barrel export(`./dto`)를 통하는가?

### Mapper

- [ ] Mapper 내부에 비즈니스 정책 결정 로직이 없는가?
- [ ] Service에서 옵션을 결정하여 Mapper에 인자로 전달하는가?

## 점진적 리팩토링 단계 확인

- [ ] 1단계(DTO/Swagger) 변경만 포함하는가?
- [ ] class-validator / ValidationPipe를 **새로** 추가한 경우, 기존에 이미 검증하던 엔드포인트인가? (기존 검증 없는 곳에 신규 추가 시 프론트 영향 발생)
- [ ] 2단계(StandardErrorFilter/ResponseTransformInterceptor) 변경이 포함된 경우, 프론트 협의가 전제되었는가?

## JSDoc (Controller · Service만 적용)

- [ ] Controller public 메서드에 JSDoc이 있는가?
- [ ] Service public 메서드에 JSDoc이 있는가?
- [ ] JSDoc이 메서드명이 이미 말하는 내용을 반복하지 않는가? ("~를 조회한다" 형태 금지)
- [ ] 비자명한 제약·부작용·정책만 기술하고 있는가?
- [ ] Repository 메서드에 JSDoc이 추가되지 않았는가? (불필요)

## 함수명 네이밍

- [ ] Controller 메서드가 `getList` / `getOne` / `create` / `update` / `delete` 규칙을 따르는가?
- [ ] Service 메서드 접두사가 의미에 맞게 쓰였는가? (`get` vs `find`, `create` vs `add`, `delete` vs `remove`)
- [ ] `doXxx`, `handleXxx`(이벤트 외), `manageXxx`, `getXxxData` 같은 안티패턴이 없는가?
- [ ] 리네이밍이 있는 경우, 호출하는 Controller/Service도 함께 수정되었는가?

## TypeScript 규칙

- [ ] `any` 타입 사용이 없는가?
- [ ] 모든 변수·파라미터·반환값에 명시적 타입이 선언되었는가?
- [ ] `@ts-ignore` / `@ts-expect-error` 사용이 없는가?

## 일반 품질

- [ ] 한글 비즈니스 용어가 보존되었는가?
- [ ] 에러 메시지가 한글로 작성되었는가?
- [ ] 수정 범위가 요청된 모듈/API로 한정되었는가? (전역 변경 없음)
- [ ] DB 스키마/인증/배포 변경이 포함된 경우 별도 작업으로 분리되었는가?

## 리뷰 출력 형식

각 파일에 대해:

1. **파일명** — 변경 요약 한 줄
2. 통과한 항목: ✅
3. 문제 항목: ❌ + 구체적 설명 + 수정 제안
4. 경고 항목: ⚠️ + 맥락 설명

마지막에 전체 요약: 블로킹 이슈 / 권고 사항 / 승인 여부
