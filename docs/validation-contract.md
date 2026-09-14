# 훅, 검사 도구 검증 명세

이 문서는 템플릿의 실행 계약과 검증 범위를 정의한다. 프로젝트별 규칙의 채택 이유와 모델 행동 평가 방법은 [ADOPTED.md](../ADOPTED.md)에 둔다.

## 실행 환경과 설치

- Bash, Git, `jq`, Python 3.9 이상을 사용한다. 회귀 테스트는 Python 표준 라이브러리로 실행한다.
- 대상 프로젝트는 훅의 명령에 맞는 Yarn과 `typecheck`/`test` 스크립트가 필요하다. 다른 패키지 매니저나 monorepo는 검사 위치, 명령을 조정한다.
- PR 이력 조회에는 인증된 `gh`와 Python이 필요하다. 커밋 전용 조회와 명시된 컨벤션 파일, PR template 사용에는 `gh`가 필요 없다.
- 기존 `.claude/`와 설정을 비교해 병합한다. 설정의 훅 경로는 공백을 포함할 수 있는 `$CLAUDE_PROJECT_DIR`를 인용한다. 로컬 전용 운영 여부는 대상 저장소의 ignore 설정으로 정한다.
- 공용 `AGENTS.md`는 루트 `CLAUDE.md`에 `@AGENTS.md`로 가져온다. [공식 메모리 문서](https://code.claude.com/docs/en/memory)에 따라 `/context`로 실제 로드 상태를 확인한다.

## Edit, Write 훅

입력은 stdin JSON이며 `tool_input.file_path`는 비어 있지 않은 문자열이어야 한다. 상대 파일 경로는 입력 `cwd` 기준으로 해석하고, `cwd`가 없으면 프로세스 작업 디렉터리를 사용한다. 대상 파일의 가장 가까운 기존 상위 디렉터리에서 Git 루트를 찾으므로 아직 없는 중첩 경로도 처리한다. 대상이 Git 저장소에 속하지 않으면 검사를 생략하며, 현재 작업 저장소를 대신 사용하지 않는다.

| 훅 | 적용 범위 | 실행과 결과 |
| --- | --- | --- |
| `pre-edit-branch-check.sh` | `PreToolUse`, `Edit\|Write` | 대상 저장소가 `main` 또는 `master`이면 stderr 사유와 exit 2로 편집을 차단. 그 외 exit 0 |
| `post-edit-typecheck.sh` | `PostToolUse`, `.ts`; `.spec.ts`, `.d.ts` 제외 | 대상 Git 루트에서 `yarn typecheck`. Yarn 종료 코드로 성공, 실패 판정 |
| `post-edit-test.sh` | `PostToolUse`, `.spec.ts` | 대상 Git 루트에서 `yarn test <루트 기준 파일 경로> --no-coverage` |

Pre 훅은 최초 커밋 전 브랜치도 확인한다. Bash로 하는 편집, commit, push, 다른 보호 브랜치는 이 훅의 적용 범위 밖이다. 팀의 Git 보호 정책은 별도로 설정한다.

Post 훅은 **동기 실행 후 피드백**을 제공한다. 검사 실패도 훅 자체는 exit 0으로 아래 JSON을 출력하며, 이미 끝난 편집을 되돌리지 않는다. 이는 [공식 훅의 종료 코드와 PostToolUse 출력 계약](https://code.claude.com/docs/en/hooks)에 맞춘다.

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "검사 결과와 실패 진단"
  }
}
```

타입 오류 개수는 보조 정보다. TS 진단이 없어도 Yarn이 실패하면 실패이며, 명령 누락, 실행 오류의 출력도 전달한다. 큰 진단은 `jq`의 stdin으로 전달해 프로세스 인자 크기 제한으로 JSON이 사라지지 않게 한다. 실제 Claude의 출력 처리 한도까지 보장하는 것은 아니다.

잘못된 입력은 Pre 훅에서 stderr + exit 2, Post 훅에서 위 JSON의 오류 피드백으로 처리한다. `jq`가 없으면 JSON을 만들 수 없으므로 Pre는 exit 2, Post는 exit 1과 stderr로 설치 오류를 알린다. 제외 확장자나 Git 루트를 찾지 못한 대상은 출력 없이 exit 0이다.

소스 편집만으로 관련 테스트를 찾거나 전체 테스트를 실행하지 않는다. 완료 시 변경에 맞는 테스트를 별도로 확인한다. 긴 검사는 대상 프로젝트에서 훅 timeout과 실행 비용도 확인한다.

## Entity 변경 수집

```bash
bash .claude/skills/entity-migration/scripts/check-entity-diff.sh
bash .claude/skills/entity-migration/scripts/check-entity-diff.sh --base main
```

- 기본 비교는 `HEAD`에서 작업 트리까지의 `src/entities/` 변경과 ignore되지 않은 미추적 파일이다. 스테이징만 된 변경도 포함한다.
- 최초 커밋 전에는 index와 작업 트리의 변경을 수집한다. `--base REF`는 유효한 커밋 기준으로 비교하므로 이미 커밋한 변경을 살필 때 사용한다.
- exit 0은 수집 성공, exit 1은 입력 또는 Git 조회 실패다. 빈 결과는 **선택한 범위에 변경이 없음**을 뜻한다. 조회 실패를 빈 결과로 바꾸지 않는다.
- 아직 구현하지 않은 제안, 비교 범위 밖의 커밋, 실제 DB 상태는 별도 확인한다. 빈 diff로 마이그레이션 불필요를 선언하지 않는다.
- 출력의 데코레이터, 옵션 목록은 휴리스틱 후보다. 전체 diff와 요청 내용을 스킬 기준으로 검토해야 한다. 이 도구는 staging, migration 생성, 실행을 하지 않는다.

## 커밋, PR 컨벤션 수집

```bash
bash .claude/skills/commit-pr/scripts/derive-git-convention.sh --mode commit 5
bash .claude/skills/commit-pr/scripts/derive-git-convention.sh --mode pr 5
bash .claude/skills/commit-pr/scripts/derive-git-convention.sh --mode commit --convention CONTRIBUTING.md
```

`commit`은 커밋 이력만 사용한다. 기본값 및 기존 숫자 인자 호출도 `commit`이다. `pr`은 명시된 컨벤션 → 지원 PR template → 한 번의 `gh pr list --json number,title,body` 순서로 자료를 선택한다. stderr 경고와 명령 실패는 종료 코드로 구분한다.

`--convention`은 호출자가 해당 작업에 적용되는 파일을 선택한 경우에 쓴다. 상대 경로는 호출한 디렉터리 기준이다. 파일 내용의 적용 여부는 스크립트가 판단하지 않는다. 대화에서 이미 정한 규칙은 파일로 다시 만들거나 확인받을 필요 없이 적용한다.

**종료 코드와 옵션의 SSOT는 [helper 계약](../.claude/skills/commit-pr/references/helper-contract.md)이다.** 여기서 표를 다시 베끼지 않는다. 같은 표를 두 곳에 두면 둘 중 하나가 낡는다. 요지만 적으면 `0`은 자료 확보, `2`는 근거 부족이라 미정 항목만 확인, `1`은 조회 실패라서 이력 없음으로 해석하지 않는다는 것이다.

이력은 규칙의 확정판이 아니다. 티켓이 안 보였다는 사실은 티켓 금지가 아니며, 제목 최대 길이도 제한이 아니다. PR 본문 혼용 여부는 수집된 본문으로 호출자가 판단한다.

## 리팩토링 분류

1단계는 요청, 응답 계약을 보존해야 한다. 기존 검증이 있었다는 사실만으로 DTO 전환이 안전해지지 않는다. 예를 들어 `typeof count !== 'number'` 검증을 `@IsOptional()`, `@Type(() => Number)`, `@IsInt()`로 바꾸면 다음 차이가 생긴다.

| 입력 | 기존 검사 | 예시 DTO 변환, 검증 |
| --- | --- | --- |
| 누락, `null` | 거절 | 허용 |
| `1.5` | 허용 | 거절 |
| 문자열 `'2'` | 거절 | 숫자로 변환 후 허용 |
| `0`, `2` | 허용 | 허용 |

따라서 이 예시는 2단계다. 필수 여부, 기본값, 형변환, 허용 입력, HTTP 상태, 에러 응답을 비교하고, 실제 pipe 설정에서 경계 사례를 검증한다. 1단계 범위이면 동등성을 입증할 수 없는 기존 검증은 유지한다. 입력만 바꾸는 2단계 작업에 응답 DTO, Mapper 작업까지 추가하지 않는다. [1단계](../.claude/skills/refactoring/references/phase1-safe-changes.md)와 [2단계](../.claude/skills/refactoring/references/phase2-contract-changes.md) 참조에 절차를 둔다.

## 토큰 proxy와 inventory

```bash
python3 tools/measure-skill-tokens.py --inventory
python3 tools/measure-skill-tokens.py
```

기본 모드는 실행 환경에 `tiktoken`이 필요하다. 격리 환경으로 실행하려면 다음과 같이 준비한다. tokenizer의 첫 사용에는 인코딩 데이터 다운로드가 필요할 수 있다.

```bash
python3 -m venv .venv
.venv/bin/python -m pip install tiktoken
.venv/bin/python tools/measure-skill-tokens.py
```

수치는 `tiktoken`의 `o200k_base`로 소스 텍스트를 센 비교용 **proxy**다. Claude의 실제 토큰 수, 청구량, 컨텍스트 점유량이 아니다. 다음 범위를 분리해 출력한다.

1. 저장소에 존재하는 루트 `CLAUDE.md`, `.claude/CLAUDE.md`, `paths` 없는 `.claude/rules/**/*.md`의 전체 소스.
2. 각 스킬 frontmatter의 소스 추정치.
3. 스킬별 router 본문, 개별 reference, router + 해당 reference 합계.

import를 재귀 확장하거나 실제 로드를 추적하지 않는다. 경로 조건이 있는 rules, 사용자, 조직 설정, system/tool prompt, runtime wrapper, 다른 agent, command, hook metadata와 cache 경제성도 추정하지 않는다. 여러 참조를 연 호출의 비용은 개별 참조 한 개의 합계와 다르다.

router 본문은 350 proxy tokens 이하일 때 exit 0, 초과하면 exit 1이다. `tiktoken` 미설치나 감지한 소스 입력 오류는 exit 2다. `--inventory`는 tokenizer 없이 lines/bytes만 출력하고 성공 시 exit 0이며, 토큰 상한 판정은 하지 않는다.

## 검증 실행과 한계

저장소 루트에서 실행한다.

```bash
python3 -m unittest discover -s tests -v
python3 tools/measure-skill-tokens.py --inventory
python3 tools/measure-skill-tokens.py
git diff --check
```

- `test_hooks.py`: 임시 Git 저장소와 가짜 Yarn으로 분기 차단, 경로 공백, 중첩 경로, 저장소 밖 대상, 검사 성공, 실패, 명령 누락, JSON 피드백과 큰 출력을 확인한다.
- `test_workflow_helpers.py`: 실제 임시 Git 이력과 가짜 `gh`로 최초 커밋 전, 미추적, 기준 커밋 diff, 모드 분리, 조회 실패, 컨벤션, template 우선순위를 확인한다.
- `test_token_measurement.py`: 파일 범위, metadata/router/reference 분리, 예산 경계, 의존성 없는 inventory와 오류 처리를 확인한다. 실제 proxy 실행을 함께 확인한다.

테스트는 실제 대상 서비스의 Yarn이나 GitHub PR 생성을 실행하지 않는다. 리팩토링 참조는 위 경계 사례와 계약을 유지하는 검증 이동, 입력만 바꾸는 작업 시나리오로 판단 지침을 검토한다. 이것을 모델 성능 개선의 실측으로 보고하지 않는다.

대상 프로젝트 적용 후에는 `/hooks`로 연결을 확인하고, 임시 저장소에서 `main`의 Edit, Write 차단, 작업 브랜치의 허용, 의도적으로 실패한 검사 결과가 Claude에 전달되는지 확인한다. `/context`로 지침과 metadata의 실제 로드 상태도 확인한다. 이 런타임 확인과 프로젝트별 테스트를 마쳐야 해당 환경에서의 동작까지 검증했다고 할 수 있다.
