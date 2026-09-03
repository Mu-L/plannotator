Follow [@plannotator](https://x.com/plannotator) on X for updates

---

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.26.2](https://github.com/backnotprop/plannotator/releases/tag/v0.26.2)   | Single-file diff tabs render fully, no more silently dropped review files, light/dark theme pairs, palette-matched code blocks   |
| [v0.26.1](https://github.com/backnotprop/plannotator/releases/tag/v0.26.1)   | GitButler 0.22.0 compatibility via capability-probed JSON flags                                                                   |
| [v0.26.0](https://github.com/backnotprop/plannotator/releases/tag/v0.26.0)   | Edit Mode (suggest by editing the diff), Guided Review virtualization, colorblind theme, safe uninstall, installer opt-outs, OpenCode 2 support |
| [v0.25.1](https://github.com/backnotprop/plannotator/releases/tag/v0.25.1)   | Codex no longer launches on review open, annotate-last follows the live conversation, pi-todos mirror, Claude Opus 5, abandoned-gate dismissal |
| [v0.25.0](https://github.com/backnotprop/plannotator/releases/tag/v0.25.0)   | Vim keyboard controls, Approve with Notes, scriptable annotate gates, persistent Guided Reviews, memory and file-watching hardening |
| [v0.24.2](https://github.com/backnotprop/plannotator/releases/tag/v0.24.2)   | Annotate YAML/JSON/TOML config files, XDG data directory support, Codex model catalog update, Cursor sandbox escape hatch        |
| [v0.24.1](https://github.com/backnotprop/plannotator/releases/tag/v0.24.1)   | Annotate accepts parent-relative `../` file paths                                                                                |
| [v0.24.0](https://github.com/backnotprop/plannotator/releases/tag/v0.24.0)   | PR/MR artifact gallery, GitButler review support, port ranges, expanded comment editor, OpenCode + Pi fixes                       |
| [v0.23.1](https://github.com/backnotprop/plannotator/releases/tag/v0.23.1)   | Startup no longer hangs on large or slow directory trees, Ask AI input stays visible after long responses                        |
| [v0.23.0](https://github.com/backnotprop/plannotator/releases/tag/v0.23.0)   | Plan approval fix for Claude Code 2.1.199+, annotate mode version diff, binary-only `--minimal` install, reviews post without attribution |
| [v0.22.0](https://github.com/backnotprop/plannotator/releases/tag/v0.22.0)   | Git-status "All changes" default review view, Commits panel with per-commit diffs, Guided Review, Pi + GitHub Copilot CLI review engines |

</details>

---

## What's New in v0.26.3

This release adds skill references in comments, gives remote sessions a URL you can actually open from another device, and fixes two small UI annoyances. Nine PRs, including a first contribution from @ivgiuliani.

### Reference agent skills in your comments with / or $

While writing a comment in plan review or annotate mode, type `/` or `$` and a menu of your installed agent skills appears: everything discovered under `~/.claude/skills`, `~/.codex/skills`, and `~/.agents/skills`, including skills installed as symlinks. Arrow keys, Tab, Enter, or a click inserts the reference; a comment can carry several. Nothing is preselected, so a stray `/` or `$` in ordinary typing never hijacks Enter, and prose like "a POST /agents endpoint" or "$5/mo" is never mistaken for a reference.

Referenced skills change what the agent receives. The exported feedback lists each one with an explicit instruction that you are asking the agent to invoke it. Skills marked `disable-model-invocation: true` cannot be invoked by the agent, so for those the feedback includes the skill's instructions directly, inside clearly fenced markers, labeled as included at your request. The menu shows a quiet badge on human-only skills so you know which treatment applies before you pick one.

The feature landed alongside its own hardening pass, driven by a pre-release QA sweep: a render loop triggered by human-only references was fixed, case-colliding skill names across roots resolve exactly, and the injection markers cannot be forged by a hostile skill body, even with invisible Unicode characters.

- [#1229](https://github.com/backnotprop/plannotator/pull/1229), hardened in [#1234](https://github.com/backnotprop/plannotator/pull/1234) and [#1235](https://github.com/backnotprop/plannotator/pull/1235)

### Remote sessions advertise a URL you can reach

Until now a remote session (SSH, devcontainer, Tailscale) printed `http://localhost:19432`, which is useless from the phone or laptop you actually want to review on. Set `PLANNOTATOR_URL_HOST` to a hostname or IP that resolves on your network (a Tailscale MagicDNS name, a tailnet IP) and every advertised session URL uses it.

The override is display-only and deliberately strict: it accepts a bare hostname, IPv4, or bracketed IPv6, and anything carrying a scheme, port, path, or credentials warns once and falls back to `localhost`. Binding is still governed by `PLANNOTATOR_REMOTE`, and local sessions ignore the override entirely (with a warning telling you why), so a tailnet-only name can never break same-machine workflows. It can also be set persistently via `~/.plannotator/config.json` (`{ "urlHost": "host" }`).

- [#1225](https://github.com/backnotprop/plannotator/pull/1225), closing [#657](https://github.com/backnotprop/plannotator/issues/657) requested by @centdix

### Full branch names in the worktree switcher

Long branch names in the review header's worktree switcher were truncated with no way to read the rest. Hovering an entry now shows the complete branch name as a tooltip.

- [#1223](https://github.com/backnotprop/plannotator/pull/1223) by @ivgiuliani

### Additional Changes

- **"Hide tools" now hides everything.** In HTML annotate sessions, hiding the tools also hides the collapsed sidebar tab flags on the left edge, so the page gets the full window ([#1226](https://github.com/backnotprop/plannotator/pull/1226))
- **Archive sharing docs corrected.** The docs now describe what archive mode actually does with sharing ([#1176](https://github.com/backnotprop/plannotator/pull/1176), closing [#1172](https://github.com/backnotprop/plannotator/issues/1172))
- **Test reliability.** The PowerShell installer tests tolerate pwsh cold starts ([#1227](https://github.com/backnotprop/plannotator/pull/1227)) and the diff renderer's test mocks restore correctly regardless of file order ([#1230](https://github.com/backnotprop/plannotator/pull/1230))

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

- fix(review): show the full branch name when hovering the worktree switcher by @ivgiuliani in [#1223](https://github.com/backnotprop/plannotator/pull/1223)
- feat: add PLANNOTATOR_URL_HOST display-only override for advertised URLs by @backnotprop in [#1225](https://github.com/backnotprop/plannotator/pull/1225)
- fix(annotate): hide the collapsed sidebar tab flags when tools are hidden by @backnotprop in [#1226](https://github.com/backnotprop/plannotator/pull/1226)
- test(install): give the PowerShell scanner tests room for pwsh cold start by @backnotprop in [#1227](https://github.com/backnotprop/plannotator/pull/1227)
- feat(comments): reference agent skills with / or $ in plan review and annotate comments by @backnotprop in [#1229](https://github.com/backnotprop/plannotator/pull/1229)
- fix(test): make the @pierre/diffs mock restore actually restore by @backnotprop in [#1230](https://github.com/backnotprop/plannotator/pull/1230)
- docs: correct archive sharing posture by @backnotprop in [#1176](https://github.com/backnotprop/plannotator/pull/1176)
- fix(editor): stop the skill-content priming effect from re-render looping by @backnotprop in [#1234](https://github.com/backnotprop/plannotator/pull/1234)
- fix(skills): harden skill references before first release by @backnotprop in [#1235](https://github.com/backnotprop/plannotator/pull/1235)

## New Contributors

- @ivgiuliani made their first contribution in [#1223](https://github.com/backnotprop/plannotator/pull/1223)

## Community

@ivgiuliani noticed truncated branch names in the worktree switcher and fixed it directly. First contribution, and a clean one.

@centdix filed the original request for network-reachable session URLs ([#657](https://github.com/backnotprop/plannotator/issues/657)), and @maxim and @prvnsmpth added the deployment details (Tailscale setups, concrete environment variable shape) that the implementation followed.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.26.2...v0.26.3
