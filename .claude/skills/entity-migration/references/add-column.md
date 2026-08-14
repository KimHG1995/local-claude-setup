# 컬럼 추가

`entity-migration` 스킬에서 "컬럼 추가"로 분류됐을 때만 읽는다.

## 생성 규칙

1. **nullable 컬럼은 그냥 추가하면 된다.** 기존 행은 `NULL`로 채워진다 — 별도 백필이 필요 없다.
2. **NOT NULL 컬럼은 반드시 `default`를 함께 지정하거나, 마이그레이션 안에서 기존 행을 먼저 채운다.** 기본값 없이 NOT NULL을 추가하면 기존 행이 있는 테이블에서 마이그레이션 자체가 실패한다.
3. **컬럼명은 기존 네이밍 컨벤션(snake_case/camelCase)을 그 테이블 기준으로 따른다.** 모듈마다 통일하려 하지 않는다 — 기존 테이블의 컬럼 목록을 먼저 확인한다.
4. **Entity의 TypeScript 타입과 컬럼 옵션이 실제 DB 제약과 일치해야 한다.** `nullable: true`인데 TS 타입에 `?`가 없는 식의 불일치를 만들지 않는다.

## Anti-pattern

- ❌ NOT NULL 컬럼을 default 없이 추가하고 "마이그레이션 실행할 때 알아서 되겠지" 하는 것 — 기존 행이 있으면 그 자리에서 실패한다.
- ❌ 컬럼을 추가하면서 같은 마이그레이션에 관련 없는 다른 테이블 변경을 끼워 넣는 것 — 롤백 단위가 커진다.
- ❌ 컬럼 추가만으로 충분한데 굳이 관계(FK)까지 함께 넣어 범위를 넓히는 것.

## Template

```ts
// Entity
@Column({ type: 'varchar', length: 20, nullable: true })
phone2?: string;

// NOT NULL + default가 필요한 경우
@Column({ type: 'int', default: 0 })
retryCount: number;
```

```ts
// Migration (TypeORM 0.2.x 스타일)
export class AddPhone2ToUser1234567890 implements MigrationInterface {
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE \`user\` ADD \`phone2\` varchar(20) NULL`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE \`user\` DROP COLUMN \`phone2\``);
  }
}
```

## Example

`User` Entity에 `phone2`(nullable varchar)를 추가한 경우 — Entity에 `@Column({ nullable: true })`만 추가하고, 마이그레이션은 `ADD COLUMN ... NULL`로 끝난다. 기존 행 마이그레이션이나 별도 백필 스크립트가 필요 없었다.

## 검증

- [ ] `nullable: true`이거나, NOT NULL이면 `default`가 있는가?
- [ ] Entity의 TS 타입과 컬럼 옵션(`nullable`)이 일치하는가?
- [ ] 이 컬럼을 채우는 로직(Service)이 함께 추가됐는가, 아니면 당분간 NULL로 둘 것인가?
