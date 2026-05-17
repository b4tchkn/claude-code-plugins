---
name: skill-audit
description: "Audit and improve Claude Code skill definitions (.claude/skills/*/SKILL.md, ~/.claude/skills/*/SKILL.md, and plugin-local skills) against official frontmatter semantics and progressive-disclosure best practices. Detects over-broad allowed-tools, missing description triggers, oversized SKILL.md bodies, invalid context/model values, and monorepo discovery mismatches; then proposes or applies concrete edits."
argument-hint: "[--dry-run] [--scope <project|user|plugin|all>] [--lang <en|ja>]"
allowed-tools: "Read, Edit, Write, Glob, Grep, Bash(git *)"
---

# Claude Code Skill Auditor & Fixer

Audit skill definitions against official frontmatter semantics and apply safe fixes. The skill performs real edits — use `--dry-run` to preview without writing.

## Arguments

- `--dry-run`: Show proposed edits without modifying files.
- `--scope <project|user|plugin|all>`: Limit scan (default: `all`).
  - `project` → `${PROJECT_ROOT}/**/.claude/skills/*/SKILL.md` (includes nested monorepo packages)
  - `user` → `~/.claude/skills/*/SKILL.md`
  - `plugin` → `${PROJECT_ROOT}/plugins/*/skills/*/SKILL.md`
- `--lang <en|ja>`: Force report language (auto-detected from the SKILL.md body otherwise).

## Best Practice Principles

Derived from the upstream `claude-code-best-practice` reference (`best-practice/claude-skills.md`, `reports/claude-skills-for-larger-mono-repos.md`) and the official Claude Code skills docs. **Verify frontmatter field names against the current official docs before fabricating a fix** — the schema evolves.

### 1. Progressive Disclosure

The skill system is designed around progressive disclosure: the `description` is always in context, the body loads only on invocation. Implications:

- **`description` should be trigger-rich.** It is the only text Claude sees before deciding to invoke. Include concrete triggers ("when X", "after Y", imperatives, example requests). Avoid abstract taglines like "Helps with code".
- **Body should be invocation-only content.** Reference material, long lists, and examples belong in sibling files under the skill directory (`REFERENCE.md`, `examples/`) — not inline.
- **Description + `when_to_use` share a 1,536-character cap.** Long combined strings are silently truncated.

### 2. Required & recommended frontmatter

