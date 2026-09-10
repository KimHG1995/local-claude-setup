#!/bin/bash
# 이 저장소의 실제 커밋/PR 이력에서 컨벤션을 뽑는다.
# 형식을 미리 정해 두지 않고 이력에서 읽는 이유는 저장소마다 다르기 때문이다.
# 이력이 부족하면 "미정"으로 표시한다. 미정 항목은 호출자가 사용자에게 되물어야 한다.
#
# 사용: bash .claude/skills/commit-pr/scripts/derive-git-convention.sh [분석할 커밋 수]
set -uo pipefail

N="${1:-5}"
MIN_SAMPLE=3 # 이보다 적으면 컨벤션을 확정하지 않는다

# 한 항목이 이 비율 이상이면 확정한다. 저장소 첫 커밋("Initial commit")처럼
# 도구가 만든 커밋 하나 때문에 매번 되묻는 것을 막는다. 예외는 확정하되 함께 표시한다.
DOMINANT_PCT=80

# 비율이 임계 이상인지 본다. 인자는 (해당 건수, 전체).
is_dominant() {
  [[ "$2" -gt 0 ]] && [[ $(($1 * 100 / $2)) -ge "$DOMINANT_PCT" ]]
}

# 한글이 섞인 문자열의 문자 수를 센다. 로케일을 지정하지 않으면 바이트가 세어진다.
charlen() {
  printf '%s' "$1" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' '
}

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$PROJECT_ROOT" ]]; then
  echo "🚫 git 저장소 루트를 찾을 수 없습니다."
  exit 1
fi
cd "$PROJECT_ROOT"

SUBJECTS=$(git log -n "$N" --format='%s' 2>/dev/null)
COUNT=$(printf '%s\n' "$SUBJECTS" | grep -c . || true)

echo "═══ 커밋 이력 (최근 ${COUNT}개) ═══"
if [[ "$COUNT" -eq 0 ]]; then
  echo "  커밋 없음"
else
  git log -n "$N" --format='  %h  %s' 2>/dev/null
fi
echo

if [[ "$COUNT" -lt "$MIN_SAMPLE" ]]; then
  echo "⚠ 표본이 ${COUNT}개뿐입니다(최소 ${MIN_SAMPLE}). 컨벤션을 확정하지 않습니다."
  echo "  → 아래 항목을 전부 사용자에게 물어보세요."
  echo "    1. 커밋 제목 언어 (한국어 / 영어)"
  echo "    2. type(scope) prefix 사용 여부"
  echo "    3. 티켓 번호 표기 위치와 형식"
  echo
  UNDETERMINED=1
else
  UNDETERMINED=0
fi

# ── 언어 ──
KO=$(printf '%s\n' "$SUBJECTS" | grep -c '[가-힣]' || true)
EN=$((COUNT - KO))
echo "── 제목 언어 ──"
echo "  한국어 ${KO}건 / 영어 ${EN}건"
if [[ "$COUNT" -gt 0 ]]; then
  if is_dominant "$KO" "$COUNT"; then
    echo "  → 한국어로 확정"
    [[ "$KO" -ne "$COUNT" ]] && echo "     (영어 ${EN}건은 예외로 둡니다)"
  elif is_dominant "$EN" "$COUNT"; then
    echo "  → 영어로 확정"
    [[ "$EN" -ne "$COUNT" ]] && echo "     (한국어 ${KO}건은 예외로 둡니다)"
  else
    echo "  → 혼용이고 어느 쪽도 ${DOMINANT_PCT}%를 넘지 않습니다. 사용자에게 물어보세요."
    UNDETERMINED=1
  fi
fi
echo

# ── type(scope) prefix ──
TYPED=$(printf '%s\n' "$SUBJECTS" | grep -cE '^(feat|fix|refactor|chore|docs|test|revert|perf|style|build|ci)(\([^)]+\))?!?: ' || true)
echo "── type(scope) prefix ──"
echo "  ${TYPED}/${COUNT}건이 conventional 형식"
if [[ "$COUNT" -gt 0 ]]; then
  UNTYPED=$((COUNT - TYPED))
  if is_dominant "$TYPED" "$COUNT"; then
    echo "  → 사용함. 실제 쓰인 type 목록:"
    printf '%s\n' "$SUBJECTS" | sed -nE 's/^([a-z]+)(\([^)]+\))?!?: .*/    \1/p' | sort -u
    [[ "$UNTYPED" -ne 0 ]] && echo "     (prefix 없는 ${UNTYPED}건은 예외로 둡니다)"
  elif is_dominant "$UNTYPED" "$COUNT"; then
    echo "  → 사용하지 않음"
    [[ "$TYPED" -ne 0 ]] && echo "     (prefix 있는 ${TYPED}건은 예외로 둡니다)"
  else
    echo "  → 혼용이고 어느 쪽도 ${DOMINANT_PCT}%를 넘지 않습니다. 사용자에게 물어보세요."
    UNDETERMINED=1
  fi
