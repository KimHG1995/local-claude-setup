#!/usr/bin/env python3
"""저장소 instruction 소스와 스킬 호출 비용을 분리해 측정한다.

기본 모드는 ``tiktoken``의 ``o200k_base``를 사용한다. 이 값은 같은 소스를
반복 측정하기 위한 proxy이며 Claude의 실제 토큰 수, 청구량, 컨텍스트 점유량이
아니다. 의존성 없이 파일 범위만 확인하려면 ``--inventory``를 사용한다.
"""

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Optional, Sequence


REPOSITORY_ROOT = Path(__file__).resolve().parent.parent
ROUTER_BUDGET = 350
TokenCounter = Callable[[str], int]


class TokenizerUnavailable(RuntimeError):
    """요청한 proxy tokenizer를 불러올 수 없다."""


@dataclass(frozen=True)
class Measurement:
    path: Path
    label: str
    lines: int
    bytes: int
    tokens: Optional[int]


@dataclass(frozen=True)
class SkillMeasurement:
    name: str
    metadata: Measurement
    router: Measurement
    references: tuple[Measurement, ...]


@dataclass(frozen=True)
class RepositoryMeasurement:
    root: Path
    static_files: tuple[Measurement, ...]
    skills: tuple[SkillMeasurement, ...]

    @property
    def static_tokens(self) -> int:
        return sum(item.tokens or 0 for item in self.static_files)

    @property
    def skill_metadata_tokens(self) -> int:
        return sum(skill.metadata.tokens or 0 for skill in self.skills)

    @property
    def over_budget(self) -> tuple[str, ...]:
        return tuple(
            skill.name
            for skill in self.skills
            if skill.router.tokens is not None and skill.router.tokens > ROUTER_BUDGET
        )


def _split_frontmatter_text(text: str, path: Path) -> tuple[str, str]:
    if not text.startswith("---\n"):
        raise ValueError(f"frontmatter 없음: {path}")
    boundary = text.find("\n---\n", 4)
    if boundary == -1:
        raise ValueError(f"frontmatter 종료 구분자 없음: {path}")
    return text[4:boundary], text[boundary + 5 :]


def split_frontmatter(path: Path) -> tuple[str, str]:
    """SKILL.md를 frontmatter와 router 본문으로 나눈다."""
    return _split_frontmatter_text(path.read_text(encoding="utf-8"), path)


