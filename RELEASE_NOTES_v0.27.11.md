Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release | Highlights |
|---|---|
| [v0.27.10](https://github.com/backnotprop/plannotator/releases/tag/v0.27.10) | Auto-viewed files on scroll, annotation undo/redo, OpenCode 2 slash commands restored, npm 12 agent terminal fix |
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

</details>

## What's New in v0.27.11

A patch release with one important resource fix, one new safety net, and a CLI fix from a first-time contributor. Every change went through independent adversarial review and a six-agent QA sweep before tagging.

### OpenCode servers no longer pile up in the background

If you had the `opencode` CLI installed, every Plannotator session quietly started an `opencode serve` process at launch, just to list OpenCode's models in the Ask AI dropdown. Ending a session with Ctrl-C never cleaned that process up, and every later session found the leftover server and loaded more state into it. Over a day of normal use this grew into a multi-gigabyte orphan process nobody started on purpose.

Three things changed. Nothing starts anymore until you actually select OpenCode in Ask AI; most users never do, and now never spawn it. When it does start, each session runs its own private server on its own port instead of sharing one, so sessions can never pile into each other. And the server is now closed when the session ends, including on Ctrl-C.

Two visible differences for OpenCode users of Ask AI: the model list fills in when you first select the provider instead of being preloaded, and you will see one `opencode serve` process per active Plannotator session rather than a shared one. Both are the intended shape of the fix.

[#1445](https://github.com/backnotprop/plannotator/pull/1445)

### Your submitted feedback is now archived locally

Every plan decision, code review submission, and annotate submission is now recorded on your machine, under `~/.plannotator/feedback/`, organized by project. Each record is one line in an append-only index plus a readable markdown file holding your review text, the excerpts it quoted, and annotation metadata, with lightweight provenance such as file paths and the git ref under review.

The reason it exists: feedback used to be gone the moment it was sent. An agent times out, a terminal closes, and the review you wrote is unrecoverable. Now there is a durable record of everything you submitted, and a growing personal archive you can analyze or learn from over time. [Herdr Annotate](https://github.com/plannotator/herdr-annotate), the terminal-side annotator, writes to the same archive with its own client label, so both tools build one history.

The archive stays on your machine and is never transmitted. It is on by default; set `PLANNOTATOR_FEEDBACK_HISTORY=0` (or `"feedbackHistory": false` in `~/.plannotator/config.json`) to turn it off, and delete `~/.plannotator/feedback/` to forget what is there. The [privacy page](https://plannotator.ai/privacy) documents it. The write path is deliberately fail-safe: if the archive cannot be written for any reason, your feedback still submits exactly as before.

[#1438](https://github.com/backnotprop/plannotator/pull/1438)

### A typo'd command now tells you instead of hanging forever

`plannotator annotatte README.md` used to print nothing and hang until killed, because an unrecognized subcommand fell through to the plan-review hook path, which waits for hook data on stdin that never arrives from a terminal. An unknown subcommand now exits immediately with the misspelled word, a "Did you mean" suggestion, and a pointer to `--help`. A registry test scrapes the real dispatcher so the known-command list can never drift and reject a valid command.

Contributed by @SumeraMartin in [#1444](https://github.com/backnotprop/plannotator/pull/1444), whose diagnosis of the stdin fallthrough was exact, in their first contribution to the project.

### Additional Changes

- **`@plannotator/ui` 0.35.2** (with `@plannotator/core` 0.25.1): hosts embedding the annotation UI can hide the Quick Label tool via the new `hideQuickLabel` prop on `AnnotationToolstrip` (forwarded by `StickyHeaderLane`). Default off; Plannotator's own surfaces are unchanged. [#1442](https://github.com/backnotprop/plannotator/pull/1442). Two broken publishes were caught and corrected the same day: 0.35.0 shipped an unresolvable `workspace:*` dependency, and 0.35.1 imported a core export the published core 0.25.0 did not contain. The source manifest now pins the exact core version, core 0.25.1 ships the missing exports, and CI installs the packed tarballs outside the monorepo and verifies real imports, TypeScript compilation, and a Vite build, so both failure classes are structurally closed. Use 0.35.2; 0.35.0 and 0.35.1 are deprecated. [#1446](https://github.com/backnotprop/plannotator/pull/1446), [#1447](https://github.com/backnotprop/plannotator/pull/1447)
- **Privacy page**: plannotator.ai/privacy now documents the local feedback archive, what a record contains, and how to disable or delete it.

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

**Pi:** Update `@plannotator/pi-extension` to 0.27.11 and restart Pi.

**OpenCode:** Clear cache and restart:

```bash
rm -rf ~/.bun/install/cache/@plannotator
```

## What's Changed

- fix(ai): stop leaking opencode serve processes in [#1445](https://github.com/backnotprop/plannotator/pull/1445)
- feat(server): durable feedback archive for every submitted review in [#1438](https://github.com/backnotprop/plannotator/pull/1438)
- fix(cli): exit on an unknown subcommand instead of blocking on stdin by @SumeraMartin in [#1444](https://github.com/backnotprop/plannotator/pull/1444)
- feat(ui): allow hosts to hide Quick Label in [#1442](https://github.com/backnotprop/plannotator/pull/1442)
- fix(ui): publish exact core dependency in [#1446](https://github.com/backnotprop/plannotator/pull/1446)
- fix(packages): publish annotation thread exports in [#1447](https://github.com/backnotprop/plannotator/pull/1447)

## New Contributors

- @SumeraMartin made their first contribution in [#1444](https://github.com/backnotprop/plannotator/pull/1444)

## Community

@SumeraMartin found the unknown-subcommand hang, diagnosed the exact stdin fallthrough that caused it, and shipped the fix with a drift-proof test suite in a first contribution that merged as written. The opencode leak was caught during our own multi-agent operations when a monitoring session flagged a multi-gigabyte orphan process, and the feedback archive grew out of repeated user reports of reviews lost to agent timeouts.

Thank you. Plannotator gets better because you tell us where it falls short.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.27.10...v0.27.11
