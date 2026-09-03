# Workspaces handoff: /embed picker moves upstream, upload arrives

Audience: Workspaces web team.
Upstream design: `DESIGN_embed-media-system.md` (Plannotator repo root). Read section 3 for the full API and section 6 for the migration plan. This handoff is the Workspaces-side instructions only.

## What is changing and why

The `/embed` slash menu (currently `apps/web/src/plannotator/embed-slash.ts`) moves into `@plannotator/ui` as `embedSlashItem()` + `embedPicker(config)`. The package now owns the menu, its rows, empty states, keyboard and screen-reader behavior, the paragraph splice, and a new "Upload HTML..." row. Workspaces answers three questions through callbacks and owns everything about storage.

This adds the feature users asked for: uploading an HTML file directly from `/embed`, including when the workspace has no HTML files yet.

Nothing about the rendered embed changes. `HtmlEmbedPreview`, resolution, the live-frame cap, grammar safety, and the video machinery stay exactly where they are. Do not migrate any render code.

## Sequencing

1. Plannotator ships `@plannotator/ui` with `embedPicker` (additive minor release; the version will be announced with the release notes and a HANDOFF.md section in the package).
2. Workspaces bumps the dependency and does the migration below.
3. Delete `embed-slash.ts` only after in-browser parity is confirmed (type `/embed` in a real workspace, check populated list, empty state, filtering, insert, and the cap notice all behave as before).

## The contract you implement

```ts
import { embedSlashItem, embedPicker, type EmbedTarget } from "@plannotator/ui/components/MarkdownEditor";

embedPicker({
  // Live read of embeddable documents. Same capture rule as wikiLinks:
  // the extensions array is captured once per mount, so this must be a
  // callback that reads current state, never a captured array.
  getTargets: () => htmlDocs, // adapt getDocuments() rows, filter kind === "html"

  // The exact markdown line for a picked target. Keep using your grammar:
  buildInsertLine: (target) => embedLinkLine(labelFor(target), getDocPath(), target.path),

  // The new work. See "Upload adapter" below.
  uploadTarget: async (kind) => { /* kind is "html" in v1 */ },

  // Optional status row. Port the MAX_LIVE_HTML_EMBEDS cap hint here.
  getNotice: (docBody) => capHintOrNull(docBody),
});
```

`EmbedTarget` is `{ kind: "html", path, title? }`. `path` is your workspace-root-relative `doc_path`; the package treats it as opaque and hands it back to `buildInsertLine`.

## Upload adapter: the important part

The adapter's job is "make a new embeddable document exist," not "store a file."

Do NOT route this through the existing `uploadTransport`. That seam stores anonymous assets and returns URLs. An embed resolves against the workspace document list by `doc_path`; a URL-backed asset will render as the unavailable card every time. The adapter must create a real workspace document.

Steps the adapter owns:

1. Open the file picker, accepting `.html` and `.htm`.
2. Enforce your permission checks. If the current surface is read-only or the user cannot create documents, do not pass `uploadTarget` at all. The package then shows no upload row (this is the intended gate; there is no disabled state).
3. Create the workspace document via your API. Filename conflicts and API errors are yours to resolve or surface.
4. Refresh the workspace document list so the new file appears in future pickers and resolves immediately.
5. Return `{ kind: "html", path: newDocPath, title }`.

Outcome semantics the package relies on:

- Resolve with a target: the package inserts it through the same path as picking an existing file.
- Resolve `null`: the user cancelled the picker. The package inserts nothing. Return `null` for cancellation, do not throw.
- Throw / reject: upload failed. The package inserts nothing and will not show any error. Surface the error yourself (toast or dialog) before or as you reject. The typed `/embed` text stays in the document so the user can retry by reopening the menu.
- The package single-flights the callback. You will never receive a second call while one is pending.
- During the dialog, the user can keep editing. The package tracks the insert position through edits and drops the insert if the user deleted the `/embed` line. Your adapter does not need to care; a document may legitimately be created with no embed inserted, which is fine (the file simply exists in the workspace).

## File-by-file migration

- `apps/web/src/plannotator/embed-slash.ts`: collapses to the config object above (roughly 60 lines: the `getTargets` adapter with the `kind === "html"` filter, the `buildInsertLine` wrapper, the ported cap-notice counting, and the upload adapter). Everything else in the file is deleted; the package now does it.
- `apps/web/src/lib/embed-insert.ts`: `planEmbedInsert` (the splice planner) moves upstream; keep `embedLinkLine`, `escapeEmbedLabel`, `relativeEmbedHref` (your grammar, still needed by `buildInsertLine`). Import the plan type from the package if you still reference it.
- `apps/web/src/lib/html-embeds.ts`, `components/html-embeds/`, video files: untouched.
- Editor wiring (`editor-extensions.ts` or equivalent): replace the old `embedHtmlSlashItem()` + `embedPickerExtension(config)` composition with the package's `embedSlashItem()` in `slashCommands({ items })` and `embedPicker(config)` composed alongside. Keep the config object a stable reference (the captured-once rule).

## Tests

- Retire the menu-behavior tests in `apps/web/test/dom/embed-slash.test.tsx`; the package carries that coverage (rows, filtering, empty states, upload semantics, splice).
- Keep or add: one adapter-wiring test (your `getTargets`/`buildInsertLine` produce the same rows and inserted line as before) and one upload integration test (pick file, document created, list refreshed, embed inserted; plus the failure path surfacing your error UI and inserting nothing).
- `apps/web/test/embed-insert.test.ts`: the grammar tests stay; the splice tests move upstream (they ship with the package release, do not duplicate them).

## Acceptance checklist (your half)

- File picker accepts `.html` and `.htm` only.
- Permission-gated surfaces pass no `uploadTarget` and show no upload row.
- Successful upload creates a document that resolves and previews like any hand-created HTML doc.
- Conflict and API errors are surfaced by Workspaces UI; the document body is never touched on failure.
- Document list refresh means an uploaded file appears in the next `/embed` open without a reload.

## Non-goals, restated

No arbitrary remote URL embeds. No render-side migration. No changes to the `#embed` grammar (a packaged default comes later, announced separately, adopt-when-ready). The provider video allowlist and its security posture are untouched.

Questions or friction with the contract: flag it against `DESIGN_embed-media-system.md` before working around it, especially anything that tempts a second upload path or a package patch.
