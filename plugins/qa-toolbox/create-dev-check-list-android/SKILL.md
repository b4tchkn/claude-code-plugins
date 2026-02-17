---
name: create-dev-check-list-android
description: Generate a minimal developer self-check checklist for Android (Kotlin/Gradle) projects from git diff to verify changes before requesting review. For other platforms (iOS, Web), use the corresponding platform-specific skill.
argument-hint: [description of the change]
disable-model-invocation: true
allowed-tools: Bash(git:*), Read, Grep, Glob
---

# Developer Self-Check (Android)

Generate a minimal checklist for Android (Kotlin/Gradle) developers to verify changes before requesting review.

> **Note:** This skill is specific to Android projects using Kotlin and Gradle. For iOS or Web projects, use the corresponding platform-specific skill.

## Execution Steps

### 1. Identify Changes

Collect change information:

- **Modified files**: !`git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null`
- **Diff summary**: !`git diff --stat 2>/dev/null; git diff --cached --stat 2>/dev/null`

If `$ARGUMENTS` is provided, use it as additional context for the change description.

Categorize changed files:

- **UI**: `*Screen.kt`, `*Composable.kt`, `*.xml` layouts
- **ViewModel**: `*ViewModel.kt`
- **Repository/Data**: `*Repository*.kt`, `*DataSource*.kt`, `*Api*.kt`
- **Model**: `*Model.kt`, `*Entity.kt`, `*Dto.kt`
- **DI**: `*Module.kt`
- **Build**: `*.gradle.kts`, `*.gradle`
- **Test**: `*Test.kt`

### 2. Generate Checklist

Based on changed file types, generate relevant checks using the templates below.

**IMPORTANT: Output the checklist as raw markdown (NOT inside a code block) so users can interact with checkboxes directly.**

#### Output Format

```markdown
## Dev Self-Check

> Quick verification before review. Check all boxes.

**Changed files:** {count} files in {modules}

### Build
- [ ] `./gradlew :play:assembleDebug` succeeds
- [ ] No new warnings introduced

### {Category-specific checks}
{Generate 2-4 checks based on change type}

### Tests
- [ ] `./gradlew :{affected-module}:test` passes

---
*All passed? Ready for review.*
```

#### Check Templates by Change Type

**UI Changes** (`*Screen.kt`, `*Composable.kt`):
- [ ] Screen displays correctly
- [ ] UI elements are tappable/interactive
- [ ] No visual glitches on rotation

**ViewModel Changes** (`*ViewModel.kt`):
- [ ] Screen using this ViewModel works
- [ ] State changes reflect in UI
- [ ] Actions trigger expected behavior

**Repository/API Changes**:
- [ ] API calls succeed (check Logcat)
- [ ] Error cases handled (try airplane mode)
- [ ] Data displays correctly in UI

**DI/Module Changes** (`*Module.kt`):
- [ ] App launches without crash
- [ ] Affected screens work

**Build/Gradle Changes**:
- [ ] Clean build succeeds
- [ ] All variants build (`assembleDebug`, `assembleRelease`)

**Model Changes**:
- [ ] Serialization/deserialization works
- [ ] Affected screens display data correctly

### 3. Copy to Clipboard

After generating the checklist, **always** copy the full markdown output to the system clipboard using `pbcopy` (macOS) or equivalent so the user can paste it immediately.

## Guidelines

- **Maximum 8 items total** - Keep it under 2 minutes
- **Observable behavior only** - What you can see/interact with
- **English only**
- **No edge cases** - Reviewers/QA will cover those
- **Focus on "does it break anything?"**
