#!/bin/bash
# 보호 브랜치(master/main)에서 직접 편집 차단
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
read_hook_input PreToolUse
find_project_root || exit 0

# symbolic-ref는 첫 커밋 전 브랜치도 확인한다. Detached HEAD는 보호 목록 밖이다.
BRANCH=$(git -C "$PROJECT_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null)

# master/main 브랜치에서 소스 파일 직접 수정 차단
if [[ "$BRANCH" == "master" || "$BRANCH" == "main" ]]; then
  printf '%s\n' "🚫 보호 브랜치 '$BRANCH'에서 직접 수정 불가" \
    '   feature/ 또는 hotfix/ 브랜치를 생성한 후 작업하세요.' >&2
  exit 2
fi

exit 0
