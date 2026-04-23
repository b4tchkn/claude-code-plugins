---
name: settings-audit
description: "Audit and improve Claude Code settings files (.claude/settings.json, .claude/settings.local.json, ~/.claude/settings.json) against official best practices. Detects missing attribution configuration, bloated permission allowlists, insecure deny-rule gaps, deprecated keys, and ill-scoped hooks; then proposes or applies concrete edits."
argument-hint: "[--dry-run] [--scope <project|user|local|all>] [--lang <en|ja>]"
allowed-tools: "Read, Edit, Write, Glob, Grep, Bash(git *), Bash(jq *), Bash(cat *), Bash(test *)"
---

# Claude Code Settings Auditor & Fixer

Audit Claude Code settings files against official best practices and apply safe fixes. The skill performs real edits — use `--dry-run` to preview without writing.

## Arguments

- `--dry-run`: Show proposed edits without modifying files.
- `--scope <project|user|local|all>`: Limit scan to one tier (default: `all`).
  - `project` → repo `.claude/settings.json`
  - `local` → repo `.claude/settings.local.json`
  - `user` → `~/.claude/settings.json`
- `--lang <en|ja>`: Force report language (auto-detected from existing CLAUDE.md otherwise).

## Best Practice Principles

Derived from the upstream `claude-code-best-practice` reference (`best-practice/claude-settings.md`) and the official Claude Code settings docs.

### 1. Use settings.json, not CLAUDE.md, for harness-enforced behavior

Settings is deterministic; CLAUDE.md is hint-level. Prefer `attribution.commit: ""` over "NEVER add Co-Authored-By" in CLAUDE.md. Flag CLAUDE.md lines that duplicate what a settings key already enforces.

### 2. Settings Hierarchy (precedence, highest → lowest)

1. Managed settings (organization, cannot be overridden)
2. Command line arguments
3. `.claude/settings.local.json` (personal, git-ignored)
4. `.claude/settings.json` (team-shared, committed)
5. `~/.claude/settings.json` (user global)

Implications:
- Team-shared rules go in `.claude/settings.json`. Personal rules go in `settings.local.json`.
- `settings.local.json` **must** be git-ignored.
- Array settings like `permissions.allow` are **concatenated and deduplicated** across scopes — duplicating an entry across tiers is noise.
- `deny` rules have highest safety precedence and cannot be overridden by lower-priority `allow`/`ask`.

### 3. Permission Hygiene

- **Avoid broad allowlists** like `Bash(*)` / `Edit(*)` / `Write(*)` in project settings. They nullify the permission system. Prefer narrow patterns: `Bash(npm run *)`, `Bash(git *)`.
- **Secrets must be denied** explicitly: at minimum `Read(.env)`, `Read(./secrets/**)`, `Read(**/*credentials*)`.
- **Destructive ops belong in `ask`**, not `allow`: `Bash(rm *)`, `Bash(git push *)`, `Bash(git reset --hard*)`.
- **Bash word-boundary trap**: `Bash(ls *)` (space) matches `ls -la` but not `lsof`; `Bash(ls*)` (no space) matches both. Flag missing spaces where they introduce unintended broad matches.
- **Duplicate rules across scopes**: the same string in user + project + local settings is redundant.
- **`:*` deprecation**: the legacy `Bash(npm:*)` suffix is deprecated; prefer `Bash(npm *)`.

### 4. Attribution Must Be Explicit

- `attribution.commit` and `attribution.pr` are deterministic. If the user wants no AI attribution in commits, set `attribution.commit: ""`.
- `includeCoAuthoredBy` is **deprecated** — replace with `attribution`.

### 5. Hooks Configuration

- `hooks` scoped in `settings.json` runs on the host. Every `type: "command"` hook should have a resolvable path — relative paths break when launched from another directory. Prefer `${CLAUDE_PLUGIN_ROOT}/...` inside plugins.
- Hook `matcher` strings must match an existing event/tool — typos silently fail.
- Prefer narrow matchers (e.g., `Bash` for `PreToolUse`) over wildcards that fire on every tool call.

