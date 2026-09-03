# Design: full file viewing and navigation in code review

Status: proposal, no implementation. Investigated 2026-08. All file references are to the current main checkout.

The ask: in code review you can expand diff context, but you cannot just open a full file. Annotate mode already renders full code files. Investigate a full code viewer inside code review: see the whole file, browse the file tree like an editor (including files not in the diff), and do click-to-definition navigation.

The short version: most of this feature already exists in the codebase, split across surfaces that do not talk to each other. Annotate mode has a full-file Pierre viewer with line annotations (`CodeFilePopout`). Code review has Cmd+click symbol resolution with a peek panel, but the peek is a dead end and its file endpoint is the crudest file server in the repo. Pierre itself natively supports full-file items with virtualization and annotations, which Plannotator has never used. The design work is mostly wiring, plus one genuinely new decision: what an annotation on an unchanged file means for review feedback.

---

## 1. Current state

### 1.1 Seeing beyond the hunks in code review today

Two mechanisms exist, both scoped to files that are in the patch:

- Per-hunk expansion. The single-file `DiffViewer` fetches `/api/file-content` eagerly on mount (`packages/review-editor/components/DiffViewer.tsx:375-391`) and re-parses the patch against the full file contents so Pierre's expand-unchanged gutter chevrons work. `AllFilesCodeView` does the same lazily as items enter the render window, applying at scroll-idle to avoid jank (`packages/review-editor/components/AllFilesCodeView.tsx:1269-1400`).
- The `expandUnchanged` display setting, a Pierre `BaseDiffOptions` boolean that renders every line of a changed file inline.

Server side, `/api/file-content` (`packages/server/review.ts:2835-2958`) is the careful one: it enforces a snapshot-echo guard (409 when the diff snapshot is stale), resolves content per diff type through the VCS provider (git object reads for committed sides, working tree for the new side), and caps each side at `MAX_REVIEW_FILE_CONTENT_BYTES = 5 MiB` (`packages/shared/review-core.ts:21`). Oversized files render a stub with `OversizedFileNotice` and cannot be expanded.

Files not in the diff are unreachable from every navigable surface: `FileTree` builds only from `parseDiffToFiles(rawPatch)` (`packages/review-editor/components/FileTree.tsx:29,204`), and the sections, commits, and search views are all views of some patch. The one exception is the code-nav peek, below.

### 1.2 Annotate mode already has the full-file viewer

The plan and annotate servers serve whole code files through `/api/doc`'s code-file branch (`packages/server/reference-handlers.ts:375-433`): literal path resolve, then a smart case-insensitive suffix resolver over a cached repo walk, allowed-roots containment (403 outside), a 2 MB cap (`MAX_ANNOTATABLE_FILE_BYTES`, `packages/core/annotatable.ts:186`), and, notably, server-side prerendering of the full file with Pierre's SSR `preloadFile` so the popout paints highlighted immediately.

The client is `CodeFilePopout` (`packages/ui/components/CodeFilePopout.tsx`, 603 lines): a modal rendering the whole file via Pierre's `<File>` component, scrolls to a `:line` anchor, and supports line-scoped annotation with a gutter "+", line-click, drag ranges, and browser text selection mapped back to line numbers. Those become `CodeAnnotation` objects (`packages/ui/types.ts:220-279`) and export in feedback under a dedicated `# Code File Feedback` section with the original code fenced (`exportCodeFileAnnotations`, `packages/ui/utils/parser.ts:1401-1438`).

The supporting machinery: a warm file-list cache (async walk, `CODE_FILE_REGEX` matching, 5000-file budget from `PLANNOTATOR_FILE_BROWSER_MAX_FILES`, 30s TTL, promise-deduped, `packages/shared/resolve-file.ts:306-377`) powers both `/api/doc/exists` batch link validation and bare-filename resolution. The folder-session file browser walks upfront with the same budget, seeds git-status files before the bulk walk so they never fall past the cap, and returns a `truncated` flag (`packages/server/reference-handlers.ts:674-744`).

### 1.3 Code navigation today

