#!/bin/bash
# TS 파일 편집 후 타입 체크 자동 실행 (non-blocking)
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# .ts 파일이고 .spec.ts / .d.ts가 아닌 경우에만 실행
if [[ -z "$FILE_PATH" ]]; then exit 0; fi
if [[ ! "$FILE_PATH" =~ \.ts$ ]] || [[ "$FILE_PATH" =~ \.spec\.ts$ ]] || [[ "$FILE_PATH" =~ \.d\.ts$ ]]; then
  exit 0
fi

PROJECT_ROOT=$(git -C "$(dirname "$FILE_PATH")" rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$PROJECT_ROOT" ]]; then exit 0; fi

cd "$PROJECT_ROOT"

echo "── TypeScript 타입 체크 ($(basename "$FILE_PATH")) ──"
OUTPUT=$(yarn typecheck 2>&1)

ERROR_COUNT=$(echo "$OUTPUT" | grep -c "error TS" 2>/dev/null || echo 0)

if [[ "$ERROR_COUNT" -eq 0 ]]; then
  echo "✅ 타입 체크 통과"
else
  echo "❌ 타입 에러 ${ERROR_COUNT}건 발견:"
  echo "$OUTPUT" | grep "error TS" | head -10
  if [[ "$ERROR_COUNT" -gt 10 ]]; then
    echo "  ... 외 $((ERROR_COUNT - 10))건 (yarn typecheck 로 전체 확인)"
  fi
fi

exit 0
