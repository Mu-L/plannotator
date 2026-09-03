Follow [@plannotator](https://x.com/plannotator) on X for updates

---

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.23.0](https://github.com/backnotprop/plannotator/releases/tag/v0.23.0)   | Plan approval fix for Claude Code 2.1.199+, annotate mode version diff, binary-only `--minimal` install, reviews post without attribution |
| [v0.22.0](https://github.com/backnotprop/plannotator/releases/tag/v0.22.0)   | Git-status "All changes" default review view, Commits panel with per-commit diffs, Guided Review, Pi + GitHub Copilot CLI review engines |
| [v0.21.4](https://github.com/backnotprop/plannotator/releases/tag/v0.21.4)   | Markdown math rendering, PR Overview panel with annotatable description and comments, agent instructions in code review, media parsing fixes |
| [v0.21.3](https://github.com/backnotprop/plannotator/releases/tag/v0.21.3)   | File comments in code review, unified click-to-highlight comments, VS Code clipboard/keyboard bridge, Codex Ask AI on app-server transport, CLI subcommand help |
| [v0.21.2](https://github.com/backnotprop/plannotator/releases/tag/v0.21.2)   | Custom reviews as Agent Skills, Cursor + OpenCode review engines, whole-file/general findings, deleted-annotation fix, Codex Ask AI outside git repos |
| [v0.21.1](https://github.com/backnotprop/plannotator/releases/tag/v0.21.1)   | Annotate-last blank-page fix on multi-message sessions                                                                            |
| [v0.21.0](https://github.com/backnotprop/plannotator/releases/tag/v0.21.0)   | Direct document editing in annotate mode, live git-status file tree, in-app agent terminal, open files in external apps, HTML renders as HTML |
| [v0.20.3](https://github.com/backnotprop/plannotator/releases/tag/v0.20.3)   | Annotations no longer lost when clicking away, off-screen indicator for open comments                                            |
| [v0.20.2](https://github.com/backnotprop/plannotator/releases/tag/v0.20.2)   | Pierre CodeView all-files review, large-PR pipeline and instant-open checkout, unified agent engine selection, Pi programmatic plan mode |
| [v0.20.1](https://github.com/backnotprop/plannotator/releases/tag/v0.20.1)   | Pi extension install hotfix (pinned `@pierre/diffs` after a broken upstream release)                                             |
| [v0.20.0](https://github.com/backnotprop/plannotator/releases/tag/v0.20.0)   | Multi-repo workspace reviews, semantic diff overview, UI 2.0 themes and plan look chooser, leaner single-source skill install   |

</details>

---

## What's New in v0.23.1

A two-fix patch. Startup no longer hangs when Plannotator is launched from inside a very large or slow directory tree, and the Ask AI input box stays put after long responses.

### Startup no longer hangs on large or slow directory trees

On launch, Plannotator warms a cache of the code files under your working directory so it can resolve file links in plans and annotations. That walk was synchronous and unbounded, and it ran before the server started listening. On an ordinary repo you never noticed. On a very large tree, or a slow one like a FUSE-mounted monorepo with millions of files, the walk never finished — so `plannotator annotate` and the plan flow hung indefinitely with no browser, no output, and no server.

The walk is now bounded by the same `PLANNOTATOR_FILE_BROWSER_MAX_FILES` limit the file browser already uses, it runs asynchronously so it yields between directories, and it starts only after the server is listening. The review UI opens immediately and the file list fills in the background. The same limit now also bounds the command-line markdown and folder discovery paths, so resolving a bare filename can't stall on a huge tree either. Direct file paths in plans still resolve exactly as before; only bare-filename lookups on repositories past the limit are affected, and the limit is configurable.

PR [#1036](https://github.com/backnotprop/plannotator/pull/1036) by @backnotprop, closing [#978](https://github.com/backnotprop/plannotator/issues/978) reported by @DGroundD.

### Ask AI input stays visible after long responses

In the document sidebar, a long completed Ask AI response could push the follow-up input box below the bottom of the panel, so you had to scroll to find it. The chat panel now sizes to the space left under the sidebar header, so only the message list scrolls and the provider bar and text box stay in view.

PR [#1035](https://github.com/backnotprop/plannotator/pull/1035) by @dmmulroy.

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

- fix: bound startup file discovery so launches don't hang on large or slow trees by @backnotprop in [#1036](https://github.com/backnotprop/plannotator/pull/1036)
- fix: keep Ask AI input visible after responses by @dmmulroy in [#1035](https://github.com/backnotprop/plannotator/pull/1035)

## Community

- @DGroundD reported the startup hang on a FUSE-mounted monorepo in [#978](https://github.com/backnotprop/plannotator/issues/978), with a clear reproduction that pinned it to the working-directory file walk

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.23.0...v0.23.1