The gesture exists: Cmd/Ctrl+click on a Pierre token in both diff surfaces fires `onCodeNavRequest` (`DiffViewer.tsx:712-718`, `AllFilesCodeView.tsx:2441-2481`; Cmd-hover shows a `pn-token-nav` affordance). The request carries `{ symbol, filePath, line, charStart, side, language? }`.

Resolution (`packages/shared/code-nav.ts`, adapters in `packages/server/code-nav.ts`) is a literal word-regexp ripgrep search: `rg --json --word-regexp --max-count 50 --max-filesize 1M`, 12 ignored dirs, optional `--type` from the source file's language, 5s timeout, 500-line parse cap. Definition vs reference is post-hoc per-line regex classification with per-language pattern sets for TS/JS, Python, Go, Rust plus generic fallbacks (`code-nav.ts:94-138,248-273`). Ranking is proximity-based: same file +1000, changed-in-diff +500, same dir +200, test-file penalty, definition bonus (`code-nav.ts:279-314`).

Honest assessment of what it can and cannot do:

- Good: top-level functions, `const/let/var` bindings, classes/interfaces/types/enums, Python `def`/`class`, Go `func` with receivers, Rust items. Same-file and changed-file results float up, which fits review flow.
- Bad: plain TS/JS class methods with no modifier (`foo() {`) classify as references, so the real definition ranks below any `const foo =` anywhere. Object-property arrows and destructuring defs are missed. Same-name symbols get no scoping at all (a symbol like `resolve` caps out at 50 of 500 matches). The `--type` filter makes cross-language references invisible. `side`, `line`, and `charStart` are accepted but never used, so a symbol deleted at HEAD returns nothing.

Presentation: results open a dockview panel below the active diff (`ReviewCodeNavPanel`, 250px, `App.tsx:945-975`). The peek is terminal: no "open file" action, no chained navigation, and the preview renders every line of the file as an unvirtualized table row with per-line `HighlightedCode` (`ReviewCodeNavPanel.tsx:66-95`), so a large file mounts thousands of components. Definitions and references are concatenated without visual distinction.

`/api/code-nav/file` (`review.ts:2988-3018`) reads `${navCwd}/${filePath}` and returns the whole file with no size cap and no snapshot guard. Both code-nav endpoints are mirrored on Pi (`apps/pi-extension/server/serverReview.ts:2953-3002`, shared module vendored via `vendor.sh:32`).

### 1.4 Annotation model in review

`CodeAnnotation` is addressed by `filePath + lineStart/lineEnd + side ('old'|'new')`, with optional `charStart/charEnd/tokenText` for token selections and anchor-context stamps (`commitSha`, `diffScope`). Text-offset addressing exists only on the plan/markdown side. Two facts matter for this design:

- Nothing guards hunk membership on creation (`handleAddAnnotationForFile`, `App.tsx:1836-1872` records whatever `pendingSelection` holds), so annotating expanded-context lines appears to already work.
- But snippet extraction reads the raw patch only: `extractLinesFromPatch` (`packages/review-editor/utils/patchParser.ts:4-58`) walks hunk lines, so out-of-hunk selections yield empty `originalCode`/`selectedCode` in the toolbar, drafts, and Ask AI context. Call Flow already demotes out-of-hunk targets to file scope via `isLineRangeInPatch`; plain line annotations do not.

Multi-instance annotation surfaces are a solved problem: `ToolbarHost`/`useAnnotationToolbar` keep drafts in module-level maps keyed by `filePath`, arbitrated by the `isFocused` prop (the guide takeover spike, `adr/research/SPIKE-guide-diff-annotation-reuse-20260702-194831.md`, documents the one known race: two surfaces claiming `isFocused` for the same file).

### 1.5 Adjacent assets

