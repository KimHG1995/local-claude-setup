---
name: commit-pr
description: 스테이징된 변경으로 커밋 메시지를 작성하거나, 브랜치 변경사항으로 PR을 생성할 때 규칙을 정한다. 형식은 미리 정해 두지 않고 그 저장소의 실제 커밋과 PR 이력에서 뽑으며, 이력이 부족하면 되묻는다. "커밋해줘", "커밋 메시지 만들어줘", "PR 만들어줘", "PR 올려줘", "draft PR 열어줘" 같은 요청에 사용한다.
---

# commit-pr

상황에 맞는 참조 **하나만** 읽는다. 커밋 후 바로 PR 같은 연속 흐름이면 순서대로 하나씩 연다.

| 상황 | 참조 파일 |
| --- | --- |
| 스테이징된 변경을 커밋 메시지로 정리 | [`references/commit-message.md`](references/commit-message.md) |
| 브랜치 변경사항을 PR로 올리기 | [`references/pr-description.md`](references/pr-description.md) |

## 형식은 이력에서 뽑는다

**커밋과 PR의 형식을 이 스킬에 박아 두지 않는다.** 저장소마다 다르기 때문이다. 우선순위는 명시된 컨벤션, 이력에서 관찰한 것, 되물음 순이다.

```bash
bash .claude/skills/commit-pr/scripts/derive-git-convention.sh 5
```

exit `0`이면 관찰 결과를 따르고, exit `2`면 표시된 미정 항목을 **사용자에게 묻고 답을 받은 뒤** 진행한다. 그럴듯한 쪽으로 채우지 않는다.

## 승인 게이트

`git commit`, `git push`, PR 생성은 [`rules/git.md`](../../rules/git.md)의 승인 게이트 대상이다. 이 스킬은 초안을 만들어 확인받는 데까지고, 실행은 확인 이후다. PR은 항상 draft로 연다.