### 6. Model / Effort / Agent

- `model: "default"` is the sanest default. Pinning to a concrete alias (`opus`) across the team forces everyone onto the same cost profile — confirm intent.
- `agent` sets the default main-conversation agent; ensure the referenced agent actually exists in `.claude/agents/`.
- `availableModels` restricts `/model` — if the team is on a budget, pin this.

### 7. MCP Configuration Hygiene

- `enableAllProjectMcpServers: true` auto-approves every server in `.mcp.json`. On public/shared repos this is a supply-chain risk — prefer `enabledMcpjsonServers: ["known-server"]`.
- An MCP server listed in `enabledMcpjsonServers` that no longer exists in `.mcp.json` is dead config.

### 8. Anti-patterns to Flag and Fix

| Anti-pattern | Severity | Proposed fix |
|---|---|---|
| `.claude/settings.local.json` not in `.gitignore` | critical | Add `.claude/settings.local.json` to `.gitignore`. |
| Secrets-like paths missing from `deny` (`.env`, `./secrets/**`, `**/*credentials*`, `**/*.pem`) | critical | Insert into `permissions.deny`. |
| `Bash(*)` or bare `*` in `allow` | high | Replace with narrow patterns; list the user's current usage and propose a minimal allowlist. |
| `includeCoAuthoredBy` present (deprecated) | medium | Replace with `attribution.commit`. |
| `attribution` missing when CLAUDE.md contains "Co-Authored-By" preference | medium | Add explicit `attribution.commit`. |
| Duplicate `permissions.allow` entries across user + project | low | Keep in the broadest applicable scope; remove duplicates from narrower scopes. |
| `hooks[].hooks[].command` path does not resolve | high | Flag; suggest `${CLAUDE_PLUGIN_ROOT}` or absolute path. |
| `hooks[].matcher` references unknown event / tool | medium | Flag for user review. |
| Destructive `Bash(rm *)` / `Bash(git push*)` in `allow` | high | Move to `ask`. |
| `enableAllProjectMcpServers: true` on a repo with `.mcp.json` tracked in git | high | Replace with explicit `enabledMcpjsonServers` allowlist. |
| Reference to `agent:` name that is not present in `.claude/agents/` | medium | Flag; suggest existing agent or remove. |
| Invalid JSON / trailing commas | critical | Block edits until fixed. |
| `$schema` missing on non-managed settings | low | Add `"$schema": "https://json.schemastore.org/claude-code-settings.json"`. |
| Deprecated `Bash(foo:*)` suffix | low | Rewrite to `Bash(foo *)`. |

## Steps

### 1. Discover Settings Files

Resolve target paths based on `--scope`:

```bash
git rev-parse --show-toplevel   # project root (may fail outside a repo; handle gracefully)
```

Candidates:
- `${PROJECT_ROOT}/.claude/settings.json`
- `${PROJECT_ROOT}/.claude/settings.local.json`
- `${HOME}/.claude/settings.json`

For each candidate, record: existence, line count, JSON validity, git-tracked status.

### 2. Parse JSON Safely

Use `jq '.' <file>` to validate. On parse error, abort that file and emit a `critical` finding; do not attempt string-level edits.

### 3. Run Checks

Apply the anti-pattern table in order. For each violation, record:

- file path
- JSON path (e.g., `permissions.allow[3]`)
- severity
- current value
- proposed value (or `null` for removal)
- explanation (one line)

Cross-file checks:
- Diff `allow` arrays between user + project + local; report duplicates.
- Detect stale `enabledMcpjsonServers` entries by reading `.mcp.json` if present.
- Detect missing `agent` target by listing `.claude/agents/*.md`.
- Read repo `.gitignore`; confirm `settings.local.json` is ignored.

### 4. Language Detection

Count Japanese characters in the nearest CLAUDE.md. `--lang` overrides. Use the detected language for the report only; never translate JSON keys.

### 5. Present Audit Report

