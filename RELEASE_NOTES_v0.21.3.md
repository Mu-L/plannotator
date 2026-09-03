Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.21.2](https://github.com/backnotprop/plannotator/releases/tag/v0.21.2)   | Custom reviews as Agent Skills, Cursor + OpenCode review engines, whole-file/general findings, deleted-annotation fix, Codex Ask AI outside git repos |
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

</details>

---

## What's New in v0.21.3

A follow-up to the code-review work in v0.21.2. The headline is file-scoped comments in code review with a reworked comment experience, and the rest of the release is fixes and polish: a new contributor fixed clipboard and keyboard handling in the VS Code extension, the CLI now prints help for its subcommands, Codex Ask AI moved onto a more reliable transport, and the Ask AI sidebar got a few rough edges sanded down. Eight changes land in total, including a first contribution from @rushelex.

### File Comments in Code Review

Until now a code-review comment always attached to a line range. This release adds file-scoped comments — a comment that belongs to a whole file rather than any single line. In the single-file view it renders as a full-text banner directly below the file path; in the all-files view it sits in the file header for expanded files. Guided reviews that produce file-level findings now anchor them where they belong instead of forcing them onto a line.

The comment experience was also unified. Clicking a comment — whether the inline card in the diff, the sidebar entry, or the file banner — replays its stored line range as a controlled highlight, and clicking it again clears the highlight. Scrolling the viewport to a comment is reserved for the sidebar and findings list, so clicking a comment inside the diff highlights it without yanking the page around. The inline, sidebar, and file-banner cards now share a single identity row (badges, author, timestamp), a single action row (edit, copy, delete), and a consistent file-name chip, replacing three separately built layouts that had drifted apart.

PR [#973](https://github.com/backnotprop/plannotator/pull/973), by @backnotprop.

### VS Code Clipboard and Keyboard Handling

The VS Code extension renders Plannotator inside a webview, and two long-standing problems made that webview feel second-class. Copy and paste didn't work — clipboard content never crossed the webview boundary — and standard VS Code keybindings like Cmd+P stopped responding while a Plannotator tab was focused. This release bridges the clipboard so copy, cut, and paste work inside the webview, and forwards keystrokes to VS Code so its keybindings resolve as expected.

PR [#970](https://github.com/backnotprop/plannotator/pull/970) closing [#864](https://github.com/backnotprop/plannotator/issues/864) and [#969](https://github.com/backnotprop/plannotator/issues/969), by @rushelex — who both reported the bugs and contributed the fix.

### Codex Ask AI on the App-Server Transport

Codex Ask AI no longer drives `codex exec` through the `@openai/codex-sdk` package. It now runs a long-lived `codex app-server` process over JSON-RPC, which respects the user's and enterprise-managed approval policy and supports interactive Allow/Deny approvals surfaced as cards in the UI. The provider id stays `codex-sdk` so existing saved preferences keep working. A startup edge case is also fixed: if the app-server process spawned but stalled on its initialize handshake, it was left running and every later question hung until an idle timer reaped it. The process is now killed on a failed handshake, so the next question starts cleanly.

PR [#971](https://github.com/backnotprop/plannotator/pull/971), by @backnotprop.

### CLI Subcommand Help

Running `plannotator review --help` (and the same for other subcommands) launched the review UI instead of printing help text. The CLI now resolves `--help` and `-h` for each subcommand before dispatching, so the help flag prints usage and exits without starting a server.

PR [#974](https://github.com/backnotprop/plannotator/pull/974) closing [#964](https://github.com/backnotprop/plannotator/issues/964), reported by @rrei.

### Clickable Ask AI Announcement Cards

The first time Ask AI appears, an announcement dialog presents the available providers as cards. Those cards were missing their click handler, so selecting a provider from the announcement did nothing. They are clickable now and select the provider as expected.

PR [#975](https://github.com/backnotprop/plannotator/pull/975) closing [#972](https://github.com/backnotprop/plannotator/issues/972), reported by @Duo-Huang.

### Ask AI Sidebar Polish

Two smaller fixes in the code-review Ask AI sidebar. The per-file chat groups used to start collapsed, so every file you had asked about had to be opened by hand; they now default to expanded, while manual collapse still works and persists. And clicking a sidebar comment that no longer matches the active PR or diff scope — for example after switching PRs in place — used to do nothing at all; it now clears the current selection so the click gives visible feedback instead of appearing broken.

### Additional Changes

- **Dependency maintenance** — GitHub Actions used by the build and release workflows were updated (`actions/checkout` to v7, `softprops/action-gh-release` to v3, and others). PR [#791](https://github.com/backnotprop/plannotator/pull/791), by @renovate.

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

- feat(review): file comments in the diff + unified click-to-highlight comment UX by @backnotprop in [#973](https://github.com/backnotprop/plannotator/pull/973)
- fix(vscode): bridge clipboard and forward keystrokes in webview by @rushelex in [#970](https://github.com/backnotprop/plannotator/pull/970)
- fix(annotate): make Ask AI announcement provider cards clickable by @backnotprop in [#975](https://github.com/backnotprop/plannotator/pull/975)
- fix(cli): print per-subcommand help instead of launching the UI by @backnotprop in [#974](https://github.com/backnotprop/plannotator/pull/974)
- fix(ai): drive Codex Ask AI via codex app-server by @backnotprop in [#971](https://github.com/backnotprop/plannotator/pull/971)
- fix(ai): kill codex app-server if the initialize handshake fails by @backnotprop
- fix(review): default Ask AI per-file chat groups to expanded by @backnotprop
- fix(review): clear selection on out-of-scope sidebar annotation click by @backnotprop
- chore(deps): update github actions by @renovate in [#791](https://github.com/backnotprop/plannotator/pull/791)

## New Contributors

- @rushelex made their first contribution in [#970](https://github.com/backnotprop/plannotator/pull/970)

## Contributors

@rushelex landed their first contribution, and a complete one: they reported that the VS Code extension couldn't paste from the clipboard ([#864](https://github.com/backnotprop/plannotator/issues/864)) and that VS Code keybindings stopped working while a Plannotator tab was focused ([#969](https://github.com/backnotprop/plannotator/issues/969)), then fixed both in [#970](https://github.com/backnotprop/plannotator/pull/970).

Thanks also to the people who reported the bugs this release fixes:

- @rrei reported that `plannotator review --help` launched the UI instead of printing help ([#964](https://github.com/backnotprop/plannotator/issues/964)), fixed in [#974](https://github.com/backnotprop/plannotator/pull/974).
- @Duo-Huang reported that the Ask AI announcement provider cards were not clickable ([#972](https://github.com/backnotprop/plannotator/issues/972)), fixed in [#975](https://github.com/backnotprop/plannotator/pull/975).

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.21.2...v0.21.3
