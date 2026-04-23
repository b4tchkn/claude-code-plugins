---
name: subagent-driven-prompt-tuning
description: "Tune Claude Code skills, slash commands, task prompts, CLAUDE.md sections, or code-generation prompts by dispatching unbiased subagents to execute them. Evaluates both the executor's self-report and caller-side metrics (tool_uses, duration, retries), then iterates until improvements plateau. Use after authoring or significantly revising a prompt, or when you suspect the root cause of an agent misbehaving is ambiguity on the instruction side."
argument-hint: "[--target <path>] [--scenarios <n>] [--max-iter <n>]"
allowed-tools: "Task, Read, Grep, Glob, Bash(git *)"
---

# Subagent-Driven Prompt Tuning

The author of a prompt cannot judge its quality. Instructions that feel "crystal clear" to the writer routinely trip up a fresh agent reading them for the first time. This skill provides a workflow to **dispatch unbiased subagents to actually execute the prompt, then evaluate it from both sides (executor self-report + caller-side metrics) and iterate until improvements plateau**.

> **Attribution**: This skill is adapted from [`empirical-prompt-tuning` in mizchi/chezmoi-dotfiles](https://github.com/mizchi/chezmoi-dotfiles/blob/main/dot_claude/skills/empirical-prompt-tuning/SKILL.md), rewritten to match the tone of this marketplace. The method itself is credited to the original author.

## Arguments

- `--target <path>`: Path to the prompt under test (SKILL.md, slash command, CLAUDE.md section, etc.)
- `--scenarios <n>`: Number of evaluation scenarios (default 2, recommended 2–3)
- `--max-iter <n>`: Maximum iterations (default 5; convergence criteria take priority)

## When to Use

- Immediately after authoring or significantly revising a skill / slash command / task prompt
- When an agent is not behaving as expected and you suspect ambiguity on the instruction side
- When hardening a high-stakes prompt (frequently-used skills, core automation prompts)

When NOT to use:

- One-off throwaway prompts (the evaluation cost is not worth it)
- When the goal is to reflect the author's subjective preference rather than improve success rate

## Principles

| Principle | Rationale |
|-----------|-----------|
| Always dispatch a fresh subagent | The author cannot structurally un-bias their own re-reading |
| Evaluate from both sides | Executor's qualitative feedback + caller-side metrics, both as primary signals |
| One theme per iteration | Mixing unrelated fixes makes it impossible to trace what worked |
| Freeze requirements up front | Never tune the scenarios to make the prompt look better |
| Require consecutive passes for convergence | A single successful iteration may be luck |

## Workflow

### Iteration 0: Description / Body Consistency Check (Static)

Before any dispatch, eliminate self-contradiction in the target prompt.

1. Read what the frontmatter `description` promises (triggers, use cases)
2. Read what the body actually covers
3. If there is a mismatch, reconcile the description or the body **before** iter 1

Example: the description advertises "navigation / form filling / data extraction" but the body is purely a `npx playwright test` CLI reference. A subagent will silently "re-interpret" the body to fit the description and produce a false positive — the skill appears accurate even though it does not cover the promised scope.

### Step 1: Baseline Preparation

Fix the following two artifacts up front.

- **Evaluation scenarios**: 2–3 (one median case + 1–2 edge cases). Each must reflect a realistic situation where the prompt would be applied.
- **Requirements checklist**: For each scenario, list 3–7 concrete items the output must satisfy. Accuracy % = items satisfied / total items. **Freeze this list — do not change it mid-run.**
  - Include at least **one** item tagged `[critical]` (otherwise the success judgment is vacuous)
  - Do not add or remove `[critical]` tags after the fact

### Step 2: Unbiased Reading

Have a "blank-slate" executor read the prompt. **Dispatch a fresh subagent** via the Task tool. Do not substitute self-re-reading. When running multiple scenarios in parallel, place the Agent calls in a single message.

See the "Environmental Constraints" section for what to do when dispatch is unavailable.

### Step 3: Execution

Hand the subagent a prompt that follows the **Subagent Invocation Contract** (see below). The executor produces artifacts / output and returns a self-report at the end.

### Step 4: Two-Sided Evaluation

From the returned result, record:

**Executor self-report** (extracted from the subagent's report body):

- Points of ambiguity
- Discretionary fill-ins
- Places where the template broke down

**Caller-side measurements**:

| Item | How to obtain |
|------|---------------|
| Success / failure | Pass (○) only if **all** `[critical]` items are ○. Any × or "partial" on a `[critical]` item → fail (×). Labels are binary ○/× only |
| Accuracy | ○ = full, × = 0, partial = 0.5; sum divided by total items |
| Step count | `tool_uses` from the Task tool's usage metadata. Include Read / Grep — do not exclude them |
| Duration | `duration_ms` from the Task tool's usage metadata |
| Retry count | Extracted from the subagent's self-report (caller cannot measure this) |

**On failure, append one line to the "Ambiguity" section of the report indicating which `[critical]` item dropped** (for root-cause traceability).

### Step 5: Minimal Diff

Apply the smallest possible edit that closes an ambiguity. **One theme per iteration** (related fixes are OK together; unrelated fixes go in the next iteration).

- **Before applying the edit, state explicitly which checklist item or judgment clause the edit satisfies**
- Edits derived purely from an axis name (without grounding in a specific judgment clause) often fail to move any metric (see "Edit Propagation Patterns")

### Step 6: Re-evaluate

Run Steps 2–5 again with a **fresh subagent**. Never reuse the previous one (it has already internalized the improvement). Increase parallelism only if iterations continue to produce new ambiguities.

### Step 7: Convergence Check

Stop when **two consecutive iterations** yield no new ambiguities AND metric deltas are below threshold. For high-stakes prompts, require three consecutive. See "Stopping Criteria" for details.

## Evaluation Axes

| Axis | How measured | Meaning |
|------|--------------|---------|
| Success / failure | Did the executor produce the intended artifact? (binary) | Floor |
| Accuracy | What % of requirements did the artifact satisfy? | Degree of partial success |
| Step count | Number of tool calls / decision steps | Proxy for instructional waste |
| Duration | `duration_ms` | Proxy for cognitive load |
| Retry count | How many times the executor redid the same decision | Signal of ambiguity |
| Ambiguity (self-report) | Bullet list from the executor | Qualitative improvement material |
| Discretionary fill-ins (self-report) | Decisions the prompt did not pin down | Surfaces implicit specification |

**Weighting**: qualitative signals (ambiguity, discretionary fill-ins) are primary; quantitative signals (duration, step count) are secondary. Optimizing purely for speed produces brittle, undernourished prompts.

### Qualitative Reading of `tool_uses`

Accuracy alone hides structural defects. `tool_uses` becomes informative as a **relative value across scenarios**:

- If one scenario's `tool_uses` is **3–5× higher** than others, the skill is likely **decision-tree-index shaped with weak self-containment** — the executor is being forced into a references descent
- Typical symptom: all scenarios sit at 1–3 tool uses except one at 15+. That one scenario lacks an in-skill recipe and the executor is hunting through `references/`
- Remedy: in iter 2, add a minimal inline worked example or an explicit pointer policy ("when to read `references/`") near the top of SKILL.md. `tool_uses` usually drops sharply

Even at 100% accuracy, an imbalance in `tool_uses` is sufficient grounds to start iter 2. Stopping on accuracy alone will miss structural defects.

### Edit Propagation Patterns (conservative / over-shoot / zero-shoot)

The edit → effect mapping is not linear. Pre-estimates fall into three patterns:

- **Conservative** (estimate > actual): an edit aimed at several axes only moved one. "Multi-axis aims tend to miss."
- **Over-shoot** (estimate < actual): a single structural change (e.g., command + config + expected output together) unexpectedly satisfied judgment clauses on multiple axes. "Structured combinations of information propagate across axes."
- **Zero-shoot** (estimate > 0, actual = 0): an edit inferred from an axis name failed to touch any judgment clause. "Axis names are not judgment clauses."

To stabilize estimates, **before applying the diff, have the subagent verbalize which judgment clause the edit satisfies**. Without clause-level linkage, estimates stay noisy. When introducing a new axis, specify each point's judgment clause at clause-granularity (e.g., "all items listed" → 2 points; "full minimal working config shown inline" → 2 points) so a subagent can score it unambiguously.

## Subagent Invocation Contract

The prompt handed to the executor must follow this structure. This is the input contract for two-sided evaluation.

```text
You are an executor reading <target prompt name> with no prior context.

## Target Prompt
<paste the full body of the target prompt, or specify a path to Read>

## Scenario
<one-paragraph situation for this scenario>

## Requirements Checklist (what the artifact must satisfy)
1. [critical] <item that must pass for the run to count as a pass>
2. <regular item>
3. <regular item>
...
(Judgment rules are defined once in "Step 4: Two-Sided Evaluation" of this skill. At least one [critical] item is required.)

## Task
1. Execute the scenario by following the target prompt and produce the artifact.
2. When finished, return your response in the report structure below.

## Report Structure
- Artifact: <the produced output or a summary of execution>
- Requirements: for each item, ○ / × / partial (with reason)
- Ambiguity: places in the target prompt where you got stuck or had to interpret wording (bullets)
- Discretionary fill-ins: decisions the prompt did not specify that you filled in yourself (bullets)
- Retries: how many times you redid the same decision, and why
```

The caller extracts the self-report sections and reads `tool_uses` / `duration_ms` from the Task tool usage metadata to fill in the evaluation-axis table.

## Environmental Constraints

When fresh subagent dispatch is unavailable (already running as a subagent, Task tool disabled, etc.), **do not apply this skill**.

- **Fallback 1**: Ask the user to run a separate Claude Code session to do the evaluation
- **Fallback 2**: Skip the evaluation and explicitly report `empirical evaluation skipped: dispatch unavailable` to the user
- **Not acceptable**: substituting self-re-reading (bias is structurally inescapable — the results cannot be trusted)

### Structural Review Mode

If you only want to check **textual consistency and clarity** of the skill / prompt (not empirical execution), switch explicitly into structural review mode. State in the subagent's invocation prompt: "This is structural review mode: check textual consistency rather than executing the target." The subagent then returns a static review instead of hitting the dispatch-unavailable skip. Structural review is a complement, not a substitute — it cannot be used for consecutive-pass convergence.

## Stopping Criteria

### Convergence (stop)

Two consecutive iterations satisfy **all** of:

- New ambiguity items: 0
- Accuracy delta: ≤ +3 points (e.g., 5% → 8% counts as saturation)
- Step count delta: within ±10%
- Duration delta: within ±15%

### Overfitting Check

At the convergence point, add **one previously-unused hold-out scenario** and evaluate. If accuracy drops more than 15 points from the recent mean, you have overfit: go back to baseline scenario design and add more edge cases.

### Divergence (question the design)

If three or more iterations fail to reduce new ambiguities, the prompt's design itself is likely wrong. Stop patching — rewrite the structure.

### Resource Cutoff

Stop when the importance of the prompt no longer justifies the remaining improvement cost (an explicit "ship it at 80%" call).

## Presentation Format

Record and present each iteration in this form:

```text
## Iteration N

### Changes from previous
- <one-line description of the edit>

### Results per scenario
| Scenario | Pass/Fail | Accuracy | steps | duration | retries |
|---|---|---|---|---|---|
| A | ○ | 90% | 4 | 20s | 0 |
| B | × | 60% | 9 | 41s | 2 |

### New ambiguities
- <Scenario B>: [critical] item N failed — <one-line reason>   # always include on failure
- <Scenario B>: <other finding>
- <Scenario A>: (none new)

### New discretionary fill-ins
- <Scenario B>: <what was filled in>

### Proposed next edit
- <one-line minimal edit>

(Convergence: X consecutive passes / Y more required to stop)
```

## Red Flags (Watch for Rationalizations)

| Rationalization that appears | What is actually happening |
|------------------------------|----------------------------|
| "Re-reading it myself gives the same signal" | You cannot structurally un-bias text you just wrote. Always dispatch a fresh subagent |
| "One scenario is enough" | One scenario overfits. At least 2, ideally 3 |
| "Zero ambiguities once — we're done" | Could be luck. Require two consecutive clean runs |
| "Let's fix several ambiguities in one pass" | You lose traceability. One theme per iteration |
| "Splitting every tiny fix into its own iteration" | Opposite trap. A "theme" is a semantic unit. A cluster of 2–3 related micro-fixes can go together — splitting explodes iteration count |
| "Metrics look good, ignore the qualitative feedback" | Speed gains can mean the prompt got too thin. Keep qualitative signals primary |
| "It would be faster to rewrite" | Correct only after 3+ iterations with no ambiguity reduction. Before that, it's avoidance |
| "Reuse the same subagent" | It has already absorbed the prior fix. Dispatch fresh every time |

## Common Failure Modes

- **Scenarios too easy or too hard**: neither produces signal. One median case + one edge case from real usage
- **Watching metrics only**: chasing only duration strips important explanations and makes prompts brittle
- **Too many changes per iteration**: you lose track of which edit mattered. One edit per iteration
- **Tuning scenarios to fit the fixes**: making scenarios easier so ambiguities "disappear" is the worst anti-pattern — it hollows out the evaluation

## Rules

- **Dispatch a fresh subagent every iteration**: reuse causes the executor to silently absorb prior improvements (bias)
- **Freeze the requirements checklist up front**: no additions, removals, or re-weighting mid-run
- **At least one `[critical]` item per scenario**: otherwise the pass criterion is vacuous
- **One theme per iteration**: do not bundle unrelated fixes
- **Do not apply the skill when dispatch is unavailable**: no self-re-reading fallback
- **Do not soften scenarios to fit fixes**: the single most destructive anti-pattern for this skill
