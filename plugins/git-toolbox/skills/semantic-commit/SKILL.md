---
name: semantic-commit
description: Split large changes into meaningful minimal units and commit with semantic messages
argument-hint: [--dry-run] [--lang <en|ja>]
allowed-tools: Bash(git *)
---

# Semantic Commit

Split large changes into meaningful minimal units and commit them sequentially with semantic commit messages. Uses only standard git commands with no external tool dependencies.

## Arguments

- `--dry-run`: Show proposed commit splits without actually committing
- `--lang <language>`: Force commit message language (`en` or `ja`)

## Steps

### 1. Analyze Changes

```bash
# Get all changes
git diff HEAD --name-status
git diff HEAD --stat
```

- Detect "large changes": 5+ files, 100+ lines, multiple feature areas, or mixed types (feat + fix + docs)
- If changes are small and cohesive, commit as a single unit

### 2. Classify Changed Files

Group files by:

1. **Feature boundary**: Files belonging to the same feature (e.g., `src/auth/` → authentication)
2. **Change type**: Tests only → `test:`, docs only → `docs:`, config only → `chore:`
3. **Dependencies**: Related files (model + migration, component + styles)
4. **Size**: Keep each commit under 10 files

```bash
# Analyze by directory structure
git diff HEAD --name-only | cut -d'/' -f1-2 | sort | uniq

# Analyze by change type
git diff HEAD --name-status | while read status file; do
  case $status in
    A) echo "$file: new" ;;
    M) echo "$file: modified" ;;
    D) echo "$file: deleted" ;;
    R*) echo "$file: renamed" ;;
  esac
done
```

### 3. Detect Project Conventions

Check commit message conventions in this priority order:

1. **CommitLint config** (highest priority): Search for `commitlint.config.*`, `.commitlintrc.*`, or `package.json` commitlint section
2. **Existing commit history**: Analyze recent 50-100 commits for patterns
3. **Project type**: Detect from `package.json`, `Cargo.toml`, `pom.xml`, etc.
4. **Conventional Commits standard** (fallback)

```bash
# Search for CommitLint config
find . -maxdepth 1 -name "commitlint.config.*" -o -name ".commitlintrc.*" | head -1

# Analyze existing commit patterns
git log --oneline -50 --pretty=format:"%s" | grep -oE '^[a-z]+' | sort | uniq -c | sort -nr
```

### 4. Detect Language

Determine commit message language:

1. Check CommitLint config for `subject-case: [0]` (indicates Japanese)
2. Analyze recent 20 commits — if 50%+ contain Japanese characters → Japanese mode
3. Check README.md language
4. Default: English

```bash
# Count Japanese commits
git log --oneline -20 --pretty=format:"%s" | grep -cE '[あ-ん]|[ア-ン]|[一-龯]'
```

### 5. Display Commit Splits

Display the computed split to the user for visibility, then proceed to commit without asking for approval. (In `--dry-run` mode, stop here without committing.)

```
Commit Splits:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Commit 1/3
Message: feat: implement user registration and login
Files:
  • src/auth/login.ts
  • src/auth/register.ts
  • src/auth/types.ts

Commit 2/3
Message: test: add authentication tests
Files:
  • tests/auth.test.ts

Commit 3/3
Message: docs: add authentication documentation
Files:
  • docs/authentication.md
```

### 6. Execute Sequential Commits

```bash
# Reset staging area
git reset HEAD

# For each commit group:
# 1. Stage only the group's files
git add <file1> <file2> ...

# 2. Verify staged files
git diff --staged --name-only

# 3. Commit with generated message
git commit -m "$(cat <<'EOF'
<type>: <description>
EOF
)"
```

### 7. Post-Commit Verification

```bash
# Verify all changes are committed
git status --porcelain

# Show created commits
git log --oneline -n 10 --graph
```

## Conventional Commits Format

```
<type>: <description>

[optional body]

[optional footer(s)]
```

**Scope is prohibited.** Do not use `<type>(<scope>):` form (e.g., `feat(auth):`, `fix(api):`). Always use `<type>:` only.

### Standard Types

**Required:**

- `feat`: New feature (user-visible functionality)
- `fix`: Bug fix

**Optional:**

- `build`: Build system or external dependency changes
- `chore`: Other changes (no release impact)
- `ci`: CI configuration changes
- `docs`: Documentation-only changes
- `style`: Code style changes (whitespace, formatting, semicolons)
- `refactor`: Code changes without bug fix or feature addition
- `perf`: Performance improvements
- `test`: Adding or modifying tests

### Breaking Changes

Breaking changes are not supported by this skill. Do not use the `!` marker (e.g., `feat!:`). If a change is breaking, describe it in the commit body instead.

## Error Handling

- On pre-commit hook failure: Retry up to 2 times, incorporating auto-fixes
- On interruption: Detect and offer to resume from last successful commit
- After completion: Verify no uncommitted changes remain

## Rules

- **No auto-push**: Never run `git push` automatically
- **No branch creation**: Commit on the current branch
- **No approval prompt**: Do not ask the user to confirm the proposed splits. Display the plan and proceed to commit directly (use `--dry-run` if a preview without committing is desired)
- **No scope, no breaking marker**: Always use `type: description` format. Never include `(scope)` or `!` in commit messages (e.g., use `feat:` not `feat(docs):` or `feat!:`)
- **Project conventions first**: Always respect existing CommitLint config and commit patterns (except scope and breaking marker — both are always disallowed by this skill)
- **One logical change per commit**: Each commit should represent a single cohesive change
- **Separate tests**: Test files should be in separate commits from implementation
- **Backup recommended**: Suggest `git stash` before processing important changes
