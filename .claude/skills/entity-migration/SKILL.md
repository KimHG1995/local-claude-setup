---
name: entity-migration
description: Entity 파일(src/entities/**)을 추가·삭제·수정하기 전이나 직후에 이 변경이 마이그레이션을 필요로 하는지, 어떤 위험이 있는지 판단한다. "Entity 수정", "컬럼 추가/삭제", "타입 변경", "마이그레이션 필요해?" 같은 상황, 그리고 Entity 파일을 건드리는 모든 작업 전에 사용한다. 마이그레이션 파일 생성·실행은 이 스킬의 범위 밖이다.
---

# entity-migration

## 이 스킬이 하는 일

Entity 변경을 건드리기 전에 멈춰서 "이 변경은 어떤 유형이고, 마이그레이션이 필요한가, 무엇을 확인해야 하는가"를 먼저 정리한다.
**마이그레이션 파일은 만들지 않는다** — 판단과 보고까지만 하고, 실행은 사람이 한다.

## 판단 전 먼저 할 일

```bash
git diff HEAD -- src/entities/
bash .claude/skills/entity-migration/scripts/check-entity-diff.sh
```

변경이 없으면 "Entity 변경 없음, 마이그레이션 불필요"로 종료한다.

## 유형 판단 → 참조 로딩

변경 내용을 아래 표에서 찾아 **해당하는 참조 파일만** 연다. 한 Entity에서 여러 유형이 섞였으면 필요한 것만 각각 연다 — 표 전체를 한 번에 열지 않는다.

| 변경 내용 | 참조 파일 |
| --- | --- |
| 컬럼 추가 | [`references/add-column.md`](references/add-column.md) |
| 컬럼 삭제 · 타입 변경 · nullable 변경 | [`references/drop-or-type-change.md`](references/drop-or-type-change.md) |
| 관계(Relation) 추가/변경 · 인덱스 추가/삭제 | [`references/relation-and-index.md`](references/relation-and-index.md) |
| 데코레이터·주석·`@ApiProperty` 옵션만 변경 | 참조 불필요 — 마이그레이션 불필요, 바로 진행 |

## 보고 형식

Entity별로 표를 만든다.

| Entity | 변경 유형 | 컬럼/필드 | 마이그레이션 필요 | 주의사항 |
| --- | --- | --- | --- | --- |
| User | 컬럼 추가 | `phone2` (nullable) | 필요 | — |
| Center | 타입 변경 | `capacity` int→bigint | 필요 | 기존 데이터 확인 필요 |
| Training | 데코레이터만 변경 | `name` | 불필요 | — |

마지막 줄에 요약: `마이그레이션 필요 항목 N건 — [항목 목록]`

## 완료 후

- 필요 항목이 있으면 **마이그레이션 파일을 만들기 전에** 사용자에게 먼저 확인받는다. 파일 생성·실행은 이 스킬의 범위 밖이다.
- `src/migrations/`에 있는 **이미 적용된** 마이그레이션 파일은 절대 직접 수정하지 않는다 — 롤백이 불가능하다. 되돌려야 하면 새 마이그레이션을 추가한다.
- `/new-feature` 흐름 중에 Entity 변경이 나왔다면, 이 판단 결과를 그 흐름에 그대로 이어서 보고한다.
