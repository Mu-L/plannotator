Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release | Highlights |
|---|---|
| [v0.27.9](https://github.com/backnotprop/plannotator/releases/tag/v0.27.9)   | WebMCP browser-agent tools, HTML refresh from disk, host seams, lazy renderers, Windows uninstall fix                            |
| [v0.27.8](https://github.com/backnotprop/plannotator/releases/tag/v0.27.8)   | Pi keeps its prompt cache across plan transitions, thumbs-up returns to HTML annotation, embed picker seam                        |
| [v0.27.7](https://github.com/backnotprop/plannotator/releases/tag/v0.27.7)   | Pi host crash fix on Windows, Call Flow tree cap, jj fork-point base, plannotator knowledge skill + llms.txt                     |
| [v0.27.6](https://github.com/backnotprop/plannotator/releases/tag/v0.27.6)   | Live app annotation lands on Pi, one interaction model for HTML pages (same-day patch on v0.27.5)                                |
| [v0.27.5](https://github.com/backnotprop/plannotator/releases/tag/v0.27.5)   | Annotate your running app, Agent TUI placement, collapsed lockfiles, VS Code theme fix, Pi fixes                                 |
| [v0.27.4](https://github.com/backnotprop/plannotator/releases/tag/v0.27.4)   | Portable Guided Review exports, guides.show share links, guide CLI, favicon switcher, jj Call Flow                               |
| [v0.27.3](https://github.com/backnotprop/plannotator/releases/tag/v0.27.3)   | Folder watcher freeze fix on large repos, first SBOM-attested release pipeline                                                   |
| [v0.27.2](https://github.com/backnotprop/plannotator/releases/tag/v0.27.2)   | Mobile plan and code review, Codex CLI 0.147 fix, folder annotate cold-start, configurable markdown extensions |
| [v0.27.1](https://github.com/backnotprop/plannotator/releases/tag/v0.27.1)   | Open-in-editor launch fix, file headers respect Viewed/Git-add visibility toggles                                                |
| [v0.27.0](https://github.com/backnotprop/plannotator/releases/tag/v0.27.0)   | Call Flow analysis, --tailscale remote reviews, review panel remembers your view, Pi rebuild (breaking command rename), focus-mode shortcut |
| [v0.26.8](https://github.com/backnotprop/plannotator/releases/tag/v0.26.8)   | Placed comment markers on HTML pages, shift-click multi-select, live app annotation                                              |
| [v0.26.7](https://github.com/backnotprop/plannotator/releases/tag/v0.26.7)   | Pinpoint targets any element on HTML pages, smarter hover labels, zero-scan hit testing                                          |

</details>

## What's New in v0.27.10

This release brings two review features people have asked for, restores the slash commands on OpenCode 2, and fixes three reported bugs. Six PRs shipped, every one shaped by community reports and requests, and the whole set went through an adversarial 29-point QA sweep before tagging.

### Files mark themselves viewed as you scroll

Reviewers reading the all-files diff top to bottom no longer check every file off by hand. Scroll past a file after actually reading it and it marks itself viewed; open a file, read it, and move on, and the same happens. Momentum-flicking to the bottom marks nothing: a file only counts once its content was on screen long enough to have been read, and collapsed or generated files (your lockfiles) never auto-mark from their folded headers.

The reviewer stays in charge. Un-viewing a file is treated as "come back to this," and auto-view will never re-check it. When a diff refreshes and a file's content changed underneath its checkmark, the checkmark comes off, so a stale check can't vouch for code an agent just rewrote. The feature is on by default with a one-time notice the first moment it fires, and it can be turned off in Settings or from the gear above the file list.

[#1430](https://github.com/backnotprop/plannotator/pull/1430)

### Undo and redo for annotations

`Mod+Z` / `Mod+Shift+Z` now work across annotation actions in plan review and code review: create, edit, and delete for comments, deletions, checkbox toggles, suggestion batches, and image annotator strokes. History is bounded, per-document, and deliberately conservative: typing in a text field keeps the browser's native undo, and comments posted by agents or external tools never enter your history, so an undo can only ever touch your own work.

Requested by @jj-valentine in [#828](https://github.com/backnotprop/plannotator/issues/828).

[#1426](https://github.com/backnotprop/plannotator/pull/1426), closing [#828](https://github.com/backnotprop/plannotator/issues/828)

### Slash commands return on OpenCode 2

OpenCode 2's plugin API originally had no way for a plugin to execute a slash command, which left `/plannotator-review`, `/plannotator-annotate`, and `/plannotator-last` dead on V2. Upstream shipped exactly the hook that was missing (anomalyco/opencode PR #44765), and Plannotator now uses it: on hosts with the new API the three commands run natively again, opening the UI directly with no model turn and your arguments passed through untouched. Agent switching selected in the review UI also works again on those hosts.

On OpenCode 2 builds that don't have the new API yet, the commands fall back to asking the agent to run the `plannotator` CLI, which works everywhere today. The native path takes over automatically as OpenCode builds update. OpenCode 1 behavior is unchanged.

[#1434](https://github.com/backnotprop/plannotator/pull/1434), [#1435](https://github.com/backnotprop/plannotator/pull/1435)

### Remote OpenCode 2 sessions show their URL

Remote sessions are only usable if you can see the session URL, and on OpenCode 2 there was no visible place for it to land. Both the new native commands and `submit_plan` now post the URL as a notice directly in the session transcript, without waking a model turn. This came out of the release QA sweep rather than a field report, which is where you want to find it.

[#1435](https://github.com/backnotprop/plannotator/pull/1435)

### Share links stop serving stale snapshots

When a teammate sent you a share link and you annotated their plan, the export kept offering the original short link back, without your annotations. The link lifecycle now tracks exactly which content a short URL was minted for and clears it the moment the content changes, so you can never send back a link that silently drops your feedback. The remaining piece, minting a fresh short link for small plans, is tracked in [#1427](https://github.com/backnotprop/plannotator/issues/1427).

Reported by @grncdr in [#798](https://github.com/backnotprop/plannotator/issues/798).

[#1425](https://github.com/backnotprop/plannotator/pull/1425), closing [#798](https://github.com/backnotprop/plannotator/issues/798)

### Agent terminal works on npm 12

npm 12 blocks dependency install scripts by default, which silently skipped node-pty's native build on Linux and left the annotate-mode Agent tab reporting "Agent unavailable" from a runtime that looked installed but couldn't load. The managed runtime now approves exactly that one build script, verifies the native binary actually exists after install, retries the build once if it doesn't, and fails loudly with the repair command instead of failing later in the UI.

Reported by @smartobc-stephen in [#1409](https://github.com/backnotprop/plannotator/issues/1409), with a diagnosis accurate down to the fix.

[#1411](https://github.com/backnotprop/plannotator/pull/1411), closing [#1409](https://github.com/backnotprop/plannotator/issues/1409)

### Additional Changes

- **Herdr Annotate**: the README and plannotator.ai now introduce [Herdr Annotate](https://github.com/plannotator/herdr-annotate), terminal-side annotation built on Plannotator TUI, with a landing page at [plannotator.ai/tui-annotate](https://plannotator.ai/tui-annotate). Annotations from the terminal land in the same Plannotator data directory, so both tools compound.
- **Firefox forced colors**: the plannotator.ai hero text no longer disappears for Firefox users running with "Override the colors specified by the page" or OS high contrast.

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

**Pi:** Update `@plannotator/pi-extension` to 0.27.10 and restart Pi.

**OpenCode:** Clear cache and restart:

```bash
rm -rf ~/.bun/install/cache/@plannotator
```

## What's Changed

- feat(review): mark files viewed as you scroll past them in [#1430](https://github.com/backnotprop/plannotator/pull/1430)
- feat: add bounded annotation undo and redo in [#1426](https://github.com/backnotprop/plannotator/pull/1426)
- feat(opencode): restore the slash commands on OpenCode 2 in [#1434](https://github.com/backnotprop/plannotator/pull/1434)
- fix(opencode): show session URLs in remote OpenCode 2 sessions in [#1435](https://github.com/backnotprop/plannotator/pull/1435)
- fix(share): invalidate stale short links in [#1425](https://github.com/backnotprop/plannotator/pull/1425)
- fix(agent-terminal): approve node-pty install scripts for npm 12 in [#1411](https://github.com/backnotprop/plannotator/pull/1411)

## Community

This release is community-shaped end to end. @jj-valentine requested undo/redo hotkeys for annotations in #828, and that request is now the bounded history system in both review surfaces. @grncdr filed the stale short-link report in #798 with a clean reproduction of the round-trip that dropped annotations. @smartobc-stephen reported the npm 12 agent-terminal failure in #1409 with a root-cause analysis so precise the fix followed it almost line for line. The auto-viewed feature and the OpenCode 2 command work both came from user reports and requests reaching us directly, and a Firefox user's report of vanishing hero text led to the forced-colors fix on the site.

Thank you all. Plannotator gets better because you tell us where it falls short.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.27.9...v0.27.10
