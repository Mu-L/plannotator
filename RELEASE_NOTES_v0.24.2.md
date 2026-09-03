Follow [@plannotator](https://x.com/plannotator) on X for updates

---

<details>
<summary><strong>Missed recent releases?</strong></summary>

| Release                                                                      | Highlights                                                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [v0.24.1](https://github.com/backnotprop/plannotator/releases/tag/v0.24.1)   | Annotate accepts parent-relative `../` file paths                                                                                |
| [v0.24.0](https://github.com/backnotprop/plannotator/releases/tag/v0.24.0)   | PR/MR artifact gallery, GitButler review support, port ranges, expanded comment editor, OpenCode + Pi fixes                       |
| [v0.23.1](https://github.com/backnotprop/plannotator/releases/tag/v0.23.1)   | Startup no longer hangs on large or slow directory trees, Ask AI input stays visible after long responses                        |
| [v0.23.0](https://github.com/backnotprop/plannotator/releases/tag/v0.23.0)   | Plan approval fix for Claude Code 2.1.199+, annotate mode version diff, binary-only `--minimal` install, reviews post without attribution |
| [v0.22.0](https://github.com/backnotprop/plannotator/releases/tag/v0.22.0)   | Git-status "All changes" default review view, Commits panel with per-commit diffs, Guided Review, Pi + GitHub Copilot CLI review engines |
| [v0.21.4](https://github.com/backnotprop/plannotator/releases/tag/v0.21.4)   | Markdown math rendering, PR Overview panel with annotatable description and comments, agent instructions in code review, media parsing fixes |
| [v0.21.3](https://github.com/backnotprop/plannotator/releases/tag/v0.21.3)   | File comments in code review, unified click-to-highlight comments, VS Code clipboard/keyboard bridge, Codex Ask AI on app-server transport, CLI subcommand help |
| [v0.21.2](https://github.com/backnotprop/plannotator/releases/tag/v0.21.2)   | Custom reviews as Agent Skills, Cursor + OpenCode review engines, whole-file/general findings, deleted-annotation fix, Codex Ask AI outside git repos |
| [v0.21.1](https://github.com/backnotprop/plannotator/releases/tag/v0.21.1)   | Annotate-last blank-page fix on multi-message sessions                                                                            |
| [v0.21.0](https://github.com/backnotprop/plannotator/releases/tag/v0.21.0)   | Direct document editing in annotate mode, live git-status file tree, in-app agent terminal, open files in external apps, HTML renders as HTML |
| [v0.20.3](https://github.com/backnotprop/plannotator/releases/tag/v0.20.3)   | Annotations no longer lost when clicking away, off-screen indicator for open comments                                            |

</details>

---

## What's New in v0.24.2

This release opens annotate to config files, adds XDG data-directory support, and gets ahead of OpenAI's July 23 model shutdowns. Twelve pull requests landed since v0.24.1. Four came from community members, and all three external authors are first-time contributors.

### Annotate YAML, JSON, TOML, and other config files

`plannotator annotate config.yaml` used to fail with "File type not supported", even though the pipeline handles any plain text. Annotate now accepts `.yaml`, `.yml`, `.json`, `.jsonc`, `.json5`, `.toml`, `.ini`, `.cfg`, `.conf`, `.properties`, `.csv`, `.tsv`, `.log`, `.xml`, and `.env.example`, rendered as plain text the same way `.txt` is. The file browser lists them in folder mode across all runtimes.

Some details worth knowing. Multi-document YAML keeps its first document (the markdown parser no longer strips a leading `---` pair as frontmatter for non-markdown files). Files over 2MB get a clear error instead of freezing the server; the same cap the code viewer has always had now protects every annotate read. `.env` is deliberately excluded, since annotate's version history copies file contents into the data directory and `.env` files commonly hold secrets. Code-file links inside plans keep their syntax-highlighted popout; only file-browser selections render as annotatable documents.

- Authored by @backnotprop in [#1099](https://github.com/backnotprop/plannotator/pull/1099), closing [#1029](https://github.com/backnotprop/plannotator/issues/1029) reported by @Serhioromano

### XDG data directory support

Plannotator stores everything under `~/.plannotator`. Linux users who keep their home directory clean have asked for XDG Base Directory support several times, in two full pull requests and an issue. The answer used to be the `PLANNOTATOR_DATA_DIR` override; now placement is also automatic: if `~/.plannotator` does not exist and `$XDG_DATA_HOME` is set to an absolute path, Plannotator uses `$XDG_DATA_HOME/plannotator`.

Nothing changes for existing users. An existing `~/.plannotator` always wins, `PLANNOTATOR_DATA_DIR` remains the top-priority override, and macOS and Windows defaults are untouched. The resolution is honored across the Claude Code, OpenCode, Amp, Pi, and VS Code paths, and the install scripts resolve `config.json` the same way. `PLANNOTATOR_DATA_DIR` is now documented in the README.

- Authored by @backnotprop in [#1093](https://github.com/backnotprop/plannotator/pull/1093), closing [#1051](https://github.com/backnotprop/plannotator/issues/1051) reported by @Ramblurr, building on earlier XDG work by @cwrau in [#568](https://github.com/backnotprop/plannotator/pull/568) and @Joao-O-Santos in [#612](https://github.com/backnotprop/plannotator/pull/612), and the single-directory model from @IstPlayer in [#795](https://github.com/backnotprop/plannotator/pull/795)

### Codex models: correct IDs, current catalog, Max and Ultra efforts

Selecting GPT-5.6 in the Agents tab launched Codex with the bare `gpt-5.6` id, which Codex rejects on ChatGPT accounts. @rNoz fixed the catalog to the canonical `gpt-5.6-sol` and migrated saved selections, including per-model reasoning and fast-mode preferences, so existing users stop sending the broken id automatically.

A follow-up aligned the whole catalog with the current Codex CLI. OpenAI retires `gpt-5.3-codex`, `gpt-5.2-codex`, `gpt-5.1-codex-max`, and `gpt-5.1-codex-mini` at the API level on July 23, so those left the picker and saved picks migrate to OpenAI's recommended replacements. `gpt-5.2` stays, since only the ChatGPT product retired it and API-key users still have it. Reasoning effort options are now per-model: `minimal` is gone (no current model supports it), and the GPT-5.6 family gains `Max`, with `Ultra` on Sol and Terra.

- Authored by @rNoz in [#1076](https://github.com/backnotprop/plannotator/pull/1076), closing [#1070](https://github.com/backnotprop/plannotator/issues/1070) reported by @ChrisRuff, and @backnotprop in [#1096](https://github.com/backnotprop/plannotator/pull/1096)

### Cursor review engine works on NixOS and hardened Linux

Review jobs launch Cursor's `agent` CLI with `--sandbox enabled` as part of their read-only posture. On systems where Cursor's sandbox cannot start (NixOS, AppArmor-restricted Linux), every Guided Review with the Cursor engine failed outright, and the flag overrode the user's own `agent sandbox disable` configuration.

The default is unchanged. A new escape hatch, `PLANNOTATOR_CURSOR_SANDBOX=0` (or `"cursorSandbox": false` in `config.json`), omits the flag entirely so the user's own Cursor configuration governs. Opting out means the review job's write protection relies on that configuration, which is why it stays opt-in.

- Authored by @backnotprop in [#1095](https://github.com/backnotprop/plannotator/pull/1095), closing [#1094](https://github.com/backnotprop/plannotator/issues/1094) reported by @Vincent-HD

### Guided Review: viewed files collapse

Marking a file as viewed in a guided review now collapses its diff to the header, matching how the all-files view behaves, so long guides show your progress at a glance. Annotation jumps from the sidebar reopen a collapsed file before scrolling, so clicking a comment never lands on a folded diff.

- Authored by @josdirksen in [#1068](https://github.com/backnotprop/plannotator/pull/1068), their first contribution

### Pi: review setup progress out of your typing area

Starting a PR review in Pi printed clone and fetch progress straight to the terminal, where it smeared across the input box until the next repaint. Progress now renders on Pi's footer status line and clears when the review opens; warnings like a failed fetch go to the chat history where they leave a trace.

- Authored by @alexanderkreidich in [#1098](https://github.com/backnotprop/plannotator/pull/1098), their first contribution

### Additional Changes

- **Installer extras stay out of your project**: the optional extra-skills step now passes `--global` to `npx skills add`, so running the installer inside a git repository can no longer write Plannotator skills into that repo's `.agents/skills/`. A parity test keeps every installer and doc command honest. By @rNoz in [#1078](https://github.com/backnotprop/plannotator/pull/1078), closing [#1077](https://github.com/backnotprop/plannotator/issues/1077).
- **Bug reports arrive with context**: new issues use a minimal form — what happened, `plannotator --version` output, OS, agent, and surface, three of them single-click dropdowns. Feature requests keep the blank-issue path. In [#1100](https://github.com/backnotprop/plannotator/pull/1100).
- **Softer pinpoint hover feedback** in the review UI. In [#1097](https://github.com/backnotprop/plannotator/pull/1097).
- **Quoted booleans in config.json now work**: hand-editing `~/.plannotator/config.json` with a quoted value like `"cursorSandbox": "false"` used to be silently ignored because the string never matched the boolean check. The config resolvers for `cursorSandbox`, `glimpse`, `annotateHistory`, and `jina` now accept `"true"`/`"false"`/`"1"`/`"0"` strings alongside real booleans. In [#1102](https://github.com/backnotprop/plannotator/pull/1102).
- **Guided review file chips expand collapsed files**: clicking a file chip in a guide section now expands the target diff if it was collapsed as viewed, instead of scrolling to a bare header. Uses the same reveal path as annotation clicks and AI citations. In [#1103](https://github.com/backnotprop/plannotator/pull/1103).

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

- fix(review): use canonical GPT-5.6 Sol model ID by @rNoz in [#1076](https://github.com/backnotprop/plannotator/pull/1076)
- fix(install): pass --global to npx skills add so extras do not leak into cwd by @rNoz in [#1078](https://github.com/backnotprop/plannotator/pull/1078)
- fix(review): Collapse viewed files in guided review by @josdirksen in [#1068](https://github.com/backnotprop/plannotator/pull/1068)
- fix(pi): keep PR review progress out of composer by @alexanderkreidich in [#1098](https://github.com/backnotprop/plannotator/pull/1098)
- feat(data-dir): respect $XDG_DATA_HOME when ~/.plannotator does not exist by @backnotprop in [#1093](https://github.com/backnotprop/plannotator/pull/1093)
- fix(review): allow disabling the Cursor sandbox via PLANNOTATOR_CURSOR_SANDBOX by @backnotprop in [#1095](https://github.com/backnotprop/plannotator/pull/1095)
- fix: align Codex model catalog and reasoning efforts with the current Codex CLI by @backnotprop in [#1096](https://github.com/backnotprop/plannotator/pull/1096)
- feat: annotate accepts YAML, JSON, TOML and other plain-text files by @backnotprop in [#1099](https://github.com/backnotprop/plannotator/pull/1099)
- feat(github): minimal bug-report issue form by @backnotprop in [#1100](https://github.com/backnotprop/plannotator/pull/1100)
- feat(ui): soften pinpoint hover feedback by @backnotprop in [#1097](https://github.com/backnotprop/plannotator/pull/1097)
- fix(config): coerce quoted boolean strings in config.json resolvers by @backnotprop in [#1102](https://github.com/backnotprop/plannotator/pull/1102)
- fix(review): expand collapsed guide files when jumping via section file chips by @backnotprop in [#1103](https://github.com/backnotprop/plannotator/pull/1103)

## New Contributors

- @rNoz made their first contribution in [#1076](https://github.com/backnotprop/plannotator/pull/1076)
- @josdirksen made their first contribution in [#1068](https://github.com/backnotprop/plannotator/pull/1068)
- @alexanderkreidich made their first contribution in [#1098](https://github.com/backnotprop/plannotator/pull/1098)

## Contributors

Three first-time contributors landed code this release. @rNoz spent a weekend stress-testing Plannotator and turned it into two merged fixes, the canonical GPT-5.6 Sol id with a careful settings migration and the installer `--global` scoping, plus a set of detailed reports still being worked through. @josdirksen brought the viewed-files collapse to Guided Review. @alexanderkreidich cleaned up Pi's review startup so progress lands in the footer instead of the composer.

The XDG work stands on earlier community efforts: @cwrau and @Joao-O-Santos each wrote full XDG implementations in [#568](https://github.com/backnotprop/plannotator/pull/568) and [#612](https://github.com/backnotprop/plannotator/pull/612), and @IstPlayer built the `PLANNOTATOR_DATA_DIR` override in [#795](https://github.com/backnotprop/plannotator/pull/795) that this release's fallback completes.

Issue reporters drove most of the fix list:

- @Ramblurr asked for XDG Base Directory support with a concrete, backward-compatible design in [#1051](https://github.com/backnotprop/plannotator/issues/1051)
- @Serhioromano requested config-file annotation in [#1029](https://github.com/backnotprop/plannotator/issues/1029)
- @ChrisRuff reported the GPT-5.6 model id mismatch with screenshots in [#1070](https://github.com/backnotprop/plannotator/issues/1070)
- @Vincent-HD reported the Cursor sandbox failure on NixOS with a working workaround in [#1094](https://github.com/backnotprop/plannotator/issues/1094)

**Full Changelog**: https://github.com/backnotprop/plannotator/compare/v0.24.1...v0.24.2
