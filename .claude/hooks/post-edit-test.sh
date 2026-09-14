#!/bin/bash
# .spec.ts 파일 편집 후 해당 테스트 자동 실행
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
read_hook_input PostToolUse

# .spec.ts 파일에만 반응
if [[ ! "$FILE_PATH" =~ \.spec\.ts$ ]]; then
  exit 0
fi

find_project_root || exit 0
cd "$PROJECT_ROOT" || hook_error "테스트 실패: 저장소로 이동할 수 없습니다: $PROJECT_ROOT"

# 저장소 루트 기준 상대 경로로 변환
RELATIVE_PATH="${FILE_PATH#$PROJECT_ROOT/}"

# 동기 실행이며 실패도 모델 컨텍스트로만 전달한다.
OUTPUT=$(yarn test "$RELATIVE_PATH" --no-coverage 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
  PASS=$(printf '%s\n' "$OUTPUT" | grep -E 'Tests:[[:space:]]+.*passed' | tail -1)
  CONTEXT="✅ 테스트 통과: $RELATIVE_PATH${PASS:+ ($PASS)}"
else
  CONTEXT="❌ 테스트 실패: $RELATIVE_PATH (exit $EXIT_CODE)"$'\n'"$OUTPUT"
fi
post_context "$CONTEXT"
exit 0
