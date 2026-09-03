Follow [@plannotator](https://x.com/plannotator) on X for updates

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
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
| [v0.26.4](https://github.com/backnotprop/plannotator/releases/tag/v0.26.4)   | Skill-menu hover jitter fix (same-day patch on v0.26.3)                                                                          |

</details>

## What's New in v0.27.7

A patch release led by a crash fix for Pi on Windows: a broken provider pipe could take down the entire Pi host mid plan review. Five PRs, three from returning community contributors, plus a new top-level knowledge skill that also powers plannotator.ai/llms.txt.

### Pi no longer crashes when a provider pipe breaks

On Windows, opening a plan review from Pi could kill the whole Pi host with an unhandled EPIPE error. The provider child process's stdin pipe broke, nothing was listening for the failure, and the host process died with it.

This is fixed as a class, not a symptom. Every provider child process (Pi and the Codex app-server transport) now routes its pipe writes through a shared guard: a broken pipe fails that provider's query cleanly, the provider is marked dead and restartable, and the host keeps running. The regression test reproduces the exact pre-fix crash in a real Node child process.

Thanks @Kaelenx for the detailed report and for verifying the fix on the original machine within the hour.

- [#1379](https://github.com/backnotprop/plannotator/pull/1379) by @backnotprop, closing [#1378](https://github.com/backnotprop/plannotator/issues/1378) reported by @Kaelenx

### Call Flow stops failing on normal reviews

Call Flow rejected any analysis producing more than 100 call trees, and languages that emit many small per-function trees (Swift, TypeScript) hit that ceiling on ordinary branch reviews. @sergdort's measurements in [#1351](https://github.com/backnotprop/plannotator/issues/1351) showed a normal 161-file review producing 470 valid trees, computed in under 800ms, rejected whole.

The tree cap is now 2,000, and a result that still exceeds it degrades instead of failing: the first 2,000 trees render and a visible warning in the panel says how many were truncated. The caps that guard against genuinely unbounded output (total nodes, tree depth, raw length) still reject exactly as before.

- [#1370](https://github.com/backnotprop/plannotator/pull/1370) by @ashish921998, closing [#1351](https://github.com/backnotprop/plannotator/issues/1351) reported by @sergdort

### jj reviews start from where your work actually began

The jj Line of work view always diffed against `trunk()`. If your work branched off a staging or development line instead, the review included every commit from that line too, burying your changes in unrelated ones.

Plannotator now asks jj where the current line of work forked from shared history and starts the review there. The base is named by its remote bookmark when one exists, then its local bookmark, then the commit ID, and jj's internal `push-*` bookmarks are never used as names. Older jj versions that cannot answer the fork-point query fall back to `trunk()` instead of failing the review.

- [#1365](https://github.com/backnotprop/plannotator/pull/1365) by @graemefolk

### A knowledge skill for every agent, and llms.txt

Agents had launcher skills for opening reviews but no reference for everything else Plannotator can do. The new top-level `plannotator` skill is that reference: every subcommand, flag, and workflow, installed for Claude Code, Codex, OpenCode, Pi, Kiro, and Gemini through their own install paths. A CI freshness guard ties the skill to the CLI source, so it cannot silently drift from what the binary actually accepts.

The same document is now served at [plannotator.ai/llms.txt](https://plannotator.ai/llms.txt) following the [llmstxt.org](https://llmstxt.org/) convention, generated from the identical source at build time.

- [#1377](https://github.com/backnotprop/plannotator/pull/1377) by @backnotprop

### oh-my-pi is its own agent origin

Sessions launched from the oh-my-pi harness were detected as Claude Code, because OMP exports Claude Code's environment markers into its shells. OMP is now detected as its own origin, ordered so nested runtimes still detect correctly, and sessions report the agent you are actually using.

- [#1373](https://github.com/backnotprop/plannotator/pull/1373) by @FNDEVVE

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

**Pi:** Update `@plannotator/pi-extension` to 0.27.7 and restart Pi.

**OpenCode:** Clear cache and restart:

```bash
rm -rf ~/.bun/install/cache/@plannotator
```

## What's Changed

- feat: detect the oh-my-pi harness as its own agent origin by @FNDEVVE in [#1373](https://github.com/backnotprop/plannotator/pull/1373)
- fix(review): detect JJ mutable line-of-work base by @graemefolk in [#1365](https://github.com/backnotprop/plannotator/pull/1365)
- feat(skills): top-level plannotator knowledge skill with a CLI freshness guard by @backnotprop in [#1377](https://github.com/backnotprop/plannotator/pull/1377)
- fix(ai): a broken RPC pipe must fail the provider, not kill the host by @backnotprop in [#1379](https://github.com/backnotprop/plannotator/pull/1379)
- fix(call-flow): keep big-but-valid tree lists instead of failing by @ashish921998 in [#1370](https://github.com/backnotprop/plannotator/pull/1370)

## Contributors

Three returning contributors landed code in this release. @graemefolk continues to own Plannotator's jj support end to end, this time replacing the assumed `trunk()` base with real fork-point detection. @ashish921998 turned @sergdort's Call Flow measurements into the fix that stops normal reviews from failing. @FNDEVVE made oh-my-pi a first-class agent origin.

Community reports that shaped this release:

- @Kaelenx reported the Pi host crash on Windows in [#1378](https://github.com/backnotprop/plannotator/issues/1378) and verified the fix on the same machine
- @sergdort measured exactly which Call Flow cap was failing normal reviews in [#1351](https://github.com/backnotprop/plannotator/issues/1351)

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.27.6...v0.27.7
