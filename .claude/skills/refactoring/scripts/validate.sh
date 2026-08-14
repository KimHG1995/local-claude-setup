#!/bin/bash
# refactoring 스킬 공통 검증: typecheck (+ 선택적 모듈 테스트) + lint
# 사용: bash .claude/skills/refactoring/scripts/validate.sh [module-path]
#   module-path 생략 시 typecheck·lint만 실행한다.
set -uo pipefail

MODULE_PATH="${1:-}"
FAIL=0

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$PROJECT_ROOT" ]]; then
  echo "🚫 git 저장소 루트를 찾을 수 없습니다."
  exit 1
fi
cd "$PROJECT_ROOT"

echo "── 1) yarn typecheck ──"
if ! yarn typecheck; then
  FAIL=1
fi

if [[ -n "$MODULE_PATH" ]]; then
  echo
  echo "── 2) yarn test (${MODULE_PATH}) ──"
  if ! yarn test --testPathPattern="$MODULE_PATH" --no-coverage; then
    FAIL=1
  fi
else
  echo
  echo "── 2) yarn test 건너뜀 — module-path 인자가 없습니다 ──"
fi

echo
echo "── 3) yarn lint ──"
if ! yarn lint; then
  FAIL=1
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "✅ 검증 통과"
else
  echo "❌ 검증 실패 — 위 로그를 확인하세요"
fi

exit "$FAIL"