- `name` — optional; defaults to the directory name. If set, must match the directory name (mismatch is the #1 "why isn't my skill loading" footgun).
- `description` — recommended (the upstream doc marks it so). Without it, auto-discovery is effectively disabled.
- `when_to_use` — optional companion to `description` for trigger phrases and examples.

### 3. `allowed-tools` — minimize

- Follows the same syntax as `settings.json` permissions (`Bash(git *)`, `Read`, `Edit`, etc.).
- Scope to the minimum the skill needs. A read-only analysis skill should not list `Write` or `Edit`.
- Missing `allowed-tools` defaults to "ask per use" — fine for rarely-invoked skills, but annoying for frequently-used ones.
- Bare `Bash` grants full shell; always prefer patterns.

### 4. `model` / `effort` / `context`

- `model` — valid values: `haiku`, `sonnet`, `opus`, full model IDs. Pinning to `haiku` for read-only discovery skills is a legitimate cost optimization.
- `effort` — `low`, `medium`, `high`, `xhigh`, `max`. `max` is Opus-4.6-only.
- `context: fork` runs the skill in an isolated subagent context. Pair with `agent: <subagent-type>` (default: `general-purpose`) when the skill's work would pollute the main context (20+ file reads, long research). Flag `context: fork` without a clear reason — it doubles the launch cost.

### 5. `paths` for auto-activation

- Accepts glob patterns (string or YAML list).
- Claude loads the skill only when working with files matching the glob. Skills with `paths` save description-budget on repos where they rarely apply.
- Use for framework-specific skills (`paths: ["**/*.tsx", "**/*.jsx"]`).
- Malformed globs (e.g., `packages/*/src/*` without `**`) can miss deeper paths — flag.

### 6. `user-invocable` / `disable-model-invocation`

- `disable-model-invocation: true` → Claude will not auto-invoke; user must type `/skill-name`.
- `user-invocable: false` → skill is hidden from the `/` menu, intended as background knowledge (e.g., for subagent preload).
- Setting both is contradictory — flag.

### 7. Monorepo discovery

Skills do **not** walk up like CLAUDE.md. Discovery paths:

1. `~/.claude/skills/*/SKILL.md` — personal, all projects
2. `${PROJECT_ROOT}/.claude/skills/*/SKILL.md` — project-level
3. `${PACKAGE}/.claude/skills/*/SKILL.md` — loaded only when files under `${PACKAGE}` are touched
4. `<plugin>/skills/*/SKILL.md` — via enabled plugins

Implications:
- A skill meant for the whole monorepo should live at the repo root, not inside one package.
- A skill in `packages/frontend/.claude/skills/` will not load when editing `packages/backend/` files — flag if the description claims to apply repo-wide.

### 8. Body length

- Keep SKILL.md bodies under ~500 lines. Beyond that, split into `SKILL.md` + `REFERENCE.md` and reference the companion file from the body.
- Front-load instructions — the model may not read to the end of a long file.

### 9. Conflicts with bundled skills

Bundled skill names: `simplify`, `batch`, `debug`, `loop`, `claude-api`.

Flag any user-defined skill with these exact names — they shadow the bundled and are almost always a mistake.

### 10. `shell` field

- Valid values: `bash` (default), `powershell`.
- `powershell` requires `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`. Flag skills that set `shell: powershell` without mentioning the env var in the body.

### 11. Anti-patterns to Flag and Fix

| Anti-pattern | Severity | Proposed fix |
|---|---|---|
| `name` ≠ directory name | critical | Rename one to match. |
| `name` shadows bundled skill (`simplify`, `batch`, `debug`, `loop`, `claude-api`) | critical | Rename. |
| Missing `description` | high | Prompt user; do not fabricate. |
| `description` + `when_to_use` over 1,536 characters | high | Move examples to the body; trim description. |
| `description` lacks concrete triggers (no verbs, no "when") | medium | Rewrite with explicit invocation cues. |
| `allowed-tools` includes `Write`/`Edit` on a read-only skill | high | Remove write tools. |
| `allowed-tools` includes bare `Bash` | medium | Replace with pattern-scoped `Bash(...)`. |
| `model` value invalid | critical | Prompt. |
| `effort: max` with non-Opus-4.6 model | medium | Remove `effort` or change `model`. |
| `context: fork` without clear rationale in body | low | Add a `Why fork?` note or remove. |
| `user-invocable: false` AND `disable-model-invocation: true` | critical | Pick one; combination makes the skill unreachable. |
| `paths:` glob syntactically suspicious (single `*` where `**` needed) | medium | Propose corrected glob. |
| `shell: powershell` without env-var note in body | low | Document the required env var. |
| SKILL.md body > 500 lines | low | Suggest extracting to `REFERENCE.md`. |
| Body consists only of a heading + empty sections | medium | Flag for rewrite. |
| Frontmatter uses unknown field | low | Flag, do not remove. |
| Duplicate `name` across project + user scope | high | Rename or delete duplicate. |
| Skill placed in `packages/*/.claude/skills/` but description claims repo-wide applicability | medium | Suggest moving to repo root `.claude/skills/`. |
| Missing or empty frontmatter (no leading `---` block) | critical | Block edits; prompt user. |

## Steps

### 1. Discover Skill Files

```bash
git rev-parse --show-toplevel
```

Glob targets per scope:
- Project: `${PROJECT_ROOT}/.claude/skills/*/SKILL.md`
- Project (nested, monorepo): `${PROJECT_ROOT}/**/.claude/skills/*/SKILL.md` (exclude `node_modules`, `.git`)
- User: `${HOME}/.claude/skills/*/SKILL.md`
- Plugin: `${PROJECT_ROOT}/plugins/*/skills/*/SKILL.md`

For each file, record: absolute path, directory name, line count, frontmatter validity.

### 2. Parse Frontmatter

Extract the YAML block between the leading `---` / `---` markers. If parsing fails, emit `critical` and skip further checks on that file.

### 3. Run Checks

Apply the anti-pattern table. For each finding record: file, field, severity, current value, proposed value, one-line rationale.

Cross-file checks:
- Collect every `name` (falling back to the directory name when absent); report duplicates within and across scopes.
- For each skill under `packages/*/.claude/skills/`, scan the body for strings like "repo-wide", "across the repository", "all packages" — flag as placement mismatch.
- Confirm `name ≡ dirname` when `name` is explicitly set.

### 4. Language Detection

Count Japanese characters in the body. `--lang` overrides. Report language does not touch YAML keys.

### 5. Present Audit Report

```
Claude Code Skill Audit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Skills scanned: 14
Findings: 8 (critical: 1, high: 2, medium: 3, low: 2)

.claude/skills/my-analyzer/SKILL.md
  [critical] name "my-analyser" ≠ directory "my-analyzer"
             → rename directory or fix frontmatter `name`
  [high]     allowed-tools includes `Edit` on a read-only skill
             → remove `Edit`, keep `Read, Grep, Glob`

plugins/git-toolbox/skills/check-github-ci/SKILL.md
  [medium]   description lacks trigger phrases
             → rewrite (e.g., "Use when CI fails. Analyzes GitHub Actions output ...")
  [low]      SKILL.md body is 612 lines
             → extract examples to REFERENCE.md

~/.claude/skills/simplify/SKILL.md
  [critical] name "simplify" shadows bundled skill
             → rename (e.g., `my-simplify`)

Proposed edits: 4 auto-fixable, 4 require user confirmation

Proceed? (y/n/edit/skip <n>/only <n,m,...>)
```

### 6. Apply Edits

Unless `--dry-run`:

1. Re-read each file before editing.
2. Update frontmatter in place — preserve key order, indentation, and trailing block.
3. **Do not auto-rename skill directories.** Directory renames may break plugin manifests, marketplace registrations, and references from commands/agents. Surface a manual-step list instead.
4. For `description` rewrites, preserve the user's original intent — prefer additive edits (prepend a trigger phrase) over full rewrites; if a full rewrite is needed, require explicit user confirmation.
5. For body extractions (large files → `REFERENCE.md`), create the companion file and replace the extracted section with a one-line pointer: `See [REFERENCE.md](REFERENCE.md) for details.`.
6. After each write, re-parse the frontmatter to confirm validity.

### 7. Verify

```bash
# List modified skills
git diff --name-only **/skills/*/SKILL.md

# Re-scan silently to confirm idempotency
```

Print a final summary:

```
Applied N edits across M files.
Manual follow-ups: K
  - rename directory `.claude/skills/my-analyser/` → `my-analyzer/` (skill won't load until dir matches)
  - update plugin manifest `plugins/foo/.claude-plugin/plugin.json` to reflect new skill name
```

## User Interaction Options

- `y` — apply all auto-fixable edits
- `n` — abort
- `edit` — revise proposed edits interactively
- `skip <n>` — skip the nth finding
- `only <n,m,...>` — apply only the specified findings

## Rules

- **Never auto-rename skill directories.** Always surface as manual step.
- **Never fabricate frontmatter fields**. If official docs disagree with a finding, official docs win; surface "verification needed".
- **Preserve the body verbatim** when editing only frontmatter.
- **Do not auto-extract large bodies** without confirmation — content ownership belongs to the skill author.
- **Respect plugin boundaries**: when editing a skill under `plugins/*/skills/`, do not touch the plugin's `plugin.json` or `marketplace.json` — surface as manual step.
- **No git operations beyond read-only queries**. Do not stage, commit, or push.
- **Idempotent**: a second run must produce zero edits.
- **Respect `--scope`**: if `user` is not in scope, never touch `~/.claude/skills/`.

## Error Handling

- Invalid YAML → `critical`, skip file edits.
- Missing frontmatter block → `critical`, skip.
- File not readable → skip, log, continue.
- Edit conflict (file changed mid-run) → abort that file, report, continue.
- Unknown frontmatter field → `low`, do not remove.

## Sources

- Upstream reference: https://github.com/shanraisshan/claude-code-best-practice/blob/main/best-practice/claude-skills.md
- Monorepo discovery report: https://github.com/shanraisshan/claude-code-best-practice/blob/main/reports/claude-skills-for-larger-mono-repos.md
- Official skills docs: https://code.claude.com/docs/en/skills
- Official bundled skills list: https://github.com/anthropics/skills/tree/main/skills
