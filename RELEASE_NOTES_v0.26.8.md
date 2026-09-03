Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.26.7](https://github.com/backnotprop/plannotator/releases/tag/v0.26.7)   | Pinpoint targets any element on HTML pages, smarter hover labels, zero-scan hit testing                                          |
| [v0.26.6](https://github.com/backnotprop/plannotator/releases/tag/v0.26.6)   | Fixed empty environment variables in sandboxed sessions (Bun 1.3.14 builds)                                                      |
| [v0.26.5](https://github.com/backnotprop/plannotator/releases/tag/v0.26.5)   | HTML pinpoint element annotations, durable annotate submissions, installer fallback for old git, vim HUD cursor fix              |
| [v0.26.4](https://github.com/backnotprop/plannotator/releases/tag/v0.26.4)   | Skill-menu hover jitter fix (same-day patch on v0.26.3)                                                                          |
| [v0.26.3](https://github.com/backnotprop/plannotator/releases/tag/v0.26.3)   | Skill references in comments with / or $, reachable remote session URLs, worktree switcher tooltips                              |
| [v0.26.2](https://github.com/backnotprop/plannotator/releases/tag/v0.26.2)   | Single-file diff tabs render fully, no more silently dropped review files, light/dark theme pairs, palette-matched code blocks   |
| [v0.26.1](https://github.com/backnotprop/plannotator/releases/tag/v0.26.1)   | GitButler 0.22.0 compatibility via capability-probed JSON flags                                                                   |
| [v0.26.0](https://github.com/backnotprop/plannotator/releases/tag/v0.26.0)   | Edit Mode (suggest by editing the diff), Guided Review virtualization, colorblind theme, safe uninstall, installer opt-outs, OpenCode 2 support |
| [v0.25.1](https://github.com/backnotprop/plannotator/releases/tag/v0.25.1)   | Codex no longer launches on review open, annotate-last follows the live conversation, pi-todos mirror, Claude Opus 5, abandoned-gate dismissal |
| [v0.25.0](https://github.com/backnotprop/plannotator/releases/tag/v0.25.0)   | Vim keyboard controls, Approve with Notes, scriptable annotate gates, persistent Guided Reviews, memory and file-watching hardening |
| [v0.24.2](https://github.com/backnotprop/plannotator/releases/tag/v0.24.2)   | Annotate YAML/JSON/TOML config files, XDG data directory support, Codex model catalog update, Cursor sandbox escape hatch        |
| [v0.24.0](https://github.com/backnotprop/plannotator/releases/tag/v0.24.0)   | PR/MR artifact gallery, GitButler review support, port ranges, expanded comment editor, OpenCode + Pi fixes                       |

</details>

## What's New in v0.26.8

This release rebuilds how annotations look and behave on HTML pages, and it is the largest change to the annotate surface since pinpoint mode shipped. Nine PRs landed, three of them from first-time contributors @Snaylaker, @atomicflag, and @monkhai.

### Placed comment markers replace inline highlights on HTML pages

Annotating a raw HTML page used to write highlight markup directly into the page's own DOM. That caused two visible bugs: multi-paragraph selections often turned only their first paragraph blue, and on some pages the injected markup broke the page's layout. Both had the same root cause, so both are gone the same way: nothing writes into the page anymore.

Annotations now appear as numbered comment bubbles projected onto a fixed overlay above the page. A bubble sits at the exact point you clicked, not a corner of the element, and it stays glued through scrolling, page re-renders, responsive reflows, and zoom. If the annotated element disappears or scrolls out of a clipped container, its bubble hides instead of floating over unrelated content, and it returns when the target does. Selections highlight through the same overlay, so highlights now always cover the full selection and can never disturb the page beneath.

The bubbles are real buttons: click one, or click the highlighted text itself, to jump to that annotation in the panel. Highlights brighten on hover so you can tell they are clickable. Bubble numbers match the numbering in the feedback your agent receives, so "see comment 3" means the same thing on screen and in the session. Committed highlights still print; annotating with Cmd+P in mind works the way it did before.

The implementation went through three adversarial review rounds, a 25-item QA gate with independent verification of every serious finding, and a follow-up hardening pass covering clipping, visibility, print, and per-frame performance on mutation-heavy pages.

- [#1257](https://github.com/backnotprop/plannotator/pull/1257), [#1258](https://github.com/backnotprop/plannotator/pull/1258)

### Shift-click selects multiple elements for one comment

One comment can now cover several places on an HTML page. Make a pinpoint selection, hold Shift, and click more elements: each gains an outline and a chip in the composer, Shift-clicking a selected element removes it, and removing the first selection promotes the next one rather than cancelling the draft. Up to 16 additional targets ride on one comment, and after saving, every target shows a bubble carrying the same comment number. Feedback to the agent lists every selected element, so "these three buttons need the same fix" is one comment, not three.

- [#1254](https://github.com/backnotprop/plannotator/pull/1254)

### HTML sessions open minimal, and stale preferences reset

Opening an HTML page to annotate now shows just the page: pinpoint input ready, tools hidden, sidebar and annotations drawer closed. Anything you change persists for your next HTML session, but only while you keep using HTML annotate. A preference untouched for a week expires back to these defaults, so a mode you tried once months ago never becomes a permanent surprise. Active users keep their setup; annotating refreshes the clock.

- [#1260](https://github.com/backnotprop/plannotator/pull/1260)

### Pages with their own Content-Security-Policy are now annotatable

An HTML file carrying its own strict CSP meta tag (common in saved pages and generated reports) silently blocked the annotation script, leaving a page you could see but not annotate. The annotate viewer now removes the document's CSP meta tags before rendering. The iframe sandbox remains the security boundary, and the file on disk is untouched.

- [#1259](https://github.com/backnotprop/plannotator/pull/1259)

### OpenCode: Qwen3.6 no longer corrupts the planning prompt

OpenCode sessions using Qwen3.6 hit a Jinja template conflict: Plannotator injected its planning instructions as multiple system-prompt parts, and Qwen's template mangled them. @atomicflag rewrote the injection to compose one consolidated system part. The review process surfaced a subtle evaluation-order bug and an escaping edge case, both fixed and regression-tested, and the QA gate then caught that the OpenCode 2 adapter still used the old multi-part path, so the fix now covers both OpenCode 1 and OpenCode 2 entry points.

- [#1114](https://github.com/backnotprop/plannotator/pull/1114) by @atomicflag, completed in [#1258](https://github.com/backnotprop/plannotator/pull/1258)

### Plan position survives window refocus in vim mode

Switching away from a plan review window and back again reset the vim cursor to the top of the document. @Snaylaker fixed the refocus path to preserve your position, so alt-tabbing to check something no longer costs you your place in a long plan.

- [#1252](https://github.com/backnotprop/plannotator/pull/1252) by @Snaylaker

### Additional Changes

- **File headers show a hover state in code review.** Diff file headers now tint on hover with a short transition, signaling that the header is clickable (it collapses the file). Contributed by @monkhai in [#1256](https://github.com/backnotprop/plannotator/pull/1256).
- **The legacy self-hosting docs route redirects to the canonical docs site.** [#1255](https://github.com/backnotprop/plannotator/pull/1255)

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

## What's Changed

- fix(vim): preserve plan position on refocus by @Snaylaker in [#1252](https://github.com/backnotprop/plannotator/pull/1252)
- Fix OpenCode plugin Jinja template corruption with Qwen3.6 by @atomicflag in [#1114](https://github.com/backnotprop/plannotator/pull/1114)
- feat(annotate): shift-click multi-element selection for raw-HTML pinpoint by @backnotprop in [#1254](https://github.com/backnotprop/plannotator/pull/1254)
- fix(marketing): redirect self-hosting guide to canonical docs by @backnotprop in [#1255](https://github.com/backnotprop/plannotator/pull/1255)
- feat(review): add file header hover state by @monkhai in [#1256](https://github.com/backnotprop/plannotator/pull/1256)
- feat(annotate): placed comment markers for raw-HTML annotation by @backnotprop in [#1257](https://github.com/backnotprop/plannotator/pull/1257)
- fix: QA-gate hardening for the v0.26.8 feature set by @backnotprop in [#1258](https://github.com/backnotprop/plannotator/pull/1258)
- fix(annotate): strip document-authored CSP meta tags that block the annotation bridge by @backnotprop in [#1259](https://github.com/backnotprop/plannotator/pull/1259)
- feat(annotate): minimal-by-default HTML sessions with stale-preference decay by @backnotprop in [#1260](https://github.com/backnotprop/plannotator/pull/1260)

## New Contributors

- @Snaylaker made their first contribution in [#1252](https://github.com/backnotprop/plannotator/pull/1252)
- @atomicflag made their first contribution in [#1114](https://github.com/backnotprop/plannotator/pull/1114)
- @monkhai made their first contribution in [#1256](https://github.com/backnotprop/plannotator/pull/1256)

## Contributors

Three first-time contributors landed changes in this release. @atomicflag took on a genuinely tricky compatibility problem between Plannotator's system-prompt injection and Qwen3.6's Jinja template, and stuck with it through three review rounds until the fix was airtight. @Snaylaker fixed the vim-mode position reset on window refocus, a small paper cut that anyone reviewing long plans felt daily. @monkhai polished the code review diff headers with a hover state that makes the collapse affordance discoverable.

Welcome to all three, and thank you.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.26.7...v0.26.8