fi
echo

# ── 티켓 번호 ──
TICKETED=$(printf '%s\n' "$SUBJECTS" | grep -cE '[A-Z]{2,}-[0-9]+' || true)
echo "── 티켓 번호 ──"
echo "  ${TICKETED}/${COUNT}건에 티켓 번호가 있음"
if [[ "$TICKETED" -gt 0 ]]; then
  echo "  실제 표기:"
  printf '%s\n' "$SUBJECTS" | grep -oE '.{0,3}[A-Z]{2,}-[0-9]+.{0,2}' | sort -u | sed 's/^/    /'
elif [[ "$COUNT" -ge "$MIN_SAMPLE" ]]; then
  echo "  → 커밋 제목에는 티켓 번호를 넣지 않음"
fi
echo

# ── 제목 길이 ──
if [[ "$COUNT" -gt 0 ]]; then
  echo "── 제목 길이 ──"
  MAXLEN=0
  while IFS= read -r s; do
    [[ -z "$s" ]] && continue
    L=$(charlen "$s")
    printf '  %3s자  %s\n' "$L" "$s"
    [[ "$L" -gt "$MAXLEN" ]] && MAXLEN="$L"
  done <<< "$SUBJECTS"
  echo "  최대 ${MAXLEN}자"
fi
echo

# ── body ──
BODIED=0
while IFS= read -r sha; do
  [[ -z "$sha" ]] && continue
  BODY=$(git log -1 --format='%b' "$sha" 2>/dev/null | grep -c . || true)
  [[ "$BODY" -gt 0 ]] && BODIED=$((BODIED + 1))
done < <(git log -n "$N" --format='%H' 2>/dev/null)
echo "── 커밋 body ──"
echo "  ${BODIED}/${COUNT}건에 body가 있음"
echo

# ── branch ──
echo "── Branch ──"
echo "  현재: $(git branch --show-current 2>/dev/null)"
echo "  로컬 목록:"
git branch --format='    %(refname:short)' 2>/dev/null | head -10
echo

# ── PR ──
echo "═══ PR 이력 ═══"
if ! command -v gh > /dev/null 2>&1; then
  echo "  gh CLI 없음. PR 컨벤션 미정이므로 사용자에게 물어보세요."
  UNDETERMINED=1
else
  # gh 실패와 "PR이 0개"를 구분한다. 둘을 뭉치면 조회하지 못한 것을 없는 것으로 보고하게 된다.
  PR_ERR=$(gh pr list --state all --limit "$N" --json number,title 2>&1 > /dev/null)
  PRS=$(gh pr list --state all --limit "$N" --json number,title 2>/dev/null)
  if [[ -n "$PR_ERR" ]]; then
    echo "  ⚠ 조회하지 못했습니다(PR이 없다는 뜻이 아닙니다):"
    echo "$PR_ERR" | head -2 | sed 's/^/      /'
    echo "  → 이 저장소의 PR 호스트를 확인하고, 형식은 사용자에게 물어보세요."
    UNDETERMINED=1
  elif [[ -z "$PRS" || "$PRS" == "[]" ]]; then
    echo "  PR 0개 (조회는 성공)."
    echo "  → PR 본문 형식을 이력에서 뽑을 수 없습니다. 사용자에게 물어보세요."
    UNDETERMINED=1
  else
    echo "$PRS" | python3 -c "
import json, sys
for p in json.load(sys.stdin):
    print(f\"  #{p['number']}  {p['title']}\")
" 2>/dev/null || echo "  (파싱 실패)"
  fi
fi
echo

# ── PR template ──
echo "── PR template ──"
TPL=$(ls .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null | head -1)
if [[ -n "$TPL" ]]; then
  echo "  있음: $TPL"
  echo "  → 이 template의 섹션 구성을 그대로 따릅니다. 별도 형식을 만들지 않습니다."
  grep -E '^#{1,3} ' "$TPL" 2>/dev/null | sed 's/^/    /'
else
  echo "  없음. PR 내용에 맞게 섹션을 구성합니다."
fi
echo

echo "═══ 결론 ═══"
if [[ "$UNDETERMINED" -eq 1 ]]; then
  echo "  ⚠ 미정 항목이 있습니다. 위에 표시된 것을 사용자에게 물어본 뒤 진행하세요."
  echo "     추측으로 채우지 않습니다."
  exit 2
fi
echo "  ✅ 이력에서 컨벤션을 확정했습니다. 위 관찰 결과를 그대로 따르세요."
