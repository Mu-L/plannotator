Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.26.8](https://github.com/backnotprop/plannotator/releases/tag/v0.26.8)   | Placed comment markers on HTML pages, shift-click multi-select, live app annotation                                              |
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

</details>

## What's New in v0.27.0

This is the largest release since v0.25.0: Call Flow analysis for code review, a first-class Tailscale story for reviewing from another device, a rework of the review panel around how people actually switch views, and a rebuilt Pi integration. Fourteen PRs landed. Every feature went through independent review, and the release as a whole passed two full QA sweeps (a 28-item verification workflow plus live journey, seam, and free-roam testing) before tagging.

> [!IMPORTANT]
> **Breaking change for Pi users:** the Pi plan-mode command is renamed `/plannotator` → `/plannotator-plan-mode`. The old command no longer does anything. Update any saved workflows or muscle memory. See the Pi section below for why.

### Call Flow: see the call paths your diff changes

Code review gets a third analysis layer alongside semantic diff: **Call Flow**, powered by CallDiff (AST-based, built with Tree-sitter, 22 languages supported). Enable it and the review computes, for the changeset on screen, every call path that gained or lost a call: trees rooted at your entry points, walking down to the exact functions the diff touched. A tax calculation moving from before a discount to after it shows up as a removed call and an added call in the same tree, rendered across every route that reaches it. A text diff cannot show you that.

Enabling Call flow is consent for a small managed runtime install (about 5 MB: a pruned CallDiff core plus only the language packs your changed files need). The install runs in the background while you review; missing languages install themselves later under the same consent, and a Languages list supports installing ahead. Nothing is downloaded unless you opt in, the app works fully without it, and a failed install degrades to a clear retry, never a broken review.

The path view organizes into collapsible entry sections with changed-path defaults and file boundaries. Every Call Flow row is commentable: click a row to start a comment, shift-click to collect multiple steps into one annotation. Comments on rows inside the visible diff anchor inline; rows outside it become file- or review-scoped feedback with the full call context preserved for your agent. A searchable raw view with a color-classified rendering is there when you want the unprocessed output, and Cmd+F inside the panel searches the analysis rather than the file tree.

- [#1268](https://github.com/backnotprop/plannotator/pull/1268), [#1270](https://github.com/backnotprop/plannotator/pull/1270), [#1271](https://github.com/backnotprop/plannotator/pull/1271), [#1272](https://github.com/backnotprop/plannotator/pull/1272), [#1277](https://github.com/backnotprop/plannotator/pull/1277)

### Review from your iPad: --tailscale mode, tailnet auto-detection, and a QR code

Two community threads asked the same question from different directions: can I run the agent on my Mac and do the review from an iPad, and can I get a diff out of a VPS without SSH port-mapping gymnastics. @nikuscs went as far as building a proof-of-concept wrapper script. As of this release the answer is built in:

```bash
plannotator review --tailscale
```

The server stays bound to localhost. Plannotator runs `tailscale serve` in front of it, prints an HTTPS URL that works on every device in your tailnet, and renders a QR code in the terminal so a phone or tablet joins by pointing a camera at it. The serve mapping is cleaned up when the session ends, an existing mapping on the port is never stolen, and if Tailscale is not installed the command fails fast with an actionable message. `annotate` and `annotate-last` support the same flag.

For classic remote mode, `PLANNOTATOR_URL_HOST=auto` now resolves your machine's MagicDNS name (or tailnet IP) automatically, so multi-VPS setups no longer configure a hostname per machine. Remote-ready output includes the same QR code.

Security posture, spelled out: nothing binds beyond localhost under `--tailscale`, the URL is reachable only inside your own tailnet, public exposure (funnel, ngrok-style tunnels) is deliberately not supported, and the annotate agent terminal stays off for tailnet-published sessions unless you set the existing `PLANNOTATOR_AGENT_TERMINAL_REMOTE=1` opt-in. The feature went through an independent security review plus an external reviewer's pass, and the follow-up hardening from both is included: startup failures exit immediately instead of hanging, serve mappings are retried on teardown and never leak silently, foreground serve configs are detected as conflicts, and `nohup` sessions survive terminal close exactly as they did before.

- [#1280](https://github.com/backnotprop/plannotator/pull/1280), [#1286](https://github.com/backnotprop/plannotator/pull/1286)

### The review panel remembers how you work

If you review in the Tree view, every new session used to open on Git status anyway, and getting back meant one more click every single time. The panel now records the view you last used (Tree or Git status) and opens there. The toggle itself gets the full top row with Tree first, the search and collapse controls moved down next to the file tree, and the footer's copy button gave way to a copy-all control in the sidebar. An explicit choice in Settings still wins over the memo.

The Commits rail also stops trapping you: clicking a commit used to permanently replace your working diff, with no way back short of restarting the session. Commits is now a self-contained detour. Entering it remembers what you were reviewing; returning to Tree restores that exact diff, and reloading mid-detour lands you back on your session default instead of stuck on a historical commit.

Two smaller traps closed with the same work: the first-run setup dialog no longer re-runs its one-time reset if you closed the tab without dismissing it, and the fallback view toggle now reflects what is actually on screen.

- [#1273](https://github.com/backnotprop/plannotator/pull/1273), [#1278](https://github.com/backnotprop/plannotator/pull/1278)

### Pi integration rebuilt: no more prompt-cache busting

The Pi extension no longer touches Pi's system prompt at all. Previously it injected planning instructions there, which busted Pi's prompt cache on every phase change and dropped AGENTS.md content, as @paullegranddc reported in [#922](https://github.com/backnotprop/plannotator/issues/922). Phase framing now travels as ordinary conversation messages, so caching works the way Pi expects and your project instructions survive.

This rebuild is why the plan-mode command is renamed: `/plannotator` → `/plannotator-plan-mode` describes what the command actually does now, and there is no alias for the old name. If you type `/plannotator` today, nothing happens; use `/plannotator-plan-mode`.

- [#1269](https://github.com/backnotprop/plannotator/pull/1269), closing [#922](https://github.com/backnotprop/plannotator/issues/922)

### Focus mode from the keyboard

@omardoescode asked for a keybind that clears both sidebars at once for keyboard-first annotation work, and it shipped the same day: **Mod+.** toggles focus mode in plan review and annotate. First press closes the Contents sidebar and the annotation panel, second press restores exactly what was open before. The binding was chosen after a full conflict audit across every surface and layout (it is also the same key code review already uses to collapse its sidebar), it never fires while you type, and the shortcuts help modal documents it in a new View section.

- [#1279](https://github.com/backnotprop/plannotator/pull/1279), closing [#1276](https://github.com/backnotprop/plannotator/issues/1276)

### Standing instructions for Guided Review

Guided Review now accepts reviewer-supplied instructions, two ways: per-launch text appended to that guide's brief, and standing instructions stored once and applied to every guide whose launch carries none. Tell it "always lead with data-model changes" once and every future guide complies. Stored globally under your Plannotator data directory, editable from the guide launch surface.

When a guide fails validation because it referenced files outside the changeset under review (for example, when instructions steer it toward a commit that is not on screen), the error now says exactly that, names the files, and tells you the fix: open that commit in the Commits panel first, then relaunch.

- [#1267](https://github.com/backnotprop/plannotator/pull/1267), [#1286](https://github.com/backnotprop/plannotator/pull/1286)

### Hardened release pipeline and security scanning

The release and deployment pipeline was rebuilt around supply-chain hygiene: every CI action is pinned to a commit SHA, releases validate that the tag sits on main and matches all seven release-coupled version manifests before anything publishes, npm publishing moved to trusted publishing (OIDC) with no long-lived token in the workflow, package construction is separated from the privileged publish step, and deploys wait for the exact commit to pass the full test suite. Gitleaks and zizmor scanning now run on every push and PR with SARIF output into GitHub code scanning, and Dependabot keeps dependencies under watch.

None of this changes the product, but if you consume Plannotator's binaries or npm packages, the artifacts you install are now attested end to end under a stricter pipeline.

- [#1274](https://github.com/backnotprop/plannotator/pull/1274)

### Additional Changes

- **Last-used view, Commits restore, and panel fixes** are covered above; the same PRs also added a tooltip to the per-row stage button and equal-width panel toggle segments. [#1273](https://github.com/backnotprop/plannotator/pull/1273)
- **Pi crash containment:** a hard VCS failure during Call Flow analysis now returns a structured error instead of killing the Pi server process. [#1272](https://github.com/backnotprop/plannotator/pull/1272)
- **Worktree diff-type guard:** degenerate `worktree:` diff types with an empty path no longer fall back to the server's own directory. [#1273](https://github.com/backnotprop/plannotator/pull/1273)
- **@plannotator/ui 0.30.0** for host applications: unanchored-annotation reporting via `onUnanchoredChange`, and `readOnly` mode keeps the host footer slot. [#1263](https://github.com/backnotprop/plannotator/pull/1263)

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

## What's Changed

- feat: reviewer-supplied extra instructions for Guided Review by @backnotprop in [#1267](https://github.com/backnotprop/plannotator/pull/1267)
- feat: add optional CallDiff call-flow analysis by @backnotprop in [#1268](https://github.com/backnotprop/plannotator/pull/1268)
- fix: never touch Pi's system prompt; phase framing as conversation messages by @backnotprop in [#1269](https://github.com/backnotprop/plannotator/pull/1269)
- feat: make the CallDiff runtime a strictly opt-in, in-UI install by @backnotprop in [#1270](https://github.com/backnotprop/plannotator/pull/1270)
- feat: install Call Flow automatically in the background on opt-in by @backnotprop in [#1271](https://github.com/backnotprop/plannotator/pull/1271)
- fix: contain /api/call-flow analysis throws as JSON error responses by @backnotprop in [#1272](https://github.com/backnotprop/plannotator/pull/1272)
- fix: remember the last-used panel view; full-width toggle and cleaner panel chrome by @backnotprop in [#1273](https://github.com/backnotprop/plannotator/pull/1273)
- ci: harden releases and add security scanning by @backnotprop in [#1274](https://github.com/backnotprop/plannotator/pull/1274)
- feat: refine Call Flow navigation and annotations by @backnotprop in [#1277](https://github.com/backnotprop/plannotator/pull/1277)
- fix: restore the prior diff when leaving the Commits view by @backnotprop in [#1278](https://github.com/backnotprop/plannotator/pull/1278)
- feat: focus-mode shortcut to toggle both sidebars by @backnotprop in [#1279](https://github.com/backnotprop/plannotator/pull/1279)
- feat: tailnet auto-advertise, ready QR code, and a first-class --tailscale mode by @backnotprop in [#1280](https://github.com/backnotprop/plannotator/pull/1280)
- fix: tailscale gate exit codes and lease gating, conditional SIGHUP, informative guide validation error by @backnotprop in [#1286](https://github.com/backnotprop/plannotator/pull/1286)
- feat(ui): onUnanchoredChange report + readOnly keeps the host footer slot by @backnotprop in [#1263](https://github.com/backnotprop/plannotator/pull/1263)

## Community

This release was shaped by the community more than any recent one:

- @nikuscs proposed Tailscale support and built a working proof-of-concept wrapper, then described the multi-VPS workflow that guided the design. `--tailscale` mode is that idea, productized.
- @freak4pc and the iPad-review thread on X articulated the "review without touching the machine" use case that the QR code and auto-advertised URLs serve.
- @omardoescode requested the focus-mode keybind ([#1276](https://github.com/backnotprop/plannotator/issues/1276)), shipped in this release, and filed the font customization request ([#1275](https://github.com/backnotprop/plannotator/issues/1275)) now on the roadmap.
- @paullegranddc reported the Pi prompt-cache busting and AGENTS.md loss ([#922](https://github.com/backnotprop/plannotator/issues/922)) that drove the Pi rebuild.
- An external reviewer's pass on the Tailscale PR caught three correctness issues before release; the fixes shipped in [#1286](https://github.com/backnotprop/plannotator/pull/1286).

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.26.8...v0.27.0
