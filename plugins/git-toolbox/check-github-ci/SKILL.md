---
name: check-github-ci
description: Check GitHub Actions CI status and provide root cause analysis with fix suggestions for any failures.
allowed-tools: Bash(gh *), Bash(git *), Read, Grep
---

# Steps

1. Run `gh pr checks` to retrieve the CI status of the current PR
2. Analyze the results:
   - All passed: Report success briefly
   - Failures present: Identify the failed job names and reasons
   - Pending: Report that checks are still running
3. If any jobs have failed:
   - Run `gh run view <run-id> --log-failed` to retrieve the error logs
   - Analyze the root cause of the error
   - Suggest a specific fix
4. Report the results to the user

# Output Format

```
## CI Check Results

- Passed: N
- Failed: N
- Pending: N
- Skipped: N

### Failed Checks (only if applicable)

**Job name**: Error summary
- Cause: ...
- Suggested fix: ...
```

# Notes

- Assumes `gh` CLI is installed and authenticated
- If failure logs are large, extract only the relevant sections
- If no PR exists, inform the user accordingly
