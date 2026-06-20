---
name: semantic-branch
description: Create a semantically named branch from current changes or a given description
argument-hint: "[--dry-run] [--lang <en|ja>] [description]"
allowed-tools: "Bash(git *), Bash(echo * | pbcopy)"
---

# Semantic Branch

Analyze current changes or a user-provided description and create a semantically named branch following `{type}/{subject}` convention.

## Arguments

- `--dry-run`: Show proposed branch name without creating the branch
- `--lang <language>`: Force subject language (`en` or `ja`)
- `[description]`: Optional free-text description of the intended work (used instead of analyzing changes)

## Steps

### 1. Gather Context

If a description argument is provided, skip to Step 3.

Otherwise, analyze current state:

```bash
# Uncommitted changes
git diff HEAD --name-status
git diff HEAD --stat

# Staged changes
git diff --cached --name-status

# Untracked files
git status --porcelain
```

### 2. Classify Changes

Group files to identify the dominant type and subject:

1. **Change type**: Determine the primary conventional commit type (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `perf`, `style`, `build`)
2. **Subject**: Derive a short kebab-case slug (2–5 words) describing what the changes do

```bash
# Identify top-level directories involved
git diff HEAD --name-only | cut -d'/' -f1-2 | sort | uniq

# Detect language of recent commits for lang auto-detection
git log --oneline -20 --pretty=format:"%s" | grep -cE '[あ-ん]|[ア-ン]|[一-龯]'
```

### 3. Detect Language

1. If `--lang` flag given, use it
2. Else if 50%+ of recent 20 commits contain Japanese characters → Japanese mode
3. Default: English

In Japanese mode, subject is written in romaji-style English kebab-case (branch names must be ASCII).

### 4. Detect Existing Branch Conventions

Check merged branch names to infer the project's naming pattern:

```bash
# Branches merged into the default branch (most reliable signal)
git log --merges --pretty=format:"%s" -50 | grep -oE "Merge (pull request|branch) '[^']+'" | grep -oE "'[^']+'" | tr -d "'"

# Fallback: all remote branch names sorted by recency
git branch -r --sort=-committerdate | head -30
```

Analyze the results:

1. Extract the naming pattern (e.g., `type/subject`, `type-subject`, `username/type/subject`)
2. If 3+ merged branches share a consistent pattern → use that pattern
3. Otherwise fall back to `{type}/{subject}`

### 5. Propose Branch Name

Present the proposed name to the user:

```
Proposed Branch Name:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  feat/user-authentication

Type   : feat
Subject: user-authentication

Create this branch? (y/n/edit):
```

- `y`: Create branch and switch to it
- `n`: Cancel
- `edit`: Accept user-provided name and create it

If `--dry-run` is set, skip the prompt and copy the proposed name to the clipboard instead:

```bash
echo -n "<branch-name>" | pbcopy
```

Then print: `Copied to clipboard.`

### 6. Execute

```bash
# Create and switch to the new branch
git checkout -b <branch-name>
```

### 7. Verify

```bash
git branch --show-current
```

Confirm the new branch is active.

## Branch Name Format

```
{type}/{subject}
```

- **type**: One of the standard conventional commit types
- **subject**: Lowercase kebab-case, 2–5 words, no special characters

### Examples

| Situation | Branch |
|-----------|--------|
| New login feature | `feat/user-login` |
| Fix null pointer in parser | `fix/parser-null-pointer` |
| Update CI pipeline | `ci/update-pipeline` |
| Refactor auth module | `refactor/auth-module` |
| Add unit tests for API | `test/api-unit-tests` |

## Rules

- **No auto-push**: Never run `git push` automatically
- **ASCII only**: Branch names must be ASCII (no Japanese characters)
- **Kebab-case subject**: Lowercase, hyphen-separated, no underscores or spaces
- **Max 50 chars**: Keep total branch name under 50 characters
- **Project conventions first**: If existing branches follow a different pattern, match it
