---
name: pr-auto-update
description: Auto-update PR descriptions based on Git change analysis
argument-hint: [--pr <num>] [--dry-run] [--lang <en|ja>]
allowed-tools: Bash(git *), Bash(gh *), Read, Grep
---

# PR Auto Update

Update Pull Request descriptions based on the repository's PR template and the latest commits. Re-evaluates existing content against the latest diff: sections that still accurately describe the diff are kept as-is, sections describing removed or changed behavior are rewritten, and empty sections are filled.

## Arguments

- `--pr <number>`: Target PR number (auto-detected from current branch if omitted)
- `--dry-run`: Show generated content without updating
- `--lang <en|ja>`: Force output language

## Steps

### 1. Detect Target PR

```bash
# Auto-detect from current branch
gh pr list --head $(git branch --show-current) --json number,title,url --jq '.[0]'

# Or use specified PR number
gh pr view <number> --json number,title,url,body,labels
```

- If `--pr <number>` is specified, use that PR
- Otherwise, find the PR associated with the current branch
- If no PR is found, inform the user and stop

### 2. Load PR Template

Look up the repository's PR template in this order and use the first one found:

1. `.github/PULL_REQUEST_TEMPLATE.md`
2. `.github/pull_request_template.md`
3. `docs/PULL_REQUEST_TEMPLATE.md`
4. `PULL_REQUEST_TEMPLATE.md`

```bash
# Example
cat .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null
```

If no template exists, fall back to a minimal structure:

```markdown
## Summary

## Changes
```

### 3. Analyze Changes

```bash
# Changed files
gh pr diff <number> --name-only

# Diff content (cap at 1000 lines for large PRs)
gh pr diff <number> | head -1000

# All commits in the PR
gh pr view <number> --json commits --jq '.commits[].messageHeadline'
```

Use this information to populate template sections — not to invent sections the template doesn't define.

### 4. Generate/Update Description

#### Per-section behavior

For each template section:

- If the existing text still accurately describes the latest diff → **keep as-is**
- If the existing text describes behavior that no longer exists or has changed → **rewrite to match current state**
- If the section is empty or contains only a placeholder → **fill with generated content**

Before applying, show a section-by-section diff preview and require user confirmation.

#### Always preserved

- HTML comments (`<!-- ... -->`)
- Checklist check states (`- [x]` / `- [ ]`)
- Separators (`---`)

#### Idempotence

When regenerating a section, if the new content is semantically equivalent to the existing text, keep the existing text byte-for-byte. Do not rewrite only to change wording, order, or formatting. This applies to the whole body as well: if nothing meaningful changed, the update is a no-op and the PR body is left untouched.

#### Language detection

1. If `--lang` is specified, use that language
2. Otherwise match the existing PR body language
3. Otherwise match the majority language of recent commit messages
4. Default: English

### 5. Update PR

If `--dry-run`, print the generated body and stop.

Otherwise show the section-by-section diff and wait for user confirmation before proceeding.

```bash
# Use gh api to preserve HTML comments
# gh pr edit --body escapes <!-- --> to &lt;!-- --&gt;
gh api \
  --method PATCH \
  "/repos/{owner}/{repo}/pulls/<number>" \
  --field body="<description>"
```

### 6. Verify and Report

```bash
gh pr view <number> --json body --jq '{body: .body[:100]}'
```

Report the PR URL and a one-line summary of what changed.

## Rules

- **Follow the repo's PR template** — do not add or remove sections it doesn't define
- **Preserve unchanged text byte-for-byte** — if a section's new content is semantically equivalent to the existing text, keep the existing text. Skip the update entirely if the whole body is unchanged.
- **Preserve HTML comments, checklist states, and separators**
- **Confirm before applying** — always show a section-by-section diff preview and require user confirmation (unless `--dry-run`)
- **Use `gh api --field body=`** for the update (`gh pr edit --body` escapes HTML comments)
- **Warn on sensitive content**: alert if the diff touches secrets, credentials, or `.env` files
- **No code pushes**: this skill only updates PR metadata
