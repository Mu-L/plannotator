Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.21.4](https://github.com/backnotprop/plannotator/releases/tag/v0.21.4)   | Markdown math rendering, PR Overview panel with annotatable description and comments, agent instructions in code review, media parsing fixes |
| [v0.21.3](https://github.com/backnotprop/plannotator/releases/tag/v0.21.3)   | File comments in code review, unified click-to-highlight comments, VS Code clipboard/keyboard bridge, Codex Ask AI on app-server transport, CLI subcommand help |
| [v0.21.2](https://github.com/backnotprop/plannotator/releases/tag/v0.21.2)   | Custom reviews as Agent Skills, Cursor + OpenCode review engines, whole-file/general findings, deleted-annotation fix, Codex Ask AI outside git repos |
| [v0.21.1](https://github.com/backnotprop/plannotator/releases/tag/v0.21.1)   | Annotate-last blank-page fix on multi-message sessions                                                                            |
| [v0.21.0](https://github.com/backnotprop/plannotator/releases/tag/v0.21.0)   | Direct document editing in annotate mode, live git-status file tree, in-app agent terminal, open files in external apps, HTML renders as HTML |
| [v0.20.3](https://github.com/backnotprop/plannotator/releases/tag/v0.20.3)   | Annotations no longer lost when clicking away, off-screen indicator for open comments                                            |
| [v0.20.2](https://github.com/backnotprop/plannotator/releases/tag/v0.20.2)   | Pierre CodeView all-files review, large-PR pipeline and instant-open checkout, unified agent engine selection, Pi programmatic plan mode |
| [v0.20.1](https://github.com/backnotprop/plannotator/releases/tag/v0.20.1)   | Pi extension install hotfix (pinned `@pierre/diffs` after a broken upstream release)                                             |
| [v0.20.0](https://github.com/backnotprop/plannotator/releases/tag/v0.20.0)   | Multi-repo workspace reviews, semantic diff overview, UI 2.0 themes and plan look chooser, leaner single-source skill install   |
| [v0.19.27](https://github.com/backnotprop/plannotator/releases/tag/v0.19.27) | Kiro CLI integration, Glimpse native window, annotate-last message picker                                                        |
| [v0.19.26](https://github.com/backnotprop/plannotator/releases/tag/v0.19.26) | Amp plugin production fixes, Mermaid rendering fix, Settings flicker fix, update notification toast and shimmer                   |

</details>

---

## What's New in v0.22.0

This release rebuilds the code review left panel around how a review actually starts: a git-status view of everything since your base branch is now the default, a Commits panel gives you the branch's history with per-commit diffs, and Guided Review turns any changeset into an agent-organized, chaptered walkthrough with live annotatable diffs. Pi and GitHub Copilot CLI join Cursor and OpenCode as review engines. Five PRs and four direct fixes land, all from the core team, verified by a 24-point QA pass before tagging.

### The review now opens on "All changes"

Code reviews used to open on unstaged changes, which answers "what did I just edit" but not the question most reviews start with: "what would a PR show if I pushed right now?" The new default diff answers exactly that. **All changes** compares the merge base with your base branch against the working tree and includes untracked files — committed work, uncommitted edits, and brand-new files in one view.

It renders as a **Git status** panel with three sections that mirror `git status`: **Committed**, **Changes**, and **Untracked**. Each row carries viewed tracking, a stage/unstage button, the change-type letter, and +/- counts, so you can stage files as you review without leaving the app. If the base branch has moved on GitHub since your last fetch, a banner offers a one-click fetch so you're reviewing against the real base.

A first-run dialog lets you pick your default view and diff type (with live previews), and both remain changeable in Settings → Git or from the review header menu. On repos where a base branch can't be resolved, the review falls back to uncommitted changes rather than hiding committed work.

PR [#990](https://github.com/backnotprop/plannotator/pull/990), by @backnotprop.

### Commits panel

The panel toggle gained a third view: **Commits**, a linear history rail of your branch, newest first, with author avatars and an "In origin/main" divider where your work meets the base. Clicking a commit opens that commit's own diff against its parent — `git show`, but annotatable — headed by the full commit message rendered as markdown.

The toggle is session-scoped: glancing at Commits (or Tree) mid-review never silently changes your saved default, and a review always opens on files, never on a historical commit. Avatars resolve by author email through the repo's forge and fall back to initials when there's no remote or CLI to ask.

PR [#994](https://github.com/backnotprop/plannotator/pull/994), by @backnotprop.

### Guided Review

Large changesets are hard to review top-to-bottom in file order. A **Guided Review** has an agent organize the current changeset — any PR or local diff — into importance-ordered chapters: the heart of the change first, its consequences next, glue last. Each section pairs a prose overview and per-file summaries with the live diffs it covers, and those diffs are the real diff viewer — annotations made inside a guide land in the same review state and export in the same feedback as everywhere else.

Open it with the **Guide** button in the review header or `Mod+Shift+G`, pick an engine and model, and generate. Sections track their own reviewed state so you can work through a big change across sittings. Guides run on Claude or Codex natively, and on Cursor, OpenCode, Pi, or GitHub Copilot CLI when installed. Every changed file is validated against the real diff server-side, so a guide can never invent files or drop them silently.

A one-time intro dialog announces the feature on first open, and the Guide button carries a subtle hint until the first time you use it.

PRs [#993](https://github.com/backnotprop/plannotator/pull/993), [#997](https://github.com/backnotprop/plannotator/pull/997), and [#1000](https://github.com/backnotprop/plannotator/pull/1000), by @backnotprop.

### Pi and GitHub Copilot CLI as review engines

The review and guide launchers gained two engines. **Pi** rides your existing Pi login (OAuth subscription or keys) with live model discovery and thinking-level control — and the Pi extension can launch Pi, so Pi users get agent reviews with zero extra setup. **GitHub Copilot CLI** runs in a locked-down non-interactive posture: no write access, a shell allowlist limited to git-family commands, and clean auto-denial for anything else.

That brings the engine roster to Claude, Codex, Cursor, OpenCode, Pi, and Copilot — and the engine layer was refactored so the next one is a two-edit change.

PRs [#993](https://github.com/backnotprop/plannotator/pull/993) and [#997](https://github.com/backnotprop/plannotator/pull/997), by @backnotprop.

### Additional Changes

- **Filenames stay visible in the Git status panel** — long paths now truncate in the directory portion (ellipsis before the final slash) so the filename always shows; a pathologically long filename truncates at its own end.
- **Commit-diff annotations stay anchored to their commit** — annotations made on a historical commit's diff are stamped with that commit, and the exported feedback labels any annotation whose anchor doesn't match the diff being sent, so an agent never reads a commit's line numbers against the working tree.
- **Avatar lookups can't delay the commit list** — forge avatar resolution now has a hard 4-second ceiling; on a hanging network the Commits panel loads immediately with initials and picks up avatars once they arrive.
- **Code review reference docs updated** — the docs page now describes the since-base default, the three panel views, Guided Review, the full engine roster, and the current server API.

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

- feat(review): "All changes" git-status review view by @backnotprop in [#990](https://github.com/backnotprop/plannotator/pull/990)
- feat(review): Commits panel — linear history rail with per-commit diffs by @backnotprop in [#994](https://github.com/backnotprop/plannotator/pull/994)
- feat(review): Guided Review + Pi agent-job provider by @backnotprop in [#993](https://github.com/backnotprop/plannotator/pull/993)
- feat: guide per-file summaries + GitHub Copilot CLI agent engine by @backnotprop in [#997](https://github.com/backnotprop/plannotator/pull/997)
- feat(review): Guided Reviews intro dialog + Guide button discovery hint by @backnotprop in [#1000](https://github.com/backnotprop/plannotator/pull/1000)
- fix(review): keep the filename visible in git-status rows by @backnotprop
- fix(review): anchor commit-diff annotations to their commit in feedback by @backnotprop
- fix(review): avatar lookups can no longer delay /api/commits by @backnotprop
- docs(marketing): bring the code-review reference up to the since-base era by @backnotprop

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.21.4...v0.22.0
