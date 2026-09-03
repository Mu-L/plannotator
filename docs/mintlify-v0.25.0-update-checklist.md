# Mintlify v0.25.0 Documentation Update Checklist

Canonical documentation: <https://docs.plannotator.ai/open-source/>

Do not link to the deprecated `plannotator.ai/docs/` site. This checklist covers factual documentation work; screenshots and artwork are not required.

Status: completed in the Mintlify source at `/Users/ramos/plannotator/docs` on July 27, 2026. `mintlify validate`, `mintlify broken-links`, JSON validation, diff checks, and 186 targeted OSS tests passed. All 42 Plannotator OSS pages are verified against v0.25.0; the separate Artifact Server page retains its own repository verification.

## CLI and annotation gates

- [x] Update `/open-source/reference/cli`.
  - [x] Add `--require-approval`.
  - [x] Add `--result-file <path>`.
  - [x] State that both options require `annotate --gate --json`.
  - [x] State that they cannot be combined with `--hook`.
  - [x] Document the strict JSON result structure.
  - [x] Document exit codes: `0` approved, `1` reviewer did not approve, and `2` configuration, startup, or publication failure.
  - [x] Explain that strict startup failures use exit code `2`.
  - [x] Explain result-file path validation and no-overwrite behavior.
  - [x] Explain that result files are written atomically with `0600` permissions where supported.
  - [x] Explain that the stdout decision is emitted before result-file publication.

- [x] Update `/open-source/reference/hooks`.
  - [x] Add strict direct-annotation gate behavior.
  - [x] Update decision and output examples.
  - [x] Add approval results that contain feedback.
  - [x] Distinguish approval with feedback from rejection.
  - [x] Document dismissed results.

- [x] Update `/open-source/workflows/annotations-and-feedback`.
  - [x] Add “Approve with Notes.”
  - [x] Remove the claim that providing feedback always means sending the review back.
  - [x] Explain which annotation transports support approval with feedback.

- [x] Update `/open-source/reference/custom-feedback`.
  - [x] Add `prompts.annotate.approvedWithNotes`.
  - [x] Explain when that prompt is used.
  - [x] Keep `prompts.annotate.approved` documented as the no-notes approval path.

## Supported documents and folders

- [x] Update `/open-source/workflows/documents`.
  - [x] Add `.yaml` and `.yml`.
  - [x] Add `.json`, `.jsonc`, and `.json5`.
  - [x] Add `.toml`.
  - [x] Add `.ini`, `.cfg`, and `.conf`.
  - [x] Add `.properties`.
  - [x] Add `.csv` and `.tsv`.
  - [x] Add `.log`.
  - [x] Add `.xml`.
  - [x] Add `.env.example`.
  - [x] State that `.env` is deliberately unsupported because it commonly contains secrets.
  - [x] State that these formats render as plain text.
  - [x] Document the 2 MiB single-file annotation limit.
  - [x] State that non-Markdown files beginning with `---` are not treated as Markdown frontmatter.

- [x] Update `/open-source/workflows/folders`.
  - [x] Add all newly supported document formats.
  - [x] Document the 2 MiB per-file limit.
  - [x] Explain that eligible files opened from folders now receive per-file history.
  - [x] Explain that eligible files can show diffs against their saved history.
  - [x] Clarify that raw HTML, converted URLs, and ordinary linked documents do not receive this history.

- [x] Update `/open-source/start/open-plannotator`.
  - [x] Replace the old Markdown, text, and HTML-only format list.
  - [x] Add the 2 MiB annotation limit.
  - [x] Mention folder-based per-file history.

## Version history

- [x] Update `/open-source/workflows/version-history`.
  - [x] Remove the statement that folder-browser sessions do not create document history.
  - [x] Document folder-session per-file history.
  - [x] Document the file types eligible for history.
  - [x] Document `PLANNOTATOR_ANNOTATE_HISTORY`.
  - [x] Clarify which document sources remain excluded.

## Guided Reviews

- [x] Update `/open-source/workflows/agent-reviews`.
  - [x] Explain that successful Guided Reviews are saved automatically.
  - [x] Add the “Previous guides” workflow.
  - [x] Document saved progress.
  - [x] Document moved and diff-changed indicators.
  - [x] Explain reopening a saved guide.
  - [x] Explain deleting a saved guide.
  - [x] Add `PLANNOTATOR_GUIDE_HISTORY`.
  - [x] Add `guideHistory: false`.
  - [x] Explain that disabling history stops new saves but does not delete existing guides.
  - [x] Explain that previously saved guides remain readable.
  - [x] Document the Guided Review collapse and reveal behavior.
  - [x] Correct the Codex review-model wording: Plannotator maintains the launched-review model catalog rather than reading it directly from the installed provider.

## AI controls

- [x] Update `/open-source/workflows/ask-ai`.
  - [x] Add `PLANNOTATOR_AI=disabled`.
  - [x] State that it disables Ask AI.
  - [x] State that it disables review-agent execution.
  - [x] State that it disables Guided Review launches.
  - [x] State that provider runtime endpoints are disabled.
  - [x] State that external reviews and annotations continue to work.
  - [x] State that saved guide data is retained.
  - [x] State that the guide-history UI is hidden while AI is disabled.
  - [x] Clarify that the annotate-mode agent terminal has separate controls.

