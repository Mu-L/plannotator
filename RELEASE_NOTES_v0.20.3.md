Follow [@plannotator](https://x.com/plannotator) on X for updates

---

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.20.2](https://github.com/backnotprop/plannotator/releases/tag/v0.20.2)   | Pierre CodeView all-files review, large-PR pipeline and instant-open checkout, unified agent engine selection, Pi programmatic plan mode |
| [v0.20.1](https://github.com/backnotprop/plannotator/releases/tag/v0.20.1)   | Pi extension install hotfix (pinned `@pierre/diffs` after a broken upstream release)                                             |
| [v0.20.0](https://github.com/backnotprop/plannotator/releases/tag/v0.20.0)   | Multi-repo workspace reviews, semantic diff overview, UI 2.0 themes and plan look chooser, leaner single-source skill install   |
| [v0.19.27](https://github.com/backnotprop/plannotator/releases/tag/v0.19.27) | Kiro CLI integration, Glimpse native window, annotate-last message picker                                                        |
| [v0.19.26](https://github.com/backnotprop/plannotator/releases/tag/v0.19.26) | Amp plugin production fixes, Mermaid rendering fix, Settings flicker fix, update notification toast and shimmer                   |
| [v0.19.24](https://github.com/backnotprop/plannotator/releases/tag/v0.19.24) | Amp integration, configurable data directory, Auto Mode permission option, Pi plan approval fix                                  |
| [v0.19.23](https://github.com/backnotprop/plannotator/releases/tag/v0.19.23) | Droid integration, Windows Pi AI fix, quieter update indicator                                                                   |
| [v0.19.22](https://github.com/backnotprop/plannotator/releases/tag/v0.19.22) | Safari copy fix in plan viewer, CLAUDE_CONFIG_DIR support for session logs                                                       |
| [v0.19.21](https://github.com/backnotprop/plannotator/releases/tag/v0.19.21) | Ask AI in plan review and annotate mode, shared AI runtime, origin-aware provider defaults                                       |
| [v0.19.20](https://github.com/backnotprop/plannotator/releases/tag/v0.19.20) | Interactive goal setup UI, OpenCode submit_plan fixes, browser no-op sentinel handling for Claude agents                         |
| [v0.19.18](https://github.com/backnotprop/plannotator/releases/tag/v0.19.18) | Edit-based submit_plan for OpenCode, Pi namespace migration, Codex annotate-last fix, OpenCode commands dir fix                  |

</details>

---

## What's New in v0.20.3

v0.20.3 is a small patch of two PRs, both focused on the comment popover used in plan review and annotate mode. The first stops in-progress annotation text from being thrown away, and stops the annotation panel from forcing itself open. The second adds a way to find a comment box again after it scrolls out of view. Both came out of community feature requests.

### Annotations No Longer Lost When You Click Away

The comment popover used to close on any click outside it, which discarded whatever you had typed but not yet saved. A misplaced click meant retyping the annotation. Now a popover that holds text or an attached image stays open when you click elsewhere, so your in-progress work survives a stray click. Empty popovers still close on an outside click, and Escape and the X button still cancel explicitly, so nothing changes about how you dismiss a box you actually want to discard.

The same release stops annotations from forcing the right annotation panel open. If you had closed the panel, adding a plan annotation or a code-file popout annotation used to reopen it and pull focus away from what you were reading. The panel now stays in whatever state you left it, and you can open it from the header toggle when you want it. The annotation itself is still selected and still shows its highlight, so it is never lost or hidden.

- [#919](https://github.com/backnotprop/plannotator/pull/919) closing [#821](https://github.com/backnotprop/plannotator/issues/821) and [#888](https://github.com/backnotprop/plannotator/issues/888), contributed by @backnotprop

### Off-Screen Indicator for an Open Comment

Because an open comment box now persists when you click or scroll away, it became possible to leave one open above or below the visible area and lose track of it. When that happens, a small pill appears pinned to the top or bottom of the viewport with a chevron pointing toward the box and an "Open comment" label. Clicking it scrolls back to the comment. The indicator only appears for a box that has actually left the viewport and disappears as soon as it returns, so it stays out of the way the rest of the time.

- [#920](https://github.com/backnotprop/plannotator/pull/920), contributed by @backnotprop

## Install / Update

**macOS / Linux:**

```bash
curl -fsSL https://plannotator.ai/install.sh | bash
```

**Windows:**

```powershell
irm https://plannotator.ai/install.ps1 | iex
```

**Extra skills** (compound, setup-goal, visual-explainer), opt-in:

```bash
npx skills add backnotprop/plannotator/apps/skills/extra
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

**Droid:** Install via the plugin marketplace:

```
droid plugin marketplace add backnotprop/plannotator
droid plugin install plannotator@plannotator
```

**Amp:** Install the CLI first, then copy the plugin:

```bash
mkdir -p ~/.config/amp/plugins
curl -fsSL https://raw.githubusercontent.com/backnotprop/plannotator/main/apps/amp-plugin/plannotator.ts \
  -o ~/.config/amp/plugins/plannotator.ts
```

**Kiro CLI:** The installer auto-detects Kiro and installs skills automatically. After installing the CLI, launch with:

```bash
kiro-cli chat --agent plannotator
```

Upgrading from before v0.20.0? Read the [v0.20.0 release notes](https://github.com/backnotprop/plannotator/releases/tag/v0.20.0) first; that release changed how skills install.

---

## What's Changed

- Keep annotation panel closed when adding annotations by @backnotprop in [#919](https://github.com/backnotprop/plannotator/pull/919)
- feat(annotate): off-screen indicator for open comment popover by @backnotprop in [#920](https://github.com/backnotprop/plannotator/pull/920)

## Community

Both changes in this release answer feature requests from the community. @8bitjoey asked for the annotation input to keep its text instead of closing on an outside click ([#821](https://github.com/backnotprop/plannotator/issues/821)), and @jj-valentine asked for annotations to be saved rather than lost ([#888](https://github.com/backnotprop/plannotator/issues/888)). @SyahrulBhudiF and @gwynnnplaine joined the discussion on #821 that shaped the behavior.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.20.2...v0.20.3
