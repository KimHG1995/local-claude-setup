#!/usr/bin/env python3
"""
스킬 구조의 토큰 비용을 잰다.

README 의 "구조를 이렇게 바꾼 이유" 절 숫자를 재현하는 스크립트다.
주장을 문서에만 적어두면 낡으니, 언제든 다시 돌려 확인할 수 있게 남긴다.

사용:
    pip install tiktoken
    python3 tools/measure-skill-tokens.py

토크나이저 주의:
    tiktoken o200k_base 는 Claude 의 토크나이저가 아니다. 절대값은 근사치다.
    다만 비교 대상 양쪽이 같은 언어·같은 성격의 텍스트라 '비율'과 '차이'는
    토크나이저 선택에 거의 영향받지 않는다. 이 스크립트가 보는 것도 그쪽이다.
"""
import re
import sys
from pathlib import Path

try:
    import tiktoken
except ImportError:
    sys.exit("tiktoken 이 필요하다:  pip install tiktoken")

ENC = tiktoken.get_encoding("o200k_base")
SKILLS = Path(__file__).resolve().parent.parent / ".claude" / "skills"

# SKILL.md 본문 상한. 라우터가 정당하게 담는 것은 세 가지다 —
# (1) 유형 판단 로직, (2) 유형과 무관하게 매번 필요한 출력 형식,
# (3) 참조를 열기 전에 걸려야 하는 안전장치.
# 그 이상은 references/ 로 내려가야 한다. 350 은 위 셋을 담은 실측치
# (198 / 270 / 334) 에 여유를 둔 값이고, 라우터가 다시 불어나는 것을
# 잡아내는 게 목적이다. 처음 재구성 직후엔 610/580/365 였다.
ROUTER_BUDGET = 350


def tok(text: str) -> int:
    return len(ENC.encode(text))


def split_frontmatter(path: Path) -> tuple[int, int]:
    """(frontmatter 토큰, 본문 토큰). frontmatter 는 항상 상주, 본문은 트리거 시 로딩."""
    text = path.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
    if not m:
        raise ValueError(f"frontmatter 없음: {path}")
    return tok(m.group(1)), tok(m.group(2))


def main() -> int:
    skills = sorted(p for p in SKILLS.iterdir() if (p / "SKILL.md").exists())
    if not skills:
        sys.exit(f"스킬을 찾지 못함: {SKILLS}")

    resident = 0
    rows = []
    for s in skills:
        fm, body = split_frontmatter(s / "SKILL.md")
        resident += fm
        refs = sorted((s / "references").glob("*.md")) if (s / "references").is_dir() else []
        rows.append((s.name, fm, body, [(r.name, tok(r.read_text(encoding="utf-8"))) for r in refs]))

    print("=" * 72)
    print("스킬별 구성")
    print("=" * 72)
    for name, fm, body, refs in rows:
        flag = "" if body <= ROUTER_BUDGET else f"  ← 라우터 비만 (목표 {ROUTER_BUDGET})"
        print(f"\n  {name}")
        print(f"    frontmatter (상주) {fm:>6,}")
        print(f"    SKILL.md 본문      {body:>6,}{flag}")
        for rn, rt in refs:
            print(f"      references/{rn:<34s} {rt:>6,}")

    print("\n" + "=" * 72)
    print("항상 상주하는 비용")
    print("=" * 72)
    print(f"\n  frontmatter 합계: {resident:,} 토큰  (200k 컨텍스트의 {resident/200_000*100:.2f}%)")
    print("  스킬을 쓰지 않아도 매 요청에 실린다. 시스템 프롬프트라 캐시된다.")

    print("\n" + "=" * 72)
    print("호출 1회당 구조 오버헤드")
    print("=" * 72)
    print("""
  비교 기준: 참조 파일 하나를 사용자가 직접 지목해 읽히는 경우(= 구버전 방식)
  대비, 스킬로 라우팅했을 때 추가로 드는 비용.
""")
    print(f"  {'스킬':<20s} {'상주':>7s} {'라우터':>8s} {'오버헤드':>10s}")
    print("  " + "-" * 48)
    for name, fm, body, refs in rows:
        print(f"  {name:<20s} {resident:>7,} {body:>8,} {resident + body:>+10,}")

    over = [resident + body for _, _, body, _ in rows]
    print(f"\n  평균 오버헤드: {sum(over)/len(over):,.0f} 토큰 / 호출")
    print("""
  이 오버헤드로 사는 것:
    - 자동 트리거 (사용자가 파일명을 몰라도 됨)
    - 유형 판단을 모델이 수행 (구버전은 사용자가 직접 골랐음)
    - 판단 기준이 파일로 명시되어 버전 관리됨
""")

    fat = [n for n, _, b, _ in rows if b > ROUTER_BUDGET]
    if fat:
        print(f"  ⚠ 라우터 예산({ROUTER_BUDGET}) 초과: {', '.join(fat)}")
        print("    라우팅에 필요 없는 내용은 references/ 로 내린다.")
        return 1
    print(f"  ✅ 모든 라우터가 예산({ROUTER_BUDGET}) 안에 있다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
