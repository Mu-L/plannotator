Follow [@plannotator](https://x.com/plannotator) on X for updates

---

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.19.27](https://github.com/backnotprop/plannotator/releases/tag/v0.19.27) | Kiro CLI integration, Glimpse native window, annotate-last message picker                                                        |
| [v0.19.26](https://github.com/backnotprop/plannotator/releases/tag/v0.19.26) | Amp plugin production fixes, Mermaid rendering fix, Settings flicker fix, update notification toast and shimmer                   |
| [v0.19.24](https://github.com/backnotprop/plannotator/releases/tag/v0.19.24) | Amp integration, configurable data directory, Auto Mode permission option, Pi plan approval fix                                  |
| [v0.19.23](https://github.com/backnotprop/plannotator/releases/tag/v0.19.23) | Droid integration, Windows Pi AI fix, quieter update indicator                                                                   |
| [v0.19.22](https://github.com/backnotprop/plannotator/releases/tag/v0.19.22) | Safari copy fix in plan viewer, CLAUDE_CONFIG_DIR support for session logs                                                       |
| [v0.19.21](https://github.com/backnotprop/plannotator/releases/tag/v0.19.21) | Ask AI in plan review and annotate mode, shared AI runtime, origin-aware provider defaults                                       |
| [v0.19.20](https://github.com/backnotprop/plannotator/releases/tag/v0.19.20) | Interactive goal setup UI, OpenCode submit_plan fixes, browser no-op sentinel handling for Claude agents                         |
| [v0.19.18](https://github.com/backnotprop/plannotator/releases/tag/v0.19.18) | Edit-based submit_plan for OpenCode, Pi namespace migration, Codex annotate-last fix, OpenCode commands dir fix                  |
| [v0.19.17](https://github.com/backnotprop/plannotator/releases/tag/v0.19.17) | Reworked goal setup skill (interview-driven flow), CLI --version flag                                                            |
| [v0.19.16](https://github.com/backnotprop/plannotator/releases/tag/v0.19.16) | Code navigation with peek view (Cmd/Ctrl+click tokens in diffs)                                                                 |
| [v0.19.15](https://github.com/backnotprop/plannotator/releases/tag/v0.19.15) | Commit-based diff base, jj evolution diffs, GitLab reliability fixes, OpenCode command intercept fix                             |

<em>AWESOME</em>

</details>

---

## What's New in v0.20.0

v0.20.0 is the largest release in a while: 11 PRs, three of them from first-time contributors. Code review gains multi-repo workspace support and a semantic diff overview. The interface gets a full visual refresh with two new themes, a grid-versus-flat plan look, and a full-page HTML annotation mode. Under the hood, the way skills and commands install has been rationalized so each artifact has a single source of truth and a default install ships lean. Several reliability fixes round it out across OpenCode, Pi, Windows, and GitLab.

---

> [!IMPORTANT]
> **v0.20.0 is a large release, and two of its changes affect existing installs. Please read these before you upgrade.**
>
> **1. Extra skills are no longer installed by default.** The `plannotator-compound`, `plannotator-setup-goal`, and `plannotator-visual-explainer` skills used to ship with every install. They now install separately, so a default install stays lean. To add them:
> ```bash
> npx skills add backnotprop/plannotator/apps/skills/extra
> ```
> When you upgrade, the installer performs a one-time cleanup that removes the old default-installed copies of these three skills from `~/.claude/skills` and `~/.agents/skills`. If you want them, reinstall with the command above. Copies you install yourself with `npx skills add` are never touched again. (Kiro CLI is the exception and keeps receiving setup-goal and visual-explainer.)
>
> **2. On Claude Code, the slash commands are now skills.** Claude Code merged custom commands into skills, so Plannotator follows suit. `/plannotator-review`, `/plannotator-annotate`, and `/plannotator-last` are now installed as Claude Code skills under `~/.claude/skills` (same names, same behavior). The old `~/.claude/commands/plannotator-*.md` files are removed automatically on upgrade. The standalone `/plannotator-status` and `/plannotator-archive` commands are gone: plan archive browsing now lives in a sidebar tab during plan review. If you use the marketplace plugin, run `/plugin marketplace update` once so the old namespaced `plannotator:*` entries disappear from the `/` menu.
>
> If git is missing or a fetch is blocked, the installer now stops with a clear message instead of silently leaving you half-installed. git is required.

---

### Multi-Repo Workspace Reviews

Code review previously required a git repository as the working directory. Teams working across several services in a parent folder had no way to review them together: each repo needed its own session, and feedback was fragmented.

You can now run `plannotator review` from a non-git parent directory that contains multiple repositories. Plannotator discovers the nested repos that have local changes, pre-selects them, and presents a single review session covering all of them. Diff switching, file-content lookups, staging, and agent operations are all repo-aware, and the review feedback covers every repo in one pass. The single-repo workflow is unchanged: the workspace flow only engages when the directory you start from is not itself a repository.

- [#543](https://github.com/backnotprop/plannotator/pull/543) closing [#527](https://github.com/backnotprop/plannotator/issues/527), contributed by @Oscar-Silva

### Semantic Diff Overview

Code review now opens to a semantic diff overview that groups changes by what was modified rather than only by which lines moved. It runs the `sem` analyzer over the active patch and shows the result as the default landing panel, with a sidebar entry above All Files, rows for binary changes, inline error reporting, and retry.

The analyzer ships as an optional sidecar that the installers fetch without blocking the rest of the install, and the overview is available in both the Bun-based servers (Claude Code, OpenCode) and the Pi extension's Node server. When the sidecar is unavailable, review falls back cleanly to the standard diff view.

- [#871](https://github.com/backnotprop/plannotator/pull/871), contributed by @backnotprop

### UI 2.0: New Themes, Plan Look Chooser, and Full-Page HTML Annotation

The interface received a broad visual refresh. Two new themes, Simple and Neutral, join the existing set, built on a refreshed design-system token bridge. The overlay scrollbar library was removed in favor of native scrolling, which is lighter and more accessible.

Plan rendering now offers two looks. Grid keeps your plan as a floating card on grid paper; Clean is a simpler, edge-to-edge flat card. A first-run dialog announces the release and lets you pick. The release announcement also surfaces what is new in the release and links to the full notes.

Annotation gains a full-page HTML mode. Running `plannotator annotate --render-html` opens an HTML report or explainer rendered edge-to-edge in a sandboxed frame, themed to match Plannotator, and lets you annotate it directly with text selection or by clicking an element, instead of flattening it to markdown first. This pairs naturally with the visual-explainer skill's HTML output.

- [#863](https://github.com/backnotprop/plannotator/pull/863) and [#879](https://github.com/backnotprop/plannotator/pull/879), contributed by @backnotprop

### Leaner Install and Single-Source Skills

The way Plannotator ships skills and commands was restructured so each artifact has exactly one authoritative source. Core skills (review, annotate, last) install from a single location to both `~/.claude/skills` and Codex's `~/.agents/skills`. The extra skills move to opt-in installation via `npx skills add` (see the note at the top of these release notes). Every installer's hard-coded command and skill text was removed in favor of copying the real files from the repository, which eliminates a class of cross-platform escaping bugs.

The installers also became stricter and safer to re-run. git is now a hard requirement, and a missing git or a failed fetch stops the install with an actionable message rather than silently skipping steps. Cleanup of legacy command files and stale Codex skills only happens after the replacement skill is on disk, so no upgrade path can leave you with neither. A one-time migration ledger tracks the extras cleanup so re-running the installer never re-removes skills you reinstalled yourself.

First-run interactive installs ask whether to add the extra skills and whether to make any skills model-invocable, and the answers are saved and reused on later runs. Automated and piped installs never prompt and keep the safe defaults.

- [#850](https://github.com/backnotprop/plannotator/pull/850) closing [#516](https://github.com/backnotprop/plannotator/issues/516), [#817](https://github.com/backnotprop/plannotator/issues/817), [#823](https://github.com/backnotprop/plannotator/issues/823), [#842](https://github.com/backnotprop/plannotator/issues/842), [#852](https://github.com/backnotprop/plannotator/issues/852), and [#853](https://github.com/backnotprop/plannotator/issues/853); follow-ups in [#872](https://github.com/backnotprop/plannotator/pull/872) and [#873](https://github.com/backnotprop/plannotator/pull/873), contributed by @backnotprop

### Expand Unchanged Regions by Default

Code review gains a persistent setting to expand unchanged diff regions by default. With it enabled, changed files open with their surrounding context already unfolded instead of requiring manual clicks. The toggle is available from both the main review display settings and the compact diff options popover, and it persists across sessions.

- [#858](https://github.com/backnotprop/plannotator/pull/858) closing [#857](https://github.com/backnotprop/plannotator/issues/857), contributed by @Perlten

### OpenCode Runtime Compatibility

The OpenCode plugin was split into a portable entry point and a Bun-only embedded runtime, so Node-hosted OpenCode no longer imports Bun server code at load time. On Bun hosts the plugin runs its full embedded runtime; on Node hosts it falls back gracefully to the installed Plannotator CLI. The fix restores agent switching, the recent-message picker for `plannotator last`, share disabling, and PR review semantics through the CLI bridge, and hardens sandboxed OpenCode startup so it uses a private port instead of attaching to an unrelated server.

- [#849](https://github.com/backnotprop/plannotator/pull/849) closing [#596](https://github.com/backnotprop/plannotator/issues/596), [#681](https://github.com/backnotprop/plannotator/issues/681), and [#847](https://github.com/backnotprop/plannotator/issues/847), contributed by @backnotprop

### Glimpse Native Window on Windows

On Windows, Glimpse never launched: npm installs `glimpseui` only as script shims with no native executable, so the plain spawn always failed and Plannotator fell back to a browser tab. The server now detects this case and launches Glimpse by running its package entry point directly with `node`, which keeps the HTML stdin pipe intact. Non-Windows hosts are unaffected.

- [#861](https://github.com/backnotprop/plannotator/pull/861) closing [#860](https://github.com/backnotprop/plannotator/issues/860), contributed by @NikiforovAll

### Additional Changes

- **Windows install prompt timeout and OpenCode cleanup.** The PowerShell installer's first-run prompts no longer hang indefinitely without a terminal, and a stale OpenCode archive command stub is swept on upgrade. [#875](https://github.com/backnotprop/plannotator/pull/875)
- **GitLab merge request review reliability.** GitLab MR review keeps the raw-diffs endpoint as primary and falls back to the paginated diffs endpoint when it is empty or fails, with a clear error when a merge request genuinely has no diff. (in [#879](https://github.com/backnotprop/plannotator/pull/879))
- **Claude Fable 5 model option.** Fable 5 was added to the code review and Ask AI model selectors alongside Opus 4.8.

## Install / Update

**macOS / Linux:**

```bash
curl -fsSL https://plannotator.ai/install.sh | bash
```

**Windows:**

```powershell
irm https://plannotator.ai/install.ps1 | iex
```

**Extra skills** (compound, setup-goal, visual-explainer), now opt-in:

```bash
npx skills add backnotprop/plannotator/apps/skills/extra
```

**Claude Code Plugin:** Run `/plugin` in Claude Code, find **plannotator**, and click **"Update now"**. Then run `/plugin marketplace update` once to clear the old namespaced command entries.

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

---

## What's Changed

- feat(review): support multi-repo workspace reviews by @Oscar-Silva in [#543](https://github.com/backnotprop/plannotator/pull/543)
- Fix OpenCode plugin runtime compatibility by @backnotprop in [#849](https://github.com/backnotprop/plannotator/pull/849)
- Single-source skills (core/extra), replace Claude Code commands with skills, de-hardcode installers by @backnotprop in [#850](https://github.com/backnotprop/plannotator/pull/850)
- Add persistent full-file diff context setting by @Perlten in [#858](https://github.com/backnotprop/plannotator/pull/858)
- fix(server): launch Glimpse via node on Windows instead of unspawnable npm shim by @NikiforovAll in [#861](https://github.com/backnotprop/plannotator/pull/861)
- UI 2.0 visual refresh by @backnotprop in [#863](https://github.com/backnotprop/plannotator/pull/863)
- feat(review): add semantic diff overview by @backnotprop in [#871](https://github.com/backnotprop/plannotator/pull/871)
- fix(install): restore /plannotator-* bash execution on Claude Code and harden unattended installs by @backnotprop in [#872](https://github.com/backnotprop/plannotator/pull/872)
- chore: remove the redundant /plannotator-status and /plannotator-archive commands by @backnotprop in [#873](https://github.com/backnotprop/plannotator/pull/873)
- fix(install): Windows prompt timeout and stale OpenCode archive stub sweep by @backnotprop in [#875](https://github.com/backnotprop/plannotator/pull/875)
- feat(plan): grid-default plan look chooser and 0.20.0 release dialog, with GitLab, sem, and install fixes by @backnotprop in [#879](https://github.com/backnotprop/plannotator/pull/879)
- feat(review): add Claude Fable 5 to the model selectors by @backnotprop

## New Contributors

- @Oscar-Silva made their first contribution in [#543](https://github.com/backnotprop/plannotator/pull/543)
- @Perlten made their first contribution in [#858](https://github.com/backnotprop/plannotator/pull/858)
- @NikiforovAll made their first contribution in [#861](https://github.com/backnotprop/plannotator/pull/861)

## Contributors

@Oscar-Silva built multi-repo workspace review, adding repo discovery from a non-git parent directory and making diff switching, file-content lookups, staging, and agent routing repo-aware, with regression coverage for the new workspace paths. @Perlten contributed the persistent full-file diff context setting, wiring it through server config and both the single-file and all-files diff views, and also reported the original request. @NikiforovAll diagnosed and fixed the Windows Glimpse launch failure, tracing it to npm's script-shim packaging and switching to a direct `node` spawn that preserves the stdin pipe, and reported the underlying issue with a clear reproduction table.

This release also resolved a number of community-reported issues. @daviziks requested multi-repo review support for poly-repo workflows. @possiblyneal asked for a way to hide legacy alias skill names from the Claude skill list. @stefanbinoj raised loading skills into the system prompt by default. @cwardgar reported that Plannotator did not respect `CODEX_HOME`. @robsonpeixoto reported the marketplace plugin not installing the compound skill. @mactavishz, @boris-gorbylev, and @matteo9924 reported the OpenCode plugin load and runtime failures that the runtime split resolves.

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.19.27...v0.20.0
