---
name: subagent-audit
description: "Audit and improve Claude Code subagent definitions (.claude/agents/*.md, ~/.claude/agents/*.md) against official best practices. Detects over-broad tools, missing PROACTIVELY hints, redundant 'general-qa'-style agents, conflicting permissionMode, deprecated Task(...) syntax, and invalid model aliases; then proposes or applies concrete edits."
argument-hint: "[--dry-run] [--scope <project|user|all>] [--lang <en|ja>]"
allowed-tools: "Read, Edit, Write, Glob, Grep, Bash(git *)"
---

# Claude Code Subagent Auditor & Fixer

Audit subagent definitions against official frontmatter semantics and apply safe fixes. The skill performs real edits — use `--dry-run` to preview without writing.

## Arguments

- `--dry-run`: Show proposed edits without modifying files.
- `--scope <project|user|all>`: Limit scan (default: `all`).
  - `project` → `${PROJECT_ROOT}/.claude/agents/*.md`
  - `user` → `~/.claude/agents/*.md`
- `--lang <en|ja>`: Force report language (auto-detected from the agent file body otherwise).

## Best Practice Principles

Derived from the upstream `claude-code-best-practice` reference (`best-practice/claude-subagents.md`) and the official Claude Code subagent docs. **Verify frontmatter field names against the current official docs before fabricating a fix** — the schema evolves quickly.

### 1. Feature-specific, not role-shaped

Prefer `payment-flow-reviewer` over `general-qa`. Prefer `auth-middleware-refactorer` over `backend-engineer`. Role-shaped agents dilute context and compete with built-in defaults. Flag agents whose `name` matches generic roles (`backend-engineer`, `frontend-dev`, `qa`, `reviewer` without a feature qualifier).

### 2. Required frontmatter

`name` and `description` are required. Everything else is optional, but:

- `description` should describe **when to invoke**, not what the agent is. Start with a verb.
- Include the literal word **`PROACTIVELY`** (or a localized equivalent) when the agent is intended for auto-invocation.
- `name` must be lowercase-with-hyphens, unique across user + project scopes.

### 3. Minimize `tools` allowlist

The default is "inherit all tools" — this is often too broad. Agents that only read code should not have `Write`, `Edit`, `Bash`. Flag:

- Exploration/research agents (description contains "explore", "research", "analyze", "review") that list `Write` or `Edit`.
- Agents listing `Bash` without a pattern — `Bash` inherits full shell access.
- `Agent(*)` or `Task(*)` (spawn-any) unless the agent is explicitly an orchestrator.
- `Task(agent_type)` — deprecated alias for `Agent(agent_type)`. Still works but flag as `low`.

### 4. `model` field

Accepted values: `sonnet`, `opus`, `haiku`, a full model ID (e.g., `claude-opus-4-6`), or `inherit`. Anything else is a typo.

Guidance:
- Heavy-lifting (code generation, architecture) → `opus` / `sonnet`.
- Fast read-only exploration → `haiku`.
- If unset, defaults to `inherit` — acceptable and often preferable; pinning locks cost.

### 5. `permissionMode`

Valid: `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan`.

- `bypassPermissions` on any non-trivial agent is a red flag — it disables user prompts entirely. Never recommend.
- `acceptEdits` is fine for agents that edit a single well-defined scope.
- `plan` makes the agent read-only — but if `tools` also includes `Write`/`Edit`, that is a contradiction.

### 6. `isolation: "worktree"`

For agents that run long refactors or parallel experiments, `isolation: "worktree"` isolates filesystem changes. Suggest adding it when an agent's description mentions "refactor", "experiment", or "parallel" and the tool list includes `Write`/`Edit`.

### 7. `skills` preloading

`skills` injects **full skill content** at startup (not lazy-loaded). Over-stuffing the skills list bloats the agent's initial context and reduces headroom. Flag agents with more than 5 preloaded skills — ask whether lazy discovery would suffice.

### 8. Other fields

- `maxTurns` — sanity cap for long-running agents. If missing on an agent with `PROACTIVELY` invocation, suggest a cap.
- `background: true` — should pair with `maxTurns`; unbounded background agents are a footgun.
- `effort` — `max` is Opus-4.6-only. Flag `effort: max` combined with `model: sonnet`/`haiku`.
- `color` — cosmetic; flag only if invalid (outside the documented palette).
- `hooks` scoped to the agent — validate `matcher` strings (same rules as settings hooks).
- `initialPrompt` — only meaningful when this agent runs as the main session agent. If the agent is only used as a subagent (spawned), `initialPrompt` is dead.

### 9. Conflicts with built-in agents

Built-in agent names: `general-purpose`, `Explore`, `Plan`, `statusline-setup`, `claude-code-guide`.

Flag any user-defined agent with these exact names — they shadow the built-in and are almost always a mistake.

### 10. Anti-patterns to Flag and Fix

