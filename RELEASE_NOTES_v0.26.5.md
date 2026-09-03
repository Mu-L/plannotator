Follow [@plannotator](https://x.com/plannotator) on X for updates

---

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.26.4](https://github.com/backnotprop/plannotator/releases/tag/v0.26.4)   | Skill-menu hover jitter fix (same-day patch on v0.26.3)                                                                          |
| [v0.26.3](https://github.com/backnotprop/plannotator/releases/tag/v0.26.3)   | Skill references in comments with / or $, reachable remote session URLs, worktree switcher tooltips                              |
| [v0.26.2](https://github.com/backnotprop/plannotator/releases/tag/v0.26.2)   | Single-file diff tabs render fully, no more silently dropped review files, light/dark theme pairs, palette-matched code blocks   |
| [v0.26.1](https://github.com/backnotprop/plannotator/releases/tag/v0.26.1)   | GitButler 0.22.0 compatibility via capability-probed JSON flags                                                                   |
| [v0.26.0](https://github.com/backnotprop/plannotator/releases/tag/v0.26.0)   | Edit Mode (suggest by editing the diff), Guided Review virtualization, colorblind theme, safe uninstall, installer opt-outs, OpenCode 2 support |
| [v0.25.1](https://github.com/backnotprop/plannotator/releases/tag/v0.25.1)   | Codex no longer launches on review open, annotate-last follows the live conversation, pi-todos mirror, Claude Opus 5, abandoned-gate dismissal |
| [v0.25.0](https://github.com/backnotprop/plannotator/releases/tag/v0.25.0)   | Vim keyboard controls, Approve with Notes, scriptable annotate gates, persistent Guided Reviews, memory and file-watching hardening |
| [v0.24.2](https://github.com/backnotprop/plannotator/releases/tag/v0.24.2)   | Annotate YAML/JSON/TOML config files, XDG data directory support, Codex model catalog update, Cursor sandbox escape hatch        |
| [v0.24.1](https://github.com/backnotprop/plannotator/releases/tag/v0.24.1)   | Annotate accepts parent-relative `../` file paths                                                                                |
| [v0.24.0](https://github.com/backnotprop/plannotator/releases/tag/v0.24.0)   | PR/MR artifact gallery, GitButler review support, port ranges, expanded comment editor, OpenCode + Pi fixes                       |
| [v0.23.1](https://github.com/backnotprop/plannotator/releases/tag/v0.23.1)   | Startup no longer hangs on large or slow directory trees, Ask AI input stays visible after long responses                        |
| [v0.23.0](https://github.com/backnotprop/plannotator/releases/tag/v0.23.0)   | Plan approval fix for Claude Code 2.1.199+, annotate mode version diff, binary-only `--minimal` install, reviews post without attribution |

</details>

---

## What's New in v0.26.5

This release makes annotate feedback durable, rebuilds how you annotate raw HTML pages, and fixes real bugs reported from the field: lost Pi feedback after a reload, a vim cursor hiding behind the HUD, and an installer failure on older git. Seven PRs, two from external contributors, including a first contribution from @Whamp.

### Your annotate feedback can no longer be lost

When you submitted annotate feedback after the invoking agent had already timed out, the server settled the decision with nobody listening and deleted your draft. The feedback then existed nowhere. Reported by @0okay after exactly this happened on Windows.

Now the server writes your submitted feedback to a durable record under your data directory before it deletes the draft, so a vanished consumer can no longer take your work with it. If the record cannot be written, the draft is kept as the recovery copy instead. This applies to single local file sessions; URL, folder, and last-message sessions stay fully stateless, and disabling annotate history keeps everything stateless as before.

- [#1237](https://github.com/backnotprop/plannotator/pull/1237), closing [#678](https://github.com/backnotprop/plannotator/issues/678) reported by @0okay

### Annotating HTML pages: pinpoint-first

Raw-HTML annotate sessions got a rework. Pinpoint is now the default input: hover highlights the element under your cursor, a click pins it and opens the comment composer directly, and each element annotation gets a numbered badge. Drag selection is still one toggle away, and your choice is remembered separately from markdown sessions.

Pages also open minimal: the first session hides the toolstrip, tab flags, and sidebar so you see just the page, and every session after that opens with exactly the chrome you last left visible.

Under the hood, element annotations now carry a verified CSS anchor so they restore to the same element when you re-open a page, even after the page was regenerated. Restoration is deliberately fail-closed: when the anchor cannot be trusted, the annotation falls back to text search, and text that moved elsewhere in the page is followed rather than mis-pinned. The feature shipped through two adversarial review rounds plus a 25-item QA sweep, which hardened anchor verification, capped selection sizes, kept pin badges out of printed pages, and bounded anchor building so a click on deeply nested markup can never freeze the tab.

- [#1243](https://github.com/backnotprop/plannotator/pull/1243), hardened in [#1245](https://github.com/backnotprop/plannotator/pull/1245) and [#1246](https://github.com/backnotprop/plannotator/pull/1246)

### Pi: feedback delivers after a reload

A Plannotator browser tab can outlive a Pi `/reload`. When feedback arrived from such a tab, the extension rejected the freshly reloaded runtime as the same stale session (reload preserves Pi's session id) and the feedback was dropped with an error. @Whamp diagnosed the root cause and fixed it: the extension now tracks an in-process runtime token, so a reload counts as a new active runtime and both feedback and notifications route to it. Comes with a regression test simulating the exact reload scenario.

- [#1240](https://github.com/backnotprop/plannotator/pull/1240) by @Whamp

### Vim: the cursor stays out from under the HUD

Document vim navigation used to pin the cursor target flush against the viewport edge, exactly where the sticky action bar and the key HUD float, so `j`/`k` motion at the top or bottom of a document hid the caret behind an overlay. @rNoz reported it and fixed it: cursor movement now reveals its target with a scrolloff-style margin sized to the viewport, so keyboard motion keeps the caret visible the way mouse scrolling always did.

- [#1154](https://github.com/backnotprop/plannotator/pull/1154) by @rNoz, closing [#1153](https://github.com/backnotprop/plannotator/issues/1153) reported by @rNoz

### The installer works on older git

`install.sh` failed its skills step with a misleading "network or git error" on systems whose git predates 2.25 (for example a stale Xcode Command Line Tools git), because `git clone --sparse` does not exist there. Reported by @dubbl-a. All three installers now probe for the capability and fall back to a plain shallow clone, surfacing the real git error when something else goes wrong. A follow-up in this release also pins the probe to a stable locale, so localized git builds take the fallback correctly too.

- [#1239](https://github.com/backnotprop/plannotator/pull/1239), closing [#1238](https://github.com/backnotprop/plannotator/issues/1238) reported by @dubbl-a, hardened in [#1246](https://github.com/backnotprop/plannotator/pull/1246)

### Additional Changes

- **Windows Codex wording corrected.** The README claimed Codex hooks are disabled on native Windows while the installer called them experimental and printed setup steps. The docs now agree: experimental, with manual steps ([#1241](https://github.com/backnotprop/plannotator/issues/1241) reported by @dustintran333)
- **Print stays clean.** Printing an annotated HTML page no longer bakes pin badges or pinpoint overlays into the output; inline annotation marks remain printable on purpose ([#1245](https://github.com/backnotprop/plannotator/pull/1245))
- **CI now runs every DOM suite.** Eight DOM-gated test files were silently skipping in CI, including the vim and HTML-annotate suites; they are wired in and enforced on every run

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

- Fix feedback delivery after Pi reload by @Whamp in [#1240](https://github.com/backnotprop/plannotator/pull/1240)
- fix(install): fall back to a plain shallow clone when git lacks --sparse by @backnotprop in [#1239](https://github.com/backnotprop/plannotator/pull/1239)
- fix(annotate): persist submitted feedback before deleting the draft by @backnotprop in [#1237](https://github.com/backnotprop/plannotator/pull/1237)
- fix(vim): keep the j/k cursor clear of the HUD bands when scrolling by @rNoz in [#1154](https://github.com/backnotprop/plannotator/pull/1154)
- feat(annotate): pinpoint-first raw-HTML sessions with element anchors and a minimal-first render by @backnotprop in [#1243](https://github.com/backnotprop/plannotator/pull/1243)
- chore: fold in pre-release QA findings by @backnotprop in [#1245](https://github.com/backnotprop/plannotator/pull/1245)
- fix: address the three pre-release sweep findings by @backnotprop in [#1246](https://github.com/backnotprop/plannotator/pull/1246)

## New Contributors

- @Whamp made their first contribution in [#1240](https://github.com/backnotprop/plannotator/pull/1240)

## Community

@Whamp hit the Pi reload bug in daily use, traced it to session identity surviving the reload, and shipped the fix with a regression test. First contribution, and a precise one.

@rNoz continues to make vim mode better than we left it: he filed the HUD occlusion report ([#1153](https://github.com/backnotprop/plannotator/issues/1153)) with a demo video and fixed it himself, including a pure scroll-math helper with its own test suite.

Issue reporters this release:

- @0okay reported the lost-feedback failure ([#678](https://github.com/backnotprop/plannotator/issues/678)) that drove the durable-submission work
- @dubbl-a reported the old-git installer failure ([#1238](https://github.com/backnotprop/plannotator/issues/1238)) with the exact git version and error output that made the fix straightforward
- @dustintran333 caught the README contradicting the installer on Windows Codex hooks ([#1241](https://github.com/backnotprop/plannotator/issues/1241))

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.26.4...v0.26.5
