#!/bin/bash
# .spec.ts 파일 편집 후 해당 테스트 자동 실행
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# .spec.ts 파일에만 반응
if [[ -z "$FILE_PATH" ]] || [[ ! "$FILE_PATH" =~ \.spec\.ts$ ]]; then
  exit 0
fi

PROJECT_ROOT=$(git -C "$(dirname "$FILE_PATH")" rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$PROJECT_ROOT" ]]; then exit 0; fi

cd "$PROJECT_ROOT"

# src/ 기준 상대 경로로 변환
RELATIVE_PATH="${FILE_PATH#$PROJECT_ROOT/}"

echo "── 테스트 실행: $RELATIVE_PATH ──"
OUTPUT=$(yarn test "$RELATIVE_PATH" --no-coverage 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
  PASS=$(echo "$OUTPUT" | grep -E "Tests:\s+.*passed" | tail -1)
  echo "✅ 테스트 통과${PASS:+ ($PASS)}"
else
  echo "❌ 테스트 실패:"
  echo "$OUTPUT" | grep -E "FAIL|●|expect|Error" | head -20
fi

exit 0
