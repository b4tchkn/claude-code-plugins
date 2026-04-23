# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Claude Code plugin marketplace — a collection of plugins that provide slash-command skills for Claude Code. There is no build system, package.json, or compiled output. The repository is pure configuration and markdown.

## Architecture

```
.claude-plugin/marketplace.json    # Root marketplace registry (lists all plugins)
plugins/{name}/
  .claude-plugin/plugin.json       # Plugin metadata (name, version, description, author)
  skills/{skill-name}/SKILL.md     # Skill definition (frontmatter + instructions)
.github/workflows/
  create-release-pr.yml            # Manual trigger: bumps version, opens release PR
  publish-release.yml              # Auto trigger: tags + publishes GitHub Release on merge
```

Each skill is a single `SKILL.md` file with YAML frontmatter defining `name`, `description`, `argument-hint`, `allowed-tools`, and optionally `disable-model-invocation`. The markdown body contains step-by-step instructions that Claude Code follows when the skill is invoked.

## Plugins

| Plugin | Version | Skills |
|--------|---------|--------|
| git-toolbox | 0.3.0 | check-github-ci, create-draft-pr, semantic-commit, pr-auto-update |
| qa-toolbox | 0.1.0 | create-dev-check-list-android, copy-simple-qa-cases |
| ccusage-analyzer | 0.0.0 | analyze-usage |
| claude-code-best-practice | 0.0.0 | claude-md-best-practice |

## Adding a New Plugin

1. Create `plugins/{name}/.claude-plugin/plugin.json` with metadata
2. Create `plugins/{name}/skills/{skill-name}/SKILL.md` for each skill
3. Register the plugin in `.claude-plugin/marketplace.json` under the `plugins` array

## Adding a New Skill to an Existing Plugin

Create `plugins/{plugin}/skills/{skill-name}/SKILL.md` with this structure:

```yaml
---
name: skill-name
description: One-line description
argument-hint: [--flag] [positional]
allowed-tools: Bash(git *), Bash(gh *), Read, Grep
---
```

The `allowed-tools` field restricts which tools the skill can use. Common patterns:
- `Bash(git *)`, `Bash(gh *)` — Git and GitHub CLI
- `Bash(npx ccusage*)` — External CLI tools
- `Read`, `Grep`, `Glob` — File operations

## Conventions

### Commit Messages

Conventional Commits format: `{type}: {description}`

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `ci`, `release`

### Branch Naming

`{type}/{subject}` — e.g., `feat/new-skill`, `fix/pr-template`, `docs/readme`

### Release Process

Releases are automated via GitHub Actions workflows:

1. Trigger "Create Release PR" workflow — select plugin and bump type (patch/minor/major)
2. Workflow creates branch `release/{plugin}/v{version}`, bumps `plugin.json` version and marketplace version, opens PR
3. Merging the release PR to `main` triggers "Publish Release" — creates tag `{plugin}/v{version}` and GitHub Release

### Versioning

- Each plugin has independent semver in its `plugin.json`
- The root marketplace version in `.claude-plugin/marketplace.json` bumps its minor version on every plugin release
- Tags follow the format `{plugin}/v{version}` (e.g., `git-toolbox/v0.3.0`)
