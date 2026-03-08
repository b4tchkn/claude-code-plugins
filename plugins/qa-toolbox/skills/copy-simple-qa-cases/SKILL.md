---
name: copy-simple-qa-cases
description: Generate QA test cases from branch diff and PR body for manual testing handoff. Use when the user wants to create test cases, QA checklist, or testing instructions for a pull request.
argument-hint: [--lang en|ja] [PR number]
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh:*), Read, Grep, Glob
---

# QA Test Case Generator

Generate concise, well-structured test cases from the current branch's code changes and PR description, then copy to clipboard.

## Execution Steps

### 1. Gather Context

Parse `$ARGUMENTS` to extract:

- **PR number**: If a numeric value is found in `$ARGUMENTS`, use it as the target PR number
- **Language flag**: Check for `--lang ja` or `--lang en`

#### If PR number is specified:

Use `gh pr` commands with the PR number to fetch context from that specific PR:

- **PR body**: !`gh pr view $PR_NUMBER --json body --jq '.body'`
- **PR diff**: !`gh pr diff $PR_NUMBER`
- **Commit messages**: !`gh pr view $PR_NUMBER --json commits --jq '.commits[].messageHeadline'`

#### If no PR number is specified:

Use the current branch's context:

- **PR body**: !`gh pr view --json body --jq '.body' 2>/dev/null || echo "No PR found"`
- **Branch diff summary**: !`git diff develop --stat 2>/dev/null || git diff main --stat 2>/dev/null || echo "No diff found"`
- **Branch diff**: !`git diff develop 2>/dev/null || git diff main 2>/dev/null || echo "No diff found"`
- **Commit messages**: !`git log develop..HEAD --oneline 2>/dev/null || git log main..HEAD --oneline 2>/dev/null || echo "No commits found"`

### 2. Analyze Changes

From the gathered context, identify:

- What functionality was changed or added
- What errors/crashes were fixed (if bug fix)
- Which screens/features are affected
- What edge cases exist

### 3. Generate Test Cases

Write test cases in **Markdown format** with the following rules:

#### Language

- Default: English
- If `$ARGUMENTS` contains `--lang ja` or Japanese text, write in Japanese

#### Format

```markdown
## Test Cases: {Brief title describing the change}

### Background

{1-2 sentences: what was changed/fixed and why}

---

### TC1: {Test case name}

- **Precondition**: {Required state before testing}
- **Steps**: {What to do}
- **Expected**: {What should happen}

### TC2: {Test case name}

- **Precondition**: {Required state before testing}
- **Steps**: {What to do}
- **Expected**: {What should happen}

...
```

#### Guidelines

- Keep each field to **1-2 sentences max** - QA engineers should be able to scan quickly
- Focus on **user-visible behavior**, not implementation details
- Include the **most critical/risky scenario** as a separate test case
- For bug fixes, always include a test case that **reproduces the original issue**
- Total test cases: typically 5-10, adjust based on scope of changes
- Do NOT include code-level details (class names, method names, variable names)
- Use plain language that a QA engineer without code context can understand

### 4. Copy to Clipboard

After generating test cases, **always** copy the full markdown output to the system clipboard using `pbcopy` (macOS) or equivalent so the user can paste it immediately.
