Follow [@plannotator](https://x.com/plannotator) on X for updates

---

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.25.0](https://github.com/backnotprop/plannotator/releases/tag/v0.25.0)   | Vim keyboard controls, Approve with Notes, scriptable annotate gates, persistent Guided Reviews, memory and file-watching hardening |
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

</details>

---

## What's New in v0.25.1

Eight pull requests landed since v0.25.0, six of them from community members, and four authors made their first contribution. The release stops code review from launching Codex when you never asked for it, teaches `plannotator last` which conversation you are actually in, adds Claude Opus 5 to the model pickers, and mirrors approved plan checklists into editable pi-todos. Two fixes came out of pre-release QA rather than a report.

### Opening a review no longer launches Codex

Constructing the AI runtime ran Codex model discovery immediately, which meant that simply opening a code review spawned a `codex app-server` process. Users who had Codex installed but never intended to use it got a stray process, and on macOS the launch could raise a Gatekeeper prompt in front of a review they were trying to read.

Discovery is now deferred until a Codex session actually starts, or until you explicitly select Codex in the provider picker. Selecting Codex activates it and refreshes the model list on that gesture, so the real catalog and per-model reasoning-effort options still appear before you pick anything. Saved model preferences are left alone rather than being overwritten by a placeholder.

- Authored by @rNoz in [#1145](https://github.com/backnotprop/plannotator/pull/1145), closing [#1144](https://github.com/backnotprop/plannotator/issues/1144)

### `plannotator last` follows the live conversation

Two separate bugs made `plannotator last` annotate the wrong message.

In Claude Code, `/rewind` does not remove anything from the session transcript. It re-parents the next message to an earlier point and leaves everything after that orphaned in the file forever. Reading the file bottom-up therefore offered messages that were no longer part of the conversation. The message picker now walks the conversation tree from the newest entry back to the root, so rewound branches stay out. On a linear session the result is identical to before, and a transcript whose structure cannot be trusted falls back to the previous behavior rather than returning nothing.

In GitHub Copilot CLI, `plannotator last` picked a session by file order and would silently annotate a stale transcript instead of the live one. Copilot CLI exposes no environment fingerprint, so the fix walks the process ancestry and matches it against Copilot's own session lock files, which identifies the live session deterministically even with several sessions open in the same directory.

- Transcript tree walk by @BrandonNoad in [#1141](https://github.com/backnotprop/plannotator/pull/1141)
- Copilot session routing by @mararn1618 in [#1150](https://github.com/backnotprop/plannotator/pull/1150), closing [#1149](https://github.com/backnotprop/plannotator/issues/1149)

### Approved plan checklists mirror into pi-todos

Under Pi, an approved plan's checklist lived only in the plan and the progress widget. If you also use [pi-todos](https://github.com/mitsuhiko/agent-stuff), your todos and your plan were two separate lists.

On plan approval, Plannotator now detects pi-todos and mirrors the approved checklist into it, closing each todo as the agent completes the corresponding step. Sync is one-way, so reordering or rewording a todo can never desync plan execution. The mirror is additive: the existing progress widget stays exactly as it was, because pi-todos renders its list on demand rather than continuously, and replacing a live display with files behind a keystroke would be a downgrade. It is inert when no provider is present, and `PLANNOTATOR_TODO_PROVIDER=off` turns it off entirely.

- Authored by @jms830 in [#1139](https://github.com/backnotprop/plannotator/pull/1139), implementing the one-way half of [#484](https://github.com/backnotprop/plannotator/issues/484)

### Abandoned annotate gates stop waiting forever

A structured annotate gate (`--gate --json`) blocks until the reviewer decides. If every review surface was closed without a decision, nothing ever settled and the calling script waited indefinitely.

Each open review surface now holds a lease over a heartbeat stream. Once at least one client has connected, closing the last one starts a 30-second reconnect window; reconnecting inside that window continues the same review, and expiry resolves the gate as the same `dismissed` decision an explicit Close produces. The saved annotation draft is deliberately kept, so an abandoned review can still be recovered. Page lifecycle events are not used for this, because reload and navigation fire the same events as abandonment and cannot be told apart. A session that never receives a client never auto-dismisses, so browser-launch failures still need a timeout on the caller's side, and remote sessions keep the behavior off because a tunnel disconnect would read as an abandoned review.

- Authored by @rNoz in [#1143](https://github.com/backnotprop/plannotator/pull/1143), closing [#1142](https://github.com/backnotprop/plannotator/issues/1142)

### Claude Opus 5

Claude Opus 5 is available in the Ask AI model picker and in the review-agent model list that Review Agents, Code Tour, and Guided Review launch from. Launched review jobs now default to Opus 5 instead of Opus 4.7. Existing saved model preferences are untouched: this changes the default for anyone who has not chosen a model.

- Authored by @backnotprop in [#1151](https://github.com/backnotprop/plannotator/pull/1151)

### Approving with notes now reaches Amp and Droid

Approve with Notes shipped in v0.25.0, but the Amp and Droid adapters dropped the feedback field on approved decisions. Approving with annotations sent a bare "Approved." and the notes were lost. Both adapters now surface the notes, using the same wording the other runtimes already emit.

- Authored by @Souptik96 in [#1146](https://github.com/backnotprop/plannotator/pull/1146), closing [#1137](https://github.com/backnotprop/plannotator/issues/1137)

### Additional Changes

- **Reopening search selects the existing query.** Pressing `Cmd`/`Ctrl`+`F` in code review with text already in the search box now focuses the input and selects its contents, so typing replaces the old query instead of appending to it. Matches how browser find behaves. By @omederos in [#1152](https://github.com/backnotprop/plannotator/pull/1152)
- **Pi no longer crashes after plan approval in headless sessions.** Pi 0.69 and later invalidate an extension's session context on teardown, and every call on a stale context throws. The post-approval continuation timer polled that context, so a session ending underneath it (headless plan runs, or `/new` immediately after approving) killed the whole Pi process. The continuation now cancels instead, and the fire-and-forget browser open no longer crashes Pi through an unhandled rejection when a launcher fails. Closing [#1140](https://github.com/backnotprop/plannotator/issues/1140)
- **The pi-todos mirror stays inside the project.** Found in pre-release QA: a repository shipping `.pi/todos` as a symlink pointing elsewhere had the plan checklist written to the symlink target. The implicit `<cwd>/.pi/todos` path must now resolve inside the project or the provider reads as absent. An explicitly configured `PI_TODO_PATH` is still honored anywhere, since that is the user's own choice.
- **The abandoned-gate fix now covers OpenCode.** Also found in pre-release QA: three of the four places that start an annotate server were wired for lease-based dismissal, and OpenCode's `/plannotator-last` bridge was missed, so it still hung on abandonment. It is wired now, with a test that checks every call site so the next one cannot be missed the same way.

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

- feat(pi): mirror plan checklist to pi-todos by @jms830 in [#1139](https://github.com/backnotprop/plannotator/pull/1139)
- feat(ai): add Claude Opus 5 across providers and review agents by @backnotprop in [#1151](https://github.com/backnotprop/plannotator/pull/1151)
- fix(hook): read annotate-last from Claude Code's transcript tree, not file order by @BrandonNoad in [#1141](https://github.com/backnotprop/plannotator/pull/1141)
- fix(amp,droid): surface Approve-with-Notes feedback instead of dropping it by @Souptik96 in [#1146](https://github.com/backnotprop/plannotator/pull/1146)
- fix(hook): route annotate-last to the live Copilot CLI session by @mararn1618 in [#1150](https://github.com/backnotprop/plannotator/pull/1150)
- feat(annotate): dismiss abandoned gate sessions by @rNoz in [#1143](https://github.com/backnotprop/plannotator/pull/1143)
- fix(ui): focus and select existing review search text by @omederos in [#1152](https://github.com/backnotprop/plannotator/pull/1152)
- fix(ai): defer Codex model discovery until a Codex session starts by @rNoz in [#1145](https://github.com/backnotprop/plannotator/pull/1145)

---

## New Contributors

- @jms830 made their first contribution in [#1139](https://github.com/backnotprop/plannotator/pull/1139)
- @Souptik96 made their first contribution in [#1146](https://github.com/backnotprop/plannotator/pull/1146)
- @mararn1618 made their first contribution in [#1150](https://github.com/backnotprop/plannotator/pull/1150)
- @omederos made their first contribution in [#1152](https://github.com/backnotprop/plannotator/pull/1152)

---

## Contributors

@rNoz filed and fixed both of this release's runtime problems on the Pi and Codex side. #1144 identified that Codex discovery ran during AI runtime construction, which is what made opening any review launch Codex, and #1142 identified that structured annotate gates never settled once every client disconnected. Both PRs arrived tested, and the lease design in #1143 is careful work: it infers presence from a connection rather than from page lifecycle events, which is what makes reload and navigation distinguishable from abandonment.

@BrandonNoad diagnosed the `/rewind` behavior in Claude Code transcripts, wrote it up clearly enough that the fix was easy to reason about, and helped settle the compaction edge case during review.

@mararn1618 reported the Copilot CLI staleness in #1149 and had the fix open within the day, including the lock-file approach that makes live-session detection deterministic rather than a guess.

@jms830 implemented the pi-todos mirror as a first contribution, including a `TodoProvider` interface that leaves room for other providers, and traced pi-todos and oh-my-pi carefully enough to argue for an additive mirror instead of replacing the progress widget. The reasoning was recorded in the code rather than lost in the thread.

@Souptik96 fixed the Amp and Droid approve-with-notes gap, matching the wording the other runtimes already use rather than inventing a new shape for those two adapters.

@omederos fixed the review search field so reopening it selects the existing query, which is how browser find has always worked.

@JayGhiya asked for pi-todos interoperability in [#484](https://github.com/backnotprop/plannotator/issues/484) and described why it mattered: todos in pi-todos are editable, which makes them good for steering. That request is what #1139 implements.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.25.0...v0.25.1
