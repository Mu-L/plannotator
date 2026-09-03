Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.21.1](https://github.com/backnotprop/plannotator/releases/tag/v0.21.1)   | Annotate-last blank-page fix on multi-message sessions                                                                            |
| [v0.21.0](https://github.com/backnotprop/plannotator/releases/tag/v0.21.0)   | Direct document editing in annotate mode, live git-status file tree, in-app agent terminal, open files in external apps, HTML renders as HTML |
| [v0.20.3](https://github.com/backnotprop/plannotator/releases/tag/v0.20.3)   | Annotations no longer lost when clicking away, off-screen indicator for open comments                                            |
| [v0.20.2](https://github.com/backnotprop/plannotator/releases/tag/v0.20.2)   | Pierre CodeView all-files review, large-PR pipeline and instant-open checkout, unified agent engine selection, Pi programmatic plan mode |
| [v0.20.1](https://github.com/backnotprop/plannotator/releases/tag/v0.20.1)   | Pi extension install hotfix (pinned `@pierre/diffs` after a broken upstream release)                                             |
| [v0.20.0](https://github.com/backnotprop/plannotator/releases/tag/v0.20.0)   | Multi-repo workspace reviews, semantic diff overview, UI 2.0 themes and plan look chooser, leaner single-source skill install   |
| [v0.19.27](https://github.com/backnotprop/plannotator/releases/tag/v0.19.27) | Kiro CLI integration, Glimpse native window, annotate-last message picker                                                        |
| [v0.19.26](https://github.com/backnotprop/plannotator/releases/tag/v0.19.26) | Amp plugin production fixes, Mermaid rendering fix, Settings flicker fix, update notification toast and shimmer                   |
| [v0.19.24](https://github.com/backnotprop/plannotator/releases/tag/v0.19.24) | Amp integration, configurable data directory, Auto Mode permission option, Pi plan approval fix                                  |
| [v0.19.23](https://github.com/backnotprop/plannotator/releases/tag/v0.19.23) | Droid integration, Windows Pi AI fix, quieter update indicator                                                                   |
| [v0.19.22](https://github.com/backnotprop/plannotator/releases/tag/v0.19.22) | Safari copy fix in plan viewer, CLAUDE_CONFIG_DIR support for session logs                                                       |

</details>

---

## What's New in v0.21.2

Six PRs land in this release, with most of the work going into code review. You can now run your own Agent Skills as review profiles, and the review engine picker gains two new options — Cursor and OpenCode — alongside the existing Claude and Codex paths. A draft-persistence bug that resurrected deleted annotations is fixed, and Codex users get two improvements from a first-time contributor.

### Custom Reviews as Agent Skills

Until now the code review engine ran a fixed review prompt. This release lets you point a review at any Agent Skill you already have installed. Enable a skill as a review profile and the agent runs that skill's instructions against your diff instead of the built-in prompt, so a security skill, a style-guide skill, or any review methodology you've written becomes a one-click review.

Findings also gained two new shapes. A review can now attach a finding to an entire file rather than a specific line, and it can raise a general finding that applies to the whole changeset instead of any single location. Whole-file and general findings render in their own sections and flow through to the exported feedback the agent receives, so nothing a reviewer raises gets dropped because it didn't map to a line.

PR [#955](https://github.com/backnotprop/plannotator/pull/955), by @backnotprop.

### Cursor and OpenCode Review Engines

The review engine selection now includes Cursor and OpenCode in addition to Claude and Codex. Both run through a unified "marker" protocol: the agent runs its own CLI (`agent` for Cursor, `opencode run` for OpenCode) against your changes and returns findings in a delimited block that Plannotator parses back into annotations. The engines are opt-in and only appear when their CLI is installed, and they share the same finding pipeline as the existing engines, so whole-file and general findings work across all four.

PR [#959](https://github.com/backnotprop/plannotator/pull/959), by @backnotprop.

### Deleted Review Annotations Stay Deleted

In code review, deleting an annotation and then refreshing the page brought it back. The draft autosave kept the last saved copy, and a deletion wasn't being persisted as a real edit, so the next load restored the annotation the user had removed. This release records deletions with a generation tombstone so they survive a refresh and a late autosave can't revive them, while leaving genuine drafts intact.

PR [#951](https://github.com/backnotprop/plannotator/pull/951) closing [#948](https://github.com/backnotprop/plannotator/issues/948), reported by @alexanderkreidich.

### Codex Ask AI Outside Git Repos

Ask AI on the Codex provider assumed it was running inside a git repository and failed when it wasn't. It now probes for a working tree and skips the git-repo check when there isn't one, so Ask AI works in plain directories that aren't under version control.

PR [#965](https://github.com/backnotprop/plannotator/pull/965), by @ericclemmons.

### Codex Desktop Review URL Surfacing

When Plannotator runs inside the Codex desktop app, the session URL wasn't easy to find. It now prints the review URL to the terminal when it detects the Codex desktop host, so the link is visible instead of buried.

PR [#966](https://github.com/backnotprop/plannotator/pull/966), by @ericclemmons.

### Additional Changes

- **Landing page section order** — the capabilities section now sits above the demos on the marketing site. PR [#953](https://github.com/backnotprop/plannotator/pull/953), by @backnotprop.

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

- fix(review): persist annotation deletions so they don't resurrect on refresh by @backnotprop in [#951](https://github.com/backnotprop/plannotator/pull/951)
- feat(marketing): restructure landing page section order by @backnotprop in [#953](https://github.com/backnotprop/plannotator/pull/953)
- feat(review): custom reviews as Agent Skills + whole-file/general findings by @backnotprop in [#955](https://github.com/backnotprop/plannotator/pull/955)
- feat(review): Cursor + OpenCode review engines (unified marker-review) by @backnotprop in [#959](https://github.com/backnotprop/plannotator/pull/959)
- Allow Codex Ask AI outside git repos by @ericclemmons in [#965](https://github.com/backnotprop/plannotator/pull/965)
- Improve Codex App review URL discoverability by @ericclemmons in [#966](https://github.com/backnotprop/plannotator/pull/966)

## New Contributors

- @ericclemmons made their first contribution in [#965](https://github.com/backnotprop/plannotator/pull/965)

## Contributors

@ericclemmons landed two Codex improvements in his first contributions to the project: making Ask AI work outside git repositories in [#965](https://github.com/backnotprop/plannotator/pull/965), and surfacing the review URL when running inside the Codex desktop app in [#966](https://github.com/backnotprop/plannotator/pull/966).

Thanks to @alexanderkreidich, who reported in [#948](https://github.com/backnotprop/plannotator/issues/948) that deleted review annotations reappeared after a refresh — the bug this release fixes.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.21.1...v0.21.2
