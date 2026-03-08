---
name: pr-auto-update
description: Auto-update PR descriptions based on Git change analysis
argument-hint: [--pr <num>] [--dry-run] [--lang <en|ja>]
allowed-tools: Bash(git *), Bash(gh *), Read, Grep
---

# PR Auto Update

Automatically update Pull Request descriptions by analyzing Git changes. Preserves existing content and only fills in empty sections.

## Arguments

- `--pr <number>`: Target PR number (auto-detected from current branch if omitted)
- `--dry-run`: Show generated content without actually updating
- `--lang <en|ja>`: Force output language (`en` or `ja`)

## Steps

### 1. Detect Target PR

```bash
# Auto-detect from current branch
gh pr list --head $(git branch --show-current) --json number,title,url --jq '.[0]'

# Or use specified PR number
gh pr view <number> --json number,title,url,body,labels
```

- If `--pr <number>` is specified in `$ARGUMENTS`, use that PR
- Otherwise, find the PR associated with the current branch
- If no PR is found, inform the user and stop

### 2. Analyze Changes

```bash
# Get changed files
gh pr diff <number> --name-only

# Get diff content (limit to first 1000 lines for large PRs)
gh pr diff <number> | head -1000

# Get commit history
gh pr view <number> --json commits --jq '.commits[].messageHeadline'
```

Analyze the following dimensions:
- **File patterns**: docs, tests, CI/CD, dependencies, source code
- **Change content**: bug fixes, new features, refactoring, performance, security
- **Commit messages**: semantic prefixes (feat, fix, docs, etc.)

### 3. Generate/Update Description

#### Template priority

1. **Existing PR body**: Preserve all existing content — never modify written sections
2. **Project template**: Use `.github/PULL_REQUEST_TEMPLATE.md` structure if available
3. **Default format**: Simple `## What does this change?` format as fallback

#### Content preservation rules

- Sections with user-written content: **keep exactly as-is**
- Empty sections or placeholder comments: **fill with generated content**
- HTML comments (`<!-- ... -->`): **always preserve**
- Functional comments (e.g., Copilot review rules): **always preserve**
- Separators (`---`): **always preserve**

#### Language detection

1. If `--lang` is specified, use that language
2. Check existing PR body language
3. Check recent commit messages (50%+ Japanese → Japanese)
4. Default: English

### 4. Update PR

#### Dry-run mode

If `--dry-run` is specified, display the generated description without updating:

```
=== DRY RUN ===
Description:
<generated description>
```

#### Actual update

**Description** — Use GitHub API to preserve HTML comments:

```bash
# IMPORTANT: Use gh api with --field to avoid HTML comment escaping
# Do NOT use `gh pr edit --body` as it escapes <!-- --> to &lt;!-- --&gt;
gh api \
  --method PATCH \
  "/repos/{owner}/{repo}/pulls/<number>" \
  --field body="<description>"
```

### 5. Verify and Report

```bash
# Verify the update
gh pr view <number> --json body --jq '{body: .body[:100]}'
```

- Confirm that the description was updated correctly
- Report the PR URL and summary to the user

## Rules

### Content Preservation

- **Never modify existing content**: Do not change a single character of user-written text
- **Fill empty sections only**: Only populate placeholder/comment sections
- **Preserve all HTML comments**: `<!-- ... -->` must remain intact
- **Preserve functional comments**: Copilot review rules, bot directives, etc.
- **Backup before update**: Store the original body in case of rollback needs

### HTML Comment Handling

- **Use `gh api --field body=`** for description updates (preserves HTML comments)
- **Do NOT use `gh pr edit --body`** (escapes HTML comments)
- Avoid complex shell pipe operations that could corrupt content

### Safety

- **Recommend `--dry-run`** for first-time use on a repository
- **Warn on sensitive content**: Alert if changes include secrets, credentials, or `.env` files
- **No auto-push**: This skill only updates PR metadata — never pushes code
- **Match project style**: Follow existing PR description patterns in the repository
