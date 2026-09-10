# local-claude-setup

[한국어](README.md) | [English](README.en.md)

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
2. **Judgment criteria (`rules/`)** — not procedure, but what's always true: how to decide what to build, test quality, layer boundaries
3. **Task-level commands** — commit, PR creation, PR review, new-feature planning, migration checks
4. **Judgment guides (`skills/`)** — especially for refactoring, where "how far is safe" needs a clear line
5. **Automatic guardrails** — blocking protected branches, running typecheck/tests automatically

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

### 2. `.claude/rules/`

If `skills/` is procedure, this is **what stays true regardless of procedure**. Not mixing the two is the whole point.

They load at different times, and that difference is the placement rule.

| File | Loads when | Covers |
| --- | --- | --- |
| `minimal-coding.md` | always | laziness ladder, trust boundary, not building what wasn't asked |
| `git.md` | always | commits, branches, push, approval gates |
| `code-quality.md` | `**/*.ts` Read | no tautological tests, verifiable units |
| `nestjs.md` | `src/**/*.ts` Read | layer boundaries, validation, responses, external calls, naming |

**An always-resident slot costs whatever it weighs.** So the first two stay short, and file-type conventions moved down to the two `paths`-gated files. Most sessions don't write code at all.

There's a trap here. **The `paths` gate only applies when a matching file is read with the `Read` tool.** `Write` and `Edit` don't trigger it, and neither does Bash. So **a task that only creates new files can finish with no coding rules applied at all.** On top of that, `paths`-gated rules aren't inherited by subagents, so any delegation that writes code has to say "Read this rules file directly" in the delegation text.

---

### 3. `.claude/commands/`

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

### 4. `.claude/skills/`

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
  - `references/commit-message.md` — how to derive the format from history, split-commit decisions
  - `references/pr-description.md` — PR template first, the always-apply clauses, draft PR rules
  - `scripts/derive-git-convention.sh` — observes the convention from real commits and PRs, and flags what it could not settle

The reason refactoring is split into two phases is simple: bundling everything under the label "refactoring" makes "safe cleanup" and "contract change" bleed into each other. Entity changes are the same — adding a column and dropping/retyping one carry different risk. `commit-pr` splits along a different axis — not risk-by-type, but **stage of work** (commit vs. PR). Splitting by type keeps the AI from **quietly widening the scope of a change**, and it only reads the one reference file that matches the situation at hand.

---

### 5. `.claude/agents/`

Only procedures where fresh context **is the point**. An agent definition puts its name, description, and tool list into every session's system prompt, so these don't get created casually.

- `rules-check.md` — checks a given diff against `rules/` and returns **violations only**.

Cutting the role this narrow is the trick. **It doesn't fix anything, doesn't commit, and doesn't hunt for bugs.** A session that wrote the code will only confirm judgments it already made, which is why this runs in fresh context.

And **if it can't quote the sentence in `rules/` that was broken, the finding gets dropped.** A rules violation isn't a defect, so it can't be verified by tracing a failure path — quoting is the only verification available. That clause is what stops the "usually you'd want to…" scope creep that LLM reviewers drift into.

### 6. `.claude/hooks/`

This is, literally, **automatic guardrails**.

- `pre-edit-branch-check.sh`
  - blocks direct edits on `main`/`master`
- `post-edit-typecheck.sh`
  - runs `yarn typecheck` automatically after a `.ts` file is edited
- `post-edit-test.sh`
  - runs the matching test automatically after a `.spec.ts` file is edited

In other words, it doesn't stop at "writing the rule down" — the minimum validation is wired to **fire immediately after the edit**.

---

### 7. `.claude/settings.local.json`

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
| `refactoring` | 132 | 273 | +629 |
| `commit-pr` | 116 | 310 | +666 |
| `entity-migration` | 108 | 332 | +688 |

**This structure does not save tokens. It costs about 661 extra tokens per invocation.**

I'd fooled myself by comparing against a "one flat file holding every type" baseline. No such file ever existed in this repo. `refactoring-phase1.md` / `phase2.md` were **already split by type**, and naming one loaded only that one. The old setup was already progressive — a human just did the routing.

So the real difference isn't "did you split by type," it's **"does a human or the model do the routing,"** and that costs about 660 tokens per call. What it buys:

