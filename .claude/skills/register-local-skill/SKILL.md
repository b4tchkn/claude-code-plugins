---
name: register-local-skill
description: Register a local skill (~/.claude/skills/{name}/SKILL.md) into this repository's plugin. Use when the user says "register this skill to a plugin", "add my local skill to the marketplace", "publish a skill I made locally", or any variant of moving a skill from ~/.claude into a plugin.
argument-hint: "[skill-name] [--plugin <plugin-name>]"
allowed-tools: Read, Write, Edit, Bash(ls *), Bash(mkdir *), Bash(cat *)
---

# Register Local Skill

Move a skill from `~/.claude/skills/` into one of the plugins in this repository.

## Steps

### 1. Identify the skill

If `skill-name` is given as an argument, use it. Otherwise list available local skills and ask the user which one to register:

```bash
ls ~/.claude/skills/
```

Read the skill file to understand what it does:

```bash
cat ~/.claude/skills/{name}/SKILL.md
```

### 2. Choose the target plugin

If `--plugin` is given, use it. Otherwise list the available plugins and ask the user:

```bash
ls plugins/
```

Present candidates with a one-line rationale for each (e.g., "git-toolbox — git/GitHub workflows", "claude-code-best-practice — configuration auditing and planning tools"). Ask which plugin fits, or whether a new one should be created.

### 3. Create the skill file

```bash
mkdir -p plugins/{plugin}/skills/{skill-name}
```

Copy the content exactly from `~/.claude/skills/{skill-name}/SKILL.md` into `plugins/{plugin}/skills/{skill-name}/SKILL.md`. Do not modify the skill body — preserve the original frontmatter and instructions verbatim.

### 4. Update CLAUDE.md

In the root `CLAUDE.md`, find the Plugins table and add `{skill-name}` to the comma-separated skills list for the target plugin.

### 5. Update README.md

Read `README.md` to understand the existing format, then:

1. In the summary table, increment the skill count for the target plugin.
2. In the plugin's `#### Skills` section, add a new entry for the skill using the same format as existing entries:
   ```
   **`/{skill-name}`** `[argument-hint if any]` — {description from SKILL.md frontmatter}
   ```
   Derive the argument hint and description directly from the skill's frontmatter.

### 6. Confirm and prompt for commit

Report what was created/updated:
- `plugins/{plugin}/skills/{skill-name}/SKILL.md` — created
- `CLAUDE.md` — updated plugins table
- `README.md` — updated skill count and added skill description

Ask the user if they want to commit now.

## Rules

- Never modify the skill content. The user already validated it locally; copy it as-is.
- Never create a new plugin unless the user explicitly requests it.
- Do not push to git; only commit if the user confirms.
