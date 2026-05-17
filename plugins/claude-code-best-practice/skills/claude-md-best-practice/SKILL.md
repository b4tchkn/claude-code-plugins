---
name: claude-md-best-practice
description: "Audit and automatically improve CLAUDE.md files based on Claude Code best practices. Scans for all CLAUDE.md files in the repository, evaluates them against established guidelines (line length, structure, monorepo loading behavior, shared vs component-specific content), reports findings, and applies concrete edits to fix issues."
argument-hint: "[--dry-run] [--path <dir>] [--lang <en|ja>]"
allowed-tools: "Read, Edit, Write, Glob, Grep, Bash(git *)"
---

# CLAUDE.md Best Practice Auditor & Fixer

Audit all CLAUDE.md files in the repository against Claude Code best practices, then automatically apply fixes. The skill performs real edits — use `--dry-run` to preview without writing.

## Arguments

- `--dry-run`: Show proposed edits without modifying files
- `--path <dir>`: Limit scan to a specific directory (default: repository root)
- `--lang <en|ja>`: Force report language (auto-detected from existing CLAUDE.md content otherwise)

## Best Practice Principles

These rules are derived from the `claude-code-best-practice` reference repository and official Claude Code documentation.

### 1. Length & Conciseness

- **Keep each CLAUDE.md under 200 lines.** Claude adheres more reliably to shorter files.
- Extract verbose sections to dedicated docs (e.g., `docs/architecture.md`) and link from CLAUDE.md.
- Remove auto-generated sections that bloat context (e.g., `<claude-mem-context>` recent activity tables that exceed ~10 lines).

### 2. Loading Behavior (Monorepo-aware)

Claude Code uses two loading mechanisms:

- **Ancestor loading (UP)**: Walks up from CWD to filesystem root at startup. All ancestor CLAUDE.md files load immediately.
- **Descendant loading (DOWN)**: Subdirectory CLAUDE.md files load **lazily** — only when Claude reads files in those subdirectories.
- **Siblings never load** into each other.

Implications for content placement:

- Root CLAUDE.md → repository-wide conventions only (coding standards, commit format, PR templates).
- Component CLAUDE.md (e.g., `frontend/CLAUDE.md`) → component-specific patterns only.
- Avoid duplicating the same guidance at root and component levels.

### 3. Structure Conventions

A healthy CLAUDE.md typically contains:

- **Repository Overview** — one-paragraph summary of what the repo is
- **Architecture / Key Components** — directory layout and critical module relationships
- **Critical Patterns** — non-obvious conventions (e.g., subagent orchestration rules)
- **Configuration Hierarchy** — if applicable
- **Workflow / Commit Rules** — project-specific git conventions
- **Documentation Pointers** — links to further reading

Hierarchical headings must not skip levels (no `##` → `####`).

### 4. Personal vs Shared

- **CLAUDE.md** (committed): team-shared instructions
- **CLAUDE.local.md** (gitignored): personal preferences and experiments
- **`~/.claude/CLAUDE.md`** (global): applies to ALL sessions
- Recommend `CLAUDE.local.md` entries in `.gitignore` when personal preferences leak into committed CLAUDE.md.

### 5. Rule Files vs CLAUDE.md

Project-specific rules that apply conditionally should live in `.claude/rules/*.md` with `paths:` YAML frontmatter for lazy loading. Avoid stuffing conditional rules into always-loaded CLAUDE.md.

### 6. Anti-patterns to Flag and Fix

- Files exceeding 200 lines
- Auto-generated activity logs bloating static context (trim `<claude-mem-context>` blocks to header-only or remove entirely from committed files)
- Duplicated content across root and component CLAUDE.md
- Skipped heading levels
- Sibling-assumption references (e.g., frontend CLAUDE.md referencing backend CLAUDE.md expecting it to be loaded)
- Absolute GitHub URLs where a relative link would work
- TODO/WIP markers left in committed instructions
- Vague directives like "follow best practices" without concrete rules
- Secrets, tokens, or personal email addresses

## Steps

### 1. Discover CLAUDE.md Files

```bash
# Respect --path if provided, otherwise scan from repo root
git rev-parse --show-toplevel
```

Use Glob to find all CLAUDE.md and CLAUDE.local.md files:

- `**/CLAUDE.md`
- `**/CLAUDE.local.md`

