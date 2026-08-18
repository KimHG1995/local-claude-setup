# local-claude-setup

[한국어](README.md) · [English](README.en.md)

A repo where I keep the rules, workflows, and guardrails I actually need when using Claude Code locally, under `.claude/`.

The core idea was shaped by two things:

- the **modular `.claude` layout** I saw in [ChrisWiles/claude-code-showcase](https://github.com/ChrisWiles/claude-code-showcase/tree/main/.claude)
- the **discipline for keeping an LLM from guessing wrong** I picked up from [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills)

I didn't copy either one as-is — I reworked both into the way I actually like to work. So this repo isn't really "a collection of good prompts." It's closer to **an operating guide for using Claude Code more consistently**.

---

## Why I built it this way

The same problems keep showing up the more I use Claude Code:

- it jumps straight into implementation without checking what it needs to check
- it touches surrounding code beyond the scope of the change
- it says "done" without actually verifying anything
- the review/planning/migration checks I do on every project have to be re-explained every time

Instead of trying to fix this with one clever prompt, **splitting the rules into role-specific files that pin down the workflow** worked better for me.

So this repo is roughly four layers:

1. **Local operating rules** — when to stop, what to ask, what's off-limits
2. **Task-level commands** — commit, PR review, new-feature planning, migration checks
3. **Judgment guides** — especially for things like refactoring, where "how far is safe" needs a clear line
4. **Automatic guardrails** — blocking protected branches, running typecheck/tests automatically

---

## Architecture

### 1. `.claude/CLAUDE.md`

This layer sits on top of the shared `AGENTS.md` and the root `CLAUDE.md` as a **local operating manual**.

It does three things, broadly:

- forces certain work to be confirmed first
- restricts certain work unless explicitly requested
- decides what validation runs by default after an edit

In other words, it's less "figure it out yourself" delegation and more **a brake and guardrail that makes the AI pause once more before acting**.

---

### 2. `.claude/commands/`

Repeated tasks are split out as slash commands.

- `new-feature.md` — reads the module structure before implementing a feature, and proposes an implementation order first
- `commit.md` — analyzes staged changes and drafts a commit message (judgment rules live in the `commit-pr` skill)
- `pr.md` — opens a draft PR from the current branch's commits, filling in the Jira ticket, commit list, and change summary (judgment rules live in the `commit-pr` skill)
- `pr-review.md` — reviews the current branch's changes against an architecture checklist
- `migration-check.md` — only reports whether an Entity change actually needs a migration

The point isn't to make Claude "just do the thing" immediately — it's to **pin down the judgment order and the output format** to some degree.

For example, `/new-feature` doesn't write code right away. It:

1. asks about whatever context is still missing
2. reads the target module's structure
3. proposes an implementation order, including where commits should split
4. waits for confirmation before starting

Speed matters, but I care more about **a predictable workflow**, so that's how this is built.

---

### 3. `.claude/skills/`

This is less a command and more **a judgment guide, split by type, that only loads what's actually needed**. Why it's shaped this way is explained separately below, under "How I Rebuilt the Skill Structure."

Every skill follows the same shape.

```text
skills/<name>/
├─ SKILL.md              ← trigger description + type decision only (no heavy content)
├─ references/
│  └─ <type>.md           ← rules + anti-pattern + template + example
└─ scripts/
   └─ <validation>.sh
```

There are three skills right now.

- **`refactoring/`** — splits refactoring into two phases.
  - `references/phase1-safe-changes.md` — changes with no frontend impact that can be applied immediately (DTO separation, Swagger cleanup, moving existing validation into class-validator)
  - `references/phase2-contract-changes.md` — response-structure standardization that needs frontend coordination (Filter / Interceptor / wrapped / paged responses)
  - `scripts/validate.sh` — typecheck → (optional) module tests → lint
- **`entity-migration/`** — splits Entity changes by risk.
  - `references/add-column.md` / `drop-or-type-change.md` / `relation-and-index.md`
  - `scripts/check-entity-diff.sh` — heuristically surfaces column/relation/index changes from the `src/entities/` diff
- **`commit-pr/`** — splits into two moments: writing a commit message and writing a PR body.
  - `references/commit-message.md` — type/scope judgment, split-commit decisions, the English-description rule (Steps 1–6)
  - `references/pr-description.md` — rules for a draft PR body that carries the Jira ticket, commit list, and change summary
  - `scripts/collect-pr-context.sh` — gathers the branch, ticket ID, commit list, and file-change stats in one shot

The reason refactoring is split into two phases is simple: bundling everything under the label "refactoring" makes "safe cleanup" and "contract change" bleed into each other. Entity changes are the same — adding a column and dropping/retyping one carry different risk. `commit-pr` splits along a different axis — not risk-by-type, but **stage of work** (commit vs. PR). Splitting by type keeps the AI from **quietly widening the scope of a change**, and it only reads the one reference file that matches the situation at hand.

---

### 4. `.claude/hooks/`

This is, literally, **automatic guardrails**.

- `pre-edit-branch-check.sh`
  - blocks direct edits on `main`/`master`
- `post-edit-typecheck.sh`
  - runs `yarn typecheck` automatically after a `.ts` file is edited
- `post-edit-test.sh`
  - runs the matching test automatically after a `.spec.ts` file is edited

In other words, it doesn't stop at "writing the rule down" — the minimum validation is wired to **fire immediately after the edit**.

---

### 5. `.claude/settings.local.json`

This file is what actually makes the structure above run.

- restricts allowed commands to a minimal set
- wires the pre/post Edit-Write hooks
- keeps open only the validation commands I actually use locally

This is less "just a config file" and more **the policy file that decides how far the AI is allowed to move on its own**.

---

## How I Rebuilt the Skill Structure (with measurements)

I used to just list files flat — `skills/refactoring-phase1.md`, `refactoring-phase2.md`. Once I started adding more skills, one thing bothered me: **these weren't real Claude Code Skills.** They were plain markdown, not a `SKILL.md` with `name`/`description` frontmatter — so they only fired when I explicitly named them in chat ("use the phase-1 refactoring guide"). Nothing made Claude reach for them on its own.

So I switched to the loading model Claude Code Skills already support — three layers, loaded progressively.

1. **Metadata (`name` + `description`)** — always resident. This is what Claude uses to decide "is this skill relevant right now."
2. **`SKILL.md` body** — loaded only once a skill triggers. Type-decision logic only, nothing heavier.
3. **`references/*.md`** — once a type is picked, exactly one reference file gets read.

### Then I actually measured it

I originally wrote this up as "token optimization." Having measured it, **that framing was wrong.** The reproduction script lives in the repo:

```bash
python3 tools/measure-skill-tokens.py
```

Results (tiktoken `o200k_base`, an approximation of Claude's tokenizer):

| Skill | Resident (frontmatter) | Router (`SKILL.md` body) | Overhead per invocation |
| --- | ---: | ---: | ---: |
| `commit-pr` | 117 | 198 | +556 |
| `refactoring` | 131 | 270 | +628 |
| `entity-migration` | 110 | 334 | +692 |

**This structure does not save tokens. It costs about 625 extra tokens per invocation.**

I'd fooled myself by comparing against a "one flat file holding every type" baseline. No such file ever existed in this repo. `refactoring-phase1.md` / `phase2.md` were **already split by type**, and naming one loaded only that one. The old setup was already progressive — a human just did the routing.

So the real difference isn't "did you split by type," it's **"does a human or the model do the routing,"** and that costs 625 tokens per call. What it buys:

- **Auto-triggering** — you don't have to know the filename
- **The model picks the type** — previously I had to choose phase 1 vs. phase 2 myself, and choosing wrong meant proceeding under the wrong guide
- **The decision criteria live in a versioned file**

The third is what actually matters. Running a phase-2 change (one that alters the response contract) under the phase-1 guide breaks the frontend. One such incident costs far more than 625 tokens × every invocation. The 358 resident tokens are 0.18% of a 200k context and sit in the cached system prompt.

### The real problem was router bloat

Right after the restructure the routers were **610 / 580 / 365** tokens. Content with nothing to do with routing (validation steps, post-completion reporting rules, general prose) was sitting in `SKILL.md` — and `refactoring/SKILL.md`'s validation section was **verbatim duplication of what both reference files already contained**.

Pushing that down into the references got them to **198 / 270 / 334**. A router legitimately holds three things and no more: type-decision logic, output format needed regardless of type, and safety rails that must fire before a reference opens. The measurement script fails if a router exceeds 350 — the point is to catch it creeping back up.

One claim did survive: **adding a type is nearly free** — one more line in the decision list, about 12 tokens. The old approach didn't grow in tokens either, but it grew the list of filenames a human had to remember, and the odds of picking right went down.

I left `.claude/commands/` alone on purpose. Commands only load when you explicitly call `/name`, so they were already lazy-loaded — no reason to wrap them in the same pattern.

Every `references/*.md` follows the same shape now: **rules → anti-pattern → template → example → validation**. Rules alone skip "why this is wrong"; an example alone skips "how this generalizes." Bundling all five means one reference file is enough to go from judgment call to implementation to verification. Validation is a real, runnable script (`scripts/*.sh`) rather than a checklist someone has to re-explain by hand every time.

The authoring convention itself — frontmatter limited to `name`/`description`, description doubling as the actual trigger phrase, handing off to the next skill just by naming it in the body — came from Anthropic's `skill-creator` conventions, not something I invented.

> Side note: my own design memo (`claude-code-orchestration.md`) sketches something bigger — a plan → auto → ship → review skill chain that carries a task from an approved plan to a draft PR without re-prompting. I only pulled the **skill-authoring conventions** from it this round, not the chain itself — that needs session task-list integration, approval gates, and subagent delegation rules of its own, and deserves to be scoped separately.

### If you're adding a new skill

Copy this shape and fill it in.

1. Write `SKILL.md` — put the phrases you'd actually say in `description`, keep the body to the type-decision table only.
2. One `references/<type>.md` per type — rules / anti-pattern / template / example / validation.
3. Add a script under `scripts/` if there's something worth automating.
4. If an existing command already encodes the same judgment table, don't copy it — point the command at the skill instead (see how `migration-check.md` now points at `entity-migration/`). Two copies of the same table always drift apart.

---

## What kind of repo this is

This repo is a little different from a typical template repo.

Rather than handing Claude one all-purpose prompt, I'd rather split things up:

- **behavioral principles go in `CLAUDE.md`**
- **repeated tasks go in `commands/`**
- **fine-grained judgment criteria go in `skills/`**
- **mistake prevention goes in `hooks/`**

So the architecture itself is less **prompt-centric** and more **workflow-centric**.

Roughly, here's what I took from each of the two references that influenced it:

- from `claude-code-showcase`
  - splitting `.claude/` into role-based folders
  - the separated operating structure of commands / skills / hooks / settings
- from `andrej-karpathy-skills`
  - the principle-first mindset that keeps an AI from jumping to conclusions
  - putting confirmation, scope limits, and validation criteria ahead of just implementing something

And what I added on top of that:

- Korean-language working context
- examples and flows tuned for backend work
- practical checkpoints like migrations, DTOs, Mappers, response formats, branch rules
- more emphasis on "where to stop" than on "automate everything unconditionally"

---

## How to use it

The usual flow looks like this.

### 1. `.claude/CLAUDE.md` sets the baseline

Before starting work, this file decides:

- what to ask about first
- how far you're allowed to modify
- what's off-limits

### 2. Repeated tasks are called as slash commands

Examples:

- `/new-feature` — plan before adding a feature
- `/migration-check` — judge whether an Entity change needs a migration
- `/pr-review` — review the whole current branch against a checklist
- `/commit` — analyze staged changes and draft a commit message
- `/pr` — open a draft PR from the current branch's commits (Jira ticket, commit list, change summary included)

### 3. Skills trigger on their own, or you call them directly

`skills/` are real Claude Code Skills, so when a situation matches a skill's `description` (refactoring, editing an Entity, etc.), it triggers on its own without being named. You can still call them explicitly:

- "go ahead with phase-1 refactoring"
- "standardize the response structure per phase-2 refactoring"
- "check whether this Entity change needs a migration" (though touching an Entity file already gets `entity-migration` to react before you say anything)

So `skills/` work less like commands and more like **a guide that switches Claude's judgment mode** — the difference from a command is that you don't have to name it every time the way you do with `/name`.

### 4. Hooks run minimal validation automatically after an edit

- editing a TS file triggers a typecheck
- editing a test file runs that test
- a protected branch blocks the edit outright

This means nobody has to keep asking "did you run the typecheck?" by hand.

---

## Principles I actually care about

In the end, this repo exists to turn the following principles into an actual workflow, not just documentation.

1. **Ask first when something is unknown**
2. **Don't touch anything beyond the scope of the task**
3. **Put planning and verification ahead of implementation**
4. **Keep safe changes and contract changes separate**
5. **Pin the local workflow down as behavior, not just as a document**

These principles trace back to the mindset I got from `andrej-karpathy-skills`, and the structural layout owes a lot to `claude-code-showcase`. But what came out the other end is really **a local guide set I reassembled my own way**.

---

## Directory structure

```text
.claude/
├─ CLAUDE.md
├─ commands/
│  ├─ commit.md
│  ├─ migration-check.md
│  ├─ new-feature.md
│  ├─ pr-review.md
│  └─ pr.md
├─ hooks/
│  ├─ post-edit-test.sh
│  ├─ post-edit-typecheck.sh
│  └─ pre-edit-branch-check.sh
├─ settings.local.json
└─ skills/
   ├─ refactoring/
   │  ├─ SKILL.md
   │  ├─ references/
   │  │  ├─ phase1-safe-changes.md
   │  │  └─ phase2-contract-changes.md
   │  └─ scripts/
   │     └─ validate.sh
   ├─ entity-migration/
   │  ├─ SKILL.md
   │  ├─ references/
   │  │  ├─ add-column.md
   │  │  ├─ drop-or-type-change.md
   │  │  └─ relation-and-index.md
   │  └─ scripts/
   │     └─ check-entity-diff.sh
   └─ commit-pr/
      ├─ SKILL.md
      ├─ references/
      │  ├─ commit-message.md
      │  └─ pr-description.md
      └─ scripts/
         └─ collect-pr-context.sh

tools/
└─ measure-skill-tokens.py   ← reproduces the measurement table above
```

---

## Wrap-up

This repo isn't really about making Claude Code "smarter." It's closer to **a guide set that makes work less shaky and less error-prone**.

Getting a good answer matters, but before that, I care more about:

- not letting it assume things carelessly
- not letting it touch places it doesn't need to
- not letting it report "done" without verification
- not letting it produce a "tidy cleanup" that ignores the team's actual context

That's roughly why this structure exists.
