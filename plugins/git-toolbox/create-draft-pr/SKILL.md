---
name: create-draft-pr
description: Automated Draft PR creation based on Git change analysis
argument-hint: [--ja]
allowed-tools: Bash(git *), Bash(gh *)
---

# PR Create

Automate Pull Request creation through Git change analysis for an efficient PR workflow.

## Arguments

- If `$ARGUMENTS` contains `--ja`: Write PR title and description in **Japanese**
- Otherwise (default): Write PR title and description in **English**

## Steps

### 1. Pre-flight Checks

```bash
# Verify current branch (must not be develop/main)
git branch --show-current

# Check for uncommitted changes
git status
```

- If on develop or main branch, prompt the user to create a new branch
- If there are uncommitted changes, confirm with the user

### 2. Create Branch (if needed)

```bash
# Follow naming convention: {type}/{subject}
git switch develop && git pull
git switch -c feat/feature-name
```

### 3. Analyze Changes

```bash
# List commits
git log --oneline develop..HEAD

# Review changes
git diff develop...HEAD --stat
git diff develop...HEAD
```

### 4. Generate PR Description

1. Check if `.github/PULL_REQUEST_TEMPLATE.md` exists
2. If template exists, preserve its structure entirely and only fill in empty sections
3. If no template exists, create description in default format
4. Preserve all HTML comments (`<!-- ... -->`) as-is
5. Write in English (default) or Japanese based on arguments

### 5. Create Draft PR

```bash
# Create Draft PR using GitHub CLI
# Pass --body via HEREDOC to preserve HTML comments
gh pr create --draft --base develop --title "Title" --body "$(cat <<'EOF'
PR body
EOF
)"
```

### 6. Post-Creation Guidance

- Report the PR URL to the user
- Inform that the PR can be marked as Ready for Review with `gh pr ready` after CI passes

## Rules

### Template Handling

- **Existing PR description**: Fully preserve any pre-existing content
- **Fill empty sections only**: Populate placeholder sections with change details
- **Preserve HTML comments**: Keep `<!-- ... -->` intact
- **Preserve separators**: Maintain `---` and other structural elements

### Branch Naming Convention

```
{type}/{subject}

Types:
- feat/     ... New feature
- fix/      ... Bug fix
- refactor/ ... Refactoring (no functionality change)
- chore/    ... Build, CI, dependencies, maintenance

Examples:
- feat/user-profile
- fix/login-error
- refactor/api-client
- chore/update-dependencies
```

**How to determine the prefix:**

1. Analyze commit history and changes to determine the nature of the work, then select the appropriate prefix
2. If uncertain, ask the user
3. If the base branch is `release/`, prefer `fix/`

### Commit Messages

```
{type}: {description}

Examples:
- feat: implement user authentication API
- fix: resolve login error
- docs: update README
```

### Principles

1. **Always start as Draft**: All PRs are created in Draft state
2. **Incremental quality**: Draft creation -> CI check -> Ready for Review
3. **Use templates**: Always use `.github/PULL_REQUEST_TEMPLATE.md` if it exists

### Preserving HTML Comments

GitHub CLI (`gh pr edit`) may auto-escape HTML comments. Countermeasures:

1. Use HEREDOC to pass `--body` content
2. Avoid complex pipe operations or redirections
3. Never strip HTML comments; preserve the template exactly as-is
