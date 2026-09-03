Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.21.0](https://github.com/backnotprop/plannotator/releases/tag/v0.21.0)   | Direct document editing in annotate mode, live git-status file tree, in-app agent terminal, open files in external apps, HTML renders as HTML |
| [v0.20.3](https://github.com/backnotprop/plannotator/releases/tag/v0.20.3)   | Annotations no longer lost when clicking away, off-screen indicator for open comments                                            |
| [v0.20.2](https://github.com/backnotprop/plannotator/releases/tag/v0.20.2)   | Pierre CodeView all-files review, large-PR pipeline and instant-open checkout, unified agent engine selection, Pi programmatic plan mode |
| [v0.20.1](https://github.com/backnotprop/plannotator/releases/tag/v0.20.1)   | Pi extension install hotfix (pinned `@pierre/diffs` after a broken upstream release)                                             |
| [v0.20.0](https://github.com/backnotprop/plannotator/releases/tag/v0.20.0)   | Multi-repo workspace reviews, semantic diff overview, UI 2.0 themes and plan look chooser, leaner single-source skill install   |
| [v0.19.27](https://github.com/backnotprop/plannotator/releases/tag/v0.19.27) | Kiro CLI integration, Glimpse native window, annotate-last message picker                                                        |
| [v0.19.26](https://github.com/backnotprop/plannotator/releases/tag/v0.19.26) | Amp plugin production fixes, Mermaid rendering fix, Settings flicker fix, update notification toast and shimmer                   |
| [v0.19.24](https://github.com/backnotprop/plannotator/releases/tag/v0.19.24) | Amp integration, configurable data directory, Auto Mode permission option, Pi plan approval fix                                  |
| [v0.19.23](https://github.com/backnotprop/plannotator/releases/tag/v0.19.23) | Droid integration, Windows Pi AI fix, quieter update indicator                                                                   |
| [v0.19.22](https://github.com/backnotprop/plannotator/releases/tag/v0.19.22) | Safari copy fix in plan viewer, CLAUDE_CONFIG_DIR support for session logs                                                       |
| [v0.19.21](https://github.com/backnotprop/plannotator/releases/tag/v0.19.21) | Ask AI in plan review and annotate mode, shared AI runtime, origin-aware provider defaults                                       |

</details>

---

## What's New in v0.21.1

A single-fix patch release. Annotating the last assistant message could open a blank page in any conversation with more than one response. This release fixes that.

### Annotate-Last No Longer Blanks on Multi-Message Sessions

Running `/plannotator-last` (or `plannotator last`) opened a blank page whenever the session had two or more recent assistant messages. With zero or one message it worked, so it looked intermittent, but it was deterministic: the failure tracked message count. It was most visible on the Pi extension, where multi-turn sessions are the norm.

The cause was a React rendering bug. When the annotate UI assembled the feedback payload during render, it reached a helper that wrote component state as a side effect. Because that state was a freshly built map on each pass, React never settled, hit its re-render limit, and threw before drawing anything, leaving an empty page. The fix makes that render-path helper a pure read of the same data, so the work that belongs at submit time no longer fires during render. The exported feedback is unchanged; the page renders.

PR [#950](https://github.com/backnotprop/plannotator/pull/950) closing [#949](https://github.com/backnotprop/plannotator/issues/949), reported, diagnosed, and fixed by @emmaneugene.

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

- fix(editor): stop setState-during-render loop in multi-message annotate by @backnotprop in [#950](https://github.com/backnotprop/plannotator/pull/950)

## Community

Thanks to @emmaneugene, who reported the blank-page regression in [#949](https://github.com/backnotprop/plannotator/issues/949), traced it to the exact render-path state write, and supplied the fix that this release ships.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.21.0...v0.21.1