def _rule_has_paths(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        return False
    frontmatter, _ = _split_frontmatter_text(text, path)
    return re.search(r"^paths\s*:", frontmatter, re.MULTILINE) is not None


def discover_static_instruction_files(root: Path) -> list[Path]:
    """저장소에 있는 정적 상시 로드 instruction 소스만 반환한다."""
    files = [
        path
        for path in (root / "CLAUDE.md", root / ".claude" / "CLAUDE.md")
        if path.is_file()
    ]
    rules = root / ".claude" / "rules"
    if rules.is_dir():
        files.extend(
            path
            for path in sorted(rules.rglob("*.md"))
            if not _rule_has_paths(path)
        )
    return files


def _measure(
    path: Path,
    label: str,
    text: str,
    token_counter: Optional[TokenCounter],
) -> Measurement:
    return Measurement(
        path=path,
        label=label,
        lines=len(text.splitlines()),
        bytes=len(text.encode("utf-8")),
        tokens=token_counter(text) if token_counter is not None else None,
    )


def measure_repository(
    root: Path,
    token_counter: Optional[TokenCounter],
) -> RepositoryMeasurement:
    root = root.resolve()
    static_files = tuple(
        _measure(path, "전체", path.read_text(encoding="utf-8"), token_counter)
        for path in discover_static_instruction_files(root)
    )

    skills_directory = root / ".claude" / "skills"
    skills = (
        sorted(path for path in skills_directory.iterdir() if (path / "SKILL.md").is_file())
        if skills_directory.is_dir()
        else []
    )
    if not skills:
        raise FileNotFoundError(f"스킬을 찾지 못함: {skills_directory}")

    measured_skills = []
    for skill_directory in skills:
        skill_path = skill_directory / "SKILL.md"
        metadata, router = split_frontmatter(skill_path)
        references_directory = skill_directory / "references"
        reference_paths = (
            sorted(references_directory.rglob("*.md"))
            if references_directory.is_dir()
            else []
        )
        measured_skills.append(
            SkillMeasurement(
                name=skill_directory.name,
                metadata=_measure(skill_path, "frontmatter", metadata, token_counter),
                router=_measure(skill_path, "router", router, token_counter),
                references=tuple(
                    _measure(
                        reference,
                        "reference",
                        reference.read_text(encoding="utf-8"),
                        token_counter,
                    )
                    for reference in reference_paths
                ),
            )
        )

    return RepositoryMeasurement(root, static_files, tuple(measured_skills))


def load_proxy_tokenizer() -> TokenCounter:
    try:
        import tiktoken
    except ImportError as error:
        raise TokenizerUnavailable from error
    encoding = tiktoken.get_encoding("o200k_base")
    return lambda text: len(encoding.encode(text))


def _display_path(report: RepositoryMeasurement, measurement: Measurement) -> str:
    return measurement.path.relative_to(report.root).as_posix()


def print_token_report(report: RepositoryMeasurement) -> None:
    print("=" * 72)
    print("측정 범위와 해석")
    print("=" * 72)
    print("  token = tiktoken o200k_base로 센 저장소 소스 텍스트 proxy")
    print("  Claude의 실제 tokenizer, 청구량, 실제 컨텍스트 점유량이 아니다.")
    print("  runtime wrapper, system/tool prompt, user/organization 설정은 포함하지 않는다.")
    print("  agents/commands/hooks의 runtime metadata와 cache 동작, 경제성도 추정하지 않는다.")

    print("\n" + "=" * 72)
    print("저장소 정적 상시 로드 instruction 텍스트")
    print("=" * 72)
    for item in report.static_files:
        print(f"  {_display_path(report, item):<52s} {item.tokens:>7,}")
    print(f"  {'합계':<52s} {report.static_tokens:>7,}")

    print("\n" + "=" * 72)
    print("스킬 metadata 소스 추정치")
    print("=" * 72)
    for skill in report.skills:
        print(f"  {skill.name:<52s} {skill.metadata.tokens:>7,}")
    print(f"  {'합계':<52s} {report.skill_metadata_tokens:>7,}")
    print("  실제 runtime 표현이나 다른 agent metadata 전체를 뜻하지 않는다.")

    print("\n" + "=" * 72)
    print("스킬 호출 시 router + reference 소스 비용")
    print("=" * 72)
    for skill in report.skills:
        flag = (
            ""
            if skill.router.tokens <= ROUTER_BUDGET
            else f"  ← router 예산 초과 ({ROUTER_BUDGET})"
        )
        print(f"\n  {skill.name}")
        print(f"    router{'':<39s} {skill.router.tokens:>7,}{flag}")
        for reference in skill.references:
            relative = reference.path.relative_to(reference.path.parents[1]).as_posix()
            call_tokens = skill.router.tokens + reference.tokens
            print(f"    {relative:<45s} {reference.tokens:>7,}  (합계 {call_tokens:,})")

    if report.over_budget:
        print(f"\n  ⚠ router 예산({ROUTER_BUDGET}) 초과: {', '.join(report.over_budget)}")
    else:
        print(f"\n  모든 router가 예산({ROUTER_BUDGET}) 안에 있다.")


def print_inventory(report: RepositoryMeasurement) -> None:
    print("=" * 72)
    print("저장소 instruction 소스 inventory (tokenizer 미사용)")
    print("=" * 72)

    def row(measurement: Measurement, label: str) -> None:
        print(f"  {label:<52s} {measurement.lines:>6,} lines {measurement.bytes:>8,} bytes")

    print("\n정적 상시 로드 instruction")
    for item in report.static_files:
        row(item, _display_path(report, item))

    print("\n스킬 metadata / 호출 시 router, reference")
    for skill in report.skills:
        row(skill.metadata, f"{skill.name}: frontmatter")
        row(skill.router, f"{skill.name}: router")
        for reference in skill.references:
            row(reference, f"{skill.name}: {reference.path.name}")

    print(f"\nrouter token 예산 {ROUTER_BUDGET}은 inventory 모드에서 판정하지 않는다.")
    print("판정하려면 tiktoken을 설치하고 --inventory 없이 실행한다.")


def _argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--inventory",
        action="store_true",
        help="tiktoken 없이 파일별 lines/bytes만 출력한다",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=REPOSITORY_ROOT,
        help=argparse.SUPPRESS,
    )
    return parser


def main(
    argv: Optional[Sequence[str]] = None,
    tokenizer_factory: Callable[[], TokenCounter] = load_proxy_tokenizer,
) -> int:
    arguments = _argument_parser().parse_args(argv)
    try:
        if arguments.inventory:
            report = measure_repository(arguments.root, None)
            print_inventory(report)
            return 0

        try:
            token_counter = tokenizer_factory()
        except TokenizerUnavailable:
            print(
                "token proxy 측정에는 tiktoken이 필요하다. "
                "설치 후 다시 실행하거나 --inventory로 lines/bytes를 확인한다.",
                file=sys.stderr,
            )
            return 2
        report = measure_repository(arguments.root, token_counter)
    except (FileNotFoundError, ValueError) as error:
        print(error, file=sys.stderr)
        return 2

    print_token_report(report)
    return 1 if report.over_budget else 0


if __name__ == "__main__":
    sys.exit(main())
