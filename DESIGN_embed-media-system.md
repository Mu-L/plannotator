# Design: the embed media system

Status: proposal, no implementation. Investigated 2026-08. Ruling being executed: the `/embed` picker moves into `@plannotator/ui` (Option A), designed kind-aware so images, video, and iframes slot in later. File references are to the current Plannotator main checkout and the Workspaces `worktrees/main` checkout.

The question this document answers beyond the spec: Workspaces has the complete, correct model for how an embed looks and behaves once it is in a document. Who owns what, and what can the UI package distribute to make the host's life easier without taking ownership of things it cannot correctly own?

---

## 1. What exists today (verified, with paths)

### 1.1 The authoring side (the `/embed` flow)

- `@plannotator/atomic-editor`'s `slashCommands()` is a generic Notion-style insert menu. Its API is `SlashCommandItem { label, detail?, snippet?, apply?, boost?, icon? }` plus `SlashCommandsConfig { items?, replaceDefaults? }` (`node_modules/.bun/@plannotator+atomic-editor@0.8.0.../dist/slash-commands.d.ts`). It knows nothing about embeds.
- The entire `/embed` experience is Workspaces code: `apps/web/src/plannotator/embed-slash.ts` (223 lines). Two stages: a static "Embed HTML" `SlashCommandItem` whose `apply` rewrites the typed `/query` to the literal `/embed ` and calls `startCompletion`, and an app-owned `CompletionSource` that answers `/embed <query>` with the workspace's HTML documents. It registers through `EditorState.languageData` so it composes with the package's own slash source, and deliberately rides the package menu theme ("the package's menu theme deliberately styles ANY autocomplete tooltip", embed-slash.ts:36).
- Live data rides config callbacks (`getDocuments`, `getDocPath`), not captured arrays, because `MarkdownEditor`'s `extensions` prop is captured once per `documentId` (`packages/ui/components/MarkdownEditor.tsx:64-74`). embed-slash.ts's header explicitly cites this as "the wiki-links capture-hazard pattern".
- Insert grammar and splice are `apps/web/src/lib/embed-insert.ts`: `embedLinkLine()` produces `[label](relative/path.html#embed)` (escaping and percent-encoding tuned to the app's parser round-trip), and `planEmbedInsert()` plans the splice that puts that line in its own blank-line-delimited paragraph. 11 tests in `apps/web/test/embed-insert.test.ts` pin the round-trip.
- The picker also shows an honest empty state ("No HTML files in this workspace" / "No HTML files match ...") and a cap notice when the document already has `MAX_LIVE_HTML_EMBEDS` (6) live frames (embed-slash.ts:124-161).

### 1.2 The rendered side (what an embed IS once in the document)

Three layers, all Workspaces-owned today:

- **Grammar and safety** (`apps/web/src/lib/html-embeds.ts`): a standalone link line whose href ends `#embed`; `normalizeHtmlEmbedTarget()` is the security boundary (rejects absolute URLs, schemes, `..` escapes, raw `%`/whitespace/`#`/`?`, encoded slashes) and resolution happens only against the caller's already-authorized document list (`resolveHtmlEmbed`). `findStandaloneLinkLines()` is the shared scan both HTML and video embeds filter (fence-aware, indented-code-aware).
- **Promotion** (`apps/web/src/plannotator/html-embed-source.ts`, `HtmlEmbedDriver.tsx`): source grammar is confirmed against the package parser's real block segmentation (`confirmRenderedCandidates` matches `startLine` + exact `block.content`, then the DOM pass verifies the paragraph by `data-block-id` and `candidateAnchor`). The confirmed paragraph is replaced with a portal host; annotation-overlapping anchors fall back to a rewritten link instead (never breaking a stored highlight). The known C5 ordinal hazard (paragraph removal shifts web-highlighter DomMeta ordinals) is recorded in both drivers.
- **Widgets** (`apps/web/src/components/html-embeds/HtmlEmbedPreview.tsx`, 525 lines): the preview card with header, skeleton loading face, error card with retry, capped card, and the live viewport: a `sandbox="allow-scripts"` srcdoc iframe at 50% scale, `pointer-events-none` under a click-through overlay, near-viewport activation plus a global load-permit queue (`preview-activation.ts`, shared with the Wall tiles), body fetched via TanStack Query against Workspaces' preview endpoint with `injectBaseHref(usercontentBaseHref(...))` for asset resolution.

Video already exists (`VideoEmbedDriver.tsx`, `lib/video-embeds.ts`, ADR 0055): the SAME standalone-link scan and the SAME block-confirmation machinery (`video-embed-source.ts` literally calls `confirmRenderedCandidates`), promoting to either a native `<video>` for sibling `.mp4`/`.webm` assets or a click-to-load facade for a hardcoded three-provider registry (YouTube/Loom/Vimeo) where "the allowlist IS the security model" and embed URLs are minted from validated ids, never author text.

### 1.3 The seams that already exist

- `configurePlannotatorUI` already has an `uploadTransport` seam (`packages/ui/utils/upload.ts`): `upload(file: File) → Promise<{ path }>`, built for comment-composer image attachments. Workspaces implements it (`apps/web/src/plannotator/upload-transport.ts`) as an asset PUT returning a permanent content-addressed URL, with a module-global `setUploadWorkspace()` dance to scope the boot-time seam to the open workspace.
- Workspaces wires all 11 seams explicitly and forbids silent fallbacks to Plannotator's `/api/*` (`apps/web/src/plannotator/seams.ts`).

Two facts from this inventory change the plan I carried in:

1. **The existing `uploadTransport` is the wrong channel for embed uploads.** It stores an anonymous asset and returns a URL. An HTML embed must resolve to a workspace *document* (`doc_path`, `kind: "html"`) in the authorized list, or `resolveHtmlEmbed` renders an unavailable card. Embed upload means "create a document in the workspace", which involves the host's file picker, permissions, conflicts, and list refresh. It needs its own contract; overloading `uploadTransport` would be a category error.
2. **The promotion machinery is already coupled to package internals.** `confirmRenderedCandidates` depends on the package parser's block segmentation and `data-block-id` DOM contract. That is package API being consumed from app code, which is exactly the kind of coupling that should eventually live upstream where the parser can change and its confirmation logic changes with it.

---

## 2. Ownership matrix

| Layer | v1 owner | End-state owner | Migration trigger |
|---|---|---|---|
| Slash item + picker UX (menu, rows, empty states, upload row, a11y) | **Package** (`@plannotator/ui`) | Package (possibly graduating to `@plannotator/atomic-editor`) | Moves now (this design). atomic-editor graduation only if a non-React consumer appears. |
| Target listing ("what can I embed?") | Host callback | Host callback | Never moves. It is the workspace model. |
| Upload ("make this file part of the workspace") | Host callback | Host callback | Never moves. Storage, permissions, conflicts, refresh are the host's, deployed or self-hosted. |
| Insert splice (own-paragraph normalization, cursor placement) | **Package** (moves with the picker) | Package | Moves now. `planEmbedInsert` is editor string math with no app model in it. |
| Insert grammar (the exact line: `[label](href#embed)`) | Host callback (`buildInsertLine`) | The contract itself; graduates upstream once a second kind ships and the shape has stopped moving | Second embed kind authored through the picker. |
| Embed recognition + parse (standalone-link scan, `#embed` filter) | Host | Package utility (pure, browser-safe, probably `@plannotator/core`) | When grammar graduates. The scan is already pure and host-agnostic. |
| Target normalization + resolution (path safety, authorized-list lookup) | Host | Host owns resolution; the package MAY ship `normalizeHtmlEmbedTarget` as a pure utility since it is security-reviewed string logic any host needs verbatim | With recognition. |
| Promotion/confirmation machinery (block-ID confirmation, paragraph-to-host swap, annotation-overlap fallback) | Host | **Package** (it is coupled to the package parser and to web-highlighter ordinals, both package concerns) | First parser change that breaks confirmation, or the second host. Do not move in v1; it works and is tested where it is. |
| Render widgets (preview card, loading face, error/capped cards, sandboxed frame) | Host | Package ships presentational primitives with slots; host keeps composition, data fetching, routing | A second host that wants the look. Not before. |
| Caps/policy (live-frame budget, activation queue) | Host | Mechanics could be packaged with host-tuned numbers, but the activation queue is shared with non-embed surfaces (the Wall), so it stays host | Probably never; revisit if a second host rebuilds it. |
| Errors (upload failure surfacing, preview load failure) | Host | Host | Never. The package's obligation is only "no insert on failure". |

The one-sentence answer to the user's question: **the host owns what an embed IS (model, storage, resolution, policy); the package owns how an embed is AUTHORED (picker, upload row, splice) and, over time, the mechanics that are coupled to the package's own parser and DOM contract; the grammar line between them is a host callback today and becomes the shared contract once it stops moving.**

---

## 3. Package API (v1)

New module: `packages/ui/components/MarkdownEditor/embedPicker.ts` (re-exported from `@plannotator/ui/components/MarkdownEditor`, which stays the single supported import surface). Built on `@codemirror/autocomplete` exactly as embed-slash.ts is today; the codemirror packages resolve to the same copies the host's editor uses (the existing "two copies break the editor" rule in MarkdownEditor.tsx:60-63 already governs this).

```ts
/** What an embed can point at. v1 ships "html" only; the string union grows. */
export type EmbedKind = "html"; // later: | "image" | "video" | "iframe"

/** One embeddable thing the host knows about. Opaque to the package beyond display. */
export interface EmbedTarget {
  readonly kind: EmbedKind;
  /** Host-meaningful identifier (Workspaces: workspace-root-relative doc_path). */
  readonly path: string;
  /** Display title; falls back to path in menu rows. */
  readonly title?: string | null;
}

export interface EmbedPickerConfig {
  /** Live read of embeddable targets (the capture hazard: callbacks, never arrays). */
  readonly getTargets: () => readonly EmbedTarget[];
  /**
   * The exact line to write into the document for a picked target.
   * Grammar is the HOST's (Workspaces: embedLinkLine from lib/embed-insert.ts).
   * The package owns the splice around it: own-paragraph normalization,
   * cursor placement, pickedCompletion annotation.
   */
  readonly buildInsertLine: (target: EmbedTarget) => string;
  /**
   * Optional upload adapter. Present: every /embed menu (including the empty
   * state) shows an "Upload HTML..." row. Absent: no upload row, no disabled
   * placeholder (the spec's callback-absent criterion).
   *
   * Contract: resolve(target) = insert through the exact same path as a picked
   * existing target; resolve(null) = user cancelled, nothing is inserted;
   * reject = failure, nothing is inserted, the HOST surfaces the error
   * (toast, dialog), the flow stays recoverable. The package single-flights
   * calls: while one is pending, re-triggering shows an inert "Uploading..."
   * row instead of a second invocation.
   */
  readonly uploadTarget?: (kind: EmbedKind) => Promise<EmbedTarget | null>;
  /**
   * Optional per-open status row (Workspaces: the MAX_LIVE_HTML_EMBEDS cap
   * hint). Called with the current document text on each menu computation;
   * return null for no row.
   */
  readonly getNotice?: (docBody: string) => string | null;
}

/** The static "Embed HTML" slash item (compose into slashCommands({ items })). */
export function embedSlashItem(): SlashCommandItem;

/** The /embed picker completion source, registered via languageData
 *  (composes with slashCommands()'s own source, same as today). */
export function embedPicker(config: EmbedPickerConfig): Extension;
```

Decisions and their reasons:

- **Nothing goes into `configurePlannotatorUI`.** The wiki-links precedent is explicit: editor-extension data rides per-mount config callbacks because the extensions array is captured once and global seams cannot see the router. The existing `uploadTransport`'s `setUploadWorkspace()` module-global workaround (upload-transport.ts:17-29) is the documented pain of doing scoping through a boot-time seam; the embed callbacks close over live route state for free. Everything is `embedPicker(config)`.
- **`buildInsertLine` (host) + package-owned splice.** `planEmbedInsert` moves upstream essentially verbatim (it references nothing app-specific; its 11 tests move with it). `embedLinkLine`/`escapeEmbedLabel`/`relativeEmbedHref` stay host-side because the escaping is tuned to the host's parser round-trip and the `#embed` fragment is the host's grammar. When grammar graduates (section 6), `buildInsertLine` gets a packaged default and hosts stop passing it.
- **Kind-aware from day one, enforced narrow.** `EmbedKind = "html"` only; `uploadTarget` receives the kind so its signature never changes when kinds are added. The picker's v1 rows filter to `kind === "html"` (the filter currently at embed-slash.ts:102).
- **Two-stage flow is kept exactly** (static item rewrites to `/embed ` + `startCompletion`; picker source answers `/embed <query>` with `filter: false` and its own substring matcher over title AND path). It is shipped, tested behavior with documented reasons (spaces in titles vs CM's fuzzy matcher, embed-slash.ts:172-180).

### 3.1 The upload flow, precisely

The async gap between picking "Upload HTML..." and the host resolving is the one genuinely new mechanism. Design:

1. User picks the row. The typed `/embed ...` text is left in place; it is the position anchor and the visible "something is in progress here" state. (Precedent: escaping the menu already leaves inert `/embed ` text as a recoverable state, embed-slash.ts:37-39.)
2. The package invokes `uploadTarget("html")` once (single-flight; a re-opened menu during flight shows an inert "Uploading..." row).
3. On resolve(target): the package re-locates the `/embed` query line (it holds the position mapped through document changes via CM's transaction mapping; if the author deleted the line during the file dialog, the insert is dropped, nothing else is touched). It then runs `buildInsertLine(target)` + the packaged splice, identical to picking an existing file.
4. On resolve(null): nothing happens. The typed `/embed ` text remains, exactly like Escape. The user deletes it or re-triggers.
5. On reject: same as cancel from the package's side (no insert, text remains), and the host is expected to have surfaced the error itself (it owns filename conflicts and API errors per the spec). Retry is re-opening the menu.

A11y and keyboard come free and must stay free: every row (targets, upload, empty state, notice) is an ordinary CM completion option in the menu's existing listbox, so arrow/enter navigation and the menu theme apply uniformly. The upload row gets an explicit label ("Upload HTML..."), an icon following the package's icon conventions (16x16 viewBox, currentColor, embed-slash.ts:57-60), and no behavior that diverges from row semantics.

### 3.2 Spec acceptance criteria mapped

| Criterion | Owner |
|---|---|
| Upload row shown with empty list | Package (row present whenever `uploadTarget` configured) |
| Upload row alongside populated list | Package |
| Success inserts via existing embed path | Package (`buildInsertLine` + shared splice) |
| Cancel leaves document unchanged | Package (resolve(null) path) |
| Failure inserts nothing, recoverable | Package (no insert) + Host (error surfacing) |
| Callback absent: current behavior, no dead row | Package |
| Mouse/keyboard/screen reader | Package (CM listbox rows) |
| Tests: empty/populated/success/cancel/failure/absent | Package tests (see section 6) |
| File picker, `.html`/`.htm` accept, permissions, upload, conflicts, list refresh, returning the target | Host |

---

## 4. Render-side distribution (who owns the look)

Recommendation: **do not move render widgets in v1, and be explicit that most of the render side never moves.**

What should NOT move, with reasons from the code:

- `HtmlEmbedPreview` is wired into TanStack Query (`previewBodyQueryOptions`), the router (`Link`, `carryDocPanel`), the usercontent origin (`injectBaseHref(usercontentBaseHref(...))`), and an activation/load-permit system shared with a non-embed surface (the Wall, preview-activation.ts:112-114 comment). Extracting it means either dragging query/router/origin seams into the package or gutting the component. Neither serves anyone today.
- `HtmlViewer` (`packages/ui/components/html-viewer/`) is the wrong base for an embed frame. It is ~12.8k lines across the directory, of which the annotation machinery (`useHtmlAnnotation.ts` alone is 945 lines, plus the bridge script and pinpoint protocol) is the bulk. The embed viewport is ~100 lines of iframe mechanics (`PreviewViewport`, HtmlEmbedPreview.tsx:134-230) with a different posture: `sandbox="allow-scripts"`, `pointer-events-none`, `aria-hidden`, focus-recovery, scale-50. Reusing HtmlViewer would import an annotation surface into a context that must never annotate.
- The provider video registry stays host policy: ADR 0055's "the allowlist IS the security model" and minted-URL discipline (lib/video-embeds.ts) is a product security decision, not UI machinery.

What the package CAN distribute later to "make life easier", when a second consumer exists:

- **Presentational card primitives**: the frame chrome (header slot, loading skeleton face, error/capped states) as slot-based components with no data fetching, no router, no query. Workspaces would keep its drivers and queries and swap its markup for the primitives only if it wants to. This is a cosmetics-sharing move; it has zero architectural urgency.
- **The sandboxed embed viewport** as a leaner sibling of HtmlViewer's srcdoc handling (props: srcDoc, title, sandbox posture, reveal-on-load with timeout, focus recovery). Small, genuinely generic, and the place to keep the ADR 0044 postMessage tripwire documented once (HtmlEmbedPreview.tsx:195-204).
- **The promotion machinery** (`confirmRenderedCandidates`, `candidateAnchor`, the paragraph-to-portal-host swap with its C5 ordinal hazard and annotation-overlap fallback). This is the strongest future candidate because it is coupled to package contracts on both ends: the parser's block segmentation on one side and web-highlighter's DomMeta ordinals on the other. Today that coupling is stable and tested from the app; the migration trigger is the first package parser change that breaks it, or a second host needing promotion.

---

## 5. Kinds roadmap

The v1 contract is designed so each addition is additive:

- **image**: `EmbedKind` gains `"image"`. The picker gains an "Embed image" path (or the existing image paste/drop flows stay primary and the picker just lists image documents). `uploadTarget("image")` reuses the same adapter shape; whether the host implements it via document creation or its existing asset upload (upload-transport.ts) is the host's call, because the returned `EmbedTarget` is opaque to the package. `buildInsertLine` returns `![alt](path)` per host grammar.
- **video**: targets are sibling `.mp4`/`.webm` documents (the native-player arm that already renders) plus, for provider URLs, no picker involvement at all; pasting a URL on its own line is already the authoring UX and should stay it. The picker only ever lists things the host enumerates; it never becomes a URL entry field.
- **iframe / arbitrary remote URLs**: a spec non-goal today and the right call. When it comes, it must arrive as host policy in the same shape as ADR 0055's video registry: an explicit allowlist (or an explicit per-workspace admin setting for self-hosts), embed URLs minted from validated input, never author text passed through. The package's role stays mechanical: list what the host enumerates, insert what the host's grammar builds. The package must never ship a default that frames an arbitrary URL.

The invariant across all kinds: `getTargets`/`uploadTarget`/`buildInsertLine` signatures do not change; kinds change the values flowing through them.

---

## 6. Migration plan

**Step 1, package (this repo):** add `embedPicker.ts` + the moved splice planner (`planEmbedInsert` and its plan type, most likely in `@plannotator/core` since it is pure string math, re-exported through the ui surface). Tests, all named for the regression they catch:

- picker rows from `getTargets` with the substring filter (title and path), `filter: false` behavior preserved;
- empty-state rows (no targets vs no matches);
- upload row present iff `uploadTarget` configured (both list states);
- upload resolve inserts the host-built line through the splice; resolve(null) and reject insert nothing; single-flight;
- the async-gap rule: document edited so the `/embed` line is gone means no insert;
- the moved `planEmbedInsert` tests (11) verbatim;
- notice row rendered when `getNotice` returns text.

**Step 2, Workspaces:** `embed-slash.ts` collapses to a config object (~60 lines): `getTargets` adapting `getDocuments()` rows to `EmbedTarget`s (the `kind !== "html"` filter moves into the adapter), `buildInsertLine` wrapping `embedLinkLine(label, getDocPath(), target.path)`, `getNotice` keeping the cap hint (its `findHtmlEmbedCandidates`/`resolveHtmlEmbed`/`MAX_LIVE_HTML_EMBEDS` counting), and a new `uploadTarget` that opens the host file picker (`.html,.htm`), creates the workspace document via the API, refreshes the document list, and resolves the new `doc_path`. `apps/web/test/dom/embed-slash.test.tsx` (6 tests) largely retires in favor of the package tests; what stays app-side is the adapter wiring and the new upload integration test. `embed-insert.test.ts` keeps its grammar half; its splice half moves upstream.

**Step 3, later, grammar graduation:** once a second kind ships through the picker and `[label](path#embed)` has proven stable across hosts, `embedLinkLine`-equivalent moves upstream as the packaged default `buildInsertLine`, and the recognition scan (`findStandaloneLinkLines` + the `#embed` filter + `normalizeHtmlEmbedTarget`) is offered as pure `@plannotator/core` utilities so host and package cannot drift on what is an embed. Workspaces deletes its copies when it adopts them, not before, and only after in-browser parity confirmation (the packages/ui CLAUDE.md rule).

Publishing: this is additive `@plannotator/ui` API, normal lockstep minor release (`bun pm pack` core then ui, `npm publish --provenance`), with a HANDOFF.md section documenting the new seam per the established pattern.

---

## 7. Risks and open questions

1. **The async insert anchor.** Holding a position across the upload dialog and mapping it through edits is the only novel mechanism. Recommendation: leave the typed `/embed ` text as the visible anchor, map its position through transactions, drop the insert if the line was edited away. Pin all three behaviors in tests.
2. **CodeMirror copy discipline.** `embedPicker` puts `@codemirror/autocomplete`/`state`/`view` imports inside `packages/ui`. The existing rule ("build against YOUR copy... two live copies break the editor") must hold for the package's own extension exactly as it does for `wikiLinks` from atomic-editor. Recommendation: declare the `@codemirror/*` packages the same way the current dependency arrangement supports embed-slash.ts doing this from the app; verify in the Workspaces build before publishing.
3. **Where the picker ultimately lives.** atomic-editor owns `slashCommands()` and the menu theme; the picker deliberately rides both. Keeping the picker in `@plannotator/ui` splits slash-menu ownership across two packages. Accepted for v1 (single supported import surface, one release train, the ruling); revisit only if atomic-editor grows a non-Plannotator consumer.
4. **The cap-notice callback shape.** `getNotice(docBody)` passes the full text per menu computation, which is what the app already pays (embed-slash.ts:147 calls `context.state.doc.toString()` per invocation). Fine at document scale; noted in the API docs so nobody adds an O(n) scan per keystroke on a megabyte document without noticing.
5. **Workspaces' upload endpoint is new host work.** The package ships fully testable without it, but the feature is only user-visible once Workspaces implements pick-file, create-document, refresh, resolve. The spec assigns that correctly; calling it out so v1 is not declared done at package-merge time.
6. **Upload row while offline/unauthorized.** The package cannot know. The host can simply not pass `uploadTarget` for read-only surfaces (same pattern as seams.ts stubbing rules), which the callback-absent criterion already covers. Recommend documenting that as the intended gate rather than adding a `disabled` state.

---

## 8. Executive summary

Move the `/embed` picker into `@plannotator/ui` as `embedSlashItem()` + `embedPicker(config)`, with three host callbacks: `getTargets` (what exists), `buildInsertLine` (what gets written), `uploadTarget` (make a new thing exist, optional, kind-aware). The package owns the menu, the rows, the empty states, the upload row's semantics (single-flight, cancel = nothing, failure = nothing, success = same insert path), keyboard and screen-reader behavior, and the own-paragraph splice, which moves upstream with its tests. Nothing enters `configurePlannotatorUI`; the existing image `uploadTransport` is deliberately not reused because embeds resolve against workspace documents, not anonymous assets. The rendered embed model, storage, path-safety normalization, resolution, caps, and the preview widgets stay in Workspaces, where they are correct and deeply wired to its query, routing, and usercontent-origin infrastructure. The future is staged by triggers, not dates: presentational card primitives and the sandboxed viewport when a second consumer wants the look; the block-confirmation and paragraph-promotion machinery when a parser change or second host demands it; the grammar itself once a second kind proves the contract; iframe embeds only ever as host-policy allowlists in the ADR 0055 mold.
