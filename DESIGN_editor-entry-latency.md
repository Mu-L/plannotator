# Design: markdown editor entry latency (issue #1401)

Status: investigation complete, fix plan proposed, no implementation. Measured 2026-08-27 on the current main checkout (`b381ecbe`, version 0.27.8). All file references are to the local checkouts named in section 2. No tracked file in any repo was modified; the only artifact is this document plus scratch tooling under the session scratchpad.

The ask (issue #1401, "perf(ui): reduce CodeMirror first-edit measurement cost"): the Workspaces host measured 1,126 ms click-to-second-paint for a 475 byte document and 1,449 ms for a 282 KB document at 4x CPU throttling on the exact `@plannotator/ui` 0.32.0 / `@plannotator/markdown-editor` 0.4.0 / `@plannotator/atomic-editor` 0.8.0 chain, attributed the cost to CodeMirror's first geometry and selection measurement, and asked for a bounded package experiment (defer non-essential decorations until after the first editable paint).

The short version: reproduced in Plannotator itself with the same package versions, entry is 123 ms for the small document and 519 ms for a 283 KB document at 4x. The document-size-dependent cost is not CodeMirror's measurement. It is a synchronous whole-document Lezer parse that `@plannotator/atomic-editor` forces on mount (`ensureSyntaxTree(state, state.doc.length, 200)` inside three decoration builders), followed by three whole-tree walks, all inside the React commit that answers the click. CodeMirror's own first measure is real but roughly constant (90 to 110 ms at 4x regardless of document size), and most of it is a forced layout charged to the DOM selection read, not to decorations. The host's proposed experiment (deferring decoration extensions) targets a cost that measures at 12 to 23 ms at 4x and would introduce a second measure plus a visible flash; it should not be done. The roughly 1,000 ms that separates the host's small-document number from Plannotator's is on the host side of the seam.

---

## 1. Headline

| Layer | Finding |
|---|---|
| Root cause of the size-dependent cost | `@plannotator/atomic-editor` forces a full-document syntax tree at `EditorState.create` time. `tableField.create` runs first in extension order and pays it: `ensureSyntaxTree(state, state.doc.length, 200)` at `src/table-widget.ts:1405-1406`. Same call in `src/image-blocks.ts:135-136` and `src/inline-preview.ts:368-369`. CodeMirror by itself parses only the first 3,000 characters in a 20 ms budget on state creation (`@codemirror/language` `LanguageState.init`, `dist/index.js:541-546`). |
| Measured share | 283 KB at 4x: `ensureSyntaxTree` 126 ms inclusive plus 24 ms `buildImageBlocks` plus 43 ms `buildInlineDecorations` out of a 457 ms click task. 52 KB at 4x: 45 ms plus 13 ms plus 17 ms out of 209 ms. |
| Host attribution | Partially confirmed. The CodeMirror measure task exists (93 ms at 4x for 52 KB, 108 ms for 283 KB) and its biggest JS cost is `DOMSelectionState.eq` under `readSelectionRange`, which is a forced layout of the freshly inserted editor DOM. But it is the second largest task, it does not scale with document size, and it is not caused by decorations. |
| Host-side residue | Plannotator's small-document entry at 4x is 123 ms with the same packages. The host's is 1,126 ms. The difference is not in the package chain. |
| Recommended first PR | `@plannotator/atomic-editor`: bound the mount-time parse to the initial viewport window and let the already-present `treeProgressPlugin` grow it in idle time. No public API change, decoration-only, byte fidelity untouched. Expected: about 30 percent off heavy-document 4x second paint, zero change on the small control. |

## 2. Supply chain and versions

| Package | Declared by `packages/ui` | Installed in Plannotator | Local clone | Notes |
|---|---|---|---|---|
| `@plannotator/atomic-editor` | `^0.8.0` (`packages/ui/package.json:76`) | 0.8.0 (`node_modules/.bun/@plannotator+atomic-editor@0.8.0+f315964daf0509ab`) | `/Users/ramos/oss/atomic-editor` at 0.8.0, one commit past the tag (`18df720 chore: refresh audited development lockfile`), clean tree. `dist/AtomicCodeMirrorEditor.js` byte-identical to the installed copy. | Declares every `@codemirror/*` package as a peer. |
| `@plannotator/markdown-editor` | `^0.4.0` (`packages/ui/package.json:78`) | 0.4.0 (`node_modules/.bun/@plannotator+markdown-editor@0.4.0+d518ce27ce3e5b56`) | `/Users/ramos/oss/markdown-editor` at 0.4.0 (`fc5b8f0`), clean tree. | Thin wrapper; see section 4.3. |
| `@codemirror/view` | `^6.43.0` | 6.43.1 | n/a | |
| `@codemirror/state` | `^6.6.0` | 6.6.0 | n/a | |
| `@codemirror/language` | `^6.12.3` | 6.12.3 | n/a | |
| `@codemirror/lang-markdown` | `^6.5.0` | 6.5.0 | n/a | |
| `@lezer/markdown` | (transitive) | 1.6.4 | n/a | |

Plannotator's line numbers cited from `packages/ui/components/MarkdownEditor.tsx` (`:93-102`) and `@plannotator/markdown-editor` match the host's citation (`MarkdownEditor.js:18-19` in the built dist corresponds to `src/MarkdownEditor.tsx:70-86`), and `AtomicCodeMirrorEditor.tsx:243-321` is the same effect the host cited. The host's numbers were taken against `@plannotator/ui` 0.32.0; Plannotator's workspace `packages/ui` is at 0.31.0, but the editor seam (`MarkdownEditor.tsx`) is the same code.

## 3. Method

Harness: `/private/tmp/claude-501/-Users-ramos-plannotator-plannotator/34d56d5a-33a8-4878-92b2-3f4318214ae2/scratchpad/issue-1401/` (`bench.mjs`, `attrib.mjs`, `make-fixtures.mjs`, `run-all.sh`, results and traces beside them). It:

1. Builds the hook app (`bun run build:review && bun run build:hook`) and starts `bun apps/hook/server/index.ts annotate <fixture>` with `PLANNOTATOR_DATA_DIR` sandboxed under the scratchpad, `PLANNOTATOR_BROWSER=/usr/bin/true` (a slash-bearing path is executed directly by `openBrowser`, `packages/server/browser.ts:216-217`, so it is a real no-op; the documented sentinels `true`/`none` fall through to the system browser, `browser.ts:194-199`), `PLANNOTATOR_AI=disabled`, `PLANNOTATOR_REMOTE=0`, and a fixed `PLANNOTATOR_PORT`; polls `/api/plan`.
2. Drives Chrome for Testing (playwright-core 1.62.1, `chromium-1234`, headless, 1440 by 1000) with a fresh browser context per run.
3. Over CDP: `Emulation.setCPUThrottlingRate` 1 or 4, `Profiler` at 0.5 ms sampling, `Tracing` with `devtools.timeline`, `disabled-by-default-devtools.timeline`, `blink.user_timing`, `v8.execute`, `toplevel`.
4. Clicks the header Edit button (`packages/editor/App.tsx:5556-5577`, the `aria-pressed` button whose label is `Edit`) with a real mouse event. A capture-phase listener stamps `performance.mark('entry-click')`; a `MutationObserver` stamps `entry-editable` when `.cm-content[contenteditable=true]` appears and `entry-second-paint` two animation frames later. These are the same three points the host's page-side collector used.
5. Reports `RunTask` events longer than 50 ms in the click to second-paint window with a self-time breakdown (style = `UpdateLayoutTree`, layout = `Layout`, script = `FunctionCall`/`EventDispatch`/`FireAnimationFrame`/`TimerFire`), and bottom-up JS attribution from the CDP profile restricted to the same window.

Five runs per configuration on the shipped (minified) build for timings; three runs per configuration on an unminified build (`vite build --minify false` into the scratchpad, swapped into `apps/hook/dist/index.html` for those runs only and restored afterwards, verified byte-identical) for function-level attribution. Unminified timings were within 3 to 7 percent of minified.

Fixtures (deterministic, `make-fixtures.mjs`): `tiny.md` 441 bytes (headings, bold, list, task, quote, fence); `heavy.md` 52,609 bytes and `xheavy.md` 283,003 bytes, generated from the same template: frontmatter, 29 or 156 sections each with h2/h3, paragraphs with inline marks and links, bullet and task and nested lists, ordered list, blockquote, a TypeScript fence, a 4 row pipe table, a display-math block and inline math, an image, and a horizontal rule. `xheavy` matches the host's 282,692 byte fixture size.

Plannotator's annotate session passes no consumer `extensions` to `MarkdownEditor` (`packages/editor/App.tsx:5639-5646`), so this measures the built-in extension set only. The host additionally appends its collaboration binding and helpers at `AtomicCodeMirrorEditor.tsx:318`.

## 4. Measurements

### 4.1 Entry times, Plannotator, shipped build (medians of 5)

| Document | Bytes | CPU | Click to editable | Click to second paint | Long tasks (>50 ms) and attribution |
|---|---:|---:|---:|---:|---|
| tiny | 441 | 1x | 19.6 ms | 35.1 ms | none (whole entry is one 36 ms task) |
| tiny | 441 | 4x | 84.5 ms | 123.3 ms | 1: click task 95 ms (script 60, style 12, layout 7) |
| heavy | 52,609 | 1x | 44.2 ms | 73.5 ms | none (click task 45 ms, measure task 28 ms) |
| heavy | 52,609 | 4x | 190.6 ms | 288.2 ms | 2: click task 209 ms (script 141, style 16, layout 10); measure task 93 ms (layout 27, style 10, script 30) |
| xheavy | 283,003 | 1x | 92.1 ms | 127.9 ms | 1: click task 99 ms (script 72, style 5, layout 2) |
| xheavy | 283,003 | 4x | 404.2 ms | 518.5 ms | 2: click task 457 ms (script 328, style 21, layout 9); measure task 108 ms (layout 27, style 20, script 36) |

Run to run spread was under 5 percent in every configuration (for example heavy 4x second paint: 281, 284, 288, 292, 301).

Task shape is the same in every configuration: one task for the click (React render, Viewer unmount, `MarkdownEditor` mount effect, `EditorState.create`, `EditorView` construction), then CodeMirror's `requestAnimationFrame` measure task, then small follow-ups (`document.fonts.ready` re-measure, the tree-progress idle tick, a Plannotator draft save). "Click to editable" lands at the end of the first task; "second paint" lands after the measure task.

### 4.2 DOM shape

| Document | Live elements before (Viewer) | Live elements after | Elements inside `.cm-editor` | `.cm-line` rendered |
|---|---:|---:|---:|---:|
| tiny | 282 | 255 | 147 | 21 |
| heavy | 8,271 | 621 | 399 | 45 |
| xheavy | 43,450 | 1,129 | 399 | 45 |

CodeMirror renders a bounded viewport (about 1,000 px of margin above and below the visible area, `VP.Margin` in `@codemirror/view/dist/index.js:6389-6395`), so the editor DOM is the same size for the 52 KB and 283 KB documents. That is why the measure task does not scale with the document. The Viewer it replaces does scale (43 k elements for 283 KB), and its unmount is visible in the profile (section 4.3).

### 4.3 JS attribution at 4x (unminified build, median run, inclusive ms in the entry window)

| Cost center | tiny (130 ms window) | heavy (312 ms) | xheavy (533 ms) | Where |
|---|---:|---:|---:|---|
| React sync work for the click (`performWorkOnRoot`) | 90 | 203 | 392 | everything below except the measure task runs inside this |
| `EditorState.create` | 25 | 93 | 193 | `AtomicCodeMirrorEditor.tsx:249-320` |
| of which `buildTableWidgets` (`tableField.create`) | 1.8 | 51 | 139 | `table-widget.ts:1397-1440`, field at `:1517-1518` |
| of which `ensureSyntaxTree(doc.length, 200)` under it | 0.9 | 45 | 126 | `table-widget.ts:1405-1406` |
| of which `buildImageBlocks` (`imageBlocksField.create`) | n/a | 13 | 24 | `image-blocks.ts:126-171` (parse already done; this is the walk) |
| of which `LanguageState.init` (CodeMirror's own bounded parse) | 17 | 23 | 23 | `@codemirror/language/dist/index.js:541-546` |
| `EditorView` constructor | 47 | 74 | 116 | `AtomicCodeMirrorEditor.tsx:247` |
| of which `buildInlineDecorations` (ViewPlugin constructor) | 2.3 | 17 | 43 | `inline-preview.ts:337-683`, constructed at `:807-809` |
| of which `DocView` initial render (`updateInner`) | 10 | 11 | 12 | `@codemirror/view/dist/index.js:2879-2910` |
| of which `ViewState` (height map from `stateDeco`) | 4 | 10 | 18 | `dist/index.js:6149-6206` |
| Viewer unmount (`removeChild` under `commitDeletionEffectsOnFiber`) | small | 9 | 44 (+9 `detachDeletedInstance`) | `packages/editor/App.tsx:5647` Viewer branch |
| Cookie reads during App render (`getItem` via `isObsidianConfigured`, `getBearSettings`, `isOctarineConfigured`) | 6 | 11 | 6 | `packages/ui/utils/storage.ts:24-30`, called from `App` render |
| CodeMirror measure task (`EditorView.measure`) | 12 | 69 | 86 | `dist/index.js:8087-8180` |
| of which `readSelectionRange` -> `DOMSelectionState.eq` | 4 | 37 | 40 | `dist/index.js:7208-7230`, `:659-700`; a forced layout of the new editor DOM charged to the selection getter |
| of which `measureTextSize`, `clientRectsFor` | 0.5 | 4 | 6 | `dist/index.js:3324` |
| of which height map `updateHeight` | small | small | 19 | `dist/index.js:6339-6360` |

Reading the table: at 283 KB and 4x, 150 ms of the 457 ms click task is Lezer parsing (`ensureSyntaxTree` 126 plus CodeMirror's own `init` 23), a further 67 ms is the three whole-tree walks (`buildTableWidgets` minus its parse 13, `buildImageBlocks` 24, `buildInlineDecorations` 43 which includes 4 ms of parse), and 53 ms is React tearing down the 43 k element Viewer. The measure task adds 86 to 108 ms after that, of which roughly half is the forced layout on the first selection read and a quarter is real `Layout`. Extension and state plumbing that is not parse or decoration walk (`cm-state-create` bucket) is 12 to 23 ms in every configuration.

Trace-level style time (`UpdateLayoutTree` self) totals 13 ms (tiny), 25 ms (heavy), 41 ms (xheavy) at 4x across the whole window, in 4 to 5 recalcs per task. No `:has()` or descendant-heavy selectors exist in the 47 KB `inline-preview.css` (151 rules, all class-scoped under `.atomic-cm-editor`); the host's "style time 771 to 984 ms" is not reproduced here and points at the host page, not the editor stylesheet.

### 4.4 Comparison with the host's numbers

| Document | CPU | Host (Workspaces) second paint | Plannotator second paint | Delta |
|---|---:|---:|---:|---:|
| 475 / 441 bytes | 1x | 471 ms | 35 ms | 436 ms |
| 475 / 441 bytes | 4x | 1,127 ms | 123 ms | 1,004 ms |
| 282,692 / 283,003 bytes | 1x | 533 ms | 128 ms | 405 ms |
| 282,692 / 283,003 bytes | 4x | 1,449 ms | 519 ms | 930 ms |

The host's size-dependent increment (heavy minus small) is 322 ms at 4x; Plannotator's is 395 ms. Those agree within the difference in fixture content, so the document-scaling cost is the package's and is characterized above. The roughly 1,000 ms that the host sees on the small document is not in the package chain: the host's own timeline shows the read tree still mounted 322 to 403 ms after the click while "the lazy editor route resolves" (finding, "What mounts"), and the collaboration binding must be ready before `MarkdownEditorPane` mounts (`CoEditorPane.tsx:891`). Plannotator has neither: the editor code is in the single-file bundle and there is no binding.

## 5. Code trace: what runs synchronously on Edit

### 5.1 Plannotator (`packages/editor`, `packages/ui`)

1. Click on the header Edit button (`packages/editor/App.tsx:5556-5577`) -> `handleEditExitClick` (`:2525-2533`) -> `handleEditToggle` (`:2424-2452`). Synchronous work before the state change: CRLF normalization of `displayedMarkdown` (string scan, `:2430`), baseline refs, `setEditorDirty`, `setEditorDiffersFromBaseline`, then `setIsEditingMarkdown(true)` (`:2451`). Nothing heavy.
2. React re-renders the whole `App` function component (5,700 lines, dozens of `useMemo`/`useCallback` with `isEditingMarkdown` in their deps). During this render, `isObsidianConfigured()`, `getBearSettings()`, `isOctarineConfigured()` are called and each runs a regex over `document.cookie` (`packages/ui/utils/storage.ts:24-30`): 6 to 11 ms at 4x per entry, the only host-layer cost worth a line here.
3. Commit swaps the `Viewer` branch for the `MarkdownEditor` branch (`App.tsx:5638-5647`). The Viewer unmount is a synchronous DOM deletion proportional to the rendered document (43 k elements at 283 KB).
4. `MarkdownEditor` (`packages/ui/components/MarkdownEditor.tsx:93-102`) reads the theme and renders the packaged editor. No effects of its own.
5. Because the click is a discrete event, React flushes passive effects synchronously at the end of the commit (`flushPassiveEffects` under `commitRoot` in the profile), so the editor's mount effect runs inside the same task as the click. There is no yield between "Viewer gone" and "editor built"; `viewerGone` and `editable` were stamped at the same millisecond in every run.

WebMCP (`useDocumentWebMcp`, `App.tsx:3861-3870`) and the embed picker seam (`packages/ui/components/MarkdownEditor/embedPicker.ts`) do not participate: the annotate session passes no `extensions`, and no WebMCP call fires on entry. Neither shows in the profile.

### 5.2 `@plannotator/markdown-editor` (`/Users/ramos/oss/markdown-editor`)

`MarkdownEditor` (`src/MarkdownEditor.tsx:56-87`) wraps `AtomicCodeMirrorEditor` in `MarkdownSurface` (`src/MarkdownSurface.tsx:14-45`, one `useMemo` for the max-width style, two divs). `codeLanguages` defaults to `DEFAULT_CODE_LANGUAGES` (`src/code-languages.ts`), all `LanguageDescription.of({ load: () => import(...) })`, so fence grammars are lazy and cost nothing at mount. Stylesheets imported here (`markdown-editor.css` 2.3 KB, `themes/plannotator.css` 3.7 KB, atomic `inline-preview.css` 47 KB) are already in the page before the click. Nothing in this layer is measurable.

### 5.3 `@plannotator/atomic-editor` (`/Users/ramos/oss/atomic-editor`)

The mount effect at `src/AtomicCodeMirrorEditor.tsx:243-352` builds one `EditorState` and one `EditorView` synchronously (`:247-321`). In `EditorState.create` order:

1. `history()`, `drawSelection()`, `dropCursor()`, `rectangularSelection()`, `highlightActiveLine()`, `closeBrackets()`, `search()`, keymaps (`:252-299`): facet plumbing only, a few ms at 4x total.
2. `markdown({ base: markdownLanguage, codeLanguages, extensions: [frontmatter] })` (`:281-285`): `LanguageState.init` parses at most 3,000 characters within 20 ms (`@codemirror/language/dist/index.js:541-546`); 17 to 23 ms at 4x in every configuration. The rest of the document is meant to be parsed by CodeMirror's idle `parseWorker` (`dist/index.js:573-640`) in 100 ms slices.
3. `tables()` (`:300-302`) registers `tableField` (`src/table-widget.ts:1517-1535`). Its `create` calls `buildTableWidgets` (`:1397-1440`), which begins with `ensureSyntaxTree(state, state.doc.length, 200)` (`:1405-1406`). This is the synchronous whole-document parse: 45 ms at 52 KB, 126 ms at 283 KB (4x). It then walks the entire tree (`tree.iterate`, `:1409`) and, for every table, `parseTable` (cell collection) to build a block widget per table.
4. `frontmatterProperties()` (`:303`): `syntaxTree(state).topNode.getChild('Frontmatter')` (`src/frontmatter-properties.ts:130`), cheap.
5. `imageBlocks()` (`:304`): `imageBlocksField.create` -> `buildImageBlocks` (`src/image-blocks.ts:126-171`) calls the same `ensureSyntaxTree` (`:135-136`, now a no-op because the tree is complete) and walks the whole tree again with a parent chain check per `Image` node (`:143-146`): 13 to 24 ms at 4x.
6. `inlinePreview()` (`:305-307`) registers the `previewFrozenField`, the `inlinePreviewPlugin` ViewPlugin, `freezeMousePlugin`, `treeProgressPlugin`, a click handler, and an Enter keymap (`src/inline-preview.ts:970-984`).
7. `EditorView` construction (`@codemirror/view/dist/index.js:7827-7886`): `ViewState` builds the height map from the static decorations (the table and image block widgets count here, `:6198-6206`), then instantiates every ViewPlugin. `inlinePreviewPlugin`'s constructor runs `buildInlineDecorations(view)` (`inline-preview.ts:807-809`), which calls `ensureSyntaxTree` a third time (`:368-369`, again a no-op) and walks the whole tree building line classes, mark decorations, and replace decorations for the entire document (`:394-656`): 17 ms at 52 KB, 43 ms at 283 KB (4x). The design comment at `:351-367` is explicit that this is a deliberate whole-document walk chosen to avoid viewport-scoped rebuilds on iOS scroll. `treeProgressPlugin` (`src/tree-progress.ts:68-134`) also constructs and schedules an idle tick.
8. `DocView` renders the initial viewport (`dist/index.js:2879-2910`), `mountStyles` adopts the theme (`atomicEditorTheme`, `src/atomic-theme.ts:12`) and `atomicMarkdownSyntax` (`:208`, a viewport-scoped `highlightTree`, under 2 ms in every run), `updateAttrs` sets attributes, and `requestMeasure` schedules the rAF (`:7879`). `document.fonts.ready` schedules a second, cheaper measure (`:7880-7884`).

Then the measure task (`EditorView.measure`, `dist/index.js:8087-8180`): `ViewState.measure` reads `getBoundingClientRect`, scroll geometry, `measureVisibleLineHeights` (a `getClientRects` per rendered line, 45 lines) and `measureTextSize` (`:6339-6360`), updates the height map, and `docView.updateSelection(true)` reads the DOM selection (`readSelectionRange`, `:7208-7230`). That selection read is the first thing to touch layout after the editor DOM was inserted, so Chrome charges the full layout of the new subtree to it; it shows as `DOMSelectionState.eq` 37 to 40 ms at 4x. This is what the host saw as "native selection equality path 140 to 152 ms" and "`ViewState.measure` 136 to 146 ms". It is inherent to inserting a new editable subtree and does not depend on the decoration set.

No forced synchronous layout reads occur in any mount effect on the Plannotator or package side (the trace reports zero `Layout`/`UpdateLayoutTree` events with a script stack in the click task). The three `getBoundingClientRect` sites in the package (`inline-preview.ts:89`, `table-widget.ts:834`, `:1212`, `selection-toolbar.ts:175`) are all pointer-event driven, not mount driven. `edit-helpers.ts:77` (`state.doc.toString()` on Enter) is keystroke driven.

### 5.4 Is the Lezer parse incremental and viewport-bounded?

Incremental: yes (`ParseContext` keeps fragments and re-parses from the edit point). Viewport-bounded on mount: CodeMirror's own initialization is (3,000 chars, 20 ms), and its `parseWorker` continues in idle slices. `@plannotator/atomic-editor` overrides that policy at three sites with `ensureSyntaxTree(state, state.doc.length, 200)`, which temporarily sets the parse viewport to the whole document and works synchronously for up to 200 ms (`@codemirror/language/dist/index.js:196-206`). For documents that exceed the budget the package already has the recovery path: `treeProgressPlugin` (`src/tree-progress.ts`) keeps parsing in 30 ms idle ticks and dispatches `treeGrowthEffect` every 8 KB of growth, and all three builders rebuild on that effect (`table-widget.ts:1519-1523`, `image-blocks.ts:220-225`, `inline-preview.ts:826-857`). The 200 ms synchronous call is therefore not required for correctness; it exists to make the first paint complete rather than progressive.

## 6. The host's proposed experiment, evaluated

"Separate essential editing behavior from non-essential first-paint decorations and attach the deferred set after the first editable paint" would move `tables()`, `imageBlocks()`, `frontmatterProperties()` and `inlinePreview()` into a `view.dispatch({ effects: StateEffect.appendConfig.of(...) })` after the first frame.

Measured against the attribution above:

- The state and extension plumbing that deferral saves from the click task is 12 to 23 ms at 4x. The parse and the tree walks would still happen, just one frame later, and the `treeProgressPlugin` would still be needed.
- Appending the decoration fields adds block widgets (tables, images, properties) after the height map was measured, which changes line geometry and forces a second full measure loop, plus a second style recalc and layout on the editor subtree: at 4x that is another 90 to 110 ms task by the numbers in 4.1.
- The user would see raw `| a | b |` and `# ` syntax for one or two frames, then the preview. On a 4x device that flash is 100 to 200 ms long.
- Consumer extension order (`:318`) and the collaboration binding are unaffected in principle, but any consumer plugin that reads decorations at construction (Workspaces' helpers) would observe a different initial state.

Verdict: do not do it. It attacks the smallest component, adds a measure, and regresses visual stability. The host was right that "a CodeMirror reconfigure may cause another measure"; it does.

## 7. Fix plan, ranked

Savings are estimated from the 4x medians in section 4; "second paint" below means click to second paint.

### 7.1 Bound the mount-time parse in `@plannotator/atomic-editor` (recommended first)

Change: the three builders stop forcing `ensureSyntaxTree(state, state.doc.length, 200)`. At `StateField.create` time (tables, images) parse only an initial window, for example `Math.min(doc.length, 16_384)` characters with a 20 ms budget, which covers the first screenful generously (45 rendered lines were about 4 KB in these fixtures). In `inlinePreviewPlugin`'s constructor, which has the view, use `view.viewport.to` instead of `doc.length`. All later coverage comes from `treeProgressPlugin`, which already exists and already triggers rebuilds. Two supporting tweaks in the same PR: make the growth threshold adaptive (double it on each tick, or rebuild once at completion plus every N KB) so a 283 KB document does not pay 35 whole-tree rebuilds, and skip the redundant `ensureSyntaxTree` in `buildImageBlocks` and `buildInlineDecorations` when `syntaxTree(state).length >= upto` (the call is cheap but the intent should be explicit).

- Repo: `/Users/ramos/oss/atomic-editor`, `src/table-widget.ts:1405-1406`, `src/image-blocks.ts:135-136`, `src/inline-preview.ts:368-369`, `src/tree-progress.ts:30,36,109-120`.
- Public API: none. Decoration-only; document bytes never change, so the byte-fidelity contract and every editing command are untouched. Consumer extension order unchanged.
- Expected: heavy 4x second paint 288 -> about 215 ms (minus 45 parse, minus most of the 13 + 17 walks beyond the window); xheavy 4x 519 -> about 340 ms; tiny unchanged (its parse is already within the window). Editable time improves by the same amounts because everything sits in the click task.
- Risk to editing correctness: none for the text. Rendering risk: content beyond the initial window renders as raw markdown until the idle ticks catch up (tens of ms at 1x for 283 KB, a few hundred ms at 4x); a user who scrolls fast on a slow device can briefly see raw tables. This is exactly the behavior the package already exhibits for documents over the 200 ms budget, so the code paths are exercised today. The iOS momentum concern in `inline-preview.ts:351-358` is about scroll-driven rebuilds; idle-driven growth rebuilds already happen and are not scroll-anchored.
- Regression guard: (a) vitest (`src/__tests__/`, happy-dom) mounting a generated 300 KB document and asserting that `syntaxTree(state).length` right after mount is below the window plus slack, then after `await` of idle ticks equals `doc.length` and every table renders a widget; (b) a benchmark, below.

### 7.2 Pre-warm the editor state during idle (second PR, additive API)

Change: export a `prepareEditorState(markdownSource, options)` (or `createAtomicEditorState`) from `@plannotator/atomic-editor` that builds the same `EditorState` the mount effect builds, and accept an optional `initialState` prop on `AtomicCodeMirrorEditor` keyed by `documentId`. `@plannotator/markdown-editor` and `@plannotator/ui` pass it through (`MarkdownEditor` gains an optional `initialState` or a `useMarkdownEditorPrewarm(markdown, documentId)` hook that schedules the build in `requestIdleCallback`). Plannotator calls the hook once the plan is loaded and `canEditMarkdown` is true, so the click only pays `new EditorView({ state })`.

- Repos: atomic-editor (new export plus prop, `AtomicCodeMirrorEditor.tsx:247-320` split into a pure state builder), markdown-editor (prop passthrough), Plannotator `packages/ui/components/MarkdownEditor.tsx` (prop) and `packages/editor/App.tsx` (idle prewarm near `canEditMarkdown`, `:2090`).
- Public API: additive in all three packages; defaults reproduce today's behavior (the `@plannotator/ui` seam rule in `packages/ui/CLAUDE.md`).
- Expected: removes `EditorState.create` from the click task: tiny 4x 123 -> about 100 ms, heavy 288 -> about 200 ms (about 130 ms combined with 7.1), xheavy 519 -> about 330 ms (about 250 ms combined). The `EditorView` constructor (47 to 116 ms at 4x) and the measure task remain because both need the DOM.
- Risk: a stale state if the displayed markdown changes after prewarm (guard by comparing `state.doc.toString()` identity, or key on the same `documentId` string and drop on mismatch); memory for one extra state on large documents; the `extensions` capture-once contract must be honored by building the prewarmed state with the same array. Collaboration hosts must not prewarm with a binding that expects a live view; the hook should refuse when `extensions` is present unless the host opts in. Correctness of editing is unaffected because the state is the same object the effect would have created.

### 7.3 One shared block index instead of three whole-tree walks (later)

`buildTableWidgets`, `buildImageBlocks` and `buildInlineDecorations` each walk the full tree and each has its own rebuild policy. A single memoized index keyed on the tree object (tables, images, frontmatter, per-line block kinds) computed once per tree version and consumed by the three builders would remove 20 to 60 ms at 4x on large documents and shrink the rebuild storm from 7.1. Medium refactor in atomic-editor, no API change, needs the existing table and image tests plus a new "rebuild count per doc change" test. Do after 7.1 has landed and been measured.

### 7.4 Host layer, Plannotator (small, independent)

- Stop reading cookies during `App` render: `isObsidianConfigured()`, `getBearSettings()`, `isOctarineConfigured()` are called in the render body and each regex-scans `document.cookie` (`packages/ui/utils/storage.ts:24-30`). Read once into state (or `useMemo` on a settings version) and update through the existing settings handlers. 6 to 11 ms at 4x on every App render, not just this one. No API change. Guard: a unit test that mounts `App` and asserts `document.cookie` is read at most N times per render is brittle; a simpler guard is a `getItem` call counter around one `setIsEditingMarkdown` flip in an existing App test.
- Viewer unmount cost (44 ms at 4x for 283 KB) is inherent to swapping a fully rendered document for an editor. Not worth engineering around: React must delete the subtree, and keeping it mounted hidden doubles memory and is what the host's rejected experiment indirectly showed (the read tree removal is not the floor).

### 7.5 CodeMirror measure task

90 to 110 ms at 4x, constant in document size, about 40 ms of it the forced layout charged to the selection read, 27 ms real layout, 10 to 20 ms style recalc. Options are limited and low yield: `contain: layout style` on the `.pn-markdown-editor-card` would confine the style recalc and layout to the editor subtree (maybe 10 ms at 4x, zero risk, lands in markdown-editor CSS); the rAF measure and the `fonts.ready` re-measure cannot be skipped. Not recommended as a first move; measure after 7.1 and 7.2 to see if it still matters.

### 7.6 Not recommended

- Deferring decoration extensions via reconfigure (section 6).
- Yielding to the main thread between "Viewer unmounted" and "editor created": the two are one React commit (passive effects flush synchronously for a discrete event). Splitting them means a frame with neither surface, which is the visual regression the host already measured and rejected. 7.2 achieves the same goal (less work in the click task) without the blank frame.
- Viewport-scoped `buildInlineDecorations` with `visibleRanges`: the package moved away from that on purpose for iOS scroll anchoring (`inline-preview.ts:351-358`); 7.1 keeps whole-document decorations as the steady state and only bounds the first build.

## 8. Recommended first PR

`@plannotator/atomic-editor` 0.8.x: "bound the mount-time syntax tree to the initial window" (7.1), shipped with a repeatable benchmark:

1. `scripts/bench-editor-entry.mjs` in atomic-editor (next to `scripts/test-editor.mjs`, which already drives the demo page with Playwright): mount the demo with a 50 KB and a 280 KB generated fixture, record the same `entry-click` / `entry-editable` / `entry-second-paint` marks over CDP at 1x and 4x, seven fresh contexts each, print medians and long tasks. The scratch `bench.mjs` in this session's scratchpad is the working version of that script against Plannotator's annotate server and can be committed to Plannotator under `scripts/` as an untracked-until-reviewed tool for the same purpose.
2. Budget assertion in the atomic-editor script: 280 KB at 4x second paint under 400 ms and 50 KB at 4x under 250 ms on the reference machine, with the small fixture asserted not to regress (under 130 ms). Budgets are machine-specific; the script prints the baseline it was calibrated on and fails only on a 15 percent regression from a checked-in baseline file.
3. Vitest: the parse-window test from 7.1.
4. Then bump `@plannotator/markdown-editor` and `@plannotator/ui` peer ranges, republish, and re-run the Plannotator harness to confirm the 4x numbers before telling the host to upgrade.

Expected acceptance against the issue's five criteria: byte fidelity and editing commands unchanged (decoration-only change); consumer extension order and collaboration untouched; heavy-document 4x second paint improves about 30 percent; the small control is unchanged; normal and reduced-motion checks are unaffected because no animation participates (motion was already the host's negative control).

## 9. What to tell the host

1. Same packages, same document sizes, Plannotator enters the editor in 123 ms (small) and 519 ms (283 KB) at 4x. The package chain accounts for roughly 400 ms of document-dependent cost at 4x on a 283 KB document, and that is being fixed in `@plannotator/atomic-editor` (7.1 then 7.2). The remaining roughly 1,000 ms on the small document is on the host side of the `@plannotator/ui` seam: from the host's own timeline, the read tree is still mounted 322 ms after the click while the lazy editor route resolves, and the editor cannot mount until the collaboration binding is ready. Suggested host measurements: time from click to the lazy chunk's module evaluation, and time from click to the binding-ready callback that gates `MarkdownEditorPane`; preloading the editor chunk on hover or on room open, and binding ahead of the click, are host-side fixes that Plannotator cannot make.
2. The measure task attribution was right in kind (`ViewState.measure`, selection equality, `getClientRects`) but it is size-independent and mostly a forced layout of the newly inserted editable subtree; it is not caused by decorations, and deferring decorations would add a second one.
3. The "style time 771 to 984 ms" in the host profile is not reproduced by the editor stylesheet (13 to 41 ms of style recalc here). That is likely the host page's own CSS surface reacting to the swap; worth profiling a `UpdateLayoutTree` event's invalidation set in the host.
4. When 7.2 ships, the host can prewarm the state on room open and the click will only pay `EditorView` construction and the measure.
5. The rejected host experiment (removing the read article immediately) was correctly reverted; the data here show the editor build, not the read tree, is the floor, and a blank frame between the two surfaces is not a win.

## 10. Reproduce

```
cd /Users/ramos/plannotator/plannotator && bun run build:review && bun run build:hook
cd /private/tmp/claude-501/-Users-ramos-plannotator-plannotator/34d56d5a-33a8-4878-92b2-3f4318214ae2/scratchpad/issue-1401
node make-fixtures.mjs 50 heavy && node make-fixtures.mjs 276 xheavy
./run-all.sh min 5                       # tiny/heavy at 1x and 4x, shipped build
node bench.mjs --file fixtures/xheavy.md --cpu 4 --runs 5 --label min-xheavy-4x --port 19574
node attrib.mjs traces/unmin-heavy-4x-run1.cpuprofile.json   # bottom-up attribution
```

Results: `results/<label>.json` (medians, per-run timings, long tasks with breakdown, top self-time functions), `traces/<label>-run<i>.json` (Chrome trace, loadable in DevTools), `traces/<label>-run<i>.cpuprofile.json` (CDP profile with the entry window). The unminified build used for attribution is `dist-unmin/index.html`; `index.min.html` is the shipped build backup that was restored to `apps/hook/dist/index.html` after the attribution runs (verified with `cmp`).