Record each file's absolute path, line count, and git-tracked status.

### 2. Detect Language

For each file, count Japanese characters (`[あ-ん]|[ア-ン]|[一-龯]`) to decide report language per file. `--lang` overrides.

### 3. Audit Each File

Run these checks and record violations with line numbers:

| Check | Severity | Action |
|-------|----------|--------|
| Line count > 200 | high | Propose extraction of verbose sections to `docs/` |
| `<claude-mem-context>` block > 10 lines | medium | Truncate or remove |
| Heading level skip | low | Fix by inserting or demoting heading |
| Duplicate content with ancestor CLAUDE.md | high | Remove from descendant, keep in ancestor |
| Sibling CLAUDE.md reference | medium | Replace with inline note or ancestor consolidation |
| Absolute GitHub URL to same repo | low | Convert to relative link |
| Empty section (heading with no body) | low | Remove |
| TODO/FIXME/WIP markers | medium | Flag for user review |
| Personal info (emails, tokens) | critical | Flag — do NOT auto-fix, require user confirmation |
| CLAUDE.local.md committed to git | high | Recommend adding to `.gitignore` |

Cross-file checks:

- Compare root CLAUDE.md against each descendant for duplicated paragraphs (normalize whitespace, match 3+ consecutive sentences).
- Identify sibling references (e.g., `frontend/CLAUDE.md` mentioning `backend/CLAUDE.md`).

### 4. Present Audit Report

Structure the report as:

```
CLAUDE.md Audit Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Files scanned: N
Violations found: M (critical: X, high: Y, medium: Z, low: W)

/path/to/CLAUDE.md  (245 lines)
  [high]  L1-245: File exceeds 200 lines — propose extracting "Architecture" section to docs/architecture.md
  [medium] L12-48: <claude-mem-context> block (36 lines) — propose truncating to header-only
  [low]   L89→L91: Heading skip ## → #### — propose inserting ### heading

/path/to/frontend/CLAUDE.md  (87 lines)
  [high]  L5-23: Duplicate content with root CLAUDE.md "Commit Rules" — propose removing from frontend

Proposed edits: 4
Files to modify: 2

Proceed? (y/n/edit/skip <n>)
```

### 5. Apply Edits

Unless `--dry-run`, apply each approved edit using the Edit tool. For each file:

1. Read current content
2. Apply edits in reverse line order (prevents offset drift)
3. Verify post-edit line count and structure
4. Report per-file diff summary

For extractions (e.g., large sections → external docs):

1. Create the target doc file (e.g., `docs/architecture.md`) with the extracted content
2. Replace the section in CLAUDE.md with a single-line pointer: `See [docs/architecture.md](docs/architecture.md) for architecture details.`
3. Preserve original section heading as the extracted doc's title

### 6. Verify

```bash
# Confirm no broken markdown
git diff --stat

# Show line counts after fix
wc -l $(find . -name "CLAUDE.md" -not -path "*/node_modules/*")
```

Print a summary:

```
Applied N edits across M files.
Before: total X lines. After: total Y lines.
Remaining manual-review items: [list critical/personal-info flags]
```

## User Interaction Options

At the audit report prompt:

- `y`: Apply all proposed edits
- `n`: Abort without changes
- `edit`: Revise proposed edits interactively before applying
- `skip <n>`: Skip the nth violation and apply the rest
- `only <n,m,...>`: Apply only specified violations

## Rules

- **Never auto-edit critical-severity flags** (personal info, secrets). Always require explicit user confirmation.
- **Never modify CLAUDE.md files outside the repository** unless `--path` explicitly targets them.
- **Preserve user intent**: when extracting sections, keep the original text verbatim — do not rewrite.
- **Respect gitignore**: if CLAUDE.local.md is already gitignored, leave it alone.
- **No git operations beyond read-only queries** (`git rev-parse`, `git ls-files`, `git diff`). Never commit, push, or stage on behalf of the user.
- **Idempotent**: running the skill twice on a clean repo should produce zero edits on the second run.
- **Fail loud on ambiguity**: if a file's language cannot be detected or a violation is borderline, present it to the user rather than guessing.

## Error Handling

- File read failure → skip the file, log the path, continue with remaining files
- Edit conflict (file changed mid-run) → abort that file's edits, report, continue
- Proposed extraction target already exists → prompt user for alternate filename
