# local-claude-setup

[한국어](README.md) | [English](README.en.md)

A **template** holding the rules, workflows, and guardrails I want when using Claude Code, organized under `.claude/`. This repo isn't a running project. It exists so `.claude/` can be dropped onto other projects.

Two things shaped the idea:

- the **modular `.claude` layout** from [ChrisWiles/claude-code-showcase](https://github.com/ChrisWiles/claude-code-showcase/tree/main/.claude)
- the **discipline for keeping an LLM from guessing wrong** from [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills)

Neither came over as-is. I reworked both into how I actually like to work, so this is less "a collection of good prompts" and more **an operating guide for where to stop and what to ask first**.

---

## Why I built it

The same problems keep recurring the more I use Claude Code.

- It jumps straight to implementation without checking what it needs to check
- It touches code beyond the scope of the change
- It reports "done" without verifying anything
- The review, planning, and migration checks I do on every project have to be re-explained each time

Rather than fixing this with one clever prompt, **splitting the rules into role-specific files that pin down the workflow** worked better for me. So this is workflow-centric, not prompt-centric.

---

## How to apply it

Copy `.claude/` into the target project root, then adapt the items below. **Delete what you don't use.** If keeping things becomes the default, it turns into a pile of rules that no longer fit.

If `.claude/` already exists, compare it first and merge only the selected files. The template uses Bash, Git, `jq`, and Python 3.9 or later; project checks require Yarn and the project's `typecheck`/`test` scripts. Hook commands resolve from `${CLAUDE_PROJECT_DIR}`. Configure the receiving project's ignore rules if this setup is intended to remain local.

If the project shares instructions through `AGENTS.md`, import it with `@AGENTS.md` from the root `CLAUDE.md`. Merely naming the file or stating precedence does not load it. After setup, inspect `/context` for loaded instructions and `/hooks` for registered hooks.

### Must change

| File | What to change |
| --- | --- |
| `CLAUDE.md` | owner, branch pattern, Jira URL, frequently used commands, per-module notes |
| `rules/nestjs.md` | **an example in its entirety.** Rewrite it for the target project's layers and validation |
| `rules/code-quality.md` | set `paths` to that project's extensions. Currently `**/*.ts` |
| `hooks/*.sh` | package manager and commands. Currently `yarn typecheck`, `yarn test` |
| `settings.local.json` | allowed commands. Open them one at a time, as needed |
| `commands/*.md` | ticket notation and paths. Currently `KDS-XXXX`, `src/entities/` |

`rules/minimal-coding.md` and `rules/git.md` are stack-independent and mostly travel unchanged.

### Worth taking as-is

The value here is the **placement method**, not the rule text.

1. Splitting slots by when they load
2. The adopt criteria (A)/(B) and "the default is deletion"
3. The skill shape: `SKILL.md` decides the type, the content lives in `references/`
4. `rules-check`'s role definition: doesn't fix, doesn't hunt bugs, drops anything it can't quote

---

## Structure

Claude Code lets you put prompts in several slots, and each loads at a different time. That difference is the placement rule.

| Slot | Loads when | Holds |
| --- | --- | --- |
| `CLAUDE.md` | every session | what's true in every session: prohibitions, confirmation gates, personal context |
| `rules/` (no `paths`) | every session | judgment criteria that hold regardless of file type |
| `rules/` (with `paths`) | on `Read` of a match | conventions needed only when touching that file type |
| `commands/` | on `/name` | procedure and output format for repeated work |
| `skills/` | automatically when it fits, or called directly | picks a type and opens only that reference |
| `agents/` | when called as a subagent | procedures where fresh context is the point |

**An always-resident slot costs whatever it weighs.** So `minimal-coding.md` and `git.md` stay short, and file-type conventions moved down behind `paths`. Most sessions don't write code at all.

There's a trap. **The `paths` gate only fires when a matching file is read with the `Read` tool.** `Write` and `Edit` don't trigger it, and neither does Bash. So a task that only creates new files can finish with no coding rules applied. On top of that, `paths`-gated rules aren't inherited by subagents, so any delegation that writes code has to say "Read this rules file directly."

---

## Skill shape

Every skill has the same shape.

```text
skills/<name>/
├─ SKILL.md              ← trigger description + type decision only
├─ references/
│  └─ <type>.md           ← rules, anti-pattern, template, example, validation
└─ scripts/
   └─ <validation>.sh
```

Three are included. Treat all of them as examples.

- **`refactoring/`** — separates changes preserving request and response contracts (phase 1) from changes to accepted inputs, conversions, responses, or other contracts (phase 2)
- **`entity-migration/`** — separates Entity changes by risk. Adding a column and dropping one aren't the same risk
- **`commit-pr/`** — prioritizes explicit conventions and PR templates, then fills gaps **from history for the requested task.** It asks only about unresolved items with insufficient evidence

Splitting by type means only the relevant references are read. The intended benefits are automatic triggering and explicit classification. Token savings depend on the comparison baseline and the references actually loaded. The earlier figure of about 660 extra tokens per invocation was a static `o200k_base` estimate for one revision, not measured Claude usage or billing.

**A `SKILL.md` body stays under 350 `o200k_base` tokens.** A router holds the type decision, the output format needed every time, and checks needed before opening references. The tool enforces this cap and separately reports `CLAUDE.md`, unconditional rules, estimated skill metadata, and invocation bodies and references. Check actual loading and usage through `/context` and runtime usage reports. The [validation contract](docs/validation-contract.md) documents scope and commands.

---

## How rules get added and removed

LLM configs grow if you let them. 500 lines becomes 1000, instructions start contradicting each other, and the signal from the rules that matter gets buried. So the default leans toward **removing**, not adding.

**The default is deletion.** If the basis is uncertain, it's excluded rather than parked. One of two conditions has to hold.

- **(A) Something the model cannot know in principle** — my environment, my preferences and their reasoning, my past decisions. Adopted even with no failure case
- **(B) It corrects model behavior and has a reproducible failure on the current model behind it** — you have to point at "the failure that happened because this line was missing" as an actual event

What doesn't count is also written down: "it's a safety net," "seems good to have," "the original is well written," "another line references it." The last only holds once the referencing line is itself adopted.

It reduces to one question: **does removing this line actually cause a problem?**

**Behavioral evaluation of (B) happens on the receiving side.** This repository regression-tests its hooks and scripts, but project-specific rules must be evaluated on representative work. Hold the code, task, model, and tool configuration constant; compare runs with only the rule under study removed against runs retaining it. Use multiple cases and repeated runs, recording failures and regressions. One run without a failure does not establish that a rule is unnecessary. `claude --safe-mode` also disables skills, hooks, MCP, memory, and other customizations, so use it to diagnose the whole setup, not to isolate one rule's effect.

What went in and what came out is recorded in [`ADOPTED.md`](ADOPTED.md). It isn't always-resident and isn't `paths`-gated, so it's only read when editing prompts. It exists separately to **stop the same rule from being revived, or removed again, by someone who no longer knows why**.

### Not tied to a stack

Separate the concern a rule targets from the tool that addresses it.

`minimal-coding.md` says "validate input at the trust boundary" and names no library. Where that boundary sits and what validates it is `nestjs.md`'s job. Move projects and only `nestjs.md` changes.

Borrowed measurements get the same treatment. A cap like "at most 3 mocks per test" came from counting some specific repo, so carrying the number over carries no evidence. **The point is to count your own repo the same way, not to inherit the number.**

### Deliberately not built

Build out the full process and **the cost of managing the AI development process exceeds the cost of the development.** Adding one nullable field shouldn't pull in the whole planning-to-review pipeline.

- Dev pipeline skills (plan → implement → review-loop → ship). Added once the current three prove stable in real work
- A hook covering the `paths` gap. No failure from it has been observed yet. It goes in when one is

---

## Directory structure

```text
.claude/
├─ CLAUDE.md                  ← always resident. prohibitions and gates
├─ rules/
│  ├─ minimal-coding.md       (always)
│  ├─ git.md                  (always)
│  ├─ code-quality.md         (on **/*.ts Read)
│  └─ nestjs.md               (on src/**/*.ts Read, example)
├─ agents/
│  └─ rules-check.md          ← checks rules in fresh context
├─ commands/
│  ├─ commit.md
│  ├─ pr.md
│  ├─ pr-review.md
│  ├─ migration-check.md
│  └─ new-feature.md
├─ hooks/
│  ├─ common.sh               ← input, repository discovery, JSON feedback
│  ├─ pre-edit-branch-check.sh
│  ├─ post-edit-typecheck.sh
│  └─ post-edit-test.sh
├─ settings.local.json
└─ skills/
   ├─ refactoring/            (SKILL.md + references/ + scripts/)
   ├─ entity-migration/
   └─ commit-pr/

ADOPTED.md                    ← what went in, what came out, and why
docs/validation-contract.md   ← hook/helper contracts and verification scope
tests/                        ← regression tests using temporary repositories
tools/measure-skill-tokens.py ← inventories resident text and checks router cap
```

---

## Wrap-up

This isn't a config that makes Claude Code smarter. It's closer to **a guide set that makes the work less shaky and less error-prone**.

Getting a good answer matters, but first:

- don't let it assume carelessly
- don't let it touch places it doesn't need to
- don't let it report "done" without verification
- don't let it produce a "tidy cleanup" that ignores the team's actual context

Roughly that's why it exists. It wasn't built to be copied verbatim, so adapt it to your own project.