## Configuration and data storage

- [x] Update `/open-source/reference/configuration`.
  - [x] Add `guideHistory`.
  - [x] Add `cursorSandbox`.
  - [x] Document accepted values and defaults.
  - [x] Add the relevant `PLANNOTATOR_AI` behavior.
  - [x] Correct any claim that the existing example contains every supported runtime key.
  - [x] Update the complete configuration example.

- [x] Update `/open-source/reference/environment-variables`.
  - [x] Add `PLANNOTATOR_AI`.
  - [x] Add `PLANNOTATOR_GUIDE_HISTORY`.
  - [x] Add `PLANNOTATOR_CURSOR_SANDBOX`.
  - [x] Correct `PLANNOTATOR_DATA_DIR` resolution.
  - [x] State that an existing `~/.plannotator` wins.
  - [x] State that an absolute `$XDG_DATA_HOME` produces `$XDG_DATA_HOME/plannotator` when the legacy directory does not exist.
  - [x] State that relative `$XDG_DATA_HOME` values are ignored.
  - [x] State that Plannotator does not implicitly use `~/.local/share`.

- [x] Update `/open-source/troubleshooting`.
  - [x] Replace commands that assume the config is always at `~/.plannotator/config.json`.
  - [x] Add a method for determining the effective data directory.
  - [x] Add the 2 MiB annotation-file error.
  - [x] Add the untracked-file-over-5-MiB behavior.
  - [x] Add Cursor sandbox startup troubleshooting.
  - [x] Show `PLANNOTATOR_CURSOR_SANDBOX=0` as the compatibility workaround.
  - [x] Warn that disabling the explicit sandbox weakens Plannotator’s write-protection guarantee.

## Vim controls

- [x] Update `/open-source/reference/keyboard-shortcuts`.
  - [x] Document optional Vim mode.
  - [x] Explain how to enable and disable it.
  - [x] Document supported plan-review controls.
  - [x] Document supported annotation controls.
  - [x] Document visual-selection behavior.
  - [x] Document the Vim HUD.
  - [x] Document the key-reference panel.
  - [x] State that Vim mode is disabled by default.

- [x] Update `/open-source/workflows/html`.
  - [x] State that Vim controls work while annotating raw HTML.
  - [x] Distinguish raw HTML from HTML converted to Markdown.

## Code-review limits

- [x] Update `/open-source/workflows/local-changes`.
  - [x] State that untracked files up to 5 MiB can be displayed normally.
  - [x] State that untracked files over 5 MiB appear as binary additions.
  - [x] State that Plannotator refuses to load their contents.
  - [x] Explain that this prevents large files from blocking the review.

## Cursor

- [x] Update the Cursor content in `/open-source/workflows/agent-reviews`.
  - [x] Stop stating unconditionally that Cursor always runs with Plannotator’s sandbox enabled.
  - [x] Document the default `--sandbox enabled` behavior.
  - [x] Add `PLANNOTATOR_CURSOR_SANDBOX=0`.
  - [x] Add `cursorSandbox: false`.
  - [x] Explain the NixOS and AppArmor compatibility use case.
  - [x] Explain the security tradeoff.

## OpenCode

- [x] Update `/open-source/agents/opencode`.
  - [x] State that review feedback stays with the current agent by default.
  - [x] State that plan approval still defaults to the build agent.
  - [x] Document configured target-agent routing.
  - [x] Explain the warning and fallback when the configured target is unavailable.

## Pi

- [x] Update `/open-source/agents/pi`.
  - [x] Document `executionMode: "external"`.
  - [x] Document the `plannotator:plan-approved` event.
  - [x] Explain how external plan execution consumes the event.
  - [x] State that Plannotator preserves tools registered by other Pi extensions.

## VS Code and VSCodium

- [x] Update `/open-source/agents/vscode`.
  - [x] Add the Open VSX installation option.
  - [x] Link to the Open VSX listing.
  - [x] Mention VSCodium and other Open VSX-based editors.
  - [x] Keep the Microsoft Marketplace installation instructions.

## Zed Preview

- [x] Update the existing Zed integration page, or create one if none exists.
  - [x] Document the macOS “Open in App” entry.
  - [x] Explain that it opens the document in Zed Preview.

## Site-wide maintenance

- [x] Reverify every OSS page against v0.25.0.
- [x] Update the 31 pages still marked “Last verified: v0.23.1.”
- [x] Update the nine pages still marked “Last verified: v0.24.2.”
- [x] Add verification metadata to the two unstamped pages where appropriate.
- [x] Update Documents search metadata.
- [x] Update Folders search metadata.
- [x] Search Mintlify content for `plannotator.ai/docs/`.
- [x] Remove or replace every link to deprecated `plannotator.ai/docs/`.
- [x] Keep OSS links under `docs.plannotator.ai/open-source/`.
- [x] Check internal links after routes and headings change.
- [x] Check CLI examples against the v0.25.0 binary.
- [x] Check configuration examples against the current config schema.
- [x] Check environment-variable descriptions against their implemented parsers and precedence rules.
- [x] Ensure OSS pages do not present Workspaces-only features as part of open-source Plannotator.
- [x] Ensure OSS workflow links do not redirect readers into commercial Workspaces documentation.
- [x] Do not treat screenshots or artwork as required work.