```
Claude Code Settings Audit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Files scanned: 3
Violations: 7 (critical: 1, high: 3, medium: 2, low: 1)

/path/to/.claude/settings.json
  [critical] .gitignore missing `.claude/settings.local.json`
             → add line to .gitignore
  [high]     permissions.allow[2] = "Bash(*)"
             → replace with ["Bash(npm run *)", "Bash(git *)"]
             rationale: bare wildcard nullifies permission system
  [high]     permissions.allow[5] = "Bash(rm *)"
             → move to permissions.ask
  [medium]   attribution.commit missing; CLAUDE.md line 42 says "no Co-Authored-By"
             → add `"attribution": {"commit": ""}`

~/.claude/settings.json
  [medium]   `includeCoAuthoredBy` (deprecated)
             → remove, use `attribution.commit` instead
  [low]      permissions.allow[1] = "Bash(npm:*)" (deprecated suffix)
             → rewrite as "Bash(npm *)"

Proposed edits: 5 (auto-fixable), 2 (require user confirmation)

Proceed? (y/n/edit/skip <n>/only <n,m,...>)
```

### 6. Apply Edits

Unless `--dry-run`:

1. Re-read the file immediately before editing (avoid drift).
2. Edit JSON by round-tripping through `jq` to preserve key ordering and formatting where possible; if `jq` is unavailable, fall back to the Edit tool with exact string matches.
3. Never collapse nested formatting or strip comments (Claude Code settings support `//` line comments and `/* */` block comments — preserve them).
4. After each write, re-run `jq '.' <file>` to validate.
5. For `.gitignore` edits, append on a new line; do not rewrite the file.

### 7. Verify

```bash
# Re-validate every modified file
jq '.' .claude/settings.json
jq '.' .claude/settings.local.json
jq '.' ~/.claude/settings.json

# Show diff summary
git diff --stat .claude/
```

Print a final summary:

```
Applied N edits across M files.
Remaining items requiring manual review: K
  - [medium] hooks.PreToolUse[0].command does not resolve — suggest ${CLAUDE_PLUGIN_ROOT}/...
```

## User Interaction Options

At the audit prompt:

- `y` — apply all proposed edits
- `n` — abort without changes
- `edit` — revise proposed edits interactively before applying
- `skip <n>` — skip the nth violation and apply the rest
- `only <n,m,...>` — apply only the specified violations

## Rules

- **Never auto-edit critical-severity `allow`/`deny` rules** without explicit confirmation. Permissions directly affect what Claude can do — require `y`.
- **Never widen permissions automatically**. Only propose narrowing (moves into `ask`/`deny`, removal of `Bash(*)`, etc.) as auto-fix candidates.
- **Preserve comments and formatting** — round-trip through `jq` only when safe; otherwise use targeted Edit.
- **Respect managed settings**: if a file under `/Library/Application Support/ClaudeCode/`, `/etc/claude-code/`, or `C:\Program Files\ClaudeCode\` is detected, **report only, never edit**. Managed settings are IT-controlled.
- **No git operations beyond read-only queries** (`git rev-parse`, `git ls-files`, `git check-ignore`). Do not stage, commit, or push.
- **Idempotent**: a second run on a clean config must produce zero edits.
- **Fail loud on ambiguity**: if a permission pattern is borderline (e.g., `Bash(git *)` is broad but conventional), present it rather than guessing.
- **Verify existence before referencing**: `agent` targets, `enabledMcpjsonServers` entries, and hook command paths must be checked against the filesystem. If unverified, mark as "verification needed" — do not fabricate fixes.

## Error Handling

- Invalid JSON → emit `critical` finding, skip edits on that file.
- File not readable → skip, log, continue.
- `jq` unavailable → fall back to Edit-tool patches with exact string matches; warn the user in the report.
- Edit conflict (file changed mid-run) → abort that file's edits, report, continue with others.

## Sources

- Upstream reference: https://github.com/shanraisshan/claude-code-best-practice/blob/main/best-practice/claude-settings.md
- Official settings docs: https://code.claude.com/docs/en/settings
- Official permissions docs: https://code.claude.com/docs/en/permissions
- Official hooks docs: https://code.claude.com/docs/en/hooks
