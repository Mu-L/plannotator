Follow [@plannotator](https://x.com/plannotator) on X for updates

---

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.24.2](https://github.com/backnotprop/plannotator/releases/tag/v0.24.2)   | Annotate YAML/JSON/TOML config files, XDG data directory support, Codex model catalog update, Cursor sandbox escape hatch        |
| [v0.24.1](https://github.com/backnotprop/plannotator/releases/tag/v0.24.1)   | Annotate accepts parent-relative `../` file paths                                                                                |
| [v0.24.0](https://github.com/backnotprop/plannotator/releases/tag/v0.24.0)   | PR/MR artifact gallery, GitButler review support, port ranges, expanded comment editor, OpenCode + Pi fixes                       |
| [v0.23.1](https://github.com/backnotprop/plannotator/releases/tag/v0.23.1)   | Startup no longer hangs on large or slow directory trees, Ask AI input stays visible after long responses                        |
| [v0.23.0](https://github.com/backnotprop/plannotator/releases/tag/v0.23.0)   | Plan approval fix for Claude Code 2.1.199+, annotate mode version diff, binary-only `--minimal` install, reviews post without attribution |
| [v0.22.0](https://github.com/backnotprop/plannotator/releases/tag/v0.22.0)   | Git-status "All changes" default review view, Commits panel with per-commit diffs, Guided Review, Pi + GitHub Copilot CLI review engines |
| [v0.21.4](https://github.com/backnotprop/plannotator/releases/tag/v0.21.4)   | Markdown math rendering, PR Overview panel with annotatable description and comments, agent instructions in code review, media parsing fixes |
| [v0.21.3](https://github.com/backnotprop/plannotator/releases/tag/v0.21.3)   | File comments in code review, unified click-to-highlight comments, VS Code clipboard/keyboard bridge, Codex Ask AI on app-server transport, CLI subcommand help |
| [v0.21.2](https://github.com/backnotprop/plannotator/releases/tag/v0.21.2)   | Custom reviews as Agent Skills, Cursor + OpenCode review engines, whole-file/general findings, deleted-annotation fix, Codex Ask AI outside git repos |
| [v0.21.1](https://github.com/backnotprop/plannotator/releases/tag/v0.21.1)   | Annotate-last blank-page fix on multi-message sessions                                                                            |
| [v0.21.0](https://github.com/backnotprop/plannotator/releases/tag/v0.21.0)   | Direct document editing in annotate mode, live git-status file tree, in-app agent terminal, open files in external apps, HTML renders as HTML |

</details>

---

## What's New in v0.25.0

This is the largest community release Plannotator has had. Eighteen pull requests landed since v0.24.2, thirteen of them from community members, and eight authors made their first contribution. The release adds an optional Vim keyboard layer, lets approvals carry your notes to the agent, makes gated annotate sessions scriptable, persists Guided Reviews across sessions, and hardens memory use, file watching, and multi-extension behavior across the board.

### Vim keyboard controls for plan review and annotate

Plan review and annotate mode now have an optional Vim-style keyboard layer. Turn it on in Settings, then move through the document with `j`/`k` by block, refine into inline targets and exact text with `l`/`h` and the text motions, select with `v`/`V`, and create comments, redlines, and quick labels without touching the mouse. An optional HUD shows a target reticle, live keypress feedback, and a complete `?` key map while you learn. It works in raw HTML annotate sessions too.

Everything is off by default. If keyboard-driven review is not how you work, close the one-time announcement and nothing changes.

- Authored by @backnotprop in [#1127](https://github.com/backnotprop/plannotator/pull/1127)

### Approve with Notes

Approving a gated annotate session used to throw away any annotations you had made along the way. Approval was a bare "approved" and your notes vanished. Now approval can carry them: the agent receives your annotations together with the approval across Claude Code, OpenCode, and Pi, with a customizable `approvedWithNotes` prompt template for tuning the wording. The approve flow also validates stale saved edits instead of silently proceeding, and approve-with-notes anchors to the correct message in multi-message annotate-last sessions.

- Authored by @rNoz in [#1092](https://github.com/backnotprop/plannotator/pull/1092), closing [#930](https://github.com/backnotprop/plannotator/issues/930) requested by @tuanddd

### Strict automation mode for gated annotate

`plannotator annotate --gate --json` always exited 0 no matter what the reviewer decided, so scripts could not use it as a real approval gate. A new strict mode fixes that: `--require-approval` exits nonzero unless the reviewer approves (configuration errors exit with a distinct code so automation never mistakes a typo for a rejection), and `--result-file` publishes the decision atomically with a write-temp plus no-clobber rename, so readers never see a partial record. The decision always reaches stdout before file publication, so a failed publish cannot destroy a completed review. Existing non-strict behavior is byte-identical.

- Authored by @rNoz in [#1091](https://github.com/backnotprop/plannotator/pull/1091), closing [#1090](https://github.com/backnotprop/plannotator/issues/1090)

### Annotate watches your file, not your whole folder

Keeping an open source document synchronized with disk used to subscribe to the file's entire parent directory, so unrelated sibling files, nested changes, and git metadata churn all triggered pointless reconciliation. The watcher now tracks exactly the open files, in both the Bun and Pi servers, and survives atomic editor saves and platform quirks that previously could crash the watch on Linux.

- Authored by @rNoz in [#1089](https://github.com/backnotprop/plannotator/pull/1089), closing [#1088](https://github.com/backnotprop/plannotator/issues/1088)

### Guided Reviews persist across sessions

A successful Guided Review is now saved automatically under your data directory, keyed to the repository. The guide screen shows your previous guides with their reviewed-progress, lets you reopen them read-through with per-section reviewed state intact, and flags a guide whose commit no longer matches the head under review. Disable persistence with `PLANNOTATOR_GUIDE_HISTORY=0` or `"guideHistory": false` in `config.json`.

- Authored by @backnotprop in [#1115](https://github.com/backnotprop/plannotator/pull/1115), closing [#1112](https://github.com/backnotprop/plannotator/issues/1112) requested by @alexanderkreidich

### Folder annotate sessions get per-file version diffs

Single-file annotate has shown a "since last review" diff badge for a while. Folder sessions now get the same treatment per file: open a folder, pick a file you have annotated before, and a +N/-M badge shows what changed since your last visit, with rendered and raw diff views. Each file keeps its own version history, shared with single-file sessions of the same file, and the diff view dismisses itself when you switch to a file with no baseline.

- Authored by @BenNewman100 in [#1105](https://github.com/backnotprop/plannotator/pull/1105), closing [#1104](https://github.com/backnotprop/plannotator/issues/1104)

### Bounded memory for large untracked files

An unignored build artifact or large binary in git status could drive the review server to gigabytes of memory, and the freshness poll re-read the file every few seconds. Untracked files over 5 MiB now render as binary additions without loading their contents, freshness checks use size and mtime metadata instead of reading files, untracked diff generation is capped at four concurrent git processes, and oversized content is refused by the file-content endpoint in both runtimes.

- Authored by @kcosr in [#1118](https://github.com/backnotprop/plannotator/pull/1118), addressing the memory failure reported by @digitalmaster in [#940](https://github.com/backnotprop/plannotator/issues/940)

### Disable AI features for managed deployments

`PLANNOTATOR_AI=disabled` turns off Ask AI, Review Agents, and Guided Review launches across every server. The AI runtime is never constructed, so no agent processes are spawned or left idle, which matters on shared multi-user machines. Review and annotate flows work normally, saved guides remain readable, and capability probes degrade gracefully for older clients.

- Authored by @kcosr in [#1129](https://github.com/backnotprop/plannotator/pull/1129)

### OpenCode feedback goes to your agent, not a hardcoded one

Review feedback in OpenCode was hardwired to hand off to an agent named `build`. If you had disabled or renamed it, every feedback send failed silently. Feedback now defaults to whatever agent you were already talking to, and a configured agent name is validated against your live agent list before sending, with a warning toast and graceful fallback when it is missing. Plan approval keeps its automatic build handoff, so the plan-to-build workflow is unchanged.

- Authored by @cb-bradbeebe in [#1131](https://github.com/backnotprop/plannotator/pull/1131), closing [#1123](https://github.com/backnotprop/plannotator/issues/1123)

### Pi extension plays well with other extensions

Plannotator's Pi extension used to restore a snapshot of the global tool list when switching phases, wiping out tools other Pi extensions had activated or deactivated in the meantime. It now tracks exactly the tools it added for a phase and releases only those, leaving everyone else's selections alone. The planning phase always includes `plannotator_submit_plan`, even with a custom `planning.activeTools` configuration.

- Authored by @CodeByPeete in [#1124](https://github.com/backnotprop/plannotator/pull/1124)

### External plan execution handoff for Pi

An opt-in `executionMode: "external"` setting lets a companion extension own execution. On approval, instead of entering the executing phase, Plannotator restores the pre-planning state and emits a `plannotator:plan-approved` event carrying the plan path, content, working directory, and any approval feedback. Automatic execution remains the default and is unchanged.

- Authored by @cgngtr in [#1126](https://github.com/backnotprop/plannotator/pull/1126)

### Faster Pi extension loading

The Pi extension's imports now use exact `.ts` relative specifiers instead of extension probing, which cuts the module resolution work Pi's loader does on every session start.

- Authored by @dca123 in [#1106](https://github.com/backnotprop/plannotator/pull/1106)

### Additional Changes

- **Zed Preview in Open In App** - Zed's beta channel installs as a separate app on macOS; it is now its own entry in the Open In App menu, shown only when installed. On Linux and Windows the preview channel ships the plain `zed` binary, so the existing entry already covers it. By @backnotprop in [#1130](https://github.com/backnotprop/plannotator/pull/1130), closing [#1119](https://github.com/backnotprop/plannotator/issues/1119) requested by @graemefolk
- **YAML block scalars in frontmatter** - frontmatter values using `|` and `>` block scalars now parse correctly, including CRLF sources. By @ruaridhw in [#1101](https://github.com/backnotprop/plannotator/pull/1101)
- **Copying file annotations uses the right template** - the annotate-mode Copy button produced a plan-rejection message instead of annotate feedback. By @backnotprop in [#1109](https://github.com/backnotprop/plannotator/pull/1109), closing [#1107](https://github.com/backnotprop/plannotator/issues/1107) reported by @ZBQtesla
- **Windows cross-drive path fix** - annotation paths no longer break when the repository and temp directory live on different drives. By @BenNewman100 in [#1117](https://github.com/backnotprop/plannotator/pull/1117)
- **Save is the first tab stop in the comment popover** - keyboard users tab from the comment textarea straight to Save, with the visual layout unchanged. By @balasivagn in [#1122](https://github.com/backnotprop/plannotator/pull/1122), closing [#1121](https://github.com/backnotprop/plannotator/issues/1121)
- **VS Code extension on Open VSX** - the extension (v0.16.8) is published to Open VSX for VSCodium and other non-Microsoft editors, requested by @7tg in [#1110](https://github.com/backnotprop/plannotator/issues/1110)
- **Pi npm packaging fix** - the published Pi package now ships every module it imports; a missing file would have broken npm installs of this release
- **GitButler review workflow docs** - the README documents reviewing GitButler workspaces

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

- fix(ui): parse YAML block scalars in frontmatter by @ruaridhw in [#1101](https://github.com/backnotprop/plannotator/pull/1101)
- perf(pi-extension): use exact .ts relative specifiers by @dca123 in [#1106](https://github.com/backnotprop/plannotator/pull/1106)
- fix(annotate): use annotate feedback template for clipboard copy by @backnotprop in [#1109](https://github.com/backnotprop/plannotator/pull/1109)
- feat: persist Guided Reviews across sessions by @backnotprop in [#1115](https://github.com/backnotprop/plannotator/pull/1115)
- fix(review): treat cross-drive relative() results as repo escapes by @BenNewman100 in [#1117](https://github.com/backnotprop/plannotator/pull/1117)
- fix(review): bound memory for large untracked files by @kcosr in [#1118](https://github.com/backnotprop/plannotator/pull/1118)
- feat: add an option to disable AI features by @kcosr in [#1129](https://github.com/backnotprop/plannotator/pull/1129)
- fix(ui): move Save to the first tab stop in the comment popover footer by @balasivagn in [#1122](https://github.com/backnotprop/plannotator/pull/1122)
- feat(core): add Zed Preview as an Open In App target by @backnotprop in [#1130](https://github.com/backnotprop/plannotator/pull/1130)
- feat(annotate): extend per-file version diff to folder sessions by @BenNewman100 in [#1105](https://github.com/backnotprop/plannotator/pull/1105)
- fix(annotate): watch open source files exactly by @rNoz in [#1089](https://github.com/backnotprop/plannotator/pull/1089)
- feat(annotate): add strict atomic result output by @rNoz in [#1091](https://github.com/backnotprop/plannotator/pull/1091)
- feat(annotate): preserve notes on structured approval by @rNoz in [#1092](https://github.com/backnotprop/plannotator/pull/1092)
- fix(opencode): fix hardcoded default build agent when sending responses by @cb-bradbeebe in [#1131](https://github.com/backnotprop/plannotator/pull/1131)
- feat(editor): add Vim keyboard annotation controls and live HUD by @backnotprop in [#1127](https://github.com/backnotprop/plannotator/pull/1127)
- fix(pi): preserve extension tool selections by @CodeByPeete in [#1124](https://github.com/backnotprop/plannotator/pull/1124)
- feat(pi): add external plan execution handoff by @cgngtr in [#1126](https://github.com/backnotprop/plannotator/pull/1126)
- docs: add GitButler review workflow by @backnotprop in [#1111](https://github.com/backnotprop/plannotator/pull/1111)

## New Contributors

- @ruaridhw made their first contribution in [#1101](https://github.com/backnotprop/plannotator/pull/1101)
- @dca123 made their first contribution in [#1106](https://github.com/backnotprop/plannotator/pull/1106)
- @BenNewman100 made their first contribution in [#1117](https://github.com/backnotprop/plannotator/pull/1117)
- @kcosr made their first contribution in [#1118](https://github.com/backnotprop/plannotator/pull/1118)
- @balasivagn made their first contribution in [#1122](https://github.com/backnotprop/plannotator/pull/1122)
- @cb-bradbeebe made their first contribution in [#1131](https://github.com/backnotprop/plannotator/pull/1131)
- @CodeByPeete made their first contribution in [#1124](https://github.com/backnotprop/plannotator/pull/1124)
- @cgngtr made their first contribution in [#1126](https://github.com/backnotprop/plannotator/pull/1126)

## Contributors

@rNoz shipped a three-PR stack built from daily use: exact file watching, the strict automation gate, and Approve with Notes, stress-tested on a personal integration branch before ever reaching review. @BenNewman100 fixed Windows cross-drive paths and extended the version diff to folder sessions, keeping the branch current across three weeks of upstream churn. @kcosr contributed the memory bounds and the AI kill switch, both born from running Plannotator on shared agent infrastructure. @cb-bradbeebe diagnosed the hardcoded agent bug, proposed the fix on the issue, and delivered it with validation and tests. @CodeByPeete made the Pi extension a good citizen among other extensions, and @cgngtr built the external execution handoff on top of that model days after it landed. @ruaridhw fixed frontmatter block-scalar parsing, @dca123 made the Pi extension load faster, and @balasivagn improved comment-popover keyboard accessibility.

Community reports and requests shaped the release throughout:

- @tuanddd requested approve-with-annotations back in [#930](https://github.com/backnotprop/plannotator/issues/930)
- @digitalmaster reported the out-of-memory failure in [#940](https://github.com/backnotprop/plannotator/issues/940)
- @alexanderkreidich requested Guided Review persistence in [#1112](https://github.com/backnotprop/plannotator/issues/1112)
- @ZBQtesla reported the clipboard template bug in [#1107](https://github.com/backnotprop/plannotator/issues/1107)
- @graemefolk requested Zed Preview support in [#1119](https://github.com/backnotprop/plannotator/issues/1119)
- @7tg requested Open VSX publishing in [#1110](https://github.com/backnotprop/plannotator/issues/1110)

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.24.2...v0.25.0
