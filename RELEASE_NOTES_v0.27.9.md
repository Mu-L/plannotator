Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
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
| [v0.26.6](https://github.com/backnotprop/plannotator/releases/tag/v0.26.6)   | Fixed empty environment variables in sandboxed sessions (Bun 1.3.14 builds)                                                      |

</details>

## What's New in v0.27.9

Eleven pull requests, one of them from @leoreisdias. Two threads run through the release. Browser-integrated agents can now read a plan or an annotate session and leave comments on it through WebMCP, instead of scraping the page. And the raw-HTML annotation surface gained a Refresh action along with a published set of seams so other applications can run that surface as Plannotator ships it. A Windows uninstall fix and a pre-release QA pass close it out.

### Browser agents can read your document and comment on it

An agent that runs inside the browser, such as Codex's browser or Claude Code's browser, has until now had to work out what is on the page by reading the DOM. Plan review and every annotate surface (markdown, raw HTML, live app, folder) now register a small tool catalog on `document.modelContext`, the WebMCP surface those agents speak.

The catalog is deliberately narrow. `read_document` returns the whole situation in one zero-argument call: the session, the document text windowed at 16k characters and cut at a block boundary, an outline with per-section comment counts, every comment with its quote and context, sibling documents, and a set of nudge codes. `add_comments` writes a batch, anchoring by an exact quote, by section, by reply, or as a document-level note, and is idempotent by request id. `update_comment`, `remove_comments`, `reveal` and `nudge_user` round it out, with `list_documents` in folder sessions.

Three rules make this safe to ship without a consent dialog. Decisions stay with the human: no tool approves, denies, submits, closes, stages or marks anything viewed, and a test pins the catalog so none can be added quietly. An agent may edit or remove only the comments it created, which are stamped `browser-agent`; asking to touch a human's comment answers `forbidden`. And nothing is ever registered inside the sandboxed iframes, so a page you are annotating can neither see nor impersonate Plannotator's tools.

Without the API there is no footprint at all. Feature detection is one `typeof` check per mount, and when `document.modelContext` is absent the catalog is never built and no indicator, banner, request or timer is created. That was verified rather than assumed: builds from main and from the branch served the same annotate session to a Chrome without WebMCP, and the rendered DOM (44,607 characters), the request lists, the console output and the timer counts came back identical on both sides.

The nudges are what keep an agent in step with you. Every response carries codes computed from state the page already holds, so the agent learns on the call it was going to make anyway that you added a comment, that your composer is open, that the file changed on disk, or that the live app navigated to another page. A header indicator appears after the first tool call, and a Settings toggle turns the whole provider off and on.

One product change comes with it. `Annotation` gains an optional `inReplyTo` field, so an agent can answer a comment you left. A reply inherits its parent's anchor, renders indented under it in the annotations panel, and exports nested under the parent as a `**Replies:**` block, which is what puts the exchange in front of the coding agent in order. Annotations without the field render and export byte for byte as before.

Code review is phase 2 and is not in this release.

- [#1393](https://github.com/backnotprop/plannotator/pull/1393) by @backnotprop

### Refresh rendered HTML from disk

Markdown annotate sessions pick up an agent's edits as soon as the file changes on disk. Rendered HTML sessions kept showing the snapshot they loaded at startup, so the review surface went stale the moment the agent rewrote the report you were reading.

@leoreisdias added a Refresh action for local `.html` and `.htm` annotate sessions, next to Hide tools and reachable from the keyboard. It re-reads the document, remounts the sandboxed viewer, reapplies your annotations, and tells you how many anchors no longer match while keeping those comments in the panel. It is manual on purpose: this is the first checkpoint, and automatic filesystem-driven refresh waits until the restoration behavior has seen real use. URL sessions, archive views, markdown-converted HTML and non-HTML documents are unchanged, and HTML source saving stays off.

Review turned up a share-link race that predated the feature. The share request context included the identity of the resolver, and that identity changes as a side effect of its own success, so the first short link created on an HTML session discarded its own result. That is fixed with a regression test. A browser verification run found two more: the singular toast read "1 annotation no longer match the HTML", and a browser reload after a refresh reverted the page to the startup snapshot because `/api/plan` never re-read disk while the draft annotations persisted against the replaced page. `/api/plan` and `/api/share-html` now share one root read on both server runtimes, so reload and refresh land on the same bytes.

The version diff that a refresh used to cost you is back as well, recomputed rather than dropped. That fix arrived with the QA pass below.

- [#1232](https://github.com/backnotprop/plannotator/pull/1232) by @leoreisdias, with maintainer commits for the share race, the toast and the two-runtime root read

### The HTML annotation surface, packaged for hosts

Applications built on `@plannotator/ui` were hand-rolling their own code around `HtmlViewer` to get the experience Plannotator ships. The Workspaces team asked for the seams to be published, and they now are.

`HtmlSurfaceControls` gives a host the eye, the refresh and the pen with the exact markup, data attributes and aria state Plannotator's header uses, each control rendering only when its handler is passed. `useHtmlRefresh` publishes the refresh lifecycle with the backend behind a `fetchSnapshot` callback, so a host binds it to its own document store. `projectHostThreads` and `buildPersistedHtmlAnchor` in `@plannotator/core/html-anchor` project stored rows onto the annotations prop in the host's order, which is the marker numbering, and trim a composed comment's anchor for persistence within a byte budget. `AnnotationPanel` takes an `unanchoredIds` set and renders a small Unanchored chip on the matching cards. `HtmlViewer` takes `scrollBehavior` so a host can carry a reduced-motion preference across the iframe boundary, and `maxAdditionalTargets` for its own cap on shift-click targets.

Every seam is additive and defaults to today's behavior, and Plannotator's own app passes the same defaults. The one deliberate change you will see in Plannotator is that chip: annotations a Refresh could not re-anchor now carry it in the panel as well as in the toast, and it clears on the next refresh that re-anchors them. The rest was held to a real-browser A/B over an annotate session driven identically on both builds, with header, chrome and overlay-marker captures matching after normalizing minted ids and the port.

- [#1395](https://github.com/backnotprop/plannotator/pull/1395) by @backnotprop

### Renderers that load when they are needed

Mermaid, Graphviz, KaTeX and the identity dictionary used to ride every document read. They now load on demand, while Plannotator's own apps import eager entries as their first import and render exactly as before, typesetting math on the first commit with no frame of raw TeX. On the share portal the entry chunk drops from 1,831,133 to 1,211,620 gzip bytes, with the Graphviz engine and the Mermaid runtime becoming lazy chunks fetched only when a diagram is on the page. For a host that bundles by route, roughly a megabyte of renderer leaves the document-read closure.

The raw-HTML viewer's 185 KB bridge script can also be served as a separately cached asset now. A host passes `bridgeScriptUrl` and gets one classic `<script src>` in the exact position the inline script occupied; the bridge stamps a protocol version on its ready message, so a stale cached asset produces a named warning and an in-surface banner rather than a silent mismatch, and a missing one surfaces as a timeout. Plannotator passes nothing and stays inline everywhere, including the live-app proxy and the Pi and OpenCode copies.

Two rounds of adoption feedback followed the first npm release. The default KaTeX loader moved into its own module so a host that registers its own loader can alias the package default out of its build entirely. Mermaid's own `import("katex")` for `$$` labels was keeping a second KaTeX chunk alive for hosts, and is now redirected through the shared math slot for importers inside the Mermaid package only, which leaves one host-owned chunk instead of two. `bridgeErrorDisplay` lets a host that renders its own failure banner turn off the package's. The documented bridge alias regex was anchored, since the unanchored form matched any specifier ending in `/bridge-script`. And `resetMathRenderer` no longer forgets a registered loader.

- [#1394](https://github.com/backnotprop/plannotator/pull/1394), [#1398](https://github.com/backnotprop/plannotator/pull/1398), [#1399](https://github.com/backnotprop/plannotator/pull/1399) and [#1402](https://github.com/backnotprop/plannotator/pull/1402) by @backnotprop

### First edit in the atomic editor lands sooner

The Workspaces team measured the cost of clicking into the markdown editor and filed the numbers as [#1401](https://github.com/backnotprop/plannotator/issues/1401). Reproducing it in Plannotator showed that the part that grows with document size was not CodeMirror's layout measurement, as first suspected, but three editor extensions each forcing a synchronous parse of the whole document at mount. `@plannotator/atomic-editor` 0.8.1 bounds that mount-time parse to an initial window and grows the syntax tree in idle time afterwards, so decorations beyond the window fill in progressively. On a 283 KB document at 4x CPU throttling, click to second paint goes from 586 ms to 319 ms, and small documents are unchanged. Plannotator picks it up through the dependency update.

- [`2b9dbc9d`](https://github.com/backnotprop/plannotator/commit/2b9dbc9d) by @backnotprop, from [#1401](https://github.com/backnotprop/plannotator/issues/1401)

### Windows uninstall no longer stalls on the PATH edit

CI caught this one. The uninstall lifecycle smoke test failed three times in a row on a single Windows run with "Could not remove ... from the Windows user PATH", while passing on every other run. The same run's cleanup killed several orphaned browser processes, which turned out to be the cause.

`SetEnvironmentVariable` writes the registry and then broadcasts `WM_SETTINGCHANGE` to every top-level window, synchronously, one window at a time, without the flag that skips hung windows. With hung GUI processes around, that broadcast outlasted the uninstaller's 15 second command timeout, PowerShell was killed, and the uninstaller correctly refused to proceed even though the registry edit had already completed. A user with one hung window can hit the same stall.

Both PowerShell scripts now write `HKCU\Environment` directly, reading and restoring the value without expanding `%VARS%` and preserving its `REG_EXPAND_SZ` kind, and broadcast afterwards on a best-effort basis with a one second per-window timeout inside a try/catch, so nothing about notifying open windows can reach the exit code. The fail-closed behavior is intact: a real registry failure still preserves the running CLI, and a timeout with nothing on stdout is still an error because the edit is unproven. A timeout that arrives after the rollback value has been echoed is now treated as the completed edit it is, with a warning that notifying open windows timed out.

- [#1403](https://github.com/backnotprop/plannotator/pull/1403) by @backnotprop

### Pre-release QA

A review pass before tagging turned up six things worth fixing, all of them shipped here.

An HTML root that became unreadable, replaced by a directory or stripped of read permission, used to throw: Pi left `/api/plan` unanswered so the tab hung on reload, and Bun returned a 500. Both runtimes now fall back to the startup snapshot exactly as they do for a missing file. The version diff that vanished for the rest of a session once you refreshed is recomputed against the served bytes instead of being omitted, on reload and through the in-app Refresh, with no history written by a GET. The compact touch shell's Options menu had equivalents for the pen and the eye but not for Refresh, and now offers Refresh from disk under the same conditions as the header button. `HtmlSurfaceControls` rendered its refresh button only inside the eye's branch, so a host passing refresh without the eye got nothing.

Reply threading became one shared rule. `resolveReplyParents` in `@plannotator/core/annotation-threads` resolves parents linearly and cycle-safely for both the annotations panel and the export, so annotations caught in an `inReplyTo` cycle are emitted as roots rather than dropped from feedback while the header count still counted them. Both runtimes' `PATCH /api/external-annotations` now rejects a self-reference or a cycle with a 400, so the invalid state cannot be created in the first place. The WebMCP provider and the viewer also got a hygiene pass: bounded tombstone and request memories, per-instance minted ids, nudge id caps, waiter cleanup on unmount, and a shared retry epoch for diagram blocks.

- [#1405](https://github.com/backnotprop/plannotator/pull/1405) by @backnotprop

### Additional Changes

- **npm releases**: `@plannotator/core` 0.25.0 with `@plannotator/ui` 0.32.0 ([#1396](https://github.com/backnotprop/plannotator/pull/1396)), then `@plannotator/ui` 0.33.0 ([#1400](https://github.com/backnotprop/plannotator/pull/1400)) and 0.34.0 ([#1402](https://github.com/backnotprop/plannotator/pull/1402)) on the same core. Plannotator's own apps are unaffected by all of it.

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

**Pi:** Update `@plannotator/pi-extension` to 0.27.9 and restart Pi.

**OpenCode:** Clear cache and restart:

```bash
rm -rf ~/.bun/install/cache/@plannotator
```

## What's Changed

- feat(webmcp): expose plan review and annotate as WebMCP tools for browser agents by @backnotprop in [#1393](https://github.com/backnotprop/plannotator/pull/1393)
- feat(annotate): manual refresh of rendered HTML from disk by @leoreisdias in [#1232](https://github.com/backnotprop/plannotator/pull/1232)
- feat(ui): publish the HTML annotation seams hosts were hand-rolling by @backnotprop in [#1395](https://github.com/backnotprop/plannotator/pull/1395)
- perf(ui): lazy diagram and math renderers with eager entries for Plannotator by @backnotprop in [#1394](https://github.com/backnotprop/plannotator/pull/1394)
- chore(packages): bump @plannotator/core to 0.25.0, @plannotator/ui to 0.32.0 by @backnotprop in [#1396](https://github.com/backnotprop/plannotator/pull/1396)
- perf(ui): load the HTML viewer bridge by URL for hosts, with a protocol version and ready timeout by @backnotprop in [#1398](https://github.com/backnotprop/plannotator/pull/1398)
- fix(ui): 0.32.0 adoption feedback from hosts by @backnotprop in [#1399](https://github.com/backnotprop/plannotator/pull/1399)
- chore(packages): bump @plannotator/ui to 0.33.0 by @backnotprop in [#1400](https://github.com/backnotprop/plannotator/pull/1400)
- fix(ui): 0.33.0 adoption feedback and bump @plannotator/ui to 0.34.0 by @backnotprop in [#1402](https://github.com/backnotprop/plannotator/pull/1402)
- chore(ui): update @plannotator/atomic-editor to 0.8.1 for the editor entry fix by @backnotprop in [`2b9dbc9d`](https://github.com/backnotprop/plannotator/commit/2b9dbc9d)
- fix(uninstall): edit the Windows user PATH through the registry with a best-effort change broadcast by @backnotprop in [#1403](https://github.com/backnotprop/plannotator/pull/1403)
- fix: pre-release QA findings for 0.27.9 by @backnotprop in [#1405](https://github.com/backnotprop/plannotator/pull/1405)

## Community

- @leoreisdias built the HTML Refresh action in [#1232](https://github.com/backnotprop/plannotator/pull/1232), including the refresh lifecycle and the annotation restoration reporting that the maintainer additions and the QA pass then built on. It is the latest in a long run of contributions from @leoreisdias.
- The Workspaces team's adoption of `@plannotator/ui` drove three of the changes here: the parity seams in [#1395](https://github.com/backnotprop/plannotator/pull/1395), the two rounds of adoption feedback in [#1399](https://github.com/backnotprop/plannotator/pull/1399) and [#1402](https://github.com/backnotprop/plannotator/pull/1402), and the editor measurements filed as [#1401](https://github.com/backnotprop/plannotator/issues/1401) that produced the atomic-editor fix.
- @HunterClarke-git reported [#1392](https://github.com/backnotprop/plannotator/issues/1392), where settings tabs appeared only after a delay and an OpenCode session closed while the review window stayed open. The report has been investigated and a fix is designed, but it did not make this release. Work on it is under way.
- @arklanq-patronus reported [#1367](https://github.com/backnotprop/plannotator/issues/1367), where `annotate-last` on Codex fails when a single thread spans several rollout files. @mohammadrezwankhan has an open pull request for it in [#1387](https://github.com/backnotprop/plannotator/pull/1387), still under review.
- @rNoz reported [#1388](https://github.com/backnotprop/plannotator/issues/1388), where the root build script builds the hook before the review bundle it copies from, and opened [#1389](https://github.com/backnotprop/plannotator/pull/1389) with the fix. It is open.
- The Windows PATH stall was found by the release pipeline's own smoke test rather than by a user, which is what the job is there for.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.27.8...v0.27.9
