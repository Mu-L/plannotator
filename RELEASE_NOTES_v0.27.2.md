Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.27.1](https://github.com/backnotprop/plannotator/releases/tag/v0.27.1)   | Open-in-editor launch fix, file headers respect Viewed/Git-add visibility toggles                                                |
| [v0.27.0](https://github.com/backnotprop/plannotator/releases/tag/v0.27.0)   | Call Flow analysis, --tailscale remote reviews, review panel remembers your view, Pi rebuild (breaking command rename), focus-mode shortcut |
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

</details>

## What's New in v0.27.2

Plannotator now works on your phone. This release ships a full mobile experience for plan review, code review, and annotation, alongside a security hardening pass, a fix for Codex review jobs on current Codex CLI versions, a large folder-mode performance win, and configurable markdown extensions. Fourteen PRs, including a community fix from @leoreisdias and a community-requested feature from @sgiath.

### Plan and code review on phones and tablets

Review a plan from your couch. Approve a diff from the train. Plannotator's plan review, code review, and annotate surfaces now adapt to phones and tablets with a compact touch experience: full-width reading layouts, a full-screen navigator for files and contents, touch-safe comment composition that stays clear of the software keyboard, 44px touch targets, and safe-area-aware layouts that respect notches and home indicators. On iPhone Safari, plans use the browser's natural document scroll so the address bar collapses as you read.

Desktop behavior is unchanged. The compact experience activates only on coarse-pointer devices at tablet widths and below, so a narrow desktop window keeps the workspace you know. Pair it with v0.27.0's `--tailscale` flag or remote mode and your phone becomes a first-class review device: start a review on your workstation, scan the QR code, and annotate from anywhere on your tailnet.

This shipped as a five-part stack: viewport and safe-area foundation, keyboard-safe comment composition, touch and dialog primitives, the code review shell, and the plan shell.

- [#1295](https://github.com/backnotprop/plannotator/pull/1295), [#1297](https://github.com/backnotprop/plannotator/pull/1297), [#1300](https://github.com/backnotprop/plannotator/pull/1300), [#1301](https://github.com/backnotprop/plannotator/pull/1301), [#1303](https://github.com/backnotprop/plannotator/pull/1303) by @backnotprop

### Codex review jobs work again on current Codex CLIs

Codex CLI 0.147.0 removed the `--full-auto` flag, which broke every Plannotator Codex review, Guided Review, and Code Tour job at launch with an argument error. Plannotator now passes `--approve-for-me`, the flag Codex introduced as its replacement, across all three job builders.

Note the floor this implies: Codex review jobs now require codex-cli 0.147.0 or newer. Older Codex CLIs do not recognize the new flag. Thanks to @tgenov for independently reporting the breakage and pushing on a read-only sandbox for review jobs, an idea now tracked in [#1310](https://github.com/backnotprop/plannotator/issues/1310).

- [#1231](https://github.com/backnotprop/plannotator/pull/1231) by @leoreisdias

### Folder annotate opens in milliseconds on large repos

Opening a folder annotate session initialized a file watcher across the entire `.git/refs` tree to keep git status live in the file browser. On repos with hundreds of branches and tags that took 9 to 23 seconds before the first file selection was responsive. The watcher now targets the five specific git files that drive status display (HEAD, index, the reflog, packed-refs, and the current branch ref), bringing cold start to about 30ms on the same repos with the same live status behavior.

- [#1306](https://github.com/backnotprop/plannotator/pull/1306) by @backnotprop

### Annotate any markdown-like file with configurable extensions

Livebook notebooks, Quarto documents, and other markdown-dialect files were rejected by annotate because the accepted extensions were hardcoded. A new config-only setting registers extra extensions to treat as markdown:

```json
{ "markdownExtensions": [".livemd"] }
```

in `~/.plannotator/config.json`. Listed extensions are accepted everywhere annotate accepts `.md`: the CLI, the folder file browser, linked-doc and wiki-link navigation, frontmatter stripping, and version history. Entries are validated hard, and dotenv-family extensions can never be registered since annotate history copies file contents. Requested by @sgiath in [#1307](https://github.com/backnotprop/plannotator/issues/1307).

- [#1309](https://github.com/backnotprop/plannotator/pull/1309) by @backnotprop

### Security hardening across the supply chain

Four security-focused changes landed in this cycle:

- **Pi 0.79+ required.** The Pi extension now requires Pi 0.79.1 or newer and refuses older hosts with a clear message instead of running with weaker project-trust behavior. If you are on an older Pi, update Pi first. [#1291](https://github.com/backnotprop/plannotator/pull/1291)
- **Continuous scanning.** Semgrep CE and Trivy now run on every PR and weekly in monitor mode, with fail-closed scanner health checks and pinned, checksum-verified tooling. [#1294](https://github.com/backnotprop/plannotator/pull/1294)
- **Weekly DAST.** An isolated OWASP ZAP passive scan runs weekly against a disposable annotate session on an internal-only network with no credentials and blocked egress. [#1299](https://github.com/backnotprop/plannotator/pull/1299)
- **Marketing site on Astro 7.** plannotator.ai moved from Astro 5 to 7.1.6, clearing eight dependency advisories. [#1293](https://github.com/backnotprop/plannotator/pull/1293)

### Additional Changes

- **New reviewers start in Tree view.** First-time code review users now land on the file tree instead of the Git status panel. Returning users keep whatever view they had. [#1292](https://github.com/backnotprop/plannotator/pull/1292)
- **Quieter first run.** The plan-AI, vim-mode, and analysis-layers announcement dialogs are gone, and automatic AI provider selection no longer persists anything until you explicitly choose a provider. Fewer interruptions before your first review. [#1295](https://github.com/backnotprop/plannotator/pull/1295)

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

- security(pi): require Pi 0.79+ and document project trust by @backnotprop in [#1291](https://github.com/backnotprop/plannotator/pull/1291)
- feat: default new Code Review users to Tree by @backnotprop in [#1292](https://github.com/backnotprop/plannotator/pull/1292)
- security(marketing): migrate static site to Astro 7.1+ by @backnotprop in [#1293](https://github.com/backnotprop/plannotator/pull/1293)
- ci(security): add Semgrep CE and Trivy monitoring by @backnotprop in [#1294](https://github.com/backnotprop/plannotator/pull/1294)
- feat: mobile foundation and quieter first run by @backnotprop in [#1295](https://github.com/backnotprop/plannotator/pull/1295)
- feat: mobile-safe plan and code comment composition by @backnotprop in [#1297](https://github.com/backnotprop/plannotator/pull/1297)
- feat(ui): add mobile-safe touch and dialog primitives by @backnotprop in [#1300](https://github.com/backnotprop/plannotator/pull/1300)
- feat(review): add compact touch review shell by @backnotprop in [#1301](https://github.com/backnotprop/plannotator/pull/1301)
- feat(editor): mobile plan shell and navigation by @backnotprop in [#1303](https://github.com/backnotprop/plannotator/pull/1303)
- fix(review): update Codex automatic approval flag by @leoreisdias in [#1231](https://github.com/backnotprop/plannotator/pull/1231)
- fix: folder watcher cold-start refs scan by @backnotprop in [#1306](https://github.com/backnotprop/plannotator/pull/1306)
- ci(security): add isolated ZAP DAST monitoring by @backnotprop in [#1299](https://github.com/backnotprop/plannotator/pull/1299)
- feat(annotate): configurable extra markdown extensions by @backnotprop in [#1309](https://github.com/backnotprop/plannotator/pull/1309)

## Community

This release carries a lot of community fingerprints:

- @leoreisdias fixed the Codex CLI breakage in [#1231](https://github.com/backnotprop/plannotator/pull/1231), restoring Codex review jobs for everyone on current Codex versions.
- @tgenov independently diagnosed the same Codex breakage in [#1302](https://github.com/backnotprop/plannotator/pull/1302) and proposed running review jobs read-only, now tracked in [#1310](https://github.com/backnotprop/plannotator/issues/1310).
- @sgiath requested configurable markdown extensions for Livebook notebooks in [#1307](https://github.com/backnotprop/plannotator/issues/1307), with a workaround-quality write-up that traced both allowlists involved.
- @edision reported that Pi's `thinking: "max"` level is silently ignored in [#1304](https://github.com/backnotprop/plannotator/issues/1304), queued for an upcoming patch.
- @MartinNeudecker proposed direct edits alongside suggestions in code review in [#1308](https://github.com/backnotprop/plannotator/issues/1308), and followed up with workflow details that are shaping the design.
- @ashish921998 picked up the skill-menu screen reader accessibility issue in [#1233](https://github.com/backnotprop/plannotator/issues/1233).

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.27.1...v0.27.2
