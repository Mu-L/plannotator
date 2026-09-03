# Implementation handoff: embedPicker v1 in @plannotator/ui

Audience: the agent implementing the Plannotator package side of the embed media system.
Authority: `DESIGN_embed-media-system.md` (repo root) is the design of record. Section 3 is the API contract, section 6 step 1 is your scope. Where this handoff and the design doc disagree, the design doc wins; flag the conflict.
The Workspaces side is NOT yours: `HANDOFF_workspaces-embed-upload.md` covers it and another team executes it after your release.

## Required reading, in order

1. `packages/ui/CLAUDE.md` and `packages/ui/README.md` (the seam doctrine; the one rule).
2. `DESIGN_embed-media-system.md` sections 3, 6, 7.
3. The reference implementation you are generalizing, READ-ONLY, never modify:
   `~/workspaces/projects/workspaces/worktrees/main/apps/web/src/plannotator/embed-slash.ts`
   (the two-stage flow, `filter: false` reasoning, icon conventions, empty-state rows).
4. The splice planner you are porting, READ-ONLY:
   `~/workspaces/projects/workspaces/worktrees/main/apps/web/src/lib/embed-insert.ts` (`planEmbedInsert` and its plan type; the grammar helpers `embedLinkLine`, `escapeEmbedLabel`, `relativeEmbedHref` stay in Workspaces, do not port them)
   and its tests in `~/workspaces/projects/workspaces/worktrees/main/apps/web/test/embed-insert.test.ts` (port the 11 splice tests verbatim; leave the grammar tests behind).
5. `packages/ui/components/MarkdownEditor.tsx` (the captured-once extension hazard and the "build against YOUR copy" CodeMirror rule around lines 27-63).

## Scope

Two new pieces, both in this repo:

1. **`planEmbedInsert` moves to `@plannotator/core`** as a pure module (it is string math with no app or node imports; core is browser-safe and zero-dep, CI enforces no `node:` imports). Re-export through the ui surface so consumers import from `@plannotator/ui`.
2. **`packages/ui/components/MarkdownEditor/embedPicker.ts`**, re-exported from `@plannotator/ui/components/MarkdownEditor` (the single supported import surface), exporting exactly:
   - `embedSlashItem(): SlashCommandItem`
   - `embedPicker(config: EmbedPickerConfig): Extension`
   - the types `EmbedKind`, `EmbedTarget`, `EmbedPickerConfig`

Implement the contract from design section 3 verbatim: `getTargets` / `buildInsertLine` / optional `uploadTarget` / optional `getNotice`. Copy the shapes from the design doc, do not improvise names.

## Behavior requirements (the ones that get missed)

- **Two-stage flow preserved exactly**: static item rewrites the typed `/query` to the literal `/embed ` and calls `startCompletion`; the picker source answers `/embed <query>` at line starts only, with `filter: false` and its own case-insensitive substring matcher over title AND path. The reasons are documented in embed-slash.ts; keep them as comments where they justify a decision.
- **Empty states**: no targets at all vs no matches for the query are two different rows with two different labels; picking either clears the typed command. Match the existing behavior.
- **Upload row**: present in every menu state iff `uploadTarget` is configured, including the empty state. Absent config means no row and no placeholder. Ordinary completion option (the CM listbox provides keyboard and screen-reader semantics); explicit "Upload HTML..." label; icon per the package convention (16x16 viewBox, currentColor, stroke 1.5).
- **Upload lifecycle** (design 3.1, all five steps): typed `/embed` text stays as the visible anchor during the host callback; single-flight with an inert "Uploading..." row on re-open; resolve(target) inserts via `buildInsertLine` + the ported splice at the anchor position mapped through document changes (CodeMirror transaction mapping, no bookkeeping of your own invention); the insert is dropped silently if the anchor line was edited away; resolve(null) and reject both insert nothing and leave the typed text. The package never renders error UI; error surfacing is the host's.
- **Nothing enters `configurePlannotatorUI`.** Per-mount config only. If you feel a global seam is needed, stop and re-read design decision at section 3 (the `setUploadWorkspace` precedent is the argument against you).

## Tests (Testing Rules in the root CLAUDE.md apply: name the regression each test catches)

From design section 6 step 1, all mandatory:

- rows from `getTargets` with substring filtering on title and path; `filter: false` behavior (a title with spaces survives the session);
- both empty-state rows;
- upload row present/absent by config, in both list states;
- upload resolve inserts the host-built line through the splice; resolve(null) inserts nothing; reject inserts nothing; single-flight (second trigger during flight does not call the host again);
- the async-gap rule: delete the `/embed` line during a pending upload, then resolve, assert no insert and no other document change;
- anchor mapping: insert text ABOVE the `/embed` line during a pending upload, resolve, assert the embed lands at the moved position;
- the 11 ported `planEmbedInsert` tests, verbatim;
- notice row rendered when `getNotice` returns text, absent when null.

Run the packages/ui suite and the repo typecheck. Never mutate `process.env` or the real data dir at module scope (Bun runs all tests in one process).

## Dependency discipline (breaks the editor if ignored)

`embedPicker` imports `@codemirror/autocomplete`, `@codemirror/state`, `@codemirror/view`. All three are already declared in `packages/ui/package.json`; add no new dependencies. `@plannotator/atomic-editor` declares every CodeMirror package as a peer (verified: its `dependencies` is empty), so exactly one copy resolves in a host build. Do not import anything from `@plannotator/atomic-editor` internals beyond the already re-exported `SlashCommandItem` type surface in `MarkdownEditor.tsx`. Do not touch `~/oss/markdown-editor` or any atomic-editor code; v1 requires zero engine changes by design.

## Out of scope, explicitly

- Any Workspaces file (read-only reference only).
- Render-side widgets, grammar helpers, the `#embed` recognition scan (design sections 4 and 6 step 3 are later stages).
- Publishing. Land the PR; the maintainer publishes core then ui in lockstep afterward (`bun pm pack`, `npm publish --provenance`). Do not bump versions.
- `configurePlannotatorUI`, HtmlViewer, and anything under `packages/ui/components/html-viewer/`.

## Deliverables

- Branch `feat/ui-embed-picker` off latest origin/main, PR against main. PR body: problem, the design doc reference, API summary, test list. No em dashes. End with "AI-assisted (Claude) under maintainer direction."
- A HANDOFF.md section in `packages/ui` documenting the new seam, following the existing sections' pattern (the wiki-links section is the model).
- CI green. Do not merge.
- Report: PR number, any deviation from the design doc with justification, and the answer to design risk 2 (evidence that the package's CM imports resolve to the same copies in a consumer build; the repo's own review app build is acceptable evidence at this stage).
