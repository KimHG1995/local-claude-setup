#!/bin/bash
# 보호 브랜치(master/main)에서 직접 편집 차단
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$FILE_PATH" ]]; then exit 0; fi

PROJECT_ROOT=$(git -C "$(dirname "$FILE_PATH")" rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$PROJECT_ROOT" ]]; then exit 0; fi

BRANCH=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)

# master/main 브랜치에서 소스 파일 직접 수정 차단
if [[ "$BRANCH" == "master" || "$BRANCH" == "main" ]]; then
  echo "🚫 보호 브랜치 '$BRANCH'에서 직접 수정 불가"
  echo "   feature/ 또는 hotfix/ 브랜치를 생성한 후 작업하세요."
  exit 1
fi

exit 0
