---
name: entity-migration
description: Entity 파일(src/entities/**)을 추가, 삭제, 수정하기 전이나 직후에 이 변경이 마이그레이션을 필요로 하는지, 어떤 위험이 있는지 판단한다. "Entity 수정", "컬럼 추가/삭제", "타입 변경", "마이그레이션 필요해?" 같은 상황, 그리고 Entity 파일을 건드리는 모든 작업 전에 사용한다. 마이그레이션 파일 생성, 실행은 이 스킬의 범위 밖이다.
---

# entity-migration

판단, 보고만 한다. 생성, 실행은 사용자 확인 후 사람이 한다. 이미 적용된 `src/migrations/` 파일은 수정하지 않는다.

```bash
bash .claude/skills/entity-migration/scripts/check-entity-diff.sh
```

기본 범위는 HEAD→작업 트리와 미추적 Entity다. 최초 커밋 전도 지원한다. 기커밋 변경은 `--base REF`로 기준을 지정한다. 미구현 제안은 요청 내용으로 판단한다. 빈 diff는 해당 범위에 변경이 없다는 뜻이며 마이그레이션 불필요의 근거가 아니다. 실패(exit 1)는 미확인으로 보고한다. 후보 목록은 휴리스틱이므로 전체 변경을 확인한다.

필요한 참조만 연다:

- 추가 → [컬럼 추가](references/add-column.md)
- 삭제, 타입, nullable → [삭제/타입 변경](references/drop-or-type-change.md)
- 관계, 인덱스 → [관계/인덱스](references/relation-and-index.md)

주석, `@ApiProperty`만이면 불필요. DB 데코레이터는 위 기준으로 판단한다.

보고: `Entity | 유형 | 필드 | 마이그레이션 필요 | 주의사항`. 마지막에 필요 항목 수와 목록을 요약한다.
