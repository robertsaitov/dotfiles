---
name: deep-code-review
description: Evidence-first, multi-agent code review process for changed code. Use when reviewing diffs, commits, branches, pull requests, or when OpenCode's /review command is invoked.
---

# Deep Code Review

Find concrete regressions introduced by a change while minimizing false
positives. Diffs identify where to start; repository behavior determines
whether a finding is valid.

## Invariants

- Read-only. Never edit files, install dependencies, run project code, or alter
  Git state.
- Never run `git stash`, `git reset`, or another command that changes the
  index, worktree, refs, or repository history.
- Review the selected change, not the entire repository.
- Follow relevant `AGENTS.md`, `CONTEXT.md`, ADRs, contracts, and documented
  conventions.
- Do not open known secret files. If a diff exposes a secret, report the
  exposure without reproducing the value.
- Investigate uncertainty before reporting it. Omit anything still uncertain.
- Prefer no comment over a speculative, generic, or cosmetic comment.
- Existing tests are evidence, not proof that changed behavior is correct.

## Process

### 1. Establish the target

Use the target supplied by OpenCode's `/review` command. If invoked directly,
identify whether the target is uncommitted work, a commit, a branch comparison,
or a pull request before reviewing it.

The reviewer also supports this explicit file-filter form:

```text
/review files <path...>
```

This reviews only uncommitted staged, unstaged, and untracked changes for the
listed worktree paths. Retrieve them with `git diff -- <path...>`,
`git diff --cached -- <path...>`, and `git status --short`. Read a selected
untracked file directly. Quote paths, reject paths outside the worktree, and do
not treat `files` as a branch name. Files without uncommitted changes provide
no review target.

Record:

- Base and head states, when applicable.
- Changed and untracked paths.
- The apparent intent and observable behavior changes.
- Applicable repository instructions and nearby tests.

For pull requests, include the PR identifier in every delegated prompt so each
subagent can retrieve the same metadata and patch rather than assuming the
local checkout is the PR head.

### 2. Map behavioral change clusters

Group related edits by behavior or invariant, not merely by file. Examples:
one request flow spanning controller and service, one schema change plus its
consumers, or one configuration change plus startup logic.

For each cluster, identify likely blast radius:

- Callers and callees.
- Inputs, outputs, state transitions, and failure paths.
- Public APIs, persisted data, permissions, concurrency, and resource lifetime.
- Tests and analogous implementations.

Use one investigator for a focused change. Use parallel investigators for
independent clusters or genuinely different high-risk boundaries. Avoid
duplicating the same review through generic specialist checklists.

### 3. Investigate recursively

Start with a falsifiable bug hypothesis. Follow relevant call and data paths
until evidence confirms or rejects it. Use history only when it clarifies an
ambiguous invariant or intentional behavior.

A reportable candidate needs all of:

- **Changed cause:** a line in the target introduces or exposes the problem.
- **Reachable trigger:** a realistic input, state, environment, or call path.
- **Broken behavior:** a concrete incorrect result, failure, vulnerability, or
  explicit rule violation.
- **Missing protection:** no existing guard, contract, caller, or test makes the
  scenario impossible.
- **Actionability:** the author can address it within this change.

Do not report unrelated pre-existing defects, theoretical hardening, optional
refactors, missing tests without a behavioral risk, or style preferences not
required by repository rules.

### 4. Verify candidates adversarially

Pass plausible candidates to the verifier. The verifier must attempt to
disprove each one by reconstructing the trigger and searching for safeguards.
Only `confirmed` candidates may appear as findings. Drop `rejected` and
`uncertain` candidates.

Merge duplicates by root cause. If one defect affects several call sites,
report it once at the clearest changed line and describe the broader impact.

### 5. Synthesize

Order findings by severity, then confidence. Keep the smallest set that gives
the author all material information. Do not add praise or a generic change
summary before findings.

## Severity

- **P0 - Critical:** reliably enables severe security compromise, irreversible
  data loss, or broad production outage. Must block merge.
- **P1 - High:** causes incorrect behavior, a crash, authorization failure,
  corruption, or major regression in a realistic supported scenario. Should
  block merge.
- **P2 - Medium:** causes a limited but concrete defect, operational problem, or
  explicit maintainability-rule violation. Should be addressed, but impact is
  contained.

Do not inflate severity based on hypothetical scale or unsupported deployment
assumptions.

## Candidate Schema

Investigators return each candidate with:

```text
Title: imperative or factual, at most 80 characters
Priority: P0 | P1 | P2
Location: path:line
Changed cause: exact changed behavior
Trigger: realistic input/state/call path
Impact: observable failure or violated invariant
Evidence: relevant callers, contracts, guards, tests, or history checked
Confidence: high | medium | low
```

Only high-confidence candidates should normally reach verification.

## Final Output

Present findings first, ordered `P0`, `P1`, then `P2`:

```markdown
### [P1] Short finding title
`path/to/file.ts:42`

When <specific trigger>, <changed code> causes <observable impact>. <Concise
evidence explaining why existing safeguards do not prevent it>.
```

Each finding must stand alone and immediately explain the triggering conditions
and impact. Keep remediation directional unless a precise fix is necessary to
make the issue understandable.

If there are no confirmed findings, say:

```text
No findings.
```

Optionally add one short residual-risk or testing-gap sentence only when it is
material and specific. Do not turn omitted candidates into an "open questions"
section.
