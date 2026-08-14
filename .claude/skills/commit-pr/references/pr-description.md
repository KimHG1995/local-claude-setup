# PR 생성

`commit-pr` 스킬에서 "브랜치 변경사항을 PR로 올리는 상황"으로 판단됐을 때만 읽는다. PR 본문에 배경(Jira)·커밋 목록·수정내역이 전부 드러나게 만드는 절차다.

## 생성 규칙

1. **브랜치명에서 티켓 번호를 먼저 추출한다.** 규칙은 [`commit-message.md`](commit-message.md) Step 1과 동일하다 (`feature/KDS-2902_khg` → `KDS-2902`).
2. **티켓 번호가 있으면 배경 정보를 정리한다.**
   - 이 세션에 Jira 연동 도구(Atlassian/Jira MCP 등)가 연결돼 있으면 그걸로 해당 티켓의 제목·요약·링크를 가져와 PR 상단에 붙인다.
   - 연결돼 있지 않으면 사용자에게 "지라 티켓 요약 있으면 붙여넣어 주세요"라고 물어보거나, 최소한 티켓 번호만 제목에 남긴다. **존재를 확인하지 못한 링크를 지어내지 않는다.**
   - CLAUDE.md 개인화 정보에 Jira 베이스 URL이 채워져 있으면 `<베이스 URL>/browse/KDS-XXXX` 형태로 링크를 만든다.
3. **base 브랜치까지의 커밋을 전부 나열한다.** `git log <base>..HEAD --oneline` 결과를 표로 정리한다. `scripts/collect-pr-context.sh` 로 브랜치·티켓·커밋 목록·변경 파일을 한 번에 뽑을 수 있다.
4. **수정내역은 커밋 로그를 그대로 붙이지 않고, 파일/모듈 단위로 사람이 읽을 수 있게 요약한다.** `git diff <base>...HEAD --stat`을 참고하되, 그 출력 자체를 붙여넣지 않는다.
5. **PR은 항상 draft로 연다.** `gh pr create --draft`. Open으로 전환하는 것은 사람이 한다.
6. **assignee는 PR 작성자 본인으로 둔다.**
7. 실행(`gh pr create`) 전에 완성된 본문을 보여주고 사용자 확인을 받는다.

## Anti-pattern

- ❌ 존재를 확인하지 못한 Jira 링크를 추측해서 만들어 넣는 것 — 조회에 실패했으면 "링크 확인 필요"라고 명시하고 넘어간다.
- ❌ `git diff --stat` 출력을 그대로 복붙해서 "수정내역"이라고 부르는 것 — 리뷰어가 실제로 뭐가 바뀌었는지 읽을 수 있는 요약이어야 한다.
- ❌ 커밋이 여러 개인데 "총 N개 파일 변경"처럼 뭉뚱그리고 커밋 목록을 생략하는 것.
- ❌ 확인 없이 바로 Open 상태로 PR을 여는 것 — 명시적 요청 없으면 draft.
- ❌ base 브랜치를 확인하지 않고 임의로(예: 항상 `main`) 잡는 것 — Phase를 쌓는 구조라면 base가 직전 Phase 브랜치일 수 있다.

## Template

```markdown
## 배경
- [KDS-XXXX](<JIRA_BASE_URL>/browse/KDS-XXXX) — <티켓 제목>
- <티켓 설명 1~2줄 요약>

(Jira 연동 불가 · 티켓 없음이면 이 섹션 생략)

## 변경 사항
- <모듈/파일 단위 요약 1>
- <모듈/파일 단위 요약 2>

## 커밋
| Commit | 설명 |
| --- | --- |
| `<sha>` | `<commit subject>` |
| `<sha>` | `<commit subject>` |

## 테스트
- [ ] `yarn typecheck`
- [ ] `yarn test <module>`
```

## Example

```markdown
## 배경
- [KDS-2896](https://kpec.atlassian.net/browse/KDS-2896) — 메모 목록 응답 DTO 표준화
- 메모 목록 API가 Entity를 그대로 반환하고 있어 Response DTO로 분리 요청

## 변경 사항
- `memo` 모듈에 Response DTO·Mapper 추가, 컨트롤러가 DTO를 반환하도록 변경
- 기존 응답 JSON 구조는 변경 없음 (1단계 리팩토링 범위)

## 커밋
| Commit | 설명 |
| --- | --- |
| `a1b2c3d` | `feat(memo): add endpoint DTO files` |
| `e4f5g6h` | `refactor(memo): apply new DTOs to service and controller` |

## 테스트
- [x] `yarn typecheck`
- [x] `yarn test memo`
```

## 검증

```bash
bash .claude/skills/commit-pr/scripts/collect-pr-context.sh [base-branch]
```

브랜치명·티켓 번호·커밋 목록·변경 파일 통계를 한 번에 보여준다. base-branch를 생략하면 origin의 기본 브랜치를 쓴다.

PR 생성 전 체크리스트:

- [ ] 티켓 번호가 있으면 배경 섹션이 채워졌는가 (또는 사유와 함께 생략됐는가)?
- [ ] 커밋 목록에 모든 커밋이 빠짐없이 나열됐는가?
- [ ] 수정내역이 diff 통계 붙여넣기가 아니라 사람이 읽을 수 있는 요약인가?
- [ ] draft로 열렸는가?
