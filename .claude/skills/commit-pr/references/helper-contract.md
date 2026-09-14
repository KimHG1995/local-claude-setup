# Convention helper 계약

```bash
bash .claude/skills/commit-pr/scripts/derive-git-convention.sh --mode commit 5
bash .claude/skills/commit-pr/scripts/derive-git-convention.sh --mode pr 5
bash .claude/skills/commit-pr/scripts/derive-git-convention.sh --mode commit --convention CONTRIBUTING.md
```

- `--mode commit|pr`: 해당 작업의 근거만 수집한다. 기본값 및 기존 `[N]` 호출은 `commit`이며 `gh`를 호출하지 않는다. PR 요청은 반드시 `--mode pr`를 지정한다.
- `[N]`: 최근 표본 수, 기본 5, 양의 정수. 커밋은 최소 3개와 80% 우세 기준을 참고한다. 빈/적은 표본은 확정 규칙이 아니다.
- `--convention FILE`: 호출자가 **해당 작업에 적용되는 지침임을 확인한** 파일을 읽고 이력 조회를 생략한다. 상대 경로는 스크립트를 호출한 최초 작업 디렉터리를 기준으로 해석하며, 절대 경로도 지원한다. 아무 `CONTRIBUTING.md`나 선택하지 않는다. 파일 내용의 적용 여부는 스크립트가 판단하지 않는다. 대화에서 이미 정한 지침은 파일로 만들 필요 없이 직접 적용한다.
- PR 모드는 명시된 파일, 지원하는 PR template, PR 이력 순으로 자료를 선택한다. template이 있으면 이력을 조회하지 않는다. 다른 위치의 template이나 여러 template 중 선택은 호출자가 확인하고 `--convention`으로 지정할 수 있다.
- PR 이력은 `gh pr list --state all --limit N --json number,title,body` **한 번**으로 수집한다. stderr 경고만으로 실패로 보지 않고 종료 상태를 확인한다. 제목만으로 본문 구성/언어를 확정하지 않는다.

종료 코드:

| 코드 | 의미 | 호출자 처리 |
| --- | --- | --- |
| 0 | 선택한 지침/template 또는 관찰 자료 확보 | 명시된 규칙을 우선하고 자료의 적용 범위를 판단 |
| 2 | 표본 부족, 혼용 또는 PR 본문 자료 없음 | 이미 정한 항목은 유지, 나머지만 확인 |
| 1 | 잘못된 입력, Git/gh/파싱 등 조회 실패 | 실패를 보고하고 근거 보완; 이력 없음으로 해석 금지 |

이력의 티켓 미관찰은 티켓 금지가 아니며, 관찰된 제목 최대 길이는 제한이 아니다. 명시된 지침이 없고 현재 티켓 표기가 모호하면 그 항목만 묻는다. `0`도 모든 형식의 확정을 보장하지 않는다. PR 본문이 서로 다르면 적용할 구성을 확인한다. 이 도구는 커밋/스테이징/PR 생성을 실행하지 않는다.
