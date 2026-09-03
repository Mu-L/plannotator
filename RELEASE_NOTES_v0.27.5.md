Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.27.4](https://github.com/backnotprop/plannotator/releases/tag/v0.27.4)   | Portable Guided Review exports, guides.show share links, guide CLI, favicon switcher, jj Call Flow                               |
| [v0.27.3](https://github.com/backnotprop/plannotator/releases/tag/v0.27.3)   | Folder watcher freeze fix on large repos, first SBOM-attested release pipeline                                                   |
| [v0.27.2](https://github.com/backnotprop/plannotator/releases/tag/v0.27.2)   | Mobile plan and code review, Codex CLI 0.147 fix, folder annotate cold-start, configurable markdown extensions |
| [v0.27.1](https://github.com/backnotprop/plannotator/releases/tag/v0.27.1)   | Open-in-editor launch fix, file headers respect Viewed/Git-add visibility toggles                                                |
| [v0.27.0](https://github.com/backnotprop/plannotator/releases/tag/v0.27.0)   | Call Flow analysis, --tailscale remote reviews, review panel remembers your view, Pi rebuild (breaking command rename), focus-mode shortcut |
| [v0.26.8](https://github.com/backnotprop/plannotator/releases/tag/v0.26.8)   | Placed comment markers on HTML pages, shift-click multi-select, live app annotation                                              |
| [v0.26.7](https://github.com/backnotprop/plannotator/releases/tag/v0.26.7)   | Pinpoint targets any element on HTML pages, smarter hover labels, zero-scan hit testing                                          |
| [v0.26.6](https://github.com/backnotprop/plannotator/releases/tag/v0.26.6)   | Fixed empty environment variables in sandboxed sessions (Bun 1.3.14 builds)                                                      |
| [v0.26.5](https://github.com/backnotprop/plannotator/releases/tag/v0.26.5)   | HTML pinpoint element annotations, durable annotate submissions, installer fallback for old git, vim HUD cursor fix              |
| [v0.26.4](https://github.com/backnotprop/plannotator/releases/tag/v0.26.4)   | Skill-menu hover jitter fix (same-day patch on v0.26.3)                                                                          |
| [v0.26.3](https://github.com/backnotprop/plannotator/releases/tag/v0.26.3)   | Skill references in comments with / or $, reachable remote session URLs, worktree switcher tooltips                              |
| [v0.26.2](https://github.com/backnotprop/plannotator/releases/tag/v0.26.2)   | Single-file diff tabs render fully, no more silently dropped review files, light/dark theme pairs, palette-matched code blocks   |

</details>

## What's New in v0.27.5

You can now annotate your running app. Point `plannotator annotate` at a localhost URL and the actual application opens inside the annotate UI: click any element to comment on it, press Esc to use the app normally, and send it all back to your agent. This release also brings configurable Agent TUI placement, collapsed lockfiles in code review, and a wave of fixes across Pi, VS Code, and the annotation surface. Eighteen PRs, three from first-time contributors.

### Annotate your running app

`plannotator annotate http://localhost:5173` no longer converts the page to a snapshot. A per-session loopback proxy mirrors your dev server and opens the real, running app inside the annotate UI, hot reload and SPA navigation included. Click any element to pin a comment on it, shift-click to join more elements into the same comment, and use placed numbered markers to track everything. `--static` forces the old conversion; `--app` forces live mode and fails loudly if the server is not reachable.

The security boundary is deliberate: the proxy binds loopback only, validates the Host header before touching your app, authenticates every message between the page and the editor with a per-session token, and refuses to run at all in remote or tailnet-published sessions (use `--static` there). Live sessions write no session content to disk beyond your annotation draft, which is keyed per target app.

One behavior change to know: under `PLANNOTATOR_REMOTE`, annotating a localhost URL previously converted the page silently. It now exits with a clear message asking for `--static`, because silently converting when you asked for the live app hides what you are actually reviewing.

This closes the oldest open feature request in the tracker. Thanks @JulianS-Uni for the original ask in [#642](https://github.com/backnotprop/plannotator/issues/642), and @notxcain, who saw this feature early and built the first working take on a preview proxy in [#1049](https://github.com/backnotprop/plannotator/pull/1049) before we landed a from-scratch implementation.

- [#1352](https://github.com/backnotprop/plannotator/pull/1352), [#1363](https://github.com/backnotprop/plannotator/pull/1363), [#1364](https://github.com/backnotprop/plannotator/pull/1364) by @backnotprop, closing [#642](https://github.com/backnotprop/plannotator/issues/642)

### One interaction model for HTML and live pages

HTML and live-app annotate sessions now open with annotation armed: hover outlines what you are pointing at, a click opens the comment composer. Press Esc and you are in interact mode, where clicks, forms, and navigation reach the page itself. The pen button in the header (or Mod+Shift+A) re-arms annotation, text selection comments work in both modes, and the eye button hides every floating control when you just want to read. These surfaces are comment-only now: the markup-delete and label tools were markdown concepts that never fit pages, and removing them made the whole flow simpler. On phones and tablets the same controls live in the Options menu.

This also fixes the class of bug where a JS-driven page could not be used at all during annotation, reported by @Chrysweel in [#1360](https://github.com/backnotprop/plannotator/issues/1360) for slide decks.

- Part of [#1352](https://github.com/backnotprop/plannotator/pull/1352) and [#1363](https://github.com/backnotprop/plannotator/pull/1363), closing [#1360](https://github.com/backnotprop/plannotator/issues/1360)

### Put the Agent TUI where you want it

The annotate-mode agent terminal can now dock Left or Right, or stay Hidden until you ask for it. The preference persists in `~/.plannotator/config.json`, and the terminal's Position control lives in its Display popover with a matching entry in Settings. A bug fix rides along: entering wide mode used to unmount the terminal and kill a running agent session; it now stays alive in the background.

- [#1050](https://github.com/backnotprop/plannotator/pull/1050) by @leoreisdias

### Lockfiles stop burying your review

Generated files (lockfiles, minified bundles, source maps, and anything marked `linguist-generated` in `.gitattributes`) now start collapsed in the all-files review view, the way GitHub treats them. The patch itself is never filtered; a visible notice shows what was collapsed and one click expands any of it.

- [#1346](https://github.com/backnotprop/plannotator/pull/1346) by @backnotprop, closing [#1317](https://github.com/backnotprop/plannotator/issues/1317) reported by @FluxxField

### Your VS Code theme choice wins

The VS Code extension used to force the IDE's colors onto the panel, so choosing Plannotator's light theme in a dark IDE gave you a broken mix. Now your chosen theme always wins and only the System setting follows the IDE, with a one-time migration so panels upgraded from older versions follow a light IDE again instead of being stuck on an auto-seeded dark.

- [#1357](https://github.com/backnotprop/plannotator/pull/1357), [#1362](https://github.com/backnotprop/plannotator/pull/1362) by @backnotprop, closing [#1053](https://github.com/backnotprop/plannotator/issues/1053) reported by @it-sha

### Pi fixes

Three fixes for the Pi extension. `thinking: "max"` in phase config is accepted now (the whitelist predated Pi adding the level) and unrecognized values warn instead of vanishing, closing [#1304](https://github.com/backnotprop/plannotator/issues/1304) reported by @edision. Hosts that do not expose Pi's project-trust capability get an honest warning instead of being told to update Pi, closing [#1353](https://github.com/backnotprop/plannotator/issues/1353) reported by @materemias from OMP. And turning plan mode off can no longer leave stale planning instructions steering the session, closing [#1320](https://github.com/backnotprop/plannotator/issues/1320) reported by @nwhitley-trAIner.

- [#1356](https://github.com/backnotprop/plannotator/pull/1356), [#1355](https://github.com/backnotprop/plannotator/pull/1355), [#1348](https://github.com/backnotprop/plannotator/pull/1348) by @backnotprop

### Additional Changes

- **Shift+1-4 switches annotation mode** from the keyboard, and the shortcuts yield when you are typing into the comment toolbar. [#1244](https://github.com/backnotprop/plannotator/pull/1244) by @galmadar
- **The review annotation toolbar stays on screen** when the sidebar is closed, clamped exactly to the viewport. [#1354](https://github.com/backnotprop/plannotator/pull/1354) by @unexge
- **Concurrent settings writes no longer lose changes**: config saves take a bounded advisory lock, and two server processes sharing a data dir both land their writes. Part of [#1364](https://github.com/backnotprop/plannotator/pull/1364)
- **guides.show touches**: two real example guides linked on the landing page, a "Made with Plannotator" link in the viewer header, and a footer credit to diffs.com. [#1339](https://github.com/backnotprop/plannotator/pull/1339), [#1340](https://github.com/backnotprop/plannotator/pull/1340), [#1342](https://github.com/backnotprop/plannotator/pull/1342), [#1347](https://github.com/backnotprop/plannotator/pull/1347)
- **Docs caught up with the code**: the annotate command page covers live apps, and the config reference documents the new Agent TUI settings. [#1361](https://github.com/backnotprop/plannotator/pull/1361)
- **Security scanning**: guides.show share links are allowlisted in gitleaks so encrypted share URLs stop tripping secret scanning. [#1343](https://github.com/backnotprop/plannotator/pull/1343)

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

## What's Changed

- guides-show: drop the @ redirect on the 2x screenshot, credit diffs.com in the footer by @backnotprop in [#1339](https://github.com/backnotprop/plannotator/pull/1339)
- guides-show: "Made with Plannotator" link in the viewer header by @backnotprop in [#1340](https://github.com/backnotprop/plannotator/pull/1340)
- guides-show: link two real example guides under the screenshot by @backnotprop in [#1342](https://github.com/backnotprop/plannotator/pull/1342)
- ci(security): allowlist guides.show share links in gitleaks by @backnotprop in [#1343](https://github.com/backnotprop/plannotator/pull/1343)
- feat(review): collapse generated files by default in the all-files view by @backnotprop in [#1346](https://github.com/backnotprop/plannotator/pull/1346)
- guides-show: landing copy fix by @backnotprop in [#1347](https://github.com/backnotprop/plannotator/pull/1347)
- fix(pi): countermand stale plan-mode instructions on toggle-off by @backnotprop in [#1348](https://github.com/backnotprop/plannotator/pull/1348)
- feat(ui): Shift+1-4 shortcuts to switch annotation mode by @galmadar in [#1244](https://github.com/backnotprop/plannotator/pull/1244)
- feat(annotate): live local app annotation through a loopback reverse proxy by @backnotprop in [#1352](https://github.com/backnotprop/plannotator/pull/1352)
- fix(review): clamp annotation toolbar to viewport by @unexge in [#1354](https://github.com/backnotprop/plannotator/pull/1354)
- fix(pi): accept Pi's full thinking-level range and warn on unknown values by @backnotprop in [#1356](https://github.com/backnotprop/plannotator/pull/1356)
- fix(vscode): user-chosen theme wins over IDE theme sync by @backnotprop in [#1357](https://github.com/backnotprop/plannotator/pull/1357)
- fix(pi): honest capability warning when the host lacks ctx.isProjectTrusted by @backnotprop in [#1355](https://github.com/backnotprop/plannotator/pull/1355)
- feat(annotate): configurable Agent TUI placement with durable config and Hidden state by @leoreisdias in [#1050](https://github.com/backnotprop/plannotator/pull/1050)
- docs: align AGENTS.md and public docs with the v0.27.5 behavior by @backnotprop in [#1361](https://github.com/backnotprop/plannotator/pull/1361)
- fix(vscode): migrate the legacy auto-seeded dark theme cookie to system by @backnotprop in [#1362](https://github.com/backnotprop/plannotator/pull/1362)
- fix(annotate): armed-mode interaction fixes from the v0.27.5 QA gate by @backnotprop in [#1363](https://github.com/backnotprop/plannotator/pull/1363)
- fix(server): live-proxy injection and config write hardening by @backnotprop in [#1364](https://github.com/backnotprop/plannotator/pull/1364)

## New Contributors

- @leoreisdias made their first contribution in [#1050](https://github.com/backnotprop/plannotator/pull/1050)
- @galmadar made their first contribution in [#1244](https://github.com/backnotprop/plannotator/pull/1244)
- @unexge made their first contribution in [#1354](https://github.com/backnotprop/plannotator/pull/1354)

## Contributors

Three first-time contributors landed code in this release. @leoreisdias built the Agent TUI placement feature, and it arrived alongside a stack of other PRs from them that are working through review; more of that work lands soon. @galmadar added the Shift+1-4 annotation mode shortcuts. @unexge fixed the review toolbar drifting off screen, with before/after recordings that made the review easy.

@notxcain gets a special mention: their PR [#1049](https://github.com/backnotprop/plannotator/pull/1049) was the first working take on live localhost annotation, months before this release shipped it. We missed the PR at the time, which was our failure, not theirs.

Community reports that shaped this release:

- @JulianS-Uni requested website annotation in [#642](https://github.com/backnotprop/plannotator/issues/642), the oldest request closed by this release
- @Chrysweel reported slide decks being unusable during annotation in [#1360](https://github.com/backnotprop/plannotator/issues/1360)
- @it-sha reported the VS Code light theme bug in [#1053](https://github.com/backnotprop/plannotator/issues/1053)
- @edision reported the ignored `thinking: "max"` setting in [#1304](https://github.com/backnotprop/plannotator/issues/1304)
- @materemias filed the detailed OMP compatibility report in [#1353](https://github.com/backnotprop/plannotator/issues/1353)
- @FluxxField requested collapsed generated files in [#1317](https://github.com/backnotprop/plannotator/issues/1317)
- @nwhitley-trAIner reported the plan-mode toggle bug in [#1320](https://github.com/backnotprop/plannotator/issues/1320)
- @felipebn shared the OpenCode per-agent model config pattern in [#1059](https://github.com/backnotprop/plannotator/issues/1059)

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.27.4...v0.27.5
