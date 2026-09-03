Follow [@plannotator](https://x.com/plannotator) on X for updates

---

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.26.1](https://github.com/backnotprop/plannotator/releases/tag/v0.26.1)   | GitButler 0.22.0 compatibility via capability-probed JSON flags                                                                   |
| [v0.26.0](https://github.com/backnotprop/plannotator/releases/tag/v0.26.0)   | Edit Mode (suggest by editing the diff), Guided Review virtualization, colorblind theme, safe uninstall, installer opt-outs, OpenCode 2 support |
| [v0.25.1](https://github.com/backnotprop/plannotator/releases/tag/v0.25.1)   | Codex no longer launches on review open, annotate-last follows the live conversation, pi-todos mirror, Claude Opus 5, abandoned-gate dismissal |
| [v0.25.0](https://github.com/backnotprop/plannotator/releases/tag/v0.25.0)   | Vim keyboard controls, Approve with Notes, scriptable annotate gates, persistent Guided Reviews, memory and file-watching hardening |
| [v0.24.2](https://github.com/backnotprop/plannotator/releases/tag/v0.24.2)   | Annotate YAML/JSON/TOML config files, XDG data directory support, Codex model catalog update, Cursor sandbox escape hatch        |
| [v0.24.1](https://github.com/backnotprop/plannotator/releases/tag/v0.24.1)   | Annotate accepts parent-relative `../` file paths                                                                                |
| [v0.24.0](https://github.com/backnotprop/plannotator/releases/tag/v0.24.0)   | PR/MR artifact gallery, GitButler review support, port ranges, expanded comment editor, OpenCode + Pi fixes                       |
| [v0.23.1](https://github.com/backnotprop/plannotator/releases/tag/v0.23.1)   | Startup no longer hangs on large or slow directory trees, Ask AI input stays visible after long responses                        |
| [v0.23.0](https://github.com/backnotprop/plannotator/releases/tag/v0.23.0)   | Plan approval fix for Claude Code 2.1.199+, annotate mode version diff, binary-only `--minimal` install, reviews post without attribution |
| [v0.22.0](https://github.com/backnotprop/plannotator/releases/tag/v0.22.0)   | Git-status "All changes" default review view, Commits panel with per-commit diffs, Guided Review, Pi + GitHub Copilot CLI review engines |
| [v0.21.4](https://github.com/backnotprop/plannotator/releases/tag/v0.21.4)   | Markdown math rendering, PR Overview panel with annotatable description and comments, agent instructions in code review, media parsing fixes |

</details>

---

## What's New in v0.26.2

This release fixes two review regressions that shipped in v0.26.0, both reported by users within a day of release, and brings two visible improvements: pick separate light and dark themes, and code blocks that match your palette. Updating from v0.25.x? The full v0.26.0 feature notes are embedded in the [v0.26.1 release notes](https://github.com/backnotprop/plannotator/releases/tag/v0.26.1).

### Fixed: single-file diff tabs render fully again

In v0.26.0 and v0.26.1, opening a file as its own tab (clicking it in the file tree or sidebar, including PR review) showed only the changed hunks: the "N unmodified lines" bars between hunks had no expand controls and clicks did nothing, so surrounding code could not be revealed. The all-files scroll view was unaffected, which made the breakage feel random.

The cause was the diff renderer upgrade in v0.26.0. The renderer began identifying content by cache key and defaulting that key to the file name, so when the tab swapped its initial partial diff for the full expandable one, the renderer saw the same name and kept serving the stale partial render forever. The single-file view now derives cache keys from content, the same invariant the all-files view already followed.

- [#1219](https://github.com/backnotprop/plannotator/pull/1219)

### Fixed: no more silently dropped files in review diffs

The more serious of the two. In v0.26.0 and v0.26.1, certain files rendered as empty cards: listed in the tree with a modified badge but no counts, no hunks, and no way to see the change. The diff totals quietly excluded them, so nothing indicated content was missing. A reviewer could approve believing they had seen everything. Affected shapes included renamed files carrying uncommitted edits, and repositories where an object was absent from git's local object database (partial clones, for example).

The cause sat in the large-file memory bound introduced in v0.26.0. Its size probe asks git's object database how big each changed object is, but git reports a computed hash for worktree content it examined during rename detection, a hash for content that was never stored as an object. The probe got "missing" and treated missing as infinitely large, so the file was excluded and stubbed as binary. The probe now treats content it cannot find in the object database by checking the file on disk instead, and "missing" is no longer assumed oversized. The memory bound itself is unchanged: genuinely oversized files still render as stubs, and those stubs now say so on screen ("This file is over the 5 MB review limit") instead of appearing silently empty.

This was reported by a user on X with side-by-side screenshots comparing Plannotator against their editor's diff view, exactly the evidence that cracked it. Thank you.

- [#1220](https://github.com/backnotprop/plannotator/pull/1220)

### Pair a light theme and a dark theme

Settings > Theme now assigns each half of a pair: pick which palette is your light theme and which is your dark theme, and System mode switches between your two choices as your OS scheme changes (Kanagawa Lotus by day, Kanagawa Wave at night). Previously, choosing a dark-only palette pinned the mode and disabled system switching entirely. The pair persists to `~/.plannotator/config.json`, so it survives Plannotator's random ports and applies across every host. Existing theme choices migrate automatically.

- [#1217](https://github.com/backnotprop/plannotator/pull/1217), implementing part 1 of [#1211](https://github.com/backnotprop/plannotator/issues/1211) designed by @kunaaal13

### One syntax highlighter, palette-matched code blocks

Plannotator shipped two syntax highlighters: highlight.js for markdown code blocks, and Shiki inside the diff renderer. Code blocks now use the same Shiki instance the diff pane already loads, which means they finally render in your active palette (all built-in themes, colorblind included, light and dark) instead of a fixed dark style. highlight.js is removed entirely, along with a never-executed WebAssembly engine the diff renderer bundled. The plan review bundle shrank by about 1.3MB and the code review bundle by about 2.2MB.

Bare code fences (no language tag) now render as plain monospaced text instead of getting auto-detected highlighting, matching how GitHub and most markdown renderers behave. Prose quoted inside fences no longer gets colored like code.

- [#1218](https://github.com/backnotprop/plannotator/pull/1218), and [#1212](https://github.com/backnotprop/plannotator/pull/1212) by @zeke closing [#1210](https://github.com/backnotprop/plannotator/issues/1210)

### Additional Changes

- **Self-hosting docs corrected.** The guide no longer claims the portal bundles Highlight.js ([#1221](https://github.com/backnotprop/plannotator/pull/1221))

---

## Install / Update

**macOS / Linux:**

```bash
curl -fsSL https://plannotator.ai/install.sh | bash
```

**Windows:**

```powershell
irm https://plannotator.ai/install.ps1 | iex
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

---

## What's Changed

- fix: render language-less code blocks as plain text by @zeke in [#1212](https://github.com/backnotprop/plannotator/pull/1212)
- feat: pair a light theme and a dark theme, switched by mode by @backnotprop in [#1217](https://github.com/backnotprop/plannotator/pull/1217)
- perf: single Shiki highlighter, palette-matched code blocks, drop highlight.js by @backnotprop in [#1218](https://github.com/backnotprop/plannotator/pull/1218)
- fix: mint content-derived diff cache keys so single-file tabs render fully by @backnotprop in [#1219](https://github.com/backnotprop/plannotator/pull/1219)
- fix: stop stubbing files whose worktree content the size probe cannot find by @backnotprop in [#1220](https://github.com/backnotprop/plannotator/pull/1220)
- docs: self-hosting page no longer claims a bundled Highlight.js by @backnotprop in [#1221](https://github.com/backnotprop/plannotator/pull/1221)

## New Contributors

- @zeke made their first contribution in [#1212](https://github.com/backnotprop/plannotator/pull/1212)

## Community

@zeke reported the auto-detected highlighting problem with a screenshot that made the case instantly ([#1210](https://github.com/backnotprop/plannotator/issues/1210)) and fixed it himself the same day. First contribution.

@kunaaal13 designed the theme pair system in a file-accurate proposal that was adopted nearly as written ([#1211](https://github.com/backnotprop/plannotator/issues/1211)); parts 2 and 3 (custom user themes, separate fonts) remain open.

And to the reporter on X whose side-by-side editor comparison exposed the silently dropped files: that report likely saved other users from approving reviews they could not fully see.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.26.1...v0.26.2