- **Auto-triggering** — you don't have to know the filename
- **The model picks the type** — previously I had to choose phase 1 vs. phase 2 myself, and choosing wrong meant proceeding under the wrong guide
- **The decision criteria live in a versioned file**

The third is what actually matters. Running a phase-2 change (one that alters the response contract) under the phase-1 guide breaks the frontend. One such incident costs far more than 660 tokens × every invocation. The 356 resident tokens are 0.18% of a 200k context and sit in the cached system prompt.

### The real problem was router bloat

Right after the restructure the routers were **610 / 580 / 365** tokens. Content with nothing to do with routing (validation steps, post-completion reporting rules, general prose) was sitting in `SKILL.md` — and `refactoring/SKILL.md`'s validation section was **verbatim duplication of what both reference files already contained**.

Pushing that down into the references got them to **310 / 273 / 332**. A router legitimately holds three things and no more: type-decision logic, output format needed regardless of type, and safety rails that must fire before a reference opens. The measurement script fails if a router exceeds 350 — the point is to catch it creeping back up.

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

## How rules get adopted

LLM configs grow if you let them. 500 lines becomes 1000, instructions start contradicting each other, and the signal from the rules that matter gets buried. So the default leans toward **removing** rules, not adding them.

**The default is deletion.** If the basis is uncertain, it's excluded rather than parked. One of two conditions has to hold.

- **(A) Something the model cannot know in principle** — facts about my environment, my preferences and the reasoning behind them, my past decisions. Adopted even with no failure case, because no amount of model improvement carries that information over.
- **(B) It corrects model behavior, and there's a reproducible failure on the current model to back it** — you have to be able to point at "the failure that happened because this line was missing" as an actual event.

I also wrote down what **doesn't count**: "it's a safety net," "seems good to have," "the original is well written," "another line references it." That last one only holds once the referencing line is itself adopted.

The test reduces to one question: **does removing this line actually cause a problem?**

There's a method for checking (B) too. Use `claude --safe-mode` to get a state with no rules, give it a task that would provoke the mistake, and see whether the mistake actually happens. If it doesn't, that rule isn't earning its place and should go.

What went in and what came out is recorded in [`ADOPTED.md`](ADOPTED.md). It isn't always-resident and isn't `paths`-gated, so it's only read when the prompts are being edited. It exists as a separate file to **stop the same rule from being revived, or re-excluded, by someone who no longer knows why**.

### Not tied to a stack

One thing I held to throughout: **separate the concern a rule targets from the tool that addresses it.**

`rules/minimal-coding.md` says "validate input at the trust boundary" and stops there, naming no library. **Where that boundary sits in this repo and what validates it** is `rules/nestjs.md`'s job — here, class-validator and `@Standard*ValidationPipe`. Move to another project and only that file changes; `minimal-coding.md` travels unchanged.

Borrowed measurements get the same treatment. A cap like "at most 3 mocks per test" comes from counting some specific repo, so carrying the number over carries no evidence with it. **The point is to count your own repo the same way, not to inherit the number.** So `code-quality.md` keeps the signal — "lots of mocks is a result, not a cause" — with no number attached.

### What I deliberately didn't build

Build out the full process and **the cost of managing the AI development process exceeds the cost of the development.** Adding one nullable field shouldn't pull in the whole planning-to-review-convergence pipeline.

- **Dev pipeline skills** (plan → implement → review-loop → ship) — these get added after the current skill set proves stable in real work.
- **A hook to cover the `paths` gap** — that `paths` only fires on `Read` is a real fact, but **I haven't observed a failure from it in this repo yet.** It goes in when I do. That's condition (B) applied to myself.
- **Document-vault integrations** — there's no such vault in this environment.

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
├─ rules/                    ← what's always true
│  ├─ minimal-coding.md      (always resident)
│  ├─ git.md                 (always resident)
│  ├─ code-quality.md        (on **/*.ts Read)
│  └─ nestjs.md              (on src/**/*.ts Read)
├─ agents/
│  └─ rules-check.md         ← checks rules in fresh context
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
         └─ derive-git-convention.sh

ADOPTED.md                   ← what went in, what came out, and why
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
