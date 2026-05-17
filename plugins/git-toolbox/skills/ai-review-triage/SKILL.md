---
name: ai-review-triage
description: Triage AI/bot review comments on a PR and report whether each one is worth acting on. Reads comments from the current branch's PR (or a specified PR number), filters out human comments, then classifies each AI/bot comment as actionable, optional, or dismissable with reasoning.
argument-hint: [<pr-number>]
allowed-tools: Bash(gh *), Bash(git *), Read, Grep, Glob
---

# AI Review Triage

Analyze review comments left by AI code reviewers (CodeRabbit, Copilot, Gemini Code Assist, Codex, SonarCloud, etc.) on a Pull Request and report how valid each one is. Human-authored comments are excluded.

This skill only produces a judgment report. It does not modify code, post replies, or resolve threads.

## Arguments

- `<pr-number>` (optional positional): Target PR number. If omitted, the PR associated with the current branch is used.

## Steps

### 1. Resolve target PR

```bash
# If argument is a number, use it directly
# Otherwise auto-detect from current branch
gh pr list --head "$(git branch --show-current)" --json number,url,headRefName --jq '.[0]'
```

If no PR is found for the current branch and no argument was given, stop and inform the user.

### 2. Collect all review comments

Fetch three distinct comment surfaces — they live in different GitHub APIs:

```bash
# PR-level issue comments (general conversation tab)
gh api "repos/{owner}/{repo}/issues/<pr>/comments" --paginate

# Inline review comments (attached to diff lines)
gh api "repos/{owner}/{repo}/pulls/<pr>/comments" --paginate

# Review summaries (the body of a submitted review)
gh api "repos/{owner}/{repo}/pulls/<pr>/reviews" --paginate
```

For each comment record preserve: `id`, `user.login`, `user.type`, `body`, `path` (if inline), `line` / `original_line` (if inline), `html_url`, `in_reply_to_id` (if any), `created_at`.

### 3. Filter to AI/bot authors only

Keep a comment if any of the following hold for its author:

- `user.type == "Bot"` (GitHub App accounts)
- `user.login` ends with `[bot]` (e.g. `github-actions[bot]`, `coderabbitai[bot]`)
- `user.login` matches a known AI reviewer (case-insensitive, allowing `-` / `_` variants):
  - `coderabbitai`, `coderabbit-ai`
  - `copilot-pull-request-reviewer`, `github-copilot`, `copilot`
  - `gemini-code-assist`, `gemini`
  - `codex`, `chatgpt-codex-connector`
  - `sonarcloud`, `sonarqubecloud`, `sonar`
  - `codeball`, `codescene`, `deepsource`, `snyk-bot`, `sweep-ai`, `qodo-merge-pro`

Drop everything else — including comments made by the PR author or other humans, even if the body looks AI-generated.

If zero AI/bot comments remain, report that and stop.

### 4. Group replies under their parent

Some AI tools (notably CodeRabbit) post a parent comment plus threaded follow-ups. Use `in_reply_to_id` to collapse each thread into one entry: the parent body is the primary claim, replies are context.

Skip pure-noise posts with no actionable content: greetings ("On it!"), walkthrough tables of contents, status updates ("🧠 Analyzing..."), collapsible summary sections with no concrete finding. If a CodeRabbit comment contains both a walkthrough section *and* specific findings, keep only the findings.

### 5. Assess each comment

For every remaining AI comment, load the cited file/lines and judge the claim against the actual code. Do not trust the comment — verify.

```bash
# Inline comments point at a specific path+line. Read the surrounding context.
# Example: if comment targets src/foo.ts:42, read a window around line 42.
```

Classify into exactly one of:

- **`actionable`** — the finding is correct and fixing it has clear value (real bug, security issue, definite regression, broken API usage, incorrect logic).
- **`optional`** — the finding is technically valid but low-impact or stylistic (nit, naming, minor refactor suggestion, preference-level improvement).
- **`dismissable`** — the finding is wrong, already addressed elsewhere in the diff, based on a misreading of the code, a hallucinated API, or duplicates another comment.

For each comment, capture:
- `verdict`: one of the three above
- `confidence`: `high` / `medium` / `low` — how sure you are about the verdict after reading the code
- `reason`: one or two sentences grounded in what the code actually does, not in what the comment claims
- `suggested_action`: concrete next step (e.g. "fix nil check at src/foo.ts:42", "reply explaining why current behavior is intentional", "ignore")

When confidence is `low`, say so explicitly rather than guessing.

### 6. Render the report to the CLI

Print a single Markdown report to stdout. No file writes, no PR updates.

```
# AI Review Triage — PR #<num> <title>

<url>

Scanned N AI/bot comments from: <comma-separated reviewer logins>
  Actionable: A    Optional: O    Dismissable: D

---

## 🔴 Actionable (A)

### 1. <reviewer> — <path>:<line>   [confidence: high]
<short quote of the claim, trimmed to ~1 line>

**Why it's valid:** <one-sentence reason grounded in the code>
**Suggested action:** <concrete next step>
**Link:** <html_url>

---

## 🟡 Optional (O)

### 1. <reviewer> — <path>:<line>   [confidence: medium]
...

---

## ⚪ Dismissable (D)

### 1. <reviewer> — <path>:<line>   [confidence: high]
<short quote>

**Why it's not valid:** <one-sentence reason>
**Link:** <html_url>
```

Rules for the report:
- Order each section by descending confidence, then by file path.
- For non-inline comments (PR-level or review summaries), show `PR-level` instead of `<path>:<line>`.
- Keep each entry to ≤4 lines of prose. Long AI comments get truncated with `…`.
- If a bucket is empty, omit its section entirely.
- End with a one-line summary: `Recommendation: address N actionable items; the rest can be deferred or ignored.`

## Rules

- **Read-only.** Never post replies, resolve threads, edit the PR, or push code. This skill only reports.
- **Humans are out of scope.** Do not classify, summarize, or even mention human-authored comments in the output.
- **Verify before judging.** For every inline comment, read the file at the referenced line before deciding. A comment's claim is not evidence.
- **No hallucinated file references.** If a comment points at a line that no longer exists in the current diff (e.g. code was already changed), mark it `dismissable` with reason "already addressed" rather than inventing context.
- **Respect confidence.** If verifying would require running the code or understanding context you don't have, mark `confidence: low` and say what would be needed to decide.
- **Token discipline.** For very large PRs, cap the inline-comment body quote at ~200 chars and skip re-reading the same file region twice.
