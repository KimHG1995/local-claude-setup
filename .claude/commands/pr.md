현재 브랜치의 커밋을 base 브랜치 대상 draft PR로 올려라. PR 생성은 명시적 요청(이 커맨드 실행)이 있을 때만 한다.

본문 형식은 미리 정해져 있지 않다. `.github/pull_request_template.md`, 기존 PR 이력, 되물음 순으로 정한다. 절차와 규칙은 `commit-pr` 스킬에 있다.

- [`.claude/skills/commit-pr/references/pr-description.md`](../skills/commit-pr/references/pr-description.md) — 절차, 항상 적용하는 것, Anti-pattern

## 이 커맨드가 하는 일

1. 재료 수집:

   ```bash
   bash .claude/skills/commit-pr/scripts/derive-git-convention.sh 5
   ```

   exit `2`면 표시된 미정 항목을 먼저 사용자에게 묻는다.

2. 위 참조 파일의 절차에 따라 base 확인, diff 점검, `rules-check` 대조, Jira 배경 정리를 거쳐 본문을 작성한다.
3. 완성된 본문을 보여 주고 "이 내용으로 draft PR을 열까요"를 확인받는다.
4. 확인되면 실행한다.

   ```bash
   gh pr create --draft --assignee @me --base <base> --title "<제목>" --body "<본문>"
   ```

5. PR URL을 보고하고, Open으로 올리기 전에 실제 동작을 직접 확인해야 한다는 것을 한 문장으로 알린다.
