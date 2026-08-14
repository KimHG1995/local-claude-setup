# 커밋 메시지 작성

`commit-pr` 스킬에서 "커밋 메시지를 정리하는 상황"으로 판단됐을 때만 읽는다. 스테이징된 변경사항을 분석해서 커밋 메시지를 초안하고, 확인 후 커밋을 실행하는 절차다.

## 생성 규칙

### Step 1 — 티켓 번호 추출

```bash
git branch --show-current
```

브랜치명에서 티켓 번호를 추출한다.

- `feature/KDS-2902_khg` → `KDS-2902`
- `hotfix/KDS-1234` → `KDS-1234`
- 패턴 없음 → 사용자에게 "지라 티켓 번호가 있나요? (없으면 엔터)" 질문

### Step 2 — 변경사항 파악

```bash
git diff --staged --stat
git diff --staged
```

스테이징된 파일이 없으면: "`git add` 후 다시 실행하세요." 출력 후 종료.

### Step 3 — 타입·스코프 결정

변경 내용을 보고 아래 기준으로 판단한다.

| type | 판단 기준 |
| --- | --- |
| `feat` | 새 기능, 엔드포인트, DTO, 서비스 메서드 추가 |
| `fix` | 버그 수정, 잘못된 로직·쿼리 교정 |
| `refactor` | 기능 변화 없는 구조 개선, DTO 패턴 적용, 코드 정리 |
| `chore` | 마이그레이션, 설정 파일, 패키지, 불필요 파일 삭제 |
| `docs` | 주석, Swagger ApiProperty/ApiTags, README |
| `test` | 테스트 파일 추가·수정 |
| `revert` | 이전 커밋 되돌리기 |

**scope**: 변경된 주요 모듈명 (예: `user`, `alimtalk`, `reservation-date`). 여러 모듈이 동시에 바뀐 경우 → 커밋 분리를 먼저 제안한다(Step 4).

### Step 4 — 커밋 분리 여부 판단

스테이징 내용이 논리적으로 다른 단위를 포함하면 분리를 제안한다.

- 새 파일 추가(DTO, Mapper) + 기존 파일 수정(서비스에 적용)이 섞인 경우
- 두 개 이상의 무관한 모듈이 변경된 경우
- 기능 추가 + 리팩토링이 섞인 경우

**분리 제안의 설명도 반드시 영어**로 작성한다.

### Step 5 — 메시지 초안 제안

형식: `type(scope): (KDS-XXXX) 설명`

- **설명은 반드시 영어**, 명령형 동사로 시작 (`Add`, `Fix`, `Remove`, `Refactor`, `Update`, `Rename`)
- 50자 이내 권장
- 티켓 없는 경우: `type(scope): 설명` (괄호 생략)

### Step 6 — 확인 후 실행

초안을 보여주고 "이 메시지로 커밋할까요?" 확인을 받는다. 수정 요청이 있으면 반영 후 재확인.

확인되면 실행한다.

```bash
git commit -m "type(scope): (KDS-XXXX) 설명"
```

## Anti-pattern

- ❌ 설명을 한글로 쓰거나, 영어인데 명사구로 시작하는 것 (`Added`, `Fixed`처럼 과거형/`-ed`도 안 됨 — 항상 원형 명령형)
- ❌ 두 개 이상 모듈이 섞였는데 분리 제안 없이 하나로 묶어 커밋하는 것
- ❌ 확인 없이 바로 `git commit`을 실행하는 것 — Step 6은 항상 사용자 확인을 거친다
- ❌ 스테이징되지 않은 변경까지 포함해서 커밋 범위를 임의로 넓히는 것

## Template

```text
type(scope): (KDS-XXXX) Imperative English description
```

분리 제안 예시:

> "변경이 2개 단위로 나뉩니다. 분리해서 커밋할까요?
>
> 1. `feat(memo): add endpoint DTO files` — dto/ 파일들
> 2. `refactor(memo): apply new DTOs to service and controller` — service, controller"

## Example

```text
feat(memo): (KDS-2896) add lecture list response DTO and mapper
fix(reservation-date): (KDS-3011) fix timezone offset in date range query
refactor(user): (KDS-2950) extract sort logic into SortService
chore: bump typeorm to 0.2.45
```

## 검증

- [ ] type/scope가 Step 3 표 기준과 맞는가?
- [ ] 설명이 영어 명령형(원형 동사 시작)인가?
- [ ] 스테이징 내용이 논리적으로 한 단위인가? (아니면 분리 제안했는가)
- [ ] 사용자 확인을 받은 뒤에 `git commit`을 실행했는가?
