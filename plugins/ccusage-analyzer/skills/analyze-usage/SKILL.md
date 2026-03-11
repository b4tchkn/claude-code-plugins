---
name: analyze-usage
description: Analyze Claude Code usage and costs using ccusage CLI. Provides daily/monthly reports with cost summaries, trend analysis, and optimization insights.
argument-hint: [--monthly] [--session] [--since YYYYMMDD] [--until YYYYMMDD] [--breakdown]
allowed-tools: Bash(npx ccusage*)
---

# Usage & Cost Analyzer

Analyze Claude Code token usage and costs via ccusage CLI, providing actionable insights on spending patterns and optimization opportunities.

## Arguments

- `--monthly` — Show monthly aggregated report (default: daily)
- `--session` — Show session-level breakdown
- `--since YYYYMMDD` — Start date filter (e.g., `--since 20260301`)
- `--until YYYYMMDD` — End date filter (e.g., `--until 20260310`)
- `--breakdown` — Include per-model cost breakdown
- No arguments — Show recent daily report

## Steps

### 1. Parse Arguments

Parse `$ARGUMENTS` to determine:

- **Report type**: `daily` (default), `monthly` (if `--monthly`), or `session` (if `--session`)
- **Date range**: Extract `--since` and `--until` values if present
- **Breakdown**: Whether `--breakdown` is specified

### 2. Execute ccusage

Build and run the appropriate ccusage command:

```bash
# Base command pattern
npx ccusage <report-type> --json [--since YYYYMMDD] [--until YYYYMMDD]
```

- Daily report: `npx ccusage daily --json`
- Monthly report: `npx ccusage monthly --json`
- Session report: `npx ccusage session --json`
- Add `--since` / `--until` flags if date filters were specified

If the command fails, inform the user that ccusage may not be installed and suggest running `npm install -g ccusage` or using `npx ccusage` directly.

### 3. Analyze Results

Parse the JSON output and compute:

- **Total cost** (USD) and **total tokens** (input + output)
- **Cache hit rate**: cached read tokens / total input tokens
- **Per-period breakdown**: cost and token counts for each day/month/session
- **Peak usage**: identify the highest-cost period
- **Average cost** per period
- **Spike detection**: flag periods where cost exceeds 2x the average
- **Model breakdown** (if `--breakdown`): cost and token usage per model

### 4. Output Report

Format the analysis as markdown with the following structure:

```markdown
## Usage Report ({report-type}: {date-range})

### Summary

| Metric | Value |
|--------|-------|
| Total Cost | $X.XX |
| Total Tokens | X,XXX,XXX |
| Cache Hit Rate | XX.X% |
| Peak Day/Month | YYYY-MM-DD ($X.XX) |
| Average Cost/Day | $X.XX |

### Breakdown

| Date | Input Tokens | Output Tokens | Cache Read | Cost |
|------|-------------|---------------|------------|------|
| ... | ... | ... | ... | $X.XX |

### Model Breakdown (if --breakdown)

| Model | Input Tokens | Output Tokens | Cost | Share |
|-------|-------------|---------------|------|-------|
| ... | ... | ... | $X.XX | XX% |

### Insights

- {Trend observations: increasing/decreasing/stable}
- {Spike alerts if any periods exceed 2x average}
- {Cache efficiency assessment}
- {Optimization recommendations}
```

## Insights Generation Guidelines

Provide actionable insights based on the data:

- **Cache efficiency**: If cache hit rate < 50%, suggest reviewing project structure for better cache utilization
- **Cost spikes**: Highlight days/sessions with unusually high costs and note what might cause them
- **Model usage**: If multiple models are used, note cost differences and suggest model selection optimization
- **Trend**: Note if costs are trending up/down over the period

## Error Handling

- If `npx ccusage` is not available, inform the user and suggest installation
- If no data is found for the specified date range, report that clearly
- If JSON parsing fails, show the raw output and explain the issue

## Notes

- Requires ccusage CLI (`npm install -g ccusage` or use via `npx`)
- ccusage reads from local Claude Code JSONL log files
- Cost calculations are estimates based on public API pricing
