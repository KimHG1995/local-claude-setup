# 컬럼 삭제 · 타입 변경 · nullable 변경

`entity-migration` 스킬에서 이 유형으로 분류됐을 때만 읽는다. 세 유형 모두 **데이터 손실 또는 마이그레이션 실패 위험**이 있어 같은 문서로 묶여 있다.

## 생성 규칙

1. **컬럼 삭제 전에 FK 참조 여부를 확인한다.** 다른 테이블이 이 컬럼을 참조하면(FK, 또는 애플리케이션 레벨 조인 키) 삭제 순서를 먼저 정한다.
2. **타입 변경은 항상 "데이터 손실 위험"으로 취급한다.** `int`→`varchar`처럼 넓히는 방향도, `varchar(255)`→`varchar(50)`처럼 좁히는 방향도 마찬가지다 — 좁히는 변경은 특히 기존 데이터 중 잘리는 값이 있는지 먼저 확인한다.
3. **nullable 변경은 기존 NULL 데이터 유무를 먼저 확인한다.** `nullable: true`→`false`로 바꾸려면, 기존 NULL 행을 채우는 단계가 마이그레이션 안에 있어야 한다.
4. **되돌릴 수 없는 변경(컬럼 삭제, 데이터 손실 가능한 타입 축소)은 반드시 사용자 확인을 받은 뒤 진행한다.** 이 스킬은 판단까지만 하고, 승인은 사람의 몫이다.

## Anti-pattern

- ❌ `nullable: false`로 바로 바꾸고 기존 NULL 행 처리를 마이그레이션에 넣지 않는 것 — 운영 DB에 NULL이 하나라도 있으면 실패한다.
- ❌ 컬럼 타입을 좁히면서(`varchar(255)`→`varchar(50)`) 기존 데이터 길이를 확인하지 않는 것 — 조용히 잘리거나 마이그레이션이 실패한다.
- ❌ "어차피 안 쓰는 컬럼 같아서" 확인 없이 삭제하는 것 — 애플리케이션 코드에서 안 쓰더라도 리포트/배치/외부 연동이 참조할 수 있다.
- ❌ 컬럼 삭제와 타입 변경을 같은 커밋·같은 마이그레이션에 함께 넣는 것 — 실패 시 어느 부분이 원인인지 분리가 안 된다.

## Template

```ts
// nullable 변경: 기존 NULL을 먼저 채우고 나서 제약을 건다
export class MakeUserPhoneRequired1234567890 implements MigrationInterface {
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`UPDATE \`user\` SET \`phone\` = '' WHERE \`phone\` IS NULL`);
    await queryRunner.query(`ALTER TABLE \`user\` MODIFY \`phone\` varchar(20) NOT NULL`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE \`user\` MODIFY \`phone\` varchar(20) NULL`);
  }
}
```

```ts
// 컬럼 삭제: FK/참조 확인 후에만
export class DropLegacyFieldFromUser1234567890 implements MigrationInterface {
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE \`user\` DROP COLUMN \`legacy_field\``);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE \`user\` ADD \`legacy_field\` varchar(255) NULL`);
  }
}
```

## Example

`Center.capacity`를 `int`→`bigint`로 바꾼 경우 — 넓히는 방향이라 데이터 손실 위험은 낮았지만, 이 값을 참조하는 배치 집계 쿼리가 있어서 타입 변경 전에 해당 쿼리들의 캐스팅 여부를 먼저 확인했다.

## 검증

- [ ] 삭제/변경 대상 컬럼을 참조하는 FK·조인·배치가 없는가?
- [ ] nullable→NOT NULL이면, 기존 NULL 행을 채우는 단계가 마이그레이션에 포함됐는가?
- [ ] 타입을 좁히는 변경이면, 기존 데이터 중 잘리는 값이 있는지 확인했는가? (`SELECT` 로 최대 길이/범위 확인)
- [ ] 되돌릴 수 없는 변경이라면 사용자 확인을 받았는가?
