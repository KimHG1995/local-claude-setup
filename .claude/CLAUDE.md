# Local Claude Setup

이 파일은 `AGENTS.md`와 루트 `CLAUDE.md`를 **보완**한다.
공용 규칙과 충돌하면 공용 문서(`AGENTS.md` → `CLAUDE.md`)를 우선한다.
이 파일은 로컬 워크플로우·개인 컨텍스트만 담당하며, `.claude*` gitignore로 로컬 전용이다.

## 이 파일의 역할과 관련 파일

반복 작업과 패턴 지식은 아래 전용 파일에 위임한다. 모두 실제 존재하는 파일이다.

### 슬래시 커맨드 (`/명령어`로 실행)

| 파일                                  | 커맨드             | 역할                          |
| ------------------------------------- | ------------------ | ----------------------------- |
| `.claude/commands/commit.md`          | `/commit`          | 커밋 메시지 초안·실행         |
| `.claude/commands/pr.md`              | `/pr`              | draft PR 생성 (Jira 연동·커밋 목록·수정내역 포함) |
| `.claude/commands/pr-review.md`       | `/pr-review`       | PR 체크리스트 리뷰            |
| `.claude/commands/migration-check.md` | `/migration-check` | Entity 변경 마이그레이션 분석 |
| `.claude/commands/new-feature.md`     | `/new-feature`     | 기능 구현 전 계획 수립        |

### 스킬 (자동 판단 + 명시적 언급 둘 다 가능)

`SKILL.md`가 유형을 먼저 가르고, 해당 유형의 `references/*.md` 하나만 불러오는 구조다. 전체 내용을 다 읽을 필요는 없다.

| 스킬                                | 사용 시점                                                    |
| ------------------------------------ | ------------------------------------------------------------- |
| `.claude/skills/refactoring/`        | 리팩토링 시 — 1단계(안전) / 2단계(계약 변경) 유형부터 판단   |
| `.claude/skills/entity-migration/`   | Entity 파일 수정 전후 — 마이그레이션 필요 여부·위험 판단     |
| `.claude/skills/commit-pr/`          | 커밋 메시지 작성 시 / PR 생성 시 — 둘 중 해당하는 유형만 판단 |

### 설정

| 파일                          | 역할                                                  |
| ----------------------------- | ----------------------------------------------------- |
| `.claude/settings.local.json` | 훅·권한 설정 (DB 접속은 `yarn tunnel:*` 후 별도 진행) |

---

## 실행 규칙

### 수정 후 자동 실행

| 시점                | 명령                             |
| ------------------- | -------------------------------- |
| `.ts` 파일 수정 후  | `yarn typecheck`                 |
| `.spec.ts` 수정 후  | `yarn test <해당 파일>`          |
| Entity 파일 수정 후 | 마이그레이션 필요 여부 먼저 보고 |

### 테스트 원칙

- 버그 수정 — 재현 케이스를 먼저 확인하고, 관련 테스트가 있으면 통과 여부 검증
- 신규 기능 — 해당 모듈에 기존 테스트가 있으면 함께 추가·수정 고려

### 작업 전 반드시 물어볼 것

- **Entity 필드 추가·삭제·타입 변경** — 마이그레이션 누락 시 운영 장애
- **`app.module.ts` 변경** — 모듈 등록 누락·중복
- **`src/common/` 인터셉터·필터·파이프 변경** — 전 모듈 영향
- **`auths/` 모듈 변경** — 보안·토큰 포맷 영향, 별도 작업 분리 필요
- **`src/migrations/` 직접 수정** — 이미 적용된 마이그레이션은 롤백 불가

### 절대 금지 (명시적 요청 없으면)

- `git commit`, `git push`
- PR 생성(`gh pr create`) — 생성하더라도 항상 draft, Open 전환은 사람이 함
- `.env*` 파일 수정
- `migrations/` 파일 직접 편집·삭제
- 전역 리팩토링 (수정 대상 모듈 범위 밖 변경)

### 기본 생략, 필요 시만 실행

**`yarn build`** — 비용이 큰 검증이므로 기본적으로 생략.
아래 경우에만 실행을 고려:

- 모듈 wiring 변경 (`app.module.ts`, providers 등록)
- 광범위한 타입 변경 또는 여러 모듈에 걸친 수정
- 배포 영향 범위가 큰 작업

그 외 일반 수정은 `yarn typecheck`로 충분.

### 브랜치 주의

원칙적으로 `feature/` 또는 `hotfix/` 브랜치에서 작업.
`develop` / `stage` 직접 수정이 필요한 상황이면 **먼저 확인 후** 진행.

### 코드 스타일 원칙

- **Formatting** — tabs, single quotes, trailing commas. 수정 후 `yarn format` 선택적 실행.
- **Import** — 프로젝트 경로는 `src/...` 절대경로, 모듈 내부는 상대경로. 기존 파일의 스타일을 그대로 따른다.
- **타입 안정성** — `@ts-ignore`, `@ts-expect-error`, 신규 `any` 도입 지양. 이미 있는 것은 건드리지 않는다.

---

## 개인화 정보

### 사용자

- **담당자**: hgkim (khg)
- **브랜치 패턴**: `feature/KDS-XXXX_khg`, `hotfix/KDS-XXXX_khg`
- **Jira 베이스 URL**: (비어있음 — 채우면 `/pr`에서 `<베이스 URL>/browse/KDS-XXXX` 링크를 자동 생성한다. 비어있으면 링크 없이 티켓 번호만 남긴다)

### 자주 쓰는 명령

```bash
yarn typecheck
yarn tunnel:dev
yarn start:dev
yarn typeorm:run:tunnel
yarn test --testPathPattern=<module>
```

---

## 모듈별 주의사항

---

## 실수 방지 체크리스트

- [ ] Entity 수정 → 마이그레이션 필요 여부 보고?
- [ ] 새 Service/Repository 추가 → Module `providers` 등록?
- [ ] 새 Module 추가 → `app.module.ts` imports 등록?
- [ ] alimtalk 발송 로직 수정 → v1/v2 모두 확인?
- [ ] 응답 DTO 변경 → 1단계(형식 유지)인가 2단계(프론트 협의)인가?
- [ ] `common/` 파일 수정 → 영향 범위 확인?
- [ ] `yarn typecheck` 통과?
- [ ] 의미 있는 코드 변경 → `yarn lint` 고려?
