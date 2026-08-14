현재 변경된 Entity 파일을 분석하고 마이그레이션이 필요한 변경사항을 정리해서 보고하라.
마이그레이션 파일 생성·실행은 하지 않는다.

## 분석 절차

1. `git diff HEAD -- src/entities/` 로 Entity 변경사항 확인 (또는 `bash .claude/skills/entity-migration/scripts/check-entity-diff.sh` 로 컬럼/관계/인덱스 변경 후보를 빠르게 훑기)
2. 변경이 없으면 "Entity 변경 없음, 마이그레이션 불필요" 출력 후 종료

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

세부 판단 기준(생성 규칙·안티패턴·검증 항목)은 `entity-migration` 스킬로 옮겼다 — 여기서 표를 다시 베끼지 않는다.

- [`.claude/skills/entity-migration/SKILL.md`](../skills/entity-migration/SKILL.md) — 유형 분류표
- [`references/add-column.md`](../skills/entity-migration/references/add-column.md) — 컬럼 추가
- [`references/drop-or-type-change.md`](../skills/entity-migration/references/drop-or-type-change.md) — 컬럼 삭제·타입 변경·nullable 변경
- [`references/relation-and-index.md`](../skills/entity-migration/references/relation-and-index.md) — 관계·인덱스

이 커맨드는 위 기준으로 **분류하고 보고만** 한다. 세부 근거가 필요하면 해당 참조 파일을 연다.
