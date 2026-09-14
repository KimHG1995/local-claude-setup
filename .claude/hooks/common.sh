#!/bin/bash
# Edit/Write 훅에서 공유하는 입력 경계, 저장소 탐색, PostToolUse 응답.

post_context() {
  # 큰 검사 출력도 프로세스 인자 크기 제한 없이 전달한다.
  printf '%s' "$1" | jq -Rs '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: .}}'
}

hook_error() {
  if [[ "$HOOK_EVENT" == "PreToolUse" ]]; then
    printf '%s\n' "$1" >&2
    exit 2
  fi
  post_context "$1"
  exit 0
}

read_hook_input() {
  HOOK_EVENT="$1"
  if ! command -v jq >/dev/null 2>&1; then
    printf '%s\n' '훅 실행 실패: jq가 필요합니다.' >&2
    if [[ "$HOOK_EVENT" == "PreToolUse" ]]; then exit 2; else exit 1; fi
  fi
  INPUT=$(cat)
  if ! FILE_PATH=$(printf '%s' "$INPUT" | jq -er '.tool_input.file_path | select(type == "string" and length > 0)' 2>/dev/null); then
    hook_error '훅 입력 오류: 유효한 JSON과 tool_input.file_path 문자열이 필요합니다.'
  fi
  if ! HOOK_CWD=$(printf '%s' "$INPUT" | jq -er --arg cwd "$PWD" '(.cwd // $cwd) | select(type == "string" and length > 0)' 2>/dev/null); then
    hook_error '훅 입력 오류: cwd는 비어 있지 않은 경로 문자열이어야 합니다.'
  fi
  if [[ "$HOOK_CWD" != /* ]]; then HOOK_CWD="$PWD/$HOOK_CWD"; fi
  if [[ "$FILE_PATH" != /* ]]; then FILE_PATH="$HOOK_CWD/$FILE_PATH"; fi
}

find_project_root() {
  local directory
  directory=$(dirname "$FILE_PATH")
  # Write는 아직 없는 디렉터리를 대상으로 할 수 있다.
  while [[ ! -d "$directory" && "$directory" != / ]]; do
    directory=$(dirname "$directory")
  done
  PROJECT_ROOT=$(git -C "$directory" rev-parse --show-toplevel 2>/dev/null)
  [[ -n "$PROJECT_ROOT" ]]
}
