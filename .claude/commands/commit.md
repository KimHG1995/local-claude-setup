스테이징된 변경사항을 분석해서 커밋 메시지를 초안하고, 확인 후 커밋을 실행하라.

타입·스코프 판단, 커밋 분리 여부, 메시지 형식(영어 설명 규칙 포함)은 `commit-pr` 스킬로 옮겼다 — 여기서 표를 다시 베끼지 않는다.

- [`.claude/skills/commit-pr/references/commit-message.md`](../skills/commit-pr/references/commit-message.md) — Step 1~6 전체 절차, 생성 규칙, Anti-pattern, Template, Example

## 이 커맨드가 하는 일

1. 위 참조 파일의 Step 1~5에 따라 티켓 번호 추출 → 변경사항 파악 → 타입·스코프 결정 → 분리 여부 판단 → 메시지 초안까지 진행한다.
2. 초안을 보여주고 "이 메시지로 커밋할까요?" 확인을 받는다. 수정 요청이 있으면 반영 후 재확인.
3. 확인되면 실행한다.

```bash
git commit -m "type(scope): (KDS-XXXX) 설명"
```
