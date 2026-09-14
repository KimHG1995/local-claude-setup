#!/bin/bash
# TS 파일 편집 후 동기 타입 체크와 결과 피드백
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
read_hook_input PostToolUse

# .ts 파일이고 .spec.ts / .d.ts가 아닌 경우에만 실행
if [[ ! "$FILE_PATH" =~ \.ts$ ]] || [[ "$FILE_PATH" =~ \.spec\.ts$ ]] || [[ "$FILE_PATH" =~ \.d\.ts$ ]]; then
  exit 0
fi

find_project_root || exit 0
cd "$PROJECT_ROOT" || hook_error "타입 체크 실패: 저장소로 이동할 수 없습니다: $PROJECT_ROOT"

# 동기 실행이며 결과는 피드백만 한다. 편집을 되돌리거나 차단하지 않는다.
OUTPUT=$(yarn typecheck 2>&1)
EXIT_CODE=$?

if [[ "$EXIT_CODE" -eq 0 ]]; then
  CONTEXT="✅ 타입 체크 통과 ($(basename "$FILE_PATH"))"
else
  # grep은 매칭이 없으면 0을 출력하고 exit 1을 반환한다. 0을 덧붙이지 않는다.
  ERROR_COUNT=$(printf '%s\n' "$OUTPUT" | grep -c 'error TS')
  CONTEXT="❌ 타입 체크 실패 (exit $EXIT_CODE, 타입 에러 ${ERROR_COUNT}건)"$'\n'"$OUTPUT"
fi
post_context "$CONTEXT"
exit 0
