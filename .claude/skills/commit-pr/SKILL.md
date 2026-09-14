---
name: commit-pr
description: 스테이징된 변경으로 커밋 메시지를 작성하거나, 브랜치 변경사항으로 PR을 생성할 때 규칙을 정한다. 명시된 규칙과 PR 템플릿을 우선하고 해당 작업의 이력으로 보완하며, 미정 항목만 묻는다. "커밋해줘", "커밋 메시지 만들어줘", "PR 만들어줘", "PR 올려줘", "draft PR 열어줘" 같은 요청에 사용한다.
---

# commit-pr

작업에 맞는 참조만 연다. 연속 요청이면 순서대로 읽는다.

- 커밋 → [메시지 절차](references/commit-message.md)
- PR → [본문 절차](references/pr-description.md)

명시된 규칙이 우선이다. PR은 템플릿을 다음으로 적용하고, 이력은 빈 부분만 보완한다.

```bash
bash .claude/skills/commit-pr/scripts/derive-git-convention.sh --mode commit 5
bash .claude/skills/commit-pr/scripts/derive-git-convention.sh --mode pr 5
```

요청한 모드만 실행한다. 커밋 모드는 PR을 조회하지 않는다. 코드/옵션 및 미정 처리: [helper 계약](references/helper-contract.md).

`git commit`, `git push`, PR 생성은 [승인 규칙](../../rules/git.md)을 따른다. PR은 draft로 연다.
