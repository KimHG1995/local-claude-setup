현재 브랜치의 커밋을 base 브랜치 대상 PR로 올려라. PR 생성·오픈은 명시적 요청(이 커맨드 실행)이 있을 때만 한다.

본문 작성 규칙(Jira 연동, 커밋 목록, 수정내역, draft 원칙)은 `commit-pr` 스킬로 옮겼다 — 여기서 표를 다시 베끼지 않는다.

- [`.claude/skills/commit-pr/references/pr-description.md`](../skills/commit-pr/references/pr-description.md) — 생성 규칙, Anti-pattern, Template, Example

## 이 커맨드가 하는 일

1. 재료 수집:

   ```bash
   bash .claude/skills/commit-pr/scripts/collect-pr-context.sh [base-branch]
   ```

2. 위 참조 파일의 Template에 맞춰 배경(Jira)·변경 사항·커밋 목록·테스트 체크리스트를 채운다.
3. 완성된 본문을 보여주고 "이 내용으로 draft PR을 열까요?" 확인을 받는다. 수정 요청이 있으면 반영 후 재확인.
4. 확인되면 실행한다.

   ```bash
   gh pr create --draft --base <base-branch> --title "<제목>" --body "<본문>"
   ```

5. 생성된 PR URL을 보고한다. Open으로 전환·리뷰어 지정·머지는 별도 요청이 있을 때만 진행한다.
