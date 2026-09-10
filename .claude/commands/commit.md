스테이징된 변경사항을 분석해서 커밋 메시지를 초안하고, 확인 후 커밋을 실행하라.

메시지 형식은 미리 정해져 있지 않다. 명시된 컨벤션, 이력에서 관찰한 것, 되물음 순으로 정한다. 절차와 규칙은 `commit-pr` 스킬에 있다.

- [`.claude/skills/commit-pr/references/commit-message.md`](../skills/commit-pr/references/commit-message.md) — 절차, Anti-pattern, 검증

## 이 커맨드가 하는 일

1. 컨벤션 확정:

   ```bash
   bash .claude/skills/commit-pr/scripts/derive-git-convention.sh 5
   ```

   exit `2`면 표시된 미정 항목을 먼저 사용자에게 묻는다. 추측으로 채우지 않는다.

2. 위 참조 파일의 절차에 따라 티켓 번호 확인, 변경사항 파악, 분리 여부 판단을 거쳐 초안을 만든다.
3. 초안을 보여 주고 "이 메시지로 커밋할까요"를 확인받는다. 수정 요청이 있으면 반영 후 재확인.
4. 확인되면 `git commit`을 실행한다.
