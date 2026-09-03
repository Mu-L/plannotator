Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.20.3](https://github.com/backnotprop/plannotator/releases/tag/v0.20.3)   | Annotations no longer lost when clicking away, off-screen indicator for open comments                                            |
| [v0.20.2](https://github.com/backnotprop/plannotator/releases/tag/v0.20.2)   | Pierre CodeView all-files review, large-PR pipeline and instant-open checkout, unified agent engine selection, Pi programmatic plan mode |
| [v0.20.1](https://github.com/backnotprop/plannotator/releases/tag/v0.20.1)   | Pi extension install hotfix (pinned `@pierre/diffs` after a broken upstream release)                                             |
| [v0.20.0](https://github.com/backnotprop/plannotator/releases/tag/v0.20.0)   | Multi-repo workspace reviews, semantic diff overview, UI 2.0 themes and plan look chooser, leaner single-source skill install   |
| [v0.19.27](https://github.com/backnotprop/plannotator/releases/tag/v0.19.27) | Kiro CLI integration, Glimpse native window, annotate-last message picker                                                        |
| [v0.19.26](https://github.com/backnotprop/plannotator/releases/tag/v0.19.26) | Amp plugin production fixes, Mermaid rendering fix, Settings flicker fix, update notification toast and shimmer                   |
| [v0.19.24](https://github.com/backnotprop/plannotator/releases/tag/v0.19.24) | Amp integration, configurable data directory, Auto Mode permission option, Pi plan approval fix                                  |
| [v0.19.23](https://github.com/backnotprop/plannotator/releases/tag/v0.19.23) | Droid integration, Windows Pi AI fix, quieter update indicator                                                                   |
| [v0.19.22](https://github.com/backnotprop/plannotator/releases/tag/v0.19.22) | Safari copy fix in plan viewer, CLAUDE_CONFIG_DIR support for session logs                                                       |
| [v0.19.21](https://github.com/backnotprop/plannotator/releases/tag/v0.19.21) | Ask AI in plan review and annotate mode, shared AI runtime, origin-aware provider defaults                                       |
| [v0.19.20](https://github.com/backnotprop/plannotator/releases/tag/v0.19.20) | Interactive goal setup UI, OpenCode submit_plan fixes, browser no-op sentinel handling for Claude agents                         |

</details>

---

## What's New in v0.21.0

This is a large release for the annotate experience. Seventeen pull requests landed since v0.20.3, five of them from external contributors, including first contributions from four new community members. The headline is a set of features that turn annotate mode into a place where you can read, edit, run an agent, and jump into your own tools without leaving the document. Alongside that, several reliability fixes harden the paths that remote and CI users depend on.

### Edit Documents Directly in Annotate Mode

Until now, annotation was a one-way conversation: you highlighted text, wrote a comment, and the agent received your notes. If you wanted to change a sentence yourself, you described the change instead of making it.

This release adds a real markdown editor to annotate and plan mode. You can switch a document into edit mode, change the text directly, and the difference between the original and your edits is captured as a clean diff that travels to the agent alongside your annotations. The edit controls were reworked so the state is always legible: a clear **Edits** label, Save emphasis when there are unsaved changes, and a Save/Cancel pair where Cancel discards your changes after a confirmation rather than silently keeping them.

Saved source-file edits now survive a refresh. When you edit a file in annotate-folder mode and save it, the right-side Edits card is persisted in the annotation draft and restored after a reload. Restored edits are validated against the file's current contents on disk, so stale context is dropped rather than resurfaced, and the edit context is never sent to the agent if it no longer matches the file.

PR [#890](https://github.com/backnotprop/plannotator/pull/890), [#928](https://github.com/backnotprop/plannotator/pull/928), [#936](https://github.com/backnotprop/plannotator/pull/936) by @backnotprop.

### A Live File Tree for Annotated Folders

When you annotate a folder, the file tree on the left is now live. It uses a server-side file watcher rather than polling, so the tree updates as files change on disk. Git status drives per-file badges and folder totals, showing which files are modified, added, or deleted, with line counts for changes. Direct source-file edits made inside Plannotator show their save state in the tree as well: clean, dirty, saving, saved, or conflict.

Two follow-up rounds hardened this. Nested ignored folders like `node_modules` and `dist` are now pruned by path segment so the watcher never walks into them, watcher teardown is identity-safe so reconnects can't orphan old watchers, and git status reads run asynchronously with timeouts and request coalescing so a slow repository can't block the server. A startup-latency fix ensures the tree's first snapshot renders before the live watcher subscribes, so the tree no longer sits on a loading state while the watcher sets up.

PR [#931](https://github.com/backnotprop/plannotator/pull/931), [#933](https://github.com/backnotprop/plannotator/pull/933), [#935](https://github.com/backnotprop/plannotator/pull/935) by @backnotprop.

### An Agent Terminal Inside Annotate Mode

Annotate mode now includes an optional agent terminal panel. You can run a coding agent in a real terminal next to the document you're annotating, so the back-and-forth happens in one place instead of a separate window.

The terminal is backed by a PTY hosted in a small Node sidecar, since the compiled Plannotator runtime can't load native terminal bindings directly. On a normal install the runtime is provisioned automatically, and where it isn't available the panel disables itself cleanly rather than failing the session. Requires Node.js 20 or newer on your PATH.

PR [#941](https://github.com/backnotprop/plannotator/pull/941) by @backnotprop.

### Open Files in Your Editor, Terminal, or File Manager

A new "open in" control lets you launch the file you're looking at directly in an external application: VS Code, Cursor, Zed, Ghostty, iTerm2, Warp, Sublime Text, Xcode, Android Studio, or reveal it in Finder or Explorer. Only applications you actually have installed appear in the menu, the last one you used becomes the default, and copy-path and copy-diff actions are always available. The control hides itself in remote sessions where opening a local app wouldn't make sense.

This release also includes a pass on the code-review UI. The semantic diff moved from a separate docked panel into an inline accordion in the all-files view, file headers and the file tree were reworked, and the diff-freshness check was tidied.

PR [#942](https://github.com/backnotprop/plannotator/pull/942) by @backnotprop.

### HTML Files Render as HTML

Annotating an `.html` file now renders the page as HTML by default instead of converting it to markdown. For most HTML — rendered reports, exported documents, generated pages — this is what you actually want to look at. If you need the old behavior, pass `--markdown` to convert the page to text with Turndown. The serving path for raw HTML and its assets was also hardened against symlink escapes.

This is a behavior change for anyone who ran `plannotator annotate file.html` expecting a markdown view. The conversion is one flag away.

PR [#924](https://github.com/backnotprop/plannotator/pull/924), [#927](https://github.com/backnotprop/plannotator/pull/927) by @backnotprop.

### Additional Changes

- **Remote sessions always show a reachable URL.** The session URL is now printed to the terminal for remote sessions regardless of whether URL sharing is enabled, and local sessions print the URL as a fallback when the browser can't be opened (a headless box or devcontainer). This closes a long-standing gap where remote and headless users could be left with no link and a hung review. PR [#929](https://github.com/backnotprop/plannotator/pull/929), [#945](https://github.com/backnotprop/plannotator/pull/945) by @backnotprop.
- **Ask AI works on Bedrock and Vertex.** Bare model aliases were being rejected with a 400 on Amazon Bedrock and Google Vertex; model ids are now resolved to the correct provider-specific identifiers, with a safe fallback when none is configured. PR [#939](https://github.com/backnotprop/plannotator/pull/939) closing [#938](https://github.com/backnotprop/plannotator/issues/938) by @masterpavan.
- **Release binaries ignore caller `bunfig.toml`.** Compiled binaries no longer autoload a `bunfig.toml` from the directory they're run in, so a stray or hostile config in a project folder can't alter or crash the binary. PR [#937](https://github.com/backnotprop/plannotator/pull/937) by @jrpat.
- **Light-mode contrast fix in code hover previews.** Code hover previews used a dark-mode color in light mode, making text hard to read. PR [#934](https://github.com/backnotprop/plannotator/pull/934) by @hl662.
- **Turn URL sharing off via config.** URL sharing can now be disabled through `~/.plannotator/config.json` (`{ "share": "disabled" }`) in addition to the environment variable. PR [#921](https://github.com/backnotprop/plannotator/pull/921) by @yonihorn.
- **Save to Obsidian works from annotate sessions.** The annotate server was missing the `/api/save-notes` endpoint, so the "Save to Obsidian" button silently failed; the endpoint is now wired in. PR [#884](https://github.com/backnotprop/plannotator/pull/884) closing [#844](https://github.com/backnotprop/plannotator/issues/844) by @titosemi.

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

- feat(editor): markdown edit mode — direct document editing with diff-to-agent feedback by @backnotprop in [#890](https://github.com/backnotprop/plannotator/pull/890)
- feat(config): support share toggle via config.json by @yonihorn in [#921](https://github.com/backnotprop/plannotator/pull/921)
- feat(annotate): render HTML annotations as HTML by default by @backnotprop in [#924](https://github.com/backnotprop/plannotator/pull/924)
- fix(annotate): block symlink escape in HTML asset serving by @backnotprop in [#927](https://github.com/backnotprop/plannotator/pull/927)
- fix(annotate): add /api/save-notes POST endpoint to annotate server by @titosemi in [#884](https://github.com/backnotprop/plannotator/pull/884)
- feat(editor): clearer edit controls — Edits label, Save emphasis, Save/Cancel by @backnotprop in [#928](https://github.com/backnotprop/plannotator/pull/928)
- fix(server): always show remote URL + close share-html symlink gap by @backnotprop in [#929](https://github.com/backnotprop/plannotator/pull/929)
- feat(annotate): live file tree workspace status by @backnotprop in [#931](https://github.com/backnotprop/plannotator/pull/931)
- fix(annotate): polish live file tree refresh by @backnotprop in [#933](https://github.com/backnotprop/plannotator/pull/933)
- feat(annotate): persist saved file edits in drafts by @backnotprop in [#936](https://github.com/backnotprop/plannotator/pull/936)
- fix(ai): resolve Bedrock/Vertex model ids for Ask AI by @masterpavan in [#939](https://github.com/backnotprop/plannotator/pull/939)
- chore(release): disable bunfig autoload for release binaries by @jrpat in [#937](https://github.com/backnotprop/plannotator/pull/937)
- fix(ui): correct light-mode contrast in code hover preview by @hl662 in [#934](https://github.com/backnotprop/plannotator/pull/934)
- fix(annotate): live file tree startup latency by @backnotprop in [#935](https://github.com/backnotprop/plannotator/pull/935)
- feat(annotate): open files in external apps + code-review UX pass by @backnotprop in [#942](https://github.com/backnotprop/plannotator/pull/942)
- feat(annotate): WebTUI agent panel in annotate mode by @backnotprop in [#941](https://github.com/backnotprop/plannotator/pull/941)
- fix(server): surface session URL in local mode when the browser can't open by @backnotprop in [#945](https://github.com/backnotprop/plannotator/pull/945)

## New Contributors

- @titosemi made their first contribution in [#884](https://github.com/backnotprop/plannotator/pull/884)
- @hl662 made their first contribution in [#934](https://github.com/backnotprop/plannotator/pull/934)
- @jrpat made their first contribution in [#937](https://github.com/backnotprop/plannotator/pull/937)
- @masterpavan made their first contribution in [#939](https://github.com/backnotprop/plannotator/pull/939)

## Contributors

Thanks to the five external contributors in this release.

@titosemi fixed a bug that several people had run into: the "Save to Obsidian" button silently failing from annotate sessions, because the annotate server was missing the `/api/save-notes` endpoint. @masterpavan reported and fixed Ask AI's failure on Amazon Bedrock and Google Vertex, where bare model aliases were being rejected with a 400. @jrpat hardened the release binaries so they no longer autoload a `bunfig.toml` from the caller's directory, closing a path where a stray config could crash a compiled binary. @hl662 fixed a light-mode contrast bug that made code hover previews hard to read. @yonihorn, back for a fourth contribution, added a config-file switch to disable URL sharing.

Thanks also to the community members whose reports shaped this release:

- @rrpolanco for reporting the Obsidian save failure in [#844](https://github.com/backnotprop/plannotator/issues/844)

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.20.3...v0.21.0