- Pierre full-file items. `CodeView` items are a union `CodeViewDiffItem | CodeViewFileItem` (`node_modules/@pierre/diffs/dist/components/CodeView.d.ts:26-40`); file items take `FileContents` and get virtualization, line annotations, and line selection. Plannotator uses only diff items today. Pierre's SSR (`preloadFile`) is already used by the annotate server.
- Highlighting. Pierre inlines Shiki's full bundle (every grammar and theme, `shiki-js` regex engine, no wasm), so whole-file highlighting for any language costs zero extra bundle bytes. The review worker pool (`packages/review-editor/workerPool.tsx`) runs `min(cores-1, 3)` workers with a 5s fallback to main-thread plain-then-highlight; without it, main-thread tokenization profiled at over 2s during scrolling.
- CallDiff runtime. The optional managed Call Flow install (pinned CallDiff 0.4.1, per-language packs, Node 22 preflight, consent flow) prunes the runtime to exactly two entries, and one of them is `dist/extract.js` exposing `extractFunctions(filePath, content)`: a real single-file tree-sitter function extractor that Plannotator already invokes for pack validation (`packages/shared/call-flow.ts:641-651`). That is a per-file "list function definitions with spans" primitive shipping today. Anything richer (references, cross-file resolution) is internal to `runDiff`'s two-ref diff pipeline.
- VS Code. `packages/server/ide.ts:10-29` spawns `code --diff`; no `code --goto file:line` exists yet, but the CLI detection and error copy are precedent for one.
- Guide viewer. Renders diffs (not full files) behind the narrow `GuideHost` seam; its `readOnly` mode and viewport admission control are the pattern for read-only reuse, not directly needed here.

### 1.6 Constraints, with receipts

