# Mintlify v0.26.5 Documentation Update Checklist

Canonical documentation: <https://docs.plannotator.ai/open-source/>

Do not link to the deprecated `plannotator.ai/docs/` site. Mintlify source lives at `/Users/ramos/plannotator/docs`. Execute this checklist when v0.26.5 ships (docs must not describe unreleased behavior).

Status: pending release.

## Raw-HTML annotate sessions (PR #1243)

- [ ] Update the annotate page's HTML-files section.
  - [ ] Raw-HTML sessions now default to **Pinpoint** input: hover highlights the element under the cursor, click pins it and opens the comment composer directly, and each element annotation gets a numbered pin badge.
  - [ ] Pinpoint clicks create comments only; redline and quick-label remain available through drag selection (deliberate product decision).
  - [ ] Drag selection is still available from the input-method toggle; the HTML choice is remembered separately from markdown sessions (cookie `plannotator-input-method-html`).
  - [ ] Minimal-first chrome: the first-ever raw-HTML session hides the toolstrip, tab flags, and sidebar; later sessions open with exactly the chrome last left visible (cookie `plannotator-html-chrome`). "Show tools" in the header restores everything.
  - [ ] Annotations on regenerated pages restore via element anchors with a fail-closed text check; when the annotated text moved, the annotation follows the text; when it is gone entirely, the element gets a pin badge.
  - [ ] Selection text in HTML sessions is capped at 10,000 characters (security bound; truncated, not rejected).
  - [ ] Printing an HTML session hides pin badges and overlays; inline annotation marks remain printable (matches markdown behavior). Requires PR #1245.

## Durable annotate submissions (PR #1237, closes #678)

- [ ] Update the annotate page and the hooks/gates reference.
  - [ ] Single-local-file annotate sessions write each submitted decision to `history/{project}/{slug}/submissions/{timestamp}.md` BEFORE deleting the annotation draft, so feedback survives an agent-side timeout.
  - [ ] A failed record write keeps the draft as the recovery copy (a later identical session may show the restore banner with already-submitted annotations — intended).
  - [ ] URL, folder, and annotate-last sessions remain fully stateless (no history, no submission records).
  - [ ] `PLANNOTATOR_ANNOTATE_HISTORY=0` / `{ "annotateHistory": false }` now disables BOTH the version history and these submission records. Update the env-var reference accordingly.

## Installer (PR #1239, closes #1238)

- [ ] Update the installation page.
  - [ ] On git versions without `--sparse` support (e.g. git 2.23 from stale Xcode CLT), the skills fetch falls back to a plain shallow clone automatically; git is still required for a full install.

## Vim (PR #1154, closes #1153, by rNoz)

- [ ] Update the vim/keyboard reference if it describes j/k scrolling.
  - [ ] Cursor targets now reveal with a scrolloff-style margin (clamped 24-160px) instead of pinning flush against the viewport edge, so the caret stays clear of the sticky action bar and HUD overlays.

## Pi (PR #1240, by Whamp)

- [ ] Changelog-level only: feedback from a Plannotator tab now delivers correctly after a Pi `/reload` in the same session. No reference-page changes expected; verify the Pi troubleshooting page does not document the old failure as a known issue.

## Windows Codex wording (issue #1241)

- [ ] Verify the Mintlify Codex page does not claim Codex hooks are "disabled on Windows". Correct status: experimental on native Windows; the installer prints manual setup steps (`[features] hooks = true` plus the `Stop` hook). Repo README and apps/codex/README.md are already aligned.

## Validation

- [ ] `mintlify validate`
- [ ] `mintlify broken-links`
- [ ] Verify every changed page against the shipped v0.26.5 behavior.
