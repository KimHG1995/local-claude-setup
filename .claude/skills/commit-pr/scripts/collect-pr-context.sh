#!/bin/bash
# PR 본문에 필요한 재료(브랜치, 티켓 번호, 커밋 목록, 변경 파일)를 한 번에 뽑아 보여준다.
# 최종 문구 작성은 SKILL.md/references/pr-description.md 를 따른다 — 이 스크립트는 재료만 모은다.
# 사용: bash .claude/skills/commit-pr/scripts/collect-pr-context.sh [base-branch]
set -uo pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$PROJECT_ROOT" ]]; then
  echo "🚫 git 저장소 루트를 찾을 수 없습니다."
  exit 1
fi
cd "$PROJECT_ROOT"

BRANCH=$(git branch --show-current)
BASE="${1:-}"

if [[ -z "$BASE" ]]; then
  BASE=$(git remote show origin 2>/dev/null | sed -n '/HEAD branch/s/.*: //p')
  BASE="${BASE:-main}"
fi

echo "── 브랜치 ──"
echo "$BRANCH (base: $BASE)"
echo

TICKET=$(echo "$BRANCH" | grep -oE '[A-Z]+-[0-9]+' | head -1)
echo "── 티켓 번호 ──"
if [[ -n "$TICKET" ]]; then
  echo "$TICKET"
else
  echo "브랜치명에서 티켓 번호를 찾지 못함 — 사용자에게 확인"
fi
echo

echo "── 커밋 목록 (${BASE}..${BRANCH}) ──"
git log "${BASE}..HEAD" --oneline
echo

echo "── 변경 파일 통계 ──"
git diff "${BASE}...HEAD" --stat

echo
echo "※ 위 재료로 pr-description.md 의 Template을 채운다. diff --stat 출력을 그대로 '수정내역'으로 쓰지 않는다."
