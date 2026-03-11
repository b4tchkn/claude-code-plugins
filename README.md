# claude-code-plugins

A collection of [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugins that enhance Git workflows, QA processes, and usage analytics.

## Plugins

| Plugin | Version | Description | Skills |
|--------|---------|-------------|--------|
| [git-toolbox](#git-toolbox) | 0.3.0 | Git-related workflow automation | 4 |
| [qa-toolbox](#qa-toolbox) | 0.1.0 | QA workflow tools for test case generation | 2 |
| [ccusage-analyzer](#ccusage-analyzer) | 0.0.0 | Claude Code usage and cost analysis | 1 |

### git-toolbox

A plugin that provides various Git-related functionalities to interact with Git repositories.

#### Skills

**`/check-github-ci`** — Check GitHub Actions CI status and provide root cause analysis with fix suggestions for any failures. Retrieves PR check results, identifies failed jobs, fetches error logs, and suggests specific fixes.

**`/create-draft-pr`** `[--ja]` — Automated draft PR creation based on Git change analysis. Performs pre-flight checks, analyzes branch changes, generates PR descriptions (using templates if available), and creates draft PRs. Supports English (default) and Japanese output.

**`/semantic-commit`** `[--dry-run] [--lang <en|ja>]` — Split large changes into meaningful minimal units and commit them sequentially with semantic commit messages. Detects project conventions (CommitLint config, commit history patterns) and language preferences automatically.

**`/pr-auto-update`** `[--pr <num>] [--dry-run] [--lang <en|ja>]` — Auto-update PR descriptions by analyzing Git changes. Preserves existing content and HTML comments, only fills in empty sections. Uses GitHub API directly to avoid comment escaping issues.

### qa-toolbox

A plugin that provides QA workflow tools for test case generation and quality assurance.

#### Skills

**`/create-dev-check-list-android`** `[description]` — Generate a minimal developer self-check checklist for Android (Kotlin/Gradle) projects from git diff. Categorizes changed files (UI, ViewModel, Repository, DI, Build, etc.) and generates relevant verification checks. Copies output to clipboard.

**`/copy-simple-qa-cases`** `[--lang en|ja] [PR number]` — Generate QA test cases from branch diff and PR body for manual testing handoff. Produces structured test cases with preconditions, steps, and expected results. Copies output to clipboard.

### ccusage-analyzer

Analyze Claude Code usage and costs using the [ccusage](https://github.com/yutakobayashidev/ccusage) CLI to provide insights on token consumption and spending patterns.

#### Skills

**`/analyze-usage`** `[--monthly] [--session] [--since YYYYMMDD] [--until YYYYMMDD] [--breakdown]` — Analyze token usage and costs via ccusage CLI. Provides daily/monthly/session reports with cost summaries, cache hit rates, trend analysis, spike detection, and optimization recommendations.

## Installation

Install individual plugins using the Claude Code CLI:

```bash
# Install git-toolbox
claude plugin add --from https://github.com/b4tchkn/claude-code-plugins/tree/main/plugins/git-toolbox

# Install qa-toolbox
claude plugin add --from https://github.com/b4tchkn/claude-code-plugins/tree/main/plugins/qa-toolbox

# Install ccusage-analyzer
claude plugin add --from https://github.com/b4tchkn/claude-code-plugins/tree/main/plugins/ccusage-analyzer
```

Or install all plugins via the marketplace:

```bash
claude plugin add --from https://github.com/b4tchkn/claude-code-plugins
```

## Prerequisites

- **[GitHub CLI (`gh`)](https://cli.github.com/)** — Required by git-toolbox and qa-toolbox for PR operations and CI status checks
- **[ccusage](https://github.com/yutakobayashidev/ccusage)** — Required by ccusage-analyzer (`npm install -g ccusage` or use via `npx`)

## Release Workflow

This repository uses an automated two-stage release pipeline via GitHub Actions:

1. **Create Release PR** — Triggered manually via `workflow_dispatch`. Select a plugin and version bump type (patch/minor/major). The workflow bumps the version in `plugin.json`, updates the marketplace version, and opens a PR to `main`.
2. **Publish Release** — Triggered automatically when a release PR (branch prefix `release/`) is merged to `main`. Creates a Git tag (`{plugin}/v{version}`) and a GitHub Release with auto-generated notes.

## Contributing

Contributions are welcome! To add a new plugin or skill:

1. Create a new directory under `plugins/` following the existing structure
2. Add a `.claude-plugin/plugin.json` with plugin metadata
3. Add skills under `skills/{skill-name}/SKILL.md`
4. Register the plugin in `.claude-plugin/marketplace.json`
5. Open a PR

## License

TBD
