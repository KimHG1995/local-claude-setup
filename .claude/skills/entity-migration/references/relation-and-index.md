# 관계(Relation) 추가/변경 · 인덱스 추가/삭제

`entity-migration` 스킬에서 이 유형으로 분류됐을 때만 읽는다.

## 생성 규칙

1. **관계를 추가하면 FK 제약을 함께 건다.** `@JoinColumn` 없이 관계 데코레이터만 추가하지 않는다 — 애플리케이션 레벨에서만 관계처럼 보이는 상태를 만들지 않는다.
2. **FK를 거는 컬럼에 기존 데이터가 있으면, 참조 무결성부터 확인한다.** 참조할 부모 행이 없는 자식 행이 하나라도 있으면 FK 마이그레이션이 실패한다.
3. **인덱스는 실제 쿼리 패턴에 근거해서 추가한다.** "있으면 좋을 것 같아서"가 아니라, 이 인덱스로 개선되는 쿼리를 하나 이상 지목할 수 있어야 한다.
4. **인덱스 삭제 전에 그 인덱스를 타는 쿼리가 없는지 확인한다.** 삭제 후 풀스캔으로 전환되는 쿼리가 있으면 성능 저하로 이어진다.
5. **`ManyToMany`는 중간 테이블 스키마를 명시적으로 검토한다.** TypeORM이 자동 생성하는 join table 이름/컬럼이 기존 컨벤션과 맞는지 확인한다.

## Anti-pattern

- ❌ 관계 데코레이터만 추가하고 FK 마이그레이션을 빠뜨리는 것 — Entity 코드와 실제 DB 제약이 어긋난 상태로 남는다.
- ❌ 참조 무결성을 확인하지 않고 FK부터 걸어서 마이그레이션이 운영에서 실패하는 것 — 사전에 고아 레코드(orphan row) 여부를 쿼리로 확인해야 한다.
- ❌ 근거 쿼리 없이 "조회가 느린 것 같아서" 인덱스를 추가하는 것 — 컬럼이 많아질수록 쓰기 성능에 누적 비용이 든다.
- ❌ 복합 인덱스의 컬럼 순서를 실제 WHERE/ORDER BY 절 순서와 다르게 잡는 것 — 인덱스가 있어도 활용되지 않는다.

## Template

```ts
// 관계 추가 (Entity)
@ManyToOne(() => CenterEntity)
@JoinColumn({ name: 'center_id' })
center: CenterEntity;

@Column({ name: 'center_id' })
centerId: number;
```

```ts
// Migration — FK 추가 (참조 무결성 확인 후)
export class AddCenterFkToTraining1234567890 implements MigrationInterface {
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE \`training\` ADD CONSTRAINT \`FK_training_center\` FOREIGN KEY (\`center_id\`) REFERENCES \`center\`(\`id\`)`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE \`training\` DROP FOREIGN KEY \`FK_training_center\``);
  }
}
```

```ts
// Migration — 인덱스 추가 (근거 쿼리 기준 컬럼 순서)
export class AddCreatedAtIndexToReservation1234567890 implements MigrationInterface {
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE INDEX \`IDX_reservation_center_created_at\` ON \`reservation\` (\`center_id\`, \`created_at\`)`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX \`IDX_reservation_center_created_at\` ON \`reservation\``);
  }
}
```

## Example

`Training`에 `Center`로의 `@ManyToOne` 관계를 추가한 경우 — FK를 걸기 전에 `training.center_id`가 가리키는 `center.id`가 전부 존재하는지 먼저 조회로 확인했고, 고아 레코드 2건을 발견해 마이그레이션에 정리 단계를 먼저 넣은 뒤 FK를 걸었다.

## 검증

- [ ] 관계 추가 시 FK 마이그레이션이 함께 있는가?
- [ ] FK를 걸기 전 참조 무결성(고아 레코드 없음)을 확인했는가?
- [ ] 새 인덱스가 개선하는 쿼리를 구체적으로 지목할 수 있는가?
- [ ] 복합 인덱스 컬럼 순서가 실제 WHERE/ORDER BY 순서와 맞는가?
- [ ] 인덱스 삭제 시, 그 인덱스에 의존하던 쿼리가 없는지 확인했는가?
