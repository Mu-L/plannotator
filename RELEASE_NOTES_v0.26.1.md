Follow [@plannotator](https://x.com/plannotator) on X for updates

---

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
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
| [v0.21.3](https://github.com/backnotprop/plannotator/releases/tag/v0.21.3)   | File comments in code review, unified click-to-highlight comments, VS Code clipboard/keyboard bridge, Codex Ask AI on app-server transport, CLI subcommand help |

</details>

---

## What's New in v0.26.1

A single-fix patch: code review works again in GitButler workspaces running GitButler CLI 0.22.0. Because this patch landed a day after v0.26.0, the full v0.26.0 feature notes are included below; if you are updating from v0.25.x, everything in both sections is new to you.

### GitButler 0.22.0 compatibility

GitButler's CLI changed its JSON output flag twice this year. Their June change removed `--json` in favor of a global `--format json`, which is the syntax Plannotator's GitButler integration used and the one GitButler 0.21.x accepts. Their July cleanup then reverted it: GitButler 0.22.0 accepts only `--json` and rejects `--format` outright, so opening a review in a GitButler workspace on 0.22.0 failed immediately with a contract error.

Plannotator now probes capability instead of assuming a spelling. It tries `--format json status` first, and only when that fails with the specific unexpected-argument rejection does it retry once with `--json status`. Real status failures never retry and still fail loudly. The accepted spelling is remembered for the session, so 0.22.0 installs pay the failed probe once. If a future GitButler rejects both spellings, the error names both and the minimum supported version. The fix lives in the shared GitButler core, so the Bun and Pi runtimes both get it.

- [#1216](https://github.com/backnotprop/plannotator/pull/1216), closing [#1215](https://github.com/backnotprop/plannotator/issues/1215) reported by @swushi

---

## What's New in v0.26.0

v0.26.0 introduces Edit Mode, makes Guided Review fast on large changesets, adds a colorblind theme and a safe uninstall command, and hardens the installer, the review server, and the OpenCode plugin. Thirty-two PRs shipped in this release; seven came from external contributors plus one co-authored port, and four contributors landed their first PR.

### Edit Mode: author suggestions by editing the code

A new experimental way to give review feedback: click **Edit** on a file in the all-files review view and fix the code right there in the diff. When you finish, your net changes become ordinary suggestion annotations, the same shape the suggestion editor produces, with the original code in a fenced `Replaces:` block and your replacement in `Suggested code:` so the applying agent can validate the anchor. You can also select text mid-edit and turn the selection into an annotation. The browser never writes to your files on disk; the agent applies the suggestions from your feedback.

Edit Mode is off by default behind Settings > Editor > "Edit Code to Suggest". A one-time announcement dialog introduces the feature with an embedded screen recording of the flow and an explicit enable switch. The switch is deliberate design: the first draft used a primary "Turn it on" button, which reads as a generic continue and invites reflex clicks, so the opt-in became a switch you must consciously flip before the neutral Done button applies it.

Two fixes landed before release from our own QA pass: Discard now repaints the pristine diff immediately instead of leaving edited pixels on screen until an async rerender, and the same repaint removes a brief flash of stale content on the Suggest path.

- [#1193](https://github.com/backnotprop/plannotator/pull/1193), [#1207](https://github.com/backnotprop/plannotator/pull/1207), [#1209](https://github.com/backnotprop/plannotator/pull/1209), [#1213](https://github.com/backnotprop/plannotator/pull/1213)

### Guided Review handles large changesets

Guided Review used to mount a full code viewer for every file in the guide. On a large guide that meant hundreds of live viewers, around a million shadow DOM elements, 770MB of heap, and scrolling at 4 frames per second, with the view taking close to a minute to open. A shared viewport coordinator now keeps at most 8 file viewers mounted at once and swaps the rest for lightweight placeholders as you scroll. The same guide now opens in around a hundred milliseconds, holds ~140MB, and scrolls at full frame rate. Section reviewed-state, annotations, and search behave exactly as before.

- Authored by @alexanderkreidich in [#1158](https://github.com/backnotprop/plannotator/pull/1158), with its regression tests wired into CI in [#1200](https://github.com/backnotprop/plannotator/pull/1200)

### Colorblind theme

A new built-in theme designed for red-green color vision deficiency, which covers most color blindness. Additions render blue and deletions orange across diff backgrounds, gutters, indicators, and syntax highlighting, in both light and dark. The palette was tuned with CIEDE2000 color-difference measurements under simulated deuteranopia and protanopia; the worst-case separation between "added" and "removed" improves from 1.7 (indistinguishable) to 9.0 (clearly distinct). A separate tritanopia variant was evaluated and skipped on the data: the default palette already reads correctly for tritanopes.

- [#1192](https://github.com/backnotprop/plannotator/pull/1192)

### Safe uninstall

`plannotator uninstall` removes the binary, skills, hooks, and per-agent integrations, and walks through every host it recognizes (Claude Code, Codex, OpenCode, Gemini, Kiro, and friends) before touching the binary. Your data is preserved by default: plans, history, drafts, and settings stay unless you pass `--purge`. `--dry-run` shows the full removal list without deleting anything, and `--yes` skips the confirmation for scripted use. Host cleanup is required, not optional: if a host's cleanup fails, the uninstall stops with manual guidance rather than leaving a half-removed install behind.

- [#1170](https://github.com/backnotprop/plannotator/pull/1170), [#1177](https://github.com/backnotprop/plannotator/pull/1177)

### Review server memory stays bounded on huge files

Staging a very large text file used to balloon the review server; a 51MB file drove resident memory to around 240MB. Tracked files above 5MiB are now excluded from the rendered diff and shown as bounded stubs, the same treatment untracked files already had. A follow-up fix hardened the failure path: the original implementation probed object sizes with one `git cat-file --batch-check` call, and if that single call failed, every file in the review rendered as "Binary files differ" with no visible error. The size bound is now enforced by git itself through `core.bigFileThreshold`, so a failed probe degrades gracefully instead of blanking the review.

- Authored by @rNoz in [#1167](https://github.com/backnotprop/plannotator/pull/1167), closing [#1120](https://github.com/backnotprop/plannotator/issues/1120); hardened in [#1205](https://github.com/backnotprop/plannotator/pull/1205)

### Installer: opt-outs, credential-free provenance, and honest failures

The install scripts gained a family of opt-outs: `--skip-codex`, `--skip-gemini`, `--skip-kiro`, `--skip-opencode`, and now `--skip-skills`, each with a matching environment variable and `skipInstall` config key. Skipping means the installer writes nothing for that scope and never removes what a previous install wired. Attestation verification (`--verify-attestation`) now works with zero GitHub credentials by fetching the attestation bundle from GitHub's public API, falling back to authenticated gh only when needed. Both designs came from a single unusually rigorous report by @astradevkin, including the discovery of the public attestations endpoint.

Two honesty fixes shipped alongside: a failed skills checkout used to report success because of a POSIX errexit subtlety (the failure now aborts loudly, which is exactly why `--skip-skills` exists for offline installs), and installs on Windows PowerShell below 7.2 no longer die on git writing progress to stderr. The installer also authenticates its version lookup when a GitHub token is present, avoiding the anonymous 60-requests-per-hour rate limit on shared networks.

- [#1197](https://github.com/backnotprop/plannotator/pull/1197) closing [#1178](https://github.com/backnotprop/plannotator/issues/1178), [#1201](https://github.com/backnotprop/plannotator/pull/1201), [#1157](https://github.com/backnotprop/plannotator/pull/1157) by @tbontb-iaq closing [#1156](https://github.com/backnotprop/plannotator/issues/1156), and 15bca139 closing [#1162](https://github.com/backnotprop/plannotator/issues/1162)

### OpenCode 2 support (experimental)

Plan review now works on OpenCode 2 through a V2 plugin adapter that shares the same host-independent plan submission path as every other agent, with OpenCode 1 behavior fully preserved. The plugin's packaging also got two weight reductions worth noticing: the prerelease `@opencode-ai/plugin` nightly is no longer a runtime dependency (it was pulling a 95MB, 101-package closure into every install), and the `bun` peerDependency is gone (npm auto-installed the entire 50MB Bun binary into every consumer's node_modules; the runtime requirement now lives in `engines`, which is informational). Known V2 limitations are documented in the plugin README: no tool abort signal, and agent switching after approval is manual.

- Authored by @sergical in [#1194](https://github.com/backnotprop/plannotator/pull/1194); packaging fixes in [#1199](https://github.com/backnotprop/plannotator/pull/1199) and [#1204](https://github.com/backnotprop/plannotator/pull/1204); CI coverage in [#1202](https://github.com/backnotprop/plannotator/pull/1202) and [#1203](https://github.com/backnotprop/plannotator/pull/1203)

### Annotate understands natural language arguments

Slash-command hosts forward whatever the user typed, so `/plannotator-annotate look at notes.md please` used to fail with "File not found: look". The annotate CLI now probes each word and proceeds when exactly one resolves to a real file, URL, or folder. When two or more resolve, it errors naming every candidate rather than guessing, which also fixes a silent bug: `annotate a.md b.md` used to open `a.md` and drop `b.md` without a word. When nothing resolves, the CLI hands off to the reading agent with the words it tried, so the agent can re-run with a concrete target. A companion fix taught the token probe to recognize URLs wrapped in punctuation.

- [#1183](https://github.com/backnotprop/plannotator/pull/1183) closing [#1182](https://github.com/backnotprop/plannotator/issues/1182) reported by @technicalpickles, and [#1187](https://github.com/backnotprop/plannotator/pull/1187) co-authored with @technicalpickles

### Additional Changes

- **Markdown reference links render.** `[ref][1]` style links now render as real links in plans instead of raw text, closing a long-standing request ([#1168](https://github.com/backnotprop/plannotator/pull/1168) by @rNoz, closing [#923](https://github.com/backnotprop/plannotator/issues/923) reported by @Thraka)
- **Copy feedback shortcut.** `Cmd/Ctrl+Shift+Y` copies the review feedback to the clipboard from anywhere in code review ([#1155](https://github.com/backnotprop/plannotator/pull/1155) by @rian-dolphin)
- **Pi review ports release on shutdown.** Back-to-back reviews in Pi no longer hit EADDRINUSE ([#1160](https://github.com/backnotprop/plannotator/pull/1160) by @SyahrulBhudiF, closing [#1159](https://github.com/backnotprop/plannotator/issues/1159))
- **Clipboard works in remote HTTP sessions.** Copy actions fall back to the legacy clipboard path in insecure browser contexts instead of failing silently ([#1174](https://github.com/backnotprop/plannotator/pull/1174), closing [#1173](https://github.com/backnotprop/plannotator/issues/1173) reported by @quanweiZhou)
- **Partial GitLab submissions surface.** When some GitLab review comments post and others fail, the result reports exactly which ones failed instead of claiming success ([#1164](https://github.com/backnotprop/plannotator/pull/1164))
- **Archive is read-only everywhere.** Archive mode now rejects mutating actions server-side on both runtimes ([#1171](https://github.com/backnotprop/plannotator/pull/1171))
- **Privacy and network docs corrected.** The docs now accurately describe what leaves your machine and when ([#1163](https://github.com/backnotprop/plannotator/pull/1163))
- **Sharing article redirect fixed.** A legacy marketing URL no longer chains through multiple redirects ([#1180](https://github.com/backnotprop/plannotator/pull/1180))
- **@pierre/diffs upgraded to 1.3.2.** Staged through 1.2.12 and a theme major, with hover and line-background rendering verified across intensities and themes ([#1188](https://github.com/backnotprop/plannotator/pull/1188), [#1190](https://github.com/backnotprop/plannotator/pull/1190), [#1191](https://github.com/backnotprop/plannotator/pull/1191))

---

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

---

## What's Changed

**v0.26.1**

- fix: fall back across GitButler JSON flag syntaxes (but 0.22.0) by @backnotprop in [#1216](https://github.com/backnotprop/plannotator/pull/1216)
- ci: auto-sync install scripts to their dedicated S3 bucket by @backnotprop in [#1214](https://github.com/backnotprop/plannotator/pull/1214)

**v0.26.0**

- feat: add Cmd/Ctrl+Shift+Y shortcut to copy review feedback by @rian-dolphin in [#1155](https://github.com/backnotprop/plannotator/pull/1155)
- fix: authenticate installer version lookup to avoid anonymous rate limit by @tbontb-iaq in [#1157](https://github.com/backnotprop/plannotator/pull/1157)
- perf: virtualize Guided Review file cards by @alexanderkreidich in [#1158](https://github.com/backnotprop/plannotator/pull/1158)
- fix: release Pi review ports on session shutdown by @SyahrulBhudiF in [#1160](https://github.com/backnotprop/plannotator/pull/1160)
- docs: correct privacy and network claims by @backnotprop in [#1163](https://github.com/backnotprop/plannotator/pull/1163)
- fix: surface partial GitLab comment submissions by @backnotprop in [#1164](https://github.com/backnotprop/plannotator/pull/1164)
- fix: bound server memory for large tracked-file diffs by @rNoz in [#1167](https://github.com/backnotprop/plannotator/pull/1167)
- feat: render markdown reference links by @rNoz in [#1168](https://github.com/backnotprop/plannotator/pull/1168)
- feat: add safe uninstall lifecycle by @backnotprop in [#1170](https://github.com/backnotprop/plannotator/pull/1170)
- fix: enforce archive read-only surfaces by @backnotprop in [#1171](https://github.com/backnotprop/plannotator/pull/1171)
- fix: fall back to legacy copy in insecure browser contexts by @backnotprop in [#1174](https://github.com/backnotprop/plannotator/pull/1174)
- fix: require host cleanup before binary removal in uninstall by @backnotprop in [#1177](https://github.com/backnotprop/plannotator/pull/1177)
- fix: avoid sharing article redirect chain by @backnotprop in [#1180](https://github.com/backnotprop/plannotator/pull/1180)
- fix: resolve natural-language annotate arguments or hand off to the agent by @backnotprop in [#1183](https://github.com/backnotprop/plannotator/pull/1183)
- fix: recognize wrapped URLs in annotate token probe by @backnotprop and @technicalpickles in [#1187](https://github.com/backnotprop/plannotator/pull/1187)
- chore(deps): bump @pierre/diffs to 1.2.12 (stage 1 of 2) by @backnotprop in [#1188](https://github.com/backnotprop/plannotator/pull/1188)
- chore(deps): bump @pierre/diffs to 1.3.x with theme major (stage 2 of 2) by @backnotprop in [#1190](https://github.com/backnotprop/plannotator/pull/1190)
- chore(deps): bump @pierre/diffs to 1.3.2 by @backnotprop in [#1191](https://github.com/backnotprop/plannotator/pull/1191)
- feat: add colorblind theme by @backnotprop in [#1192](https://github.com/backnotprop/plannotator/pull/1192)
- feat: author suggestions by editing code in place (experimental) by @backnotprop in [#1193](https://github.com/backnotprop/plannotator/pull/1193)
- feat: add OpenCode 2 plan review adapter by @sergical in [#1194](https://github.com/backnotprop/plannotator/pull/1194)
- feat: Codex opt-out and credential-free attestation verification by @backnotprop in [#1197](https://github.com/backnotprop/plannotator/pull/1197)
- fix: drop runtime dependency on prerelease plugin nightly by @backnotprop in [#1199](https://github.com/backnotprop/plannotator/pull/1199)
- test: repair guide virtualization mock and run its tests in CI by @backnotprop in [#1200](https://github.com/backnotprop/plannotator/pull/1200)
- fix: repair the skills checkout guard, add --skip-skills by @backnotprop in [#1201](https://github.com/backnotprop/plannotator/pull/1201)
- fix(ci): repair the OpenCode 2 installed-package smoke by @backnotprop in [#1202](https://github.com/backnotprop/plannotator/pull/1202)
- ci: glob the OpenCode smoke tarball instead of pinning the version by @backnotprop in [#1203](https://github.com/backnotprop/plannotator/pull/1203)
- fix: drop the bun peerDependency from the OpenCode plugin by @backnotprop in [#1204](https://github.com/backnotprop/plannotator/pull/1204)
- fix: keep large-diff memory bound when the object-size probe fails by @backnotprop in [#1205](https://github.com/backnotprop/plannotator/pull/1205)
- feat: announce Edit Mode with an opt-in welcome dialog by @backnotprop in [#1207](https://github.com/backnotprop/plannotator/pull/1207)
- fix: repaint pristine diff immediately on edit-mode Discard by @backnotprop in [#1209](https://github.com/backnotprop/plannotator/pull/1209)
- fix: make the Edit Mode opt-in an explicit switch by @backnotprop in [#1213](https://github.com/backnotprop/plannotator/pull/1213)

## New Contributors

- @rian-dolphin made their first contribution in [#1155](https://github.com/backnotprop/plannotator/pull/1155)
- @tbontb-iaq made their first contribution in [#1157](https://github.com/backnotprop/plannotator/pull/1157)
- @SyahrulBhudiF made their first contribution in [#1160](https://github.com/backnotprop/plannotator/pull/1160)
- @sergical made their first contribution in [#1194](https://github.com/backnotprop/plannotator/pull/1194)

## Contributors

@alexanderkreidich rebuilt Guided Review's rendering around a viewport coordinator ([#1158](https://github.com/backnotprop/plannotator/pull/1158)), turning minute-long opens of large guides into instant ones, and backed it with the performance measurements quoted above.

@rNoz shipped two fixes this release: the tracked-file memory bound for the review server ([#1167](https://github.com/backnotprop/plannotator/pull/1167)) and markdown reference link rendering ([#1168](https://github.com/backnotprop/plannotator/pull/1168)), the latter closing a request that had been open since [#923](https://github.com/backnotprop/plannotator/issues/923).

@sergical brought plan review to OpenCode 2 ([#1194](https://github.com/backnotprop/plannotator/pull/1194)) and filed the follow-up to move the adapter to the stable plugin API ([#1196](https://github.com/backnotprop/plannotator/issues/1196)). First contribution.

@SyahrulBhudiF reported the Pi port exhaustion bug and then fixed it himself ([#1159](https://github.com/backnotprop/plannotator/issues/1159), [#1160](https://github.com/backnotprop/plannotator/pull/1160)). First contribution.

@tbontb-iaq did the same for the installer rate limit: report ([#1156](https://github.com/backnotprop/plannotator/issues/1156)) and fix ([#1157](https://github.com/backnotprop/plannotator/pull/1157)). First contribution.

@rian-dolphin added the copy-feedback keyboard shortcut ([#1155](https://github.com/backnotprop/plannotator/pull/1155)). First contribution.

@technicalpickles reported the natural-language annotate failure ([#1182](https://github.com/backnotprop/plannotator/issues/1182)), authored a parallel fix whose URL-probe catch and test coverage were ported with co-author credit ([#1187](https://github.com/backnotprop/plannotator/pull/1187)), and supplied the history that anchored the final design.

@astradevkin filed the report that shaped the installer work in [#1197](https://github.com/backnotprop/plannotator/pull/1197): the per-agent opt-out design and the discovery that attestation bundles can be fetched credential-free from GitHub's public API, complete with negative controls.

Community members who reported issues that drove changes in this release:

- @quanweiZhou: [#1173](https://github.com/backnotprop/plannotator/issues/1173) (clipboard failing in remote HTTP sessions)
- @diegohb: [#1162](https://github.com/backnotprop/plannotator/issues/1162) (installer failing on Windows PowerShell below 7.2)
- @Thraka: [#923](https://github.com/backnotprop/plannotator/issues/923) (markdown reference links)

## Community

@swushi reported the GitButler 0.22.0 breakage within hours of v0.26.0 shipping, with a complete reproduction, the upstream PR that caused it, and the capability-based fallback design the fix uses ([#1215](https://github.com/backnotprop/plannotator/issues/1215)). Reports of this quality make same-day patches possible.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.26.0...v0.26.1 (patch) and https://github.com/backnotprop/plannotator/compare/v0.25.1...v0.26.0 (feature release)
