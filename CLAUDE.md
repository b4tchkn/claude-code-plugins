# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

A Claude Code plugin marketplace — a collection of plugins providing slash-command skills. No build system, no compiled output. Pure configuration and markdown.

## Architecture

```
.claude-plugin/marketplace.json    # Root marketplace registry
plugins/{name}/
  .claude-plugin/plugin.json       # Plugin metadata (name, version, description, author)
  skills/{skill-name}/SKILL.md     # Skill definition (frontmatter + instructions)
.github/workflows/
  create-release-pr.yml            # Manual trigger: bumps version, opens release PR
  publish-release.yml              # Auto trigger: tags + publishes GitHub Release on merge
```

Each skill is a single `SKILL.md` with YAML frontmatter: `name`, `description`, `argument-hint`, `allowed-tools`, and optionally `disable-model-invocation`.

## Plugins

| Plugin | Skills |
|--------|--------|
| git-toolbox | check-github-ci, create-draft-pr, semantic-commit, semantic-branch, pr-auto-update, ai-review-triage |
| qa-toolbox | create-dev-check-list-android, copy-simple-qa-cases |
| ccusage-analyzer | analyze-usage |
| claude-code-best-practice | claude-md-best-practice, settings-audit, skill-audit, subagent-audit, subagent-driven-prompt-tuning, grilling |

## Adding a New Plugin

1. Create `plugins/{name}/.claude-plugin/plugin.json`
2. Create `plugins/{name}/skills/{skill-name}/SKILL.md` for each skill
3. Register in `.claude-plugin/marketplace.json` under `plugins`

## Adding a New Skill

Create `plugins/{plugin}/skills/{skill-name}/SKILL.md`:

```yaml
---
name: skill-name
description: One-line description
argument-hint: [--flag] [positional]
allowed-tools: Bash(git *), Bash(gh *), Read, Grep
---
```

Common `allowed-tools` patterns: `Bash(git *)`, `Bash(gh *)`, `Bash(npx ccusage*)`, `Read`, `Grep`, `Glob`

## Conventions

### Commit Messages

`{type}: {description}` — Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `ci`, `release`

### Branch Naming

`{type}/{subject}` — e.g., `feat/new-skill`, `fix/pr-template`

### Release Process

1. Trigger "Create Release PR" workflow — select plugin and bump type (patch/minor/major)
2. Workflow creates `release/{plugin}/v{version}` branch, bumps versions, opens PR
3. Merging triggers "Publish Release" — creates tag `{plugin}/v{version}` and GitHub Release

### Versioning

- Each plugin has independent semver in `plugin.json`
- Root marketplace version bumps minor on every plugin release
- Tags: `{plugin}/v{version}`

### GitHub Actions

Pin all `uses:` references to a full commit SHA, not a tag. Add the exact patch version as a comment.

```yaml
# Good
- uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1

# Bad
- uses: actions/checkout@v4
```

To find the SHA for a tag: `gh api repos/{owner}/{repo}/git/ref/tags/{tag} --jq '.object.sha'`
