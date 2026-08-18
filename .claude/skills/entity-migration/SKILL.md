---
name: entity-migration
description: Entity 파일(src/entities/**)을 추가·삭제·수정하기 전이나 직후에 이 변경이 마이그레이션을 필요로 하는지, 어떤 위험이 있는지 판단한다. "Entity 수정", "컬럼 추가/삭제", "타입 변경", "마이그레이션 필요해?" 같은 상황, 그리고 Entity 파일을 건드리는 모든 작업 전에 사용한다. 마이그레이션 파일 생성·실행은 이 스킬의 범위 밖이다.
---

# entity-migration

판단·보고까지만 한다. **마이그레이션 파일은 만들지 않는다** — 생성·실행은 사용자 확인 후 사람이 한다.
`src/migrations/`의 **이미 적용된** 파일은 직접 수정하지 않는다 — 되돌리려면 새 마이그레이션을 추가한다.

## 변경 확인

```bash
bash .claude/skills/entity-migration/scripts/check-entity-diff.sh
```

변경이 없으면 "Entity 변경 없음, 마이그레이션 불필요"로 종료한다.

## 유형 판단

해당하는 참조 **하나만** 연다. 여러 유형이 섞였으면 필요한 것만 각각 연다.

- 컬럼 추가 → [`references/add-column.md`](references/add-column.md)
- 컬럼 삭제 · 타입 변경 · nullable 변경 → [`references/drop-or-type-change.md`](references/drop-or-type-change.md)
- 관계(Relation) · 인덱스 추가/삭제 → [`references/relation-and-index.md`](references/relation-and-index.md)
- 데코레이터·주석·`@ApiProperty`만 변경 → 참조 불필요, 마이그레이션 불필요

## 보고 형식

Entity별 한 행씩: `Entity | 변경 유형 | 컬럼/필드 | 마이그레이션 필요 | 주의사항`
예) `Center | 타입 변경 | capacity int→bigint | 필요 | 기존 데이터 확인`

마지막 줄에 요약: `마이그레이션 필요 항목 N건 — [항목 목록]`
