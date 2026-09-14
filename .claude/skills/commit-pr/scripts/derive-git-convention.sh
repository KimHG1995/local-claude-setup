#!/bin/bash
# 요청 모드의 컨벤션 자료만 수집한다. 명시된 규칙/template이 이력보다 우선한다.
# 미정 표시는 이미 정한 규칙을 취소하지 않는다. 남은 항목만 호출자가 확인한다.
#
# 사용: derive-git-convention.sh [--mode commit|pr] [N] [--convention FILE]
# 종료: 0 자료 확보, 2 근거 부족/혼용, 1 입력/조회 실패.
#
# 호스트 전제: PR 이력 조회의 기본값은 GitHub + `gh`다. commit 모드는 Git만 쓰므로
# 호스트와 무관하다. GitLab, Bitbucket 등 다른 호스트에서는 아래 gh 블록을 그
# 호스트의 CLI나 API로 바꾸거나, `--convention FILE`로 명시된 규칙 파일을 넘겨
# 이력 조회를 건너뛴다. 조회 실패는 exit 1이라 "PR 없음"으로 오해되지 않는다.
set -uo pipefail

# Legacy [N] means commit only; PR callers must opt in explicitly.
MODE=commit
N=5
CONVENTION=""
SEEN_N=0
fail() { echo "🚫 $*" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      [[ $# -ge 2 ]] || fail "--mode 값 필요"
      MODE="$2"; shift 2 ;;
    --convention)
      [[ $# -ge 2 ]] || fail "--convention 파일 필요"
      CONVENTION="$2"; shift 2 ;;
    *)
      [[ "$SEEN_N" -eq 0 && "$1" =~ ^[1-9][0-9]*$ ]] || fail "표본 수는 양의 정수여야 합니다."
      N="$1"; SEEN_N=1; shift ;;
  esac
done
[[ "$MODE" == commit || "$MODE" == pr ]] || fail "--mode commit|pr만 지원합니다."
# Resolve caller-selected files before switching to the repository root.
if [[ -n "$CONVENTION" && "$CONVENTION" != /* ]]; then
  CONVENTION="$PWD/$CONVENTION"
fi
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
cd "$PROJECT_ROOT" || fail "저장소 이동 실패"

# The caller selects an applicable convention; arbitrary repo prose is not auto-detected.
if [[ -n "$CONVENTION" ]]; then
  [[ -f "$CONVENTION" && -r "$CONVENTION" ]] || fail "컨벤션 파일을 읽을 수 없습니다: $CONVENTION"
  echo "═══ 명시된 컨벤션 ($MODE): $CONVENTION ═══"
  cat "$CONVENTION" || fail "컨벤션 파일 읽기 실패"
  exit 0
fi
if [[ "$MODE" == pr ]]; then
  for TPL in .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md; do
    if [[ -f "$TPL" ]]; then
      echo "── PR template: $TPL ──"
      cat "$TPL" || fail "template 읽기 실패"
      echo "template 우선. 정하지 않은 항목만 기존 지침/사용자 요청으로 보완하세요."
      exit 0
    fi
  done
  command -v gh > /dev/null 2>&1 || fail "gh CLI 없음 — PR 이력을 조회하지 못했습니다."
  WORK=$(mktemp -d) || fail "임시 디렉터리 생성 실패"
  trap 'rm -rf "$WORK"' EXIT
  if ! gh pr list --state all --limit "$N" --json number,title,body > "$WORK/prs" 2> "$WORK/error"; then
    cat "$WORK/error" >&2
    fail "PR 조회 실패 (PR 0개라는 뜻이 아닙니다)."
  fi
  cat "$WORK/error" >&2
  python3 - "$WORK/prs" <<'PRPY'
import json
import sys
try:
    with open(sys.argv[1]) as source:
        prs = json.load(source)
    if not isinstance(prs, list) or any(
        not isinstance(p, dict) or not isinstance(p.get('number'), int)
        or not isinstance(p.get('title'), str) or not isinstance(p.get('body'), str)
        for p in prs
    ):
        raise ValueError('invalid PR fields')
except (OSError, ValueError) as error:
    print(f'PR 응답 파싱 실패: {error}', file=sys.stderr)
    sys.exit(1)
print('═══ PR 이력 (제목 + 본문) ═══')
if not prs:
    print('PR 0개 (조회 성공). 명시된 지침이 없으면 본문 구성을 사용자에게 물어보세요.')
    sys.exit(2)
for pr in prs:
    print(f"#{pr['number']}  {pr['title']}\n{pr['body']}\n")
if not any(pr['body'].strip() for pr in prs):
    print('본문 표본 없음. 명시된 지침이 없으면 구성을 사용자에게 물어보세요.')
    sys.exit(2)
print('관찰 자료입니다. 본문 구성/언어가 혼용되면 미정 항목만 확인하세요.')
PRPY
  exit $?
fi

if git rev-parse --verify HEAD > /dev/null 2>&1; then
  SUBJECTS=$(git log -n "$N" --format='%s') || fail "커밋 이력 조회 실패"
else
  REF=$(git symbolic-ref -q HEAD) || fail "HEAD 확인 실패"
  git show-ref --verify --quiet "$REF"
  [[ $? -eq 1 ]] || fail "HEAD 읽기 실패"
  SUBJECTS=""
fi
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
  echo "  → 이미 정한 항목은 유지하고, 아래 중 미정 항목만 사용자에게 물어보세요."
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
  echo "  → 이 표본에서 티켓 번호 미관찰 (금지 규칙이 아님). 명시된 규칙과 현재 티켓을 확인하세요."
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

echo "═══ 결론 ═══"
if [[ "$UNDETERMINED" -eq 1 ]]; then
  echo "  ⚠ 미정 항목이 있습니다. 위에 표시된 것을 사용자에게 물어본 뒤 진행하세요."
  echo "     추측으로 채우지 않습니다."
  exit 2
fi
echo "  ✅ 이력 관찰 완료. 명시된 컨벤션이 우선이며 표본은 금지/필수 규칙이 아닙니다."
