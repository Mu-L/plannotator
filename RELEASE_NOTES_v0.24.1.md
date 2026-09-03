Follow [@plannotator](https://x.com/plannotator) on X for updates

---

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.24.0](https://github.com/backnotprop/plannotator/releases/tag/v0.24.0)   | PR/MR artifact gallery, GitButler review support, port ranges, expanded comment editor, OpenCode + Pi fixes                       |
| [v0.23.1](https://github.com/backnotprop/plannotator/releases/tag/v0.23.1)   | Startup no longer hangs on large or slow directory trees, Ask AI input stays visible after long responses                        |
| [v0.23.0](https://github.com/backnotprop/plannotator/releases/tag/v0.23.0)   | Plan approval fix for Claude Code 2.1.199+, annotate mode version diff, binary-only `--minimal` install, reviews post without attribution |
| [v0.22.0](https://github.com/backnotprop/plannotator/releases/tag/v0.22.0)   | Git-status "All changes" default review view, Commits panel with per-commit diffs, Guided Review, Pi + GitHub Copilot CLI review engines |
| [v0.21.4](https://github.com/backnotprop/plannotator/releases/tag/v0.21.4)   | Markdown math rendering, PR Overview panel with annotatable description and comments, agent instructions in code review, media parsing fixes |
| [v0.21.3](https://github.com/backnotprop/plannotator/releases/tag/v0.21.3)   | File comments in code review, unified click-to-highlight comments, VS Code clipboard/keyboard bridge, Codex Ask AI on app-server transport, CLI subcommand help |
| [v0.21.2](https://github.com/backnotprop/plannotator/releases/tag/v0.21.2)   | Custom reviews as Agent Skills, Cursor + OpenCode review engines, whole-file/general findings, deleted-annotation fix, Codex Ask AI outside git repos |
| [v0.21.1](https://github.com/backnotprop/plannotator/releases/tag/v0.21.1)   | Annotate-last blank-page fix on multi-message sessions                                                                            |
| [v0.21.0](https://github.com/backnotprop/plannotator/releases/tag/v0.21.0)   | Direct document editing in annotate mode, live git-status file tree, in-app agent terminal, open files in external apps, HTML renders as HTML |
| [v0.20.3](https://github.com/backnotprop/plannotator/releases/tag/v0.20.3)   | Annotations no longer lost when clicking away, off-screen indicator for open comments                                            |
| [v0.20.2](https://github.com/backnotprop/plannotator/releases/tag/v0.20.2)   | Pierre CodeView all-files review, large-PR pipeline and instant-open checkout, unified agent engine selection, Pi programmatic plan mode |

</details>

---

## What's New in v0.24.1

A one-fix patch. `plannotator annotate` now opens a file you point to with a `../` path.

> v0.24.1 follows v0.24.0 by a few hours, so the full v0.24.0 notes are included below — most users updating now are getting both.

### Annotate accepts parent-relative file paths

Running `plannotator annotate ../docs/plan.md` failed with `File type not supported: .md`, even though `.md` is supported. The path resolver rejected any relative path that pointed outside the current directory, so a `../` path never resolved. The command then found the file on disk and reported the resolver miss as a type error, which is why the message named a supported extension.

An explicit path you type is now honored when the file exists, including a `../` path that points to a parent directory. This matches how absolute paths already work. Bare filenames still resolve only within the current project, so typing `notes.md` cannot reach a same-named file in a parent directory.

Closing [#1085](https://github.com/backnotprop/plannotator/issues/1085), reported by @shulcsm.

---

## What's New in v0.24.0

This release adds two review surfaces: a gallery for the images, videos, and documents inside PR conversations, and native GitButler workspace support. 25 pull requests landed since v0.23.1. Six came from community members, four of them first-time contributors. The release also brings port ranges, an expanded comment editor, and fixes across the OpenCode and Pi integrations.

### PR and MR artifact gallery

Pull request conversations hold more than text: screenshots of the bug, GIFs of the fix, demo videos, HTML reports, attached markdown. The review UI ignored all of it.

When you review a GitHub pull request or GitLab merge request, Plannotator now collects images, GIFs, videos, HTML, and markdown files from the description and conversation into a gallery. Selecting a tile opens a focused viewer. Markdown and sandboxed HTML render inline, and everything is annotatable: select text in a document, drop a point note on an image, pin a note to a video timestamp, or comment on the artifact as a whole. These notes join your normal review feedback with their source attached, whether the feedback posts to GitHub/GitLab or returns to your local agent.

Conversation artifacts sort newest-first, and you can hide tiles you don't want to see again. The gallery appears only for hosted reviews, since local diffs have no conversation to collect from.

- Authored by @backnotprop in [#1055](https://github.com/backnotprop/plannotator/pull/1055)

### GitButler review support

GitButler users work in a virtual-branch workspace that ordinary Git tooling misreads: HEAD sits on a synthetic workspace commit, and several branches are applied at once. Running a code review there produced confusing diffs against internals GitButler manages for you.

Plannotator now detects an active GitButler workspace and reviews it natively. The default Workspace view shows everything applied, committed changes plus assigned and unassigned working-tree changes, against GitButler's reported merge base. You can also review a single stack or one branch within a stack as committed-only diffs. Detection requires both the workspace HEAD and GitButler's local target configuration, so a leftover branch or database from a past experiment cannot hijack an ordinary Git repo. An active workspace needs the `but` CLI (0.21.0 or newer). `--gitbutler` forces the provider and `--git` remains the escape hatch. Both the Bun and Pi runtimes support it.

The original GitButler effort came from @dansusman, whose work is preserved in the commit co-author credit.

- Authored by @backnotprop in [#1067](https://github.com/backnotprop/plannotator/pull/1067), superseding [#566](https://github.com/backnotprop/plannotator/pull/566) by @dansusman

### Expanded comment editor in code review

Long review comments were cramped in the compact inline toolbar. A new expand control opens a full-size dialog that edits the same comment, so you can draft multi-paragraph findings and submit through the familiar flow. The compact composer stays the default for quick notes and gains vertical resize.

- Authored by @leoreisdias in [#1030](https://github.com/backnotprop/plannotator/pull/1030)

### Port ranges

`PLANNOTATOR_PORT` now accepts an inclusive range like `19432-19463`. Plannotator tries each port in order and binds the first available one, in both the Bun and Pi runtimes. Fixed single ports and the random-port default behave as before. This helps devcontainer and SSH setups where you forward a block of ports and run several sessions side by side.

- Authored by @iurysza in [#1042](https://github.com/backnotprop/plannotator/pull/1042), their first contribution

### OpenCode: cancelling a plan review now cleans up

Cancelling a `submit_plan` call in OpenCode left the review server running, so the next plan submission could not bind its port. Cancellation now flows through OpenCode's tool-abort contract: the server shuts down, timers and child processes are released, and the plan is kept so a resubmitted revision reuses the same fixed port.

- Authored by @backnotprop in [#1064](https://github.com/backnotprop/plannotator/pull/1064), closing [#1046](https://github.com/backnotprop/plannotator/issues/1046) reported by @fabians-px

### Pi: faster startup and honest error reporting

The extension added about two seconds to every `pi` launch because its full module graph loaded at registration. The heavy browser and server graph now loads on first use, and the large UI bundles are read only when you open a review or annotate session.

Separately, when a review engine failed (for example, out of API credits mid-review), Guided Review reported a generic parse failure instead of the real cause. Provider errors now surface as themselves.

- Authored by @backnotprop in [#1063](https://github.com/backnotprop/plannotator/pull/1063), closing [#1058](https://github.com/backnotprop/plannotator/issues/1058) reported by @tomsej, and [#1061](https://github.com/backnotprop/plannotator/pull/1061), closing [#1037](https://github.com/backnotprop/plannotator/issues/1037) reported by @alexanderkreidich

### Background git checks can no longer freeze the terminal

Plannotator periodically checks whether your review baseline is behind its remote. On repos whose remote needs interactive authentication, that background `git ls-remote` could open a credential or passphrase prompt with nowhere to render. On Pi it froze the TUI. Background discovery now runs without interaction: credential prompts are disabled, SSH runs in batch mode, and timed-out processes are cleaned up as a group. Explicit actions like the "Fetch" button keep the normal interactive authentication path.

- Authored by @backnotprop in [#1062](https://github.com/backnotprop/plannotator/pull/1062), closing [#1020](https://github.com/backnotprop/plannotator/issues/1020) reported by @r3clin3r

### Workspace mode discovers symlinked repos

Multi-repo workspace review walked real directories only, so a child repo reachable through a symlink was skipped. Symlinked and junction-linked repos are now discovered, deduplicated by real path, and labeled by their workspace-relative alias. This release also caps the discovery walk with the `PLANNOTATOR_FILE_BROWSER_MAX_FILES` budget, so a stray symlink into a huge unrelated tree cannot stall startup.

- Authored by @backnotprop in [#1060](https://github.com/backnotprop/plannotator/pull/1060), closing [#1054](https://github.com/backnotprop/plannotator/issues/1054) reported by @fruxxxl

### Additional Changes

- **JSON 404 for unknown API routes**: a nonexistent `/api/*` path used to return the full app HTML with a 200. All six servers (Bun and Pi) now return a JSON 404, while SPA routes still serve HTML. By @buihongduc132 in [#748](https://github.com/backnotprop/plannotator/pull/748), their first contribution.
- **System theme everywhere**: the System option now appears in every theme menu through a shared mode list. By @gwynnnplaine in [#1015](https://github.com/backnotprop/plannotator/pull/1015).
- **OpenCode planning handoff preserved**: approving a plan with an agent switch no longer loses the planning context. By @franktronics in [#1034](https://github.com/backnotprop/plannotator/pull/1034), their first contribution.
- **Visual-explainer Mermaid colors**: the skill emitted OKLCH theme variables Mermaid cannot parse; it now emits hex. By @FNDEVVE in [#1044](https://github.com/backnotprop/plannotator/pull/1044), closing [#1043](https://github.com/backnotprop/plannotator/issues/1043), their first contribution.
- **Review feedback validation narrowed**: submitting findings no longer risks starting a second review pass. By @backnotprop in [#1065](https://github.com/backnotprop/plannotator/pull/1065).
- **Responsive review header**: the code review header now wraps at narrow widths. By @backnotprop in [#1073](https://github.com/backnotprop/plannotator/pull/1073).
- **Open-in selector placement**: the open-in-editor selector moved after the file context. By @backnotprop in [#1072](https://github.com/backnotprop/plannotator/pull/1072).

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

### v0.24.1

- fix(annotate): resolve explicit `../` paths that escape the project root by @backnotprop, closing [#1085](https://github.com/backnotprop/plannotator/issues/1085)

### v0.24.0

- feat(review): add PR and MR artifact gallery by @backnotprop in [#1055](https://github.com/backnotprop/plannotator/pull/1055)
- Add modern GitButler review support by @backnotprop in [#1067](https://github.com/backnotprop/plannotator/pull/1067)
- feat(review): Add expanded review comment editor by @leoreisdias in [#1030](https://github.com/backnotprop/plannotator/pull/1030)
- feat(server): support bounded port ranges by @iurysza in [#1042](https://github.com/backnotprop/plannotator/pull/1042)
- Fix OpenCode plan cleanup after cancellation by @backnotprop in [#1064](https://github.com/backnotprop/plannotator/pull/1064)
- fix(review): keep background remote discovery noninteractive by @backnotprop in [#1062](https://github.com/backnotprop/plannotator/pull/1062)
- perf(pi): lazy-load runtime graph to cut startup time by @backnotprop in [#1063](https://github.com/backnotprop/plannotator/pull/1063)
- fix: surface Pi provider errors in reviews by @backnotprop in [#1061](https://github.com/backnotprop/plannotator/pull/1061)
- Fix workspace discovery for symlinked repositories by @backnotprop in [#1060](https://github.com/backnotprop/plannotator/pull/1060)
- Validate submitted findings without starting a second review by @backnotprop in [#1065](https://github.com/backnotprop/plannotator/pull/1065)
- fix(server): return JSON 404 for unknown /api/* routes instead of HTML by @buihongduc132 in [#748](https://github.com/backnotprop/plannotator/pull/748)
- fix(review): show System in theme menu via shared mode list by @gwynnnplaine in [#1015](https://github.com/backnotprop/plannotator/pull/1015)
- fix(opencode): preserve planning handoff by @franktronics in [#1034](https://github.com/backnotprop/plannotator/pull/1034)
- fix visual-explainer Mermaid theme colors by @FNDEVVE in [#1044](https://github.com/backnotprop/plannotator/pull/1044)
- fix(review): make header responsive by @backnotprop in [#1073](https://github.com/backnotprop/plannotator/pull/1073)
- Place open-in selector after file context by @backnotprop in [#1072](https://github.com/backnotprop/plannotator/pull/1072)
- Refine Workspaces waitlist page by @backnotprop in [#1056](https://github.com/backnotprop/plannotator/pull/1056)
- Route legacy docs and blog URLs to docs.plannotator.ai by @backnotprop in [#1079](https://github.com/backnotprop/plannotator/pull/1079)
- docs: connect the README to canonical Plannotator docs by @backnotprop in [#1080](https://github.com/backnotprop/plannotator/pull/1080)
- Use the production Totman favicon by @backnotprop in [#1066](https://github.com/backnotprop/plannotator/pull/1066), [#1071](https://github.com/backnotprop/plannotator/pull/1071), and [#1081](https://github.com/backnotprop/plannotator/pull/1081)
- SEO: publish the new default social card by @backnotprop in [#1082](https://github.com/backnotprop/plannotator/pull/1082)
- Add Bing Webmaster Tools site verification by @backnotprop in [#1074](https://github.com/backnotprop/plannotator/pull/1074)
- chore(deps): update github actions by @renovate in [#593](https://github.com/backnotprop/plannotator/pull/593)

## New Contributors

- @iurysza made their first contribution in [#1042](https://github.com/backnotprop/plannotator/pull/1042)
- @buihongduc132 made their first contribution in [#748](https://github.com/backnotprop/plannotator/pull/748)
- @franktronics made their first contribution in [#1034](https://github.com/backnotprop/plannotator/pull/1034)
- @FNDEVVE made their first contribution in [#1044](https://github.com/backnotprop/plannotator/pull/1044)

## Contributors

@iurysza built port range support across both server runtimes for their first contribution, with tests for the parsing edge cases. @buihongduc132's first contribution touched all six servers, giving API clients proper JSON 404s. @franktronics fixed the OpenCode planning handoff on their first PR. @FNDEVVE both reported and fixed the visual-explainer Mermaid color bug. @leoreisdias returned for a fifth contribution with the expanded comment editor. @gwynnnplaine made the System theme option consistent everywhere. @dansusman's original GitButler pull request laid the groundwork for this release's native support.

Issue reporters drove much of the fix list this cycle:

- @shulcsm reported the parent-relative annotate failure with a clear before/after reproduction in [#1085](https://github.com/backnotprop/plannotator/issues/1085)
- @fabians-px reported the OpenCode cancellation port leak in [#1046](https://github.com/backnotprop/plannotator/issues/1046)
- @r3clin3r reported the Pi TUI freeze from background SSH prompts in [#1020](https://github.com/backnotprop/plannotator/issues/1020)
- @tomsej profiled and reported the 2.1s Pi startup cost in [#1058](https://github.com/backnotprop/plannotator/issues/1058)
- @alexanderkreidich reported Guided Review masking insufficient-credit errors in [#1037](https://github.com/backnotprop/plannotator/issues/1037)
- @fruxxxl reported the symlinked-repo gap in workspace mode in [#1054](https://github.com/backnotprop/plannotator/issues/1054)

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.24.0...v0.24.1 (patch) · https://github.com/backnotprop/plannotator/compare/v0.23.1...v0.24.0 (v0.24.0)