- Two-runtime law. Every endpoint exists twice: Bun (`packages/server/review.ts`) and Pi (`apps/pi-extension/server/serverReview.ts`, hand-maintained `node:http`). Pure logic goes in `packages/shared` and is vendored by `apps/pi-extension/vendor.sh`. Code-nav is the worked example of the full pattern: one shared module, one `vendor.sh` line, two roughly 40-line handler blocks.
- Security. `validateFilePath` (`review-core.ts:2255-2259`) rejects `..` substrings and leading `/`, and that is the entire traversal defense on `/api/file-content` and `/api/code-nav/file`. No realpath containment anywhere on the review side (annotate's `isWithinAllowedRoots` is also lexical on the candidate). `/api/image` serves any absolute path behind an extension allowlist and is the anti-pattern. A new file endpoint should do better than all of these, and `/api/code-nav/file`'s missing size cap should be fixed alongside.
- Memory. The active patch is one in-memory string; file-content responses are up to 2x5 MiB strings per request; `useCodeNavPreview` caches 10 whole files client-side. Budgets exist and should be reused, not reinvented.
- Bundles. Single-file HTML, no CDN. Everything needed (grammars, worker code) is already inlined.
- Dock. Dockview loses layout on unmount (load-bearing, documented in `adr/research/SPIKE-guide-takeover-layout-20260702-194831.md`); new surfaces should be new panel types or CSS-hidden branches, never dock remounts. Adding a panel type is a constant + component + `dockApi.addPanel` (`packages/review-editor/dock/reviewPanelTypes.ts:8-17`).
- Pierre identity hazard. Pierre 1.3.2 compares nothing but `cacheKey` (defaults to file name), so every diff or file object must mint a content-hash key (`DiffViewer.tsx:349-370`). Any new full-file surface must do the same.

Pre-existing gaps worth fixing regardless of this feature: the lexical containment checks (symlink escape), the missing cap on `/api/code-nav/file`, the uncapped HTML branch of `/api/doc`, the empty-snippet behavior on out-of-hunk annotations, and the unvirtualized peek preview.

---

## 2. Design space

### 2.1 Where does a full file open

Three candidate shapes:

1. New dock panel (like CODE_NAV, SEMANTIC_DIFF). A `REVIEW_FILE` panel rendered beside or below the diff. Pros: side-by-side with the diff you are reviewing (the main reason to open a file mid-review is to check something against the diff), existing infrastructure, panel retargeting precedent (`REVIEW_DIFF_PANEL_ID` is one reused panel retargeted via `updateParameters`), no modality. Cons: dock real estate is contested on small screens.
2. Modal overlay (port `CodeFilePopout`). Pros: exists, minimal work. Cons: modal blocks exactly the cross-referencing workflow that motivates the feature; the annotate popout is a "glance at a reference" tool, not a "read this file while reviewing that diff" tool.
3. In-place expansion (grow `expandUnchanged` into "show any file inline in the all-files scroll"). Cons: conflates "the changeset" with "the repo"; the all-files surface is deliberately a view of the patch, and injecting unchanged files into it muddies staleness, search, viewed-state, and the guide capture. Rejected.

The dock panel wins. It matches how the code-nav peek already behaves and it composes: the peek panel can gain an "open file" action that opens the file panel at the selected line.

### 2.2 Rendering and highlighting at scale

Use Pierre, full stop. Two viable sub-options:

- Pierre `<File>` like `CodeFilePopout` does, or
- a one-item `CodeView` with a `CodeViewFileItem`.

Either gets virtualization, the worker pool, line annotations, line selection, and token events. The guide-reuse spike's verdict on `AllFilesCodeView` applies here too: the multi-file machinery is overhead for a single file; a purpose-built `FileViewer` component modeled on `DiffViewer`'s shape (prop-driven, own scroll container, own `ToolbarHost`) is the right unit. Highlighting is windowed by virtualization, so full-file cost is bounded by the viewport, not the file. No SSR needed on the review side (the annotate server prerenders because the popout wants instant paint without a worker pool; review already has the pool).

### 2.3 Annotating full-file views

The question with real product weight. Options:

1. Read-only file view. Cheapest, but breaks the product's core promise: everything you can see, you can annotate. A reviewer who spots a problem in an unchanged file would have to paste paths into the global comment box.
2. Annotations join review feedback as ordinary `CodeAnnotation`s. The type already supports it (file+line+side, no hunk coupling). Two integration jobs: snippet extraction must fall back from the patch to the fetched file content (a small utility beside `extractLinesFromPatch`), and export should label these so the agent knows the context is not in the diff. Precedents exist on both sides: plan diff annotations carry `[In diff content]` labels, and annotate exports a `# Code File Feedback` section with the code fenced. Fencing the selected lines is important here because the agent cannot see the annotated lines in the diff.
3. A separate feedback channel. Rejected: review has exactly one feedback submission, and splitting it would complicate the agent contract for no benefit.

Option 2 is clearly right. One consequence to accept: share links already refuse sessions with code annotations on the annotate side (`canShareCurrentSession`, `packages/editor/App.tsx:1815`); review share semantics for out-of-diff annotations should follow whatever rule review share links already apply to code annotations generally.

Content side: a full file view should show the working tree (the "new" side). That matches `/api/code-nav/file` semantics and what a reviewer means by "open the file". Old-side viewing (the file as of base) is a real want for deleted code but is deferred; the annotation `side` field keeps the door open.

Staleness: the diff has a snapshot guard; a working-tree file view deliberately does not (it shows the live file, same as code-nav preview today). If the agent edits files mid-review, the file panel can drift ahead of the diff. The existing "Diff out of date, Refresh" notice already covers the session-level story; per-panel staleness indication is a polish item, not a blocker.

### 2.4 Tree navigation

Changed-files tree stays the default; the repo tree is an opt-in mode, not a replacement. Options for placement:

1. A fourth segment in `PanelViewToggle` (`Tree | Git status | Commits | Repo`).
2. A sub-toggle inside the Tree view (`Changed | All files`).

Either works; the sub-toggle keeps the panel toggle's existing session-default/memo logic untouched (that logic is subtle and documented at length in CLAUDE.md), so it is the lower-risk shape.

The server side should reuse the annotate walk machinery rather than invent a second walker: same budget (`PLANNOTATOR_FILE_BROWSER_MAX_FILES`, default 5000), same exclusions, same `truncated` flag, same git-status seeding so changed files never fall past the cap, same 30s warm cache. The one design difference from annotate's browser: filter to code files plus annotatable docs, and badge changed files. Upfront-walk-with-budget beats lazy per-directory loading for this scale (5000 entries is a small JSON payload, and the warm cache means the walk is usually already done); lazy loading becomes worth revisiting only if the budget itself proves too small in practice, which the `truncated` flag will tell us.

Search over the repo tree: client-side substring/fuzzy filter over the returned list. No new endpoint.

### 2.5 Definition and reference navigation, three tiers

Tier A: ripgrep (exists). Cheap, no install, works everywhere rg does. Wrong in the specific ways listed in 1.3. Worth keeping as the floor and improving at the margins: add the missing TS method/property patterns, distinguish definitions from references visually in the peek, and give the peek an "open file" action. These are small fixes with outsized UX return.

Tier B: tree-sitter via the CallDiff runtime (recommended upgrade). The shipped `extract.js` gives real parsed function definitions with line spans, per file. The shape that fits: keep ripgrep as the candidate generator, then, when the Call Flow runtime and the relevant language pack are installed, run `extractFunctions` over the top N candidate definition files and check whether the symbol matches a real definition span. Promote confirmed definitions, demote regex-classified "definitions" that no parse confirms. This uses the runtime as a verifier, not a new pipeline, so it needs no CallDiff changes, and it fits the existing invocation model (short-lived Node 22 child, stdin JSON, output cap). The `CodeNavResponse.backend` field and the dead `side/line/charStart` inputs mean the API shape does not change. Costs to be honest about: Node 22 must be present, the runtime is opt-in behind Call Flow's consent (a nav feature piggybacking on that consent needs a decision, see open questions), `extractFunctions` covers functions (not types, constants, or classes uniformly across packs), and a child process per resolution adds latency (mitigable by batching candidates into one invocation and caching per file content hash).

Tier C: LSP. Rejected for now, with reasons rather than reflexes: a real language server wants project configuration, per-language install, warmup measured in seconds to minutes, and hundreds of MB resident, all managed per session in a server whose model is an ephemeral random-port process per review. tsserver alone would dominate the footprint of everything else Plannotator runs. The session model (one reviewer, short-lived, agent in the loop) does not amortize an index. If a future host (the VS Code extension) can lend its own language services, that arrives through a host seam, not through Plannotator running servers.

Tier D (escape hatch, cheap): "Open in editor at line" spawning `code --goto path:line`, precedent in `ide.ts`. For the reviewer who wants real IDE navigation, this is one small endpoint pair and one context-menu item, and it honestly outperforms anything Plannotator will build in-browser.

### 2.6 Prior art, and what fits

- GitHub blob view + symbols panel: tree-sitter tags drive a per-file symbol list and fuzzy jump; search-based references. Maps exactly onto tier B's assets: `extractFunctions` on the open file can populate a symbols dropdown in the file panel header for in-file navigation, which is cheap and high-value.
- Sourcegraph: the canonical two-tier design, "search-based code intelligence" (regex heuristics, confidence-labeled) upgraded by precise indexes where available. Validates the ripgrep-floor/tree-sitter-upgrade strategy and the practice of labeling result confidence in the UI instead of pretending.
- VS Code peek definition: inline, stays in context, Escape closes. The existing CODE_NAV panel is already this shape; the missing pieces are result quality, visual definition/reference separation, and the ability to leave the peek into a full file.

What does not fit: anything requiring a persistent index or daemon. The review server is ephemeral and single-user; per-request resolution with warm caches is the right model, and it is the model everything else in the codebase already follows.

### 2.7 Scale budgets

Named numbers, each with a source:

- Full-file serve cap: 5 MiB, aligning with `MAX_REVIEW_FILE_CONTENT_BYTES` (review-core.ts:21) so a file that can be context-expanded can also be opened, and vice versa. Oversize gets the `OversizedFileNotice` treatment, not a silent null. (The annotate side's 2 MB cap stays its own; they serve different products.)
- Repo tree: 5000 files (`PLANNOTATOR_FILE_BROWSER_MAX_FILES`), truncated flag surfaced in the UI, git-status seeding first. Source: existing budget, existing reasons (symlinks mean the budget, not the root, bounds the walk).
- Highlighting: worker pool `min(cores-1, 3)`, virtualized windows only; first paint is plain text (Pierre's existing behavior), target under 100ms to first content for a cached file. Source: workerPool.tsx profiling notes (over 2s main-thread tokenization is the disaster being avoided).
- code-nav: keep 50 results / 500 parse cap / 5s timeout / 1 MiB per-file rg cap. Tier B verification bounded to the top 5 candidate definition files per query, one child invocation, cached by file content hash.
- Client file cache: cap the file panel's content cache at 10 files (matching `useCodeNavPreview`) with LRU eviction.

---

## 3. Recommendation

Build the full-file viewer as a dock panel on Pierre file items, reuse the annotate walk for an opt-in repo tree, keep ripgrep as the nav floor with a tree-sitter verifier when the Call Flow runtime is present, and route all new file serving through one hardened shared resolver.

Named seams:

Server (both runtimes, per the code-nav pattern):

- `packages/shared/repo-file.ts` (new, vendored): `resolveRepoFileRequest` validation + a `readRepoFile(cwd, relPath)` that does relative-only + `..` rejection + realpath containment against the resolved review cwd + the 5 MiB cap. This becomes the guard for the new endpoint and retrofits onto `/api/code-nav/file`.
- `GET /api/review-file?path=` in `packages/server/review.ts` and mirrored in `apps/pi-extension/server/serverReview.ts`: returns `{ content, filepath, size, language? }` from the working tree. Same local-access gating as code-nav (workspace/gitContext/agentCwd, PR mode via `ensurePRLocalCwd`, GitButler committed views refused).
- `GET /api/repo-tree` in both runtimes: budgeted walk via the existing `resolve-file.ts` machinery, response shape borrowed from the annotate file browser (`nested tree + truncated`), changed-path list joined client-side.
- Tier B: extend `packages/shared/code-nav.ts` with an optional verifier stage that shells the CallDiff `extract.js` entry (runtime adapter already exists per server); `backend` reports `"search"` or `"search+ts"`.

Client (`packages/review-editor`):

- `FileViewer.tsx` (new): prop-driven like `DiffViewer`, renders one Pierre file item, own `ToolbarHost`, content-hash `cacheKey`, line annotations filtered from `state.allAnnotations` by path. Participates in the `isFocused` contract; the dock diff panel's focus derivation gains the same guard the guide spike prescribes so two surfaces never both claim a file.
- `REVIEW_FILE_PANEL_ID` + panel type in `reviewPanelTypes.ts`/`reviewPanelComponents.ts`; one reused panel retargeted via `updateParameters({ filePath, line? })`, matching the diff panel's model.
- Entry points, in value order: "Open file" on code-nav peek results (opens at the result line); an open-file affordance on file tree rows and the diff `FileHeader`; the repo tree mode (`Changed | All files` sub-toggle in the Tree panel); Cmd+click behavior unchanged (peek first) in v1.
- Snippet extraction fallback: `extractLinesFromContent` used by `useAnnotationToolbar`/Ask AI when `extractLinesFromPatch` comes back empty, so out-of-hunk and out-of-diff annotations carry real code.
- Export: out-of-diff annotations labeled in feedback (label plus fenced selected lines), reusing the `exportCodeFileAnnotations` shape.

Reused wholesale: Pierre + worker pool, `CodeAnnotation` + `ToolbarHost` + draft persistence, the walk/budget/warm-cache machinery, the code-nav endpoints and panel, dockview, `vendor.sh`.

Explicitly new: the shared file resolver, the two endpoint pairs, `FileViewer`, the tree mode, the tier B verifier stage, the export label.

---

## 4. Phasing

Each phase ships alone and is useful alone.

Phase 1: open the file (the 80% of the value).
- `packages/shared/repo-file.ts` + `GET /api/review-file` (both runtimes).
- `FileViewer` + `REVIEW_FILE` panel.
- "Open file" from the code-nav peek and from file tree rows / diff header.
- Snippet-extraction fallback and the feedback label, so annotating the file view round-trips correctly from day one.
- Retrofit: size cap + realpath containment on `/api/code-nav/file`.

Phase 2: browse the repo.
- `GET /api/repo-tree` (both runtimes) on the existing walk.
- `Changed | All files` sub-toggle in the Tree panel, client-side filter box, truncated banner.

Phase 3: navigation quality.
- Ripgrep pattern fixes (TS methods/properties), definition/reference visual separation in the peek, peek preview rendered via a Pierre file item instead of the unvirtualized table.
- Tier B verifier behind the Call Flow runtime; confidence surfaced in the peek ("parsed" vs "text match").
- In-file symbols dropdown in the `FileViewer` header via `extractFunctions` (runtime present) or ripgrep-on-one-file (fallback).

Phase 4 (optional, cheap, could also ride with phase 1): "Open in editor at line" via `code --goto`, following `ide.ts` conventions.

---

## 5. Out of scope

- LSP servers, in any form.
- Editing files from the review UI (Edit Mode's allowlist stays markdown-only).
- Old-side (base ref) full-file viewing; the `side` field reserves the space.
- Whole-repo text search (a different feature; the repo tree filter is name-only).
- Share-link support for out-of-diff annotations beyond whatever code annotations already do.
- Workspace (non-VCS multi-repo) and GitButler-committed-view support beyond code-nav's existing refusals; the file panel inherits code-nav's gates.
- Any change to the guide capture: guides describe the launch-time diff, and full-file panels never feed them.

---

## 6. Risks

- Focus race: a `FileViewer` and a hidden dock diff panel both claiming `isFocused` for one path corrupts draft handoff (last-write-wins on the module-level maps). Known, small, and the guide spike already prescribes the fix; it must land with phase 1, not after.
- Pierre `cacheKey` identity: forgetting the content-hash key on file items produces stale renders that look like heisenbugs. Copy the `DiffViewer` pattern verbatim.
- Feedback ambiguity: an agent receiving line comments on files not in the diff may look for them in the patch and get confused. The label + fenced code is the mitigation; wording should be tested against the actual review skills' prompts.
- Working-tree drift: the file panel shows live files with no snapshot guard, by design; a mid-review agent edit can make an annotation's line numbers stale before submission. Accepted for v1 (same exposure as code-nav preview today); the annotation's fenced snippet preserves intent even when lines drift.
- Scope gravity: this feature sits on a slippery slope toward "web IDE". The recommendation deliberately keeps navigation request/response-shaped and index-free; holding that line is a product decision as much as a technical one.
- Two-runtime drift: three new endpoint pairs is three chances for Bun/Pi divergence. Keeping every decision in the shared vendored modules (validation, resolution, caps) and the handlers thin is the only defense that has worked so far.

---

## 7. Open questions for the maintainer

1. Feedback shape for out-of-diff annotations: one review feedback stream with a per-annotation label like `[Outside diff] src/foo.ts lines 40-52` plus fenced code (recommended), or a separate trailing section like annotate's `# Code File Feedback`? Affects agent prompt compatibility, so worth deciding against the shipped review skills.
2. Panel model: one reused File panel retargeted per file (matches the diff panel, recommended), or tab-per-file (more editor-like, more dock clutter)? The retargeted model can add "pin as new tab" later; tab-per-file cannot easily walk back.
3. Repo tree placement: sub-toggle inside the Tree panel (recommended, avoids touching the PanelViewToggle persistence logic) or a fourth top-level segment?
4. Tier B consent: is using the already-installed Call Flow runtime for nav verification covered by the existing Call Flow consent (recommended: yes, it is the same runtime doing less work), or does nav need its own toggle? And should nav ever trigger a language-pack install, or only use packs already present (recommended: only already-present)?
5. Cmd+click destination: keep peek-first in v1 (recommended), or jump straight to the file panel when exactly one confirmed definition exists? The latter is the editor-familiar behavior but needs tier B confidence to not be wrong routinely.
6. Cap alignment: is 5 MiB (matching file-content) the right serve cap for the file panel, and is retrofitting that cap onto `/api/code-nav/file` an acceptable behavior change?
7. Does phase 4 ("Open in editor at line") ship with phase 1? It is a one-day escape hatch that reduces pressure on in-browser nav quality.
8. Should doc files (.md) in the repo tree open in the file panel as code, or route through the linked-doc overlay the way plan mode does? (Recommended for v1: everything opens as code in the file panel; doc-rendering integration is a follow-up.)
