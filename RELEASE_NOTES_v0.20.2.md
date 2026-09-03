Follow [@plannotator](https://x.com/plannotator) on X for updates

---

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.20.1](https://github.com/backnotprop/plannotator/releases/tag/v0.20.1)   | Pi extension install hotfix (pinned `@pierre/diffs` after a broken upstream release)                                             |
| [v0.20.0](https://github.com/backnotprop/plannotator/releases/tag/v0.20.0)   | Multi-repo workspace reviews, semantic diff overview, UI 2.0 themes and plan look chooser, leaner single-source skill install   |
| [v0.19.27](https://github.com/backnotprop/plannotator/releases/tag/v0.19.27) | Kiro CLI integration, Glimpse native window, annotate-last message picker                                                        |
| [v0.19.26](https://github.com/backnotprop/plannotator/releases/tag/v0.19.26) | Amp plugin production fixes, Mermaid rendering fix, Settings flicker fix, update notification toast and shimmer                   |
| [v0.19.24](https://github.com/backnotprop/plannotator/releases/tag/v0.19.24) | Amp integration, configurable data directory, Auto Mode permission option, Pi plan approval fix                                  |
| [v0.19.23](https://github.com/backnotprop/plannotator/releases/tag/v0.19.23) | Droid integration, Windows Pi AI fix, quieter update indicator                                                                   |
| [v0.19.22](https://github.com/backnotprop/plannotator/releases/tag/v0.19.22) | Safari copy fix in plan viewer, CLAUDE_CONFIG_DIR support for session logs                                                       |
| [v0.19.21](https://github.com/backnotprop/plannotator/releases/tag/v0.19.21) | Ask AI in plan review and annotate mode, shared AI runtime, origin-aware provider defaults                                       |
| [v0.19.20](https://github.com/backnotprop/plannotator/releases/tag/v0.19.20) | Interactive goal setup UI, OpenCode submit_plan fixes, browser no-op sentinel handling for Claude agents                         |
| [v0.19.18](https://github.com/backnotprop/plannotator/releases/tag/v0.19.18) | Edit-based submit_plan for OpenCode, Pi namespace migration, Codex annotate-last fix, OpenCode commands dir fix                  |
| [v0.19.17](https://github.com/backnotprop/plannotator/releases/tag/v0.19.17) | Reworked goal setup skill (interview-driven flow), CLI --version flag                                                            |

</details>

---

## What's New in v0.20.2

v0.20.2 is a code-review-heavy release of nine PRs, two of them from first-time contributors. The largest work rebuilds the all-files review view on Pierre's CodeView and adds a pipeline that keeps very large pull requests fast and complete instead of failing or rendering empty. Agent engine selection is unified across review and tour modes, the Pi extension gains a programmatic plan-mode control event, and several reliability fixes land across review cleanup, annotate error messaging, and markdown rendering.

### All-Files Code Review on Pierre CodeView

The all-files code review surface was rebuilt on Pierre's CodeView renderer, replacing the previous custom diff view and its lazy-mounting layer. The new foundation virtualizes large diffs, renders change-type status in file headers and the file tree, and presents renames as `old/path → new/path` rather than as a blank change. The annotation model, drafts, feedback export, and keyboard shortcuts carry over unchanged, so the way you review and send feedback is the same.

- [#885](https://github.com/backnotprop/plannotator/pull/885), contributed by @backnotprop

### Large Pull Request Pipeline, Instant-Open Checkout, and Scroll Performance

Reviewing very large pull requests previously hit several walls: GitHub refused oversized diffs outright, the local checkout blocked the review from opening, and some files came back from the platform with no patch content and rendered as empty stubs. This release addresses all three.

When a platform refuses an oversized diff, Plannotator now pages through the per-file API and stitches the result into a unified diff, so the review still loads. When the platform withholds per-file content on a truncated diff, an amber "Partial diff · Load full diff" notice offers to recompute the exact diff locally, and a staleness check surfaces a refresh prompt when the underlying files change mid-review. The `--local` checkout no longer blocks startup: the review server opens as soon as the platform diff arrives and the checkout warms in the background, with agent jobs, full-stack diff, and code navigation waiting on it only when they need real files.

Scrolling the all-files view was also reworked. Syntax highlighting moved off the main thread into a worker pool, lazy full-content augmentation no longer hitches mid-scroll, and visibility tracking was coalesced to once per frame. The result is smoother scrolling on large diffs, with a clean fallback to unhighlighted text if the worker pool is unavailable.

- [#893](https://github.com/backnotprop/plannotator/pull/893), contributed by @backnotprop

### Unified Agent Mode Engine Selection

The agent panel's engine selection was reworked so review and tour modes share one consistent model. Previously the selection conflated provider and mode in a single setting; it now separates the active mode from the engine choice (Claude or Codex) for each, with existing settings migrated forward. The change makes it clearer which engine runs for review versus tour and removes a class of confusing defaults.

- [#868](https://github.com/backnotprop/plannotator/pull/868), contributed by @codythatsme

### Programmatic Plan Mode for Pi

The Pi extension gained a `plan-mode` event so other extensions and automation can drive Plannotator's plan mode programmatically. A request can enter, exit, toggle, or query plan mode, and receives the resulting phase (`idle`, `planning`, or `executing`) in return. This opens the plan workflow to scripted and multi-extension setups on Pi without requiring a manual command or shortcut.

- [#898](https://github.com/backnotprop/plannotator/pull/898), contributed by @Termina1

### Review Cleanup and PR Feedback Fixes

Two reliability fixes for the review path. First, the standalone server now routes `SIGINT` and `SIGTERM` through its normal shutdown so the existing cleanup runs on interrupt or termination. Aborting a review while a large pull request was still checking out in the background previously left clone and fetch processes running and stale `git worktree` registrations behind; those are now cleaned up, with a second interrupt still forcing an immediate quit.

Second, the review feedback sent to the agent on "Send Feedback" now includes the triage instruction (review the feedback, verify it against the code, and discuss before changing anything) for pull request reviews, not just local diffs. The instruction is appended whenever you send annotations and is correctly omitted for platform actions that post an approval or comment directly to the host. The behavior is consistent across Claude Code, OpenCode, and Pi.

- [#914](https://github.com/backnotprop/plannotator/pull/914), contributed by @backnotprop

### Clearer Annotate and Markdown Behavior

Running `plannotator annotate` on a file type it does not support (for example a `.cs` or `.pdf` file) reported a misleading "File not found" even when the file was present. It now reports that the type is unsupported, lists the supported extensions, and points to `plannotator review` for code. Separately, custom angle-bracket autolinks are kept literal instead of having their contents parsed for markdown styling, so links that contain markdown-like characters render correctly.

- [#870](https://github.com/backnotprop/plannotator/pull/870) closing [#757](https://github.com/backnotprop/plannotator/issues/757), and [#867](https://github.com/backnotprop/plannotator/pull/867) closing [#836](https://github.com/backnotprop/plannotator/issues/836), contributed by @ishowman

### Additional Changes

- **README redesign.** The project README was rebuilt around a feature table with a centered note on AI assistance and refreshed styling. [#891](https://github.com/backnotprop/plannotator/pull/891) and [#892](https://github.com/backnotprop/plannotator/pull/892)

## Install / Update

**macOS / Linux:**

```bash
curl -fsSL https://plannotator.ai/install.sh | bash
```

**Windows:**

```powershell
irm https://plannotator.ai/install.ps1 | iex
```

**Extra skills** (compound, setup-goal, visual-explainer), opt-in:

```bash
npx skills add backnotprop/plannotator/apps/skills/extra
```

**Claude Code Plugin:** Run `/plugin` in Claude Code, find **plannotator**, and click **"Update now"**.

**OpenCode:** Clear cache and restart:

```bash
rm -rf ~/.bun/install/cache/@plannotator
```

Then in `opencode.json`:

```json
{
  "plugin": ["@plannotator/opencode@latest"]
}
```

**Pi:** Install or update the extension:

```bash
pi install npm:@plannotator/pi-extension
```

**Droid:** Install via the plugin marketplace:

```
droid plugin marketplace add backnotprop/plannotator
droid plugin install plannotator@plannotator
```

**Amp:** Install the CLI first, then copy the plugin:

```bash
mkdir -p ~/.config/amp/plugins
curl -fsSL https://raw.githubusercontent.com/backnotprop/plannotator/main/apps/amp-plugin/plannotator.ts \
  -o ~/.config/amp/plugins/plannotator.ts
```

**Kiro CLI:** The installer auto-detects Kiro and installs skills automatically. After installing the CLI, launch with:

```bash
kiro-cli chat --agent plannotator
```

Upgrading from before v0.20.0? Read the [v0.20.0 release notes](https://github.com/backnotprop/plannotator/releases/tag/v0.20.0) first; that release changed how skills install.

---

## What's Changed

- feat(review): migrate all-files code review to Pierre CodeView by @backnotprop in [#885](https://github.com/backnotprop/plannotator/pull/885)
- fix(markdown): keep custom angle autolinks literal by @ishowman in [#867](https://github.com/backnotprop/plannotator/pull/867)
- fix(annotate): improve error message for unsupported file types by @ishowman in [#870](https://github.com/backnotprop/plannotator/pull/870)
- refactor(agent-mode): Unify agent mode engine selection by @codythatsme in [#868](https://github.com/backnotprop/plannotator/pull/868)
- feat(review): large-PR pipeline, instant-open checkout, scroll perf, and worker-pool highlighting by @backnotprop in [#893](https://github.com/backnotprop/plannotator/pull/893)
- feat(readme): redesign README by @backnotprop in [#891](https://github.com/backnotprop/plannotator/pull/891)
- style(readme): center AI note under feature table by @backnotprop in [#892](https://github.com/backnotprop/plannotator/pull/892)
- fix(review): signal-safe cleanup + triage suffix for PR feedback by @backnotprop in [#914](https://github.com/backnotprop/plannotator/pull/914)
- feat(pi): add programmatic plan mode event by @Termina1 in [#898](https://github.com/backnotprop/plannotator/pull/898)

## New Contributors

- @ishowman made their first contribution in [#867](https://github.com/backnotprop/plannotator/pull/867)
- @Termina1 made their first contribution in [#898](https://github.com/backnotprop/plannotator/pull/898)

## Contributors

@ishowman landed two fixes in their first contributions: a clearer error from `plannotator annotate` when a file type is not supported, and a markdown fix that keeps custom angle-bracket autolinks literal instead of styling their contents. @Termina1 added the programmatic plan-mode event to the Pi extension, letting other extensions and automation enter, exit, toggle, or query plan mode and read back the resulting phase. @codythatsme unified agent mode engine selection so review and tour modes share one consistent model for choosing between Claude and Codex, with existing settings migrated forward.

This release also resolved community-reported issues. @NikiforovAll reported the misleading "File not found" message from `plannotator annotate` on unsupported file types, with a concrete `.cs` reproduction. @Thraka reported the markdown autolink rendering issue, and @MannXo contributed to the discussion that shaped the fix.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.20.1...v0.20.2