| Anti-pattern | Severity | Proposed fix |
|---|---|---|
| `name` missing or not lowercase-hyphen | critical | Rewrite `name`. |
| `description` missing | critical | Prompt the user; do not fabricate. |
| `name` shadows built-in (`general-purpose`, `Explore`, etc.) | critical | Rename. |
| Role-shaped name (`backend-engineer`, `qa`, `reviewer` without qualifier) | medium | Suggest feature-specific rename. |
| Description lacks action verb / invocation trigger | medium | Rewrite with explicit "when to invoke". |
| Description missing `PROACTIVELY` for auto-invoked agent | low | Add keyword. |
| `permissionMode: "bypassPermissions"` | critical | Remove / replace with `acceptEdits` or `default`. |
| `tools` includes `Write`/`Edit` on a read-only/exploration agent | high | Remove write tools. |
| `tools` includes bare `Bash` on a non-devops agent | high | Replace with pattern-scoped `Bash(...)`. |
| `tools` uses deprecated `Task(agent_type)` syntax | low | Rewrite as `Agent(agent_type)`. |
| `tools` includes `Agent(*)` on a non-orchestrator agent | medium | Narrow to specific agent names. |
| `model` value not a valid alias / ID | critical | Prompt for correct value. |
| `permissionMode: "plan"` combined with `Write`/`Edit` in tools | high | Remove write tools or switch mode. |
| `effort: "max"` on non-Opus-4.6 model | medium | Remove `effort` or switch model. |
| More than 5 preloaded `skills` | low | Ask user whether lazy discovery suffices. |
| `background: true` without `maxTurns` | medium | Suggest a `maxTurns` cap. |
| Duplicate agent `name` across user + project scopes | high | Rename or delete duplicate. |
| Body empty / boilerplate only | medium | Flag for rewrite. |
| Body over 300 lines | low | Suggest extraction of references to a companion doc. |
| Invalid frontmatter YAML | critical | Block edits; prompt user. |

## Steps

### 1. Discover Agent Files

```bash
git rev-parse --show-toplevel
```

Glob targets per scope:
- `${PROJECT_ROOT}/.claude/agents/**/*.md`
- `${HOME}/.claude/agents/**/*.md`

For each file, record: absolute path, line count, git-tracked status, frontmatter validity.

### 2. Parse Frontmatter

Extract the YAML block between the leading `---` / `---` markers. If parsing fails, emit `critical` and skip further checks on that file.

### 3. Run Checks

Apply the anti-pattern table. For each finding record: file, field, severity, current value, proposed value, one-line rationale.

Cross-file checks:
- Collect all `name` values; report duplicates within and across scopes.
- Collect all `description` strings; flag near-duplicates (Levenshtein similarity > 0.9) — often signals redundant agents.

### 4. Language Detection

Count Japanese characters in the file body. `--lang` overrides. Report language is independent of the YAML keys — never translate keys.

### 5. Present Audit Report

```
Claude Code Subagent Audit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Agents scanned: 12
Findings: 9 (critical: 1, high: 2, medium: 3, low: 3)

.claude/agents/backend-engineer.md
  [medium]  name "backend-engineer" is role-shaped
            → suggest splitting into feature-specific agents (e.g., `auth-refactorer`, `ingest-pipeline-debugger`)
  [high]    tools includes bare `Bash`
            → narrow to `Bash(npm *)`, `Bash(git *)`

.claude/agents/code-reviewer.md
  [critical] permissionMode: "bypassPermissions"
             → change to `acceptEdits` or remove
  [low]      tools includes `Task(Explore)` (deprecated alias)
             → rewrite as `Agent(Explore)`

~/.claude/agents/general-purpose.md
  [critical] name "general-purpose" shadows built-in agent
             → rename (e.g., `my-general-helper`)

Proposed edits: 5 auto-fixable, 4 require user confirmation

Proceed? (y/n/edit/skip <n>/only <n,m,...>)
```

### 6. Apply Edits

Unless `--dry-run`:

1. Re-read each file before editing.
2. Update frontmatter YAML in place — preserve key order and indentation; do not re-emit the whole block.
3. For name renames, **do not** automatically update references in other files (CLAUDE.md, settings `agent`, workflow command definitions) — those are cross-file and error-prone. Instead, surface a follow-up task list: `Manual step: update references to "backend-engineer" in <files>`.
4. After each write, re-parse the frontmatter to confirm validity.

### 7. Verify

```bash
# List modified agents
git diff --name-only .claude/agents/

# Re-scan silently to confirm idempotency
```

Print a final summary:

```
Applied N edits across M files.
Manual follow-ups: K
  - rename reference: `backend-engineer` appears in .claude/settings.json (agent:) and commands/review.md
```

## User Interaction Options

- `y` — apply all auto-fixable edits
- `n` — abort
- `edit` — revise proposed edits interactively
- `skip <n>` — skip the nth finding
- `only <n,m,...>` — apply only the specified findings

## Rules

- **Never auto-rename agents** without confirmation — other files may reference the name.
- **Never fabricate frontmatter fields**. If the official docs disagree with a finding, the official docs win; surface a "verification needed" note.
- **Never auto-remove agents** even when `name` shadows a built-in — rename or flag, never delete.
- **Preserve the body verbatim** when editing only frontmatter.
- **No git operations beyond read-only queries**. Do not stage, commit, or push.
- **Idempotent**: a second run must produce zero edits.
- **Respect `--scope`**: if `user` is not in scope, never touch `~/.claude/agents/`.

## Error Handling

- Invalid YAML → `critical`, skip file edits.
- File not readable → skip, log, continue.
- Edit conflict (file changed mid-run) → abort that file, report, continue.
- Unknown frontmatter field → flag as `low`, do not remove (may be a newer field the skill is unaware of).

## Sources

- Upstream reference: https://github.com/shanraisshan/claude-code-best-practice/blob/main/best-practice/claude-subagents.md
- Official subagents docs: https://code.claude.com/docs/en/sub-agents
- Agent-teams best practice: https://github.com/shanraisshan/claude-code-best-practice/blob/main/implementation/claude-agent-teams-implementation.md
