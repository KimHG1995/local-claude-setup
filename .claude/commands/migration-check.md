현재 변경된 Entity 파일을 분석하고 마이그레이션이 필요한 변경사항을 정리해서 보고하라.
마이그레이션 파일 생성과 실행은 하지 않는다.

## 분석 절차

1. `bash .claude/skills/entity-migration/scripts/check-entity-diff.sh`로 추적 파일의 staged/unstaged 변경과 미추적 `src/entities/` 파일을 확인한다. 최초 커밋 전 저장소도 지원한다. 스크립트는 파일을 스테이징하지 않는다.
2. 기커밋 변경은 `--base <기준 커밋/브랜치>`로 기준→현재 작업 트리를 비교한다. PR의 변경만 보려면 확인한 공통 조상 커밋을 기준으로 사용한다. 제안 단계는 요청한 변경 내용도 함께 분석한다.
3. 빈 결과는 **선택한 비교 범위에 Entity 변경 없음**으로 보고한다. 제안, 기커밋 변경 또는 실제 DB 상태까지 검증한 것이 아니므로 곧바로 마이그레이션 불필요로 결론 내리지 않는다. exit `1`은 분석 실패로 보고하고 근거를 보완한다.
4. 출력은 데코레이터 문자열 기반 후보다. 전체 diff와 새 파일을 읽어 import, 여러 줄 옵션, Entity 생성/삭제 등 후보에 안 잡히는 변경도 판단한다. ignored 파일은 기본 조회에서 제외되므로 요청 대상이면 별도 확인한다.

## 보고 형식

변경된 Entity별로 아래 표 형식으로 출력:

| Entity   | 변경 유형         | 컬럼/필드             | 마이그레이션 필요 | 주의사항              |
| -------- | ----------------- | --------------------- | ----------------- | --------------------- |
| User     | 컬럼 추가         | `phone2` (nullable)   | 필요              | —                     |
| Center   | 타입 변경         | `capacity` int→bigint | 필요              | 기존 데이터 확인 필요 |
| Training | 데코레이터만 변경 | `name`                | 불필요            | —                     |

마지막에 한 줄 요약:

> "마이그레이션 필요 항목 N건 — [항목 목록]"

## 변경 유형 판단 기준

세부 판단 기준(생성 규칙, 안티패턴, 검증 항목)은 `entity-migration` 스킬로 옮겼다 — 여기서 표를 다시 베끼지 않는다.

- [`.claude/skills/entity-migration/SKILL.md`](../skills/entity-migration/SKILL.md) — 유형 분류표
- [`references/add-column.md`](../skills/entity-migration/references/add-column.md) — 컬럼 추가
- [`references/drop-or-type-change.md`](../skills/entity-migration/references/drop-or-type-change.md) — 컬럼 삭제, 타입 변경, nullable 변경
- [`references/relation-and-index.md`](../skills/entity-migration/references/relation-and-index.md) — 관계, 인덱스

이 커맨드는 위 기준으로 **분류하고 보고만** 한다. 세부 근거가 필요하면 해당 참조 파일을 연다.
