Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
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
| [v0.26.5](https://github.com/backnotprop/plannotator/releases/tag/v0.26.5)   | HTML pinpoint element annotations, durable annotate submissions, installer fallback for old git, vim HUD cursor fix              |

</details>

## What's New in v0.27.8

A patch release with two quality-of-life fixes: Pi sessions stop losing their prompt cache when a plan finishes, and the thumbs-up returns to HTML annotation in a restrained form. Both came from user reports filed within the last week.

### Pi keeps your prompt cache when a plan finishes

Finishing plan execution on Pi used to invalidate the LLM provider's prompt cache. Plannotator injects its plan instructions as conversation messages, and when the plan ended it deleted them from the middle of the chat history. Providers cache conversations front to back, so everything after the deleted message was re-billed at full uncached rates on the next turn. In the reporting user's session that meant re-paying for roughly 90 messages.

Plannotator no longer rewrites history. Old plan instructions stay where they are, and a note at the end of the conversation tells the model the plan is over and earlier instructions no longer apply. The phase instructions now state explicitly that they supersede anything Plannotator said before, so stale planning rules cannot keep steering the model. A regression test verifies each outgoing request extends the previous one byte for byte across the full planning, executing, and idle lifecycle.

Thanks @WinPooh32 for the report, and especially for attaching the exact before/after request payloads. They turned diagnosis into a five minute job.

- [#1381](https://github.com/backnotprop/plannotator/pull/1381) by @backnotprop, closing [#1380](https://github.com/backnotprop/plannotator/issues/1380) reported by @WinPooh32

### The thumbs-up is back on HTML pages

v0.27.5 made HTML and live-app annotation comment-only: delete and label tools were markdown concepts that never fit arbitrary pages. That ruling had a side effect we did not intend to keep: there was no longer any one-click way to say "this part is good." Approving something meant opening the comment composer and typing it out.

Exactly one label affordance returns: the 👍 "Looks good" button. Select text and it is in the toolbar; pinpoint-click an element and it is a one-click action in the comment composer (disabled once you start typing, so it can never discard a draft). Everything else about comment-only holds: no delete, no label picker, no label keyboard shortcuts, and the security clamp that stops a hostile page from forcing annotations through the bridge is untouched.

- [`0ae40e73`](https://github.com/backnotprop/plannotator/commit/0ae40e73) by @backnotprop, from a developer report

### Additional Changes

- **Embed picker seam for `@plannotator/ui` hosts**: the `/embed` slash-menu picker (target list, empty states, kind-aware upload adapter, paragraph splice) is now a host-configurable extension in the published UI package, shipped to npm as `@plannotator/ui@0.31.0` with `@plannotator/core@0.24.0`. Plannotator's own apps are unaffected. [#1382](https://github.com/backnotprop/plannotator/pull/1382) by @backnotprop

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

**Pi:** Update `@plannotator/pi-extension` to 0.27.8 and restart Pi.

**OpenCode:** Clear cache and restart:

```bash
rm -rf ~/.bun/install/cache/@plannotator
```

## What's Changed

- fix(pi): append-only phase framing so plan transitions keep the prompt cache by @backnotprop in [#1381](https://github.com/backnotprop/plannotator/pull/1381)
- feat(ui): add embed media picker seam by @backnotprop in [#1382](https://github.com/backnotprop/plannotator/pull/1382)
- feat(annotate): restore a restricted thumbs-up on comment-only HTML surfaces by @backnotprop in [`0ae40e73`](https://github.com/backnotprop/plannotator/commit/0ae40e73)

## Community

- @WinPooh32 reported the Pi cache invalidation in [#1380](https://github.com/backnotprop/plannotator/issues/1380) with the request payloads that made the diagnosis immediate
- The thumbs-up gap was reported directly by a developer using HTML annotation for report review

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.27.7...v0.27.8
