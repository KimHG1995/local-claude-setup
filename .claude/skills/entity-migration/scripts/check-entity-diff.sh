#!/bin/bash
# Read-only heuristic: base (default HEAD) -> working tree, plus untracked entities.
# Initial repositories use index + working-tree diffs. Does not decide migration need.
# Usage: check-entity-diff.sh [--base REF]
set -uo pipefail
fail() { echo "🚫 $*" >&2; exit 1; }
BASE=""
if [[ $# -gt 0 ]]; then
  [[ $# -eq 2 && "$1" == "--base" && -n "$2" ]] || fail "사용: $0 [--base REF]"
  BASE="$2"
fi
PROJECT_ROOT=$(git rev-parse --show-toplevel) || fail "git 저장소 루트를 찾을 수 없습니다."
cd "$PROJECT_ROOT" || fail "저장소로 이동하지 못했습니다."
WORK=$(mktemp -d) || fail "임시 디렉터리를 만들지 못했습니다."
trap 'rm -rf "$WORK"' EXIT
: > "$WORK/diff"
: > "$WORK/files"
if [[ -n "$BASE" ]]; then
  BASE=$(git rev-parse --verify --end-of-options "${BASE}^{commit}") || fail "base를 확인하지 못했습니다."
elif git rev-parse --verify HEAD > /dev/null 2>&1; then
  BASE=HEAD
else
  # A missing branch ref is unborn; an existing but unreadable HEAD is an error.
  REF=$(git symbolic-ref -q HEAD) || fail "HEAD를 확인하지 못했습니다."
  git show-ref --verify --quiet "$REF"
  STATUS=$?
  [[ "$STATUS" -eq 1 ]] || fail "HEAD를 읽지 못했습니다."
fi
if [[ -n "$BASE" ]]; then
  git diff --no-ext-diff --no-textconv "$BASE" -- src/entities/ > "$WORK/diff" || fail "Entity diff 실패"
  git diff --name-only "$BASE" -- src/entities/ > "$WORK/files" || fail "Entity 목록 조회 실패"
else
  git diff --cached --no-ext-diff --no-textconv -- src/entities/ > "$WORK/diff" || fail "스테이징 diff 실패"
  git diff --no-ext-diff --no-textconv -- src/entities/ >> "$WORK/diff" || fail "작업 트리 diff 실패"
  git diff --cached --name-only -- src/entities/ > "$WORK/files" || fail "스테이징 목록 조회 실패"
  git diff --name-only -- src/entities/ >> "$WORK/files" || fail "작업 트리 목록 조회 실패"
fi
git ls-files --others --exclude-standard -z -- src/entities/ > "$WORK/untracked" || fail "미추적 파일 조회 실패"
while IFS= read -r -d '' FILE; do
  printf '%s\n' "$FILE" >> "$WORK/files"
  git diff --no-index --no-ext-diff --no-textconv -- /dev/null "$FILE" >> "$WORK/diff"
  STATUS=$?
  [[ "$STATUS" -le 1 ]] || fail "미추적 Entity diff 실패: $FILE"
done < "$WORK/untracked"
if [[ ! -s "$WORK/files" ]]; then
  echo "선택한 비교 범위에 Entity 변경 없음 — 제안/기커밋 변경과 DB 상태는 별도 확인"
  exit 0
fi
echo "── 변경된 Entity 파일 ──"
sort -u "$WORK/files"
echo
show_candidates() {
  echo "── $1 ──"
  # No match is normal; failures in collection above are never treated as empty.
  grep -E "$2" "$WORK/diff" | sed 's/^+/  + /; s/^-/  - /' || true
  echo
}
show_candidates '@Column 추가/삭제 후보' '^[+-].*@Column'
show_candidates '관계 데코레이터 변경 후보' '^[+-].*(@OneToMany|@ManyToOne|@ManyToMany|@OneToOne|@JoinColumn)'
show_candidates '인덱스 변경 후보' '^[+-].*@Index'
show_candidates '타입/옵션 변경 후보 (type:/nullable: 줄)' "^[+-].*(type:[[:space:]]*['\"]|nullable:[[:space:]]*(true|false))"
echo "※ 휴리스틱 후보입니다. 전체 diff와 요청 범위를 확인해 entity-migration 기준으로 판단하세요."
