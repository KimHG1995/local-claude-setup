#!/bin/bash
# src/entities/ 변경분에서 컬럼/관계/인덱스 변경 후보를 휴리스틱으로 뽑아 보여준다.
# 최종 유형 판단은 SKILL.md의 표를 기준으로 한다 — 이 스크립트는 "무엇이 바뀌었는지"를
# 빠르게 보여줄 뿐, 마이그레이션 필요 여부를 스스로 결론 내리지 않는다.
# 사용: bash .claude/skills/entity-migration/scripts/check-entity-diff.sh
set -uo pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$PROJECT_ROOT" ]]; then
  echo "🚫 git 저장소 루트를 찾을 수 없습니다."
  exit 1
fi
cd "$PROJECT_ROOT"

DIFF=$(git diff HEAD -- src/entities/)
if [[ -z "$DIFF" ]]; then
  echo "Entity 변경 없음"
  exit 0
fi

echo "── 변경된 Entity 파일 ──"
git diff HEAD --name-only -- src/entities/
echo

echo "── @Column 추가/삭제 후보 ──"
echo "$DIFF" | grep -E "^\+.*@Column" | sed 's/^/  + /'
echo "$DIFF" | grep -E "^-.*@Column" | sed 's/^/  - /'
echo

echo "── 관계 데코레이터 변경 후보 ──"
echo "$DIFF" | grep -E "^[+-].*(@OneToMany|@ManyToOne|@ManyToMany|@OneToOne|@JoinColumn)" | sed 's/^\+/  + /; s/^-/  - /'
echo

echo "── 인덱스 변경 후보 ──"
echo "$DIFF" | grep -E "^[+-].*@Index" | sed 's/^\+/  + /; s/^-/  - /'
echo

echo "── 타입/옵션 변경 후보 (type:/nullable: 줄) ──"
echo "$DIFF" | grep -E "^[+-].*(type:\s*['\"]|nullable:\s*(true|false))" | sed 's/^\+/  + /; s/^-/  - /'
echo

echo "※ 위 목록은 참고용이다. 최종 분류는 entity-migration 스킬의 SKILL.md 표를 따른다."
