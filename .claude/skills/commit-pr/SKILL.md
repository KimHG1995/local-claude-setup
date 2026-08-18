---
name: commit-pr
description: 스테이징된 변경으로 커밋 메시지를 작성하거나, 브랜치 변경사항으로 PR을 생성할 때 규칙을 정한다. 커밋 설명은 영어 명령형으로 쓰고, PR은 Jira 티켓 연동·커밋 목록·수정내역을 포함해 draft로 연다. "커밋해줘", "커밋 메시지 만들어줘", "PR 만들어줘", "PR 올려줘", "draft PR 열어줘" 같은 요청에 사용한다.
---

# commit-pr

상황에 맞는 참조 **하나만** 읽는다. 커밋 후 바로 PR 같은 연속 흐름이면 순서대로 하나씩 연다.

| 상황 | 참조 파일 |
| --- | --- |
| 스테이징된 변경을 커밋 메시지로 정리 | [`references/commit-message.md`](references/commit-message.md) |
| 브랜치 변경사항을 PR로 올리기 | [`references/pr-description.md`](references/pr-description.md) |

## 공통 규칙

- 커밋 메시지 설명과 PR 본문의 커밋 목록은 **영어**로 쓴다.
- `git commit` · `git push` · PR 생성은 `CLAUDE.md`의 "절대 금지(명시적 요청 없으면)" 항목이다. 이 스킬은 초안을 만들고 확인받는 데까지고, 실행은 확인 이후다.
