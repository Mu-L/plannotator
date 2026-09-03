# Design: bundle-weight optimization of `@plannotator/ui` without changing what any user sees

Status: proposal, investigated 2026-08-25 against `main` at `b381ecbe` (ui `0.31.0`, core `0.24.0`). Requested by the Workspaces web lane in `/Users/ramos/workspaces/research/integration/TASK-plannotator-ui-perf-2026-08-26.md`. Paths without a prefix are relative to `/Users/ramos/plannotator/plannotator`; Workspaces paths are relative to `/Users/ramos/workspaces/projects/workspaces/worktrees/main/apps/web`. Nothing tracked was modified; the builds run for section 2 wrote only to gitignored `dist/` dirs.

The maintainer's constraint is the whole brief: this is an optimization and nothing else, and any potential regression must be named, not hoped away. So every item below is treated as guilty until the mechanism is shown to leave Plannotator's own rendering byte-for-byte and tick-for-tick the same, across every consumer of the package: the Workspaces app (multi-chunk Vite), and Plannotator's own surfaces (the single-file hook and review HTML that Claude Code, OpenCode and Pi all ship, the share portal, the guides.show viewer).

The one-paragraph answer: four of the six items can ship as additive seams. Two of them (Mermaid, Graphviz) are plain dynamic imports with no behavior change anywhere. Two (KaTeX, the username dictionary) need an eager-registration seam, because a lazy default would change Plannotator's first paint even in a single-file build where nothing is fetched. The bridge script is a prop-gated asset URL with the inline literal kept as the default, plus a protocol version stamp so a cached asset from the wrong package version becomes observable. Fonts need nothing in the package (the request itself says so, and section 7 confirms it). The table popout should be deferred.

---

## 1. The build facts that decide the mechanisms

Everything hinges on what each consumer's bundler does with `import()` inside package source. This was measured, not assumed.

### 1.1 Plannotator's single-file builds inline every dynamic import

- `apps/review/vite.config.ts:33` uses `viteSingleFile()`, and `apps/review/vite.config.ts:68-72` sets `build.rollupOptions.output.inlineDynamicImports: true`. The worker build does the same (`apps/review/vite.config.ts:53-60`). `apps/hook/vite.config.ts:18` and `apps/hook/vite.config.ts:38-42` are identical in shape.
- Real build (`bun run --cwd apps/review build`, 3472 modules, then `bun run build:hook`): `apps/review/dist/` contains exactly one file, `index.html`, 17,561,818 bytes (gzip 5,613,647). `apps/hook/dist/index.html` is 21,809,726 bytes (gzip 6,799,207); `review.html` is a byte-identical copy of the review build. No `.js` chunk files, no `modulepreload` links.
- Inside the built HTML the literal `import("` occurs zero times and `__vite__mapDeps` zero times. Every existing `import()` (for example `packages/ui/utils/codeHighlight.ts:62`, `pierreLoad ??= import('@pierre/diffs')`) became Vite's preload helper around `Promise.resolve().then(() => ns)`; there are 383 such sites in the review build and 436 in the hook build. Shiki's per-grammar loaders and Mermaid's per-diagram loaders already ship this way today.
- OpenCode and Pi do not build; they copy those files (`apps/opencode-plugin/package.json:40`, `apps/pi-extension/package.json:55`). So the three agent runtimes run the identical client bundle.

Two consequences, both load-bearing for the rest of this doc:

1. **A dynamic import saves Plannotator's single-file builds zero bytes.** The module is still inlined and evaluated at bundle load. Nobody should expect the hook or review HTML to shrink from items 1, 2, 3 or 6.
2. **A dynamic import is still asynchronous even when inlined.** `Promise.resolve().then(...)` resolves in a microtask, after the current render commits. So a component that today renders synchronously (KaTeX, see 3.1) would, under a lazy import, commit one frame of un-typeset content before re-rendering, in Plannotator too. That is a visible first-paint change with no byte win attached to it, which is exactly the trade the constraint forbids. Any item whose current rendering is synchronous therefore needs an eager path that Plannotator's apps take, not a plain `import()`.

### 1.2 The portal splits chunks

`apps/portal/vite.config.ts:54-56` sets only `target: 'esnext'`; there is no `inlineDynamicImports`. `bun run build:portal` emitted 443 assets: entry `index-*.js` 5,951 KB (1,845 KB gz), 312 Shiki chunks, about 51 Mermaid diagram chunks (`cytoscape.esm` 142 KB gz, `wardley` 146 KB gz among them), KaTeX and Inter/Geist font files. The portal renders the full plan App (`apps/portal/index.tsx:3-4` imports `@plannotator/editor`, aliased to `packages/editor/App.tsx` at `apps/portal/vite.config.ts:51`), so it mounts `Viewer` with math, Mermaid and Graphviz. A new `import()` in `@plannotator/ui` becomes a separately fetched file on share.plannotator.ai. The fetch-failure mode already exists there for Mermaid diagrams and Shiki grammars, so it is not new, but it must be accounted for per item.

### 1.3 The guides.show viewer

`apps/guides-show/vite.viewer.config.ts:51` sets `inlineDynamicImports: false` explicitly, chunks to `chunks/[name].[hash].js` (`:53`), and stubs `katex/dist/katex.min.css` to an empty file (`:34`). Build result: `viewer.CTfggrYt.js` 395.0 KB gz against the 400 KB budget (`apps/guides-show/build/check-budgets.ts:12-15`), 312 lazy chunks, `check:manifest` in sync.

What the viewer does and does not contain, verified by import chain and by grepping the built entry:

- `apps/guides-show/viewer/main.tsx:29` deliberately imports `setStorageBackend` from `@plannotator/ui/utils/storage` rather than `configurePlannotatorUI`, with the comment that the configure barrel "drags markdown/math renderers into a bundle that never uses them" (`:26-28`).
- `packages/guide-viewer/renderInlineMarkdown.tsx:1` and `renderMarkdownProse.tsx:1-2` import only React and each other. No file under `packages/guide-viewer` imports `@plannotator/ui/components/Viewer`, `InlineMarkdown`, `MathBlock`, `MermaidBlock`, `GraphvizBlock`, `html-viewer` or `TablePopout`. Built entry: `katex` 0 hits, `@viz-js` 0, `uniqueUsernameGenerator` 0, `__plannotatorLiveConfig` 0.
- The viewer DOES reach `packages/ui/config` (through `apps/guides-show/viewer/ReadOnlyDiffRenderer.tsx:3` and `packages/review-editor/hooks/usePierreTheme.ts:3-13` via `ThemeProvider`), and `packages/ui/config/settings.ts:19` imports `generateIdentity`, which the build swaps for a stub returning `'reader'` (`apps/guides-show/build/read-only-stubs-plugin.ts:15`, `apps/guides-show/viewer/stubs/generateIdentity.ts:2-4`).

So: items 1, 2, 4, 5 and 6 do not reach the viewer bundle. Item 3 (identity) touches `settings.ts` and `generateIdentity.ts`, both in the viewer graph, and therefore changes `viewer.<hash>.js`, which requires `bun run --cwd apps/guides-show build:viewer && bun run --cwd apps/guides-show sync:manifest` and a regenerated `packages/core/guide-viewer-manifest.ts` (`apps/guides-show/build/sync-manifest.ts:47-54` exits 1 in `--check` mode on any byte difference; the `guides-show` CI job is path-gated on `packages/ui/` at `.github/workflows/test.yml:234`). The stub alias at `read-only-stubs-plugin.ts:15` must also be kept pointing at whatever module the dictionary import ends up in.

### 1.4 Workspaces

Workspaces consumes package source through its own Vite (rolldown) build with per-route chunks. Its four shims (`src/plannotator/math-lazy.ts`, `mermaid-lazy.ts`, `viz-lazy.ts`, `username-generator-shim.ts`) are alias rows in `vite.config.ts:79-190` that replace the bare specifiers `katex`, `mermaid`, `@viz-js/viz` and `unique-username-generator`. Its `scripts/check-boot-closure.mjs:95-181` asserts that none of katex, the Mermaid runtime (`mermaidAPI` marker) or the bridge (`plannotator-bridge` marker) is in the document read closure, and stays after the package ships these. Their identity seam is installed at `src/plannotator/seams.ts:92`.

---

## 2. Item 1: KaTeX, loaded only when math is on the page

### 2.1 Current state

- The only KaTeX JS import in the repo is `packages/ui/components/blocks/MathBlock.tsx:2` (`import katex from 'katex'`). `renderMathToHtml` at `MathBlock.tsx:11-19` calls `katex.renderToString(tex, { displayMode, throwOnError: false, strict: 'warn', trust: false, output: 'html' })`. `MathBlock` runs it in `useMemo` during render (`MathBlock.tsx:21-36`); `InlineMath` in `packages/ui/components/InlineMarkdown.tsx:313-326` does the same through the import at `InlineMarkdown.tsx:12`. **Rendering is fully synchronous: the typeset HTML is in the DOM on the first commit.** There is no try/catch around `renderToString`; `throwOnError: false` turns parse errors into KaTeX's error span, and anything else would propagate out of render (that is today's behavior and is preserved, not fixed, here).
- The wrapper attributes a host and the annotation layer depend on: `math-block math-annotatable ...`, `data-block-id`, `data-block-type="math"`, `data-math-tex`, `data-math-display="true"`, `aria-label` (`MathBlock.tsx:26-34`); `math-inline math-annotatable`, `data-math-tex`, `data-math-display="false"` (`InlineMarkdown.tsx:313-326`).
- CSS: Plannotator's apps load KaTeX's stylesheet and its 20 font faces through `packages/ui/theme.css:3` (`@import "katex/dist/katex.min.css"`), reached from `packages/editor/index.css:14` and `packages/review-editor/index.css:17`. The single-file builds inline those fonts as data URIs (about 260 KB decoded). The published `styles.css` stubs that import (`packages/ui/vite.css.config.ts:13`, `packages/ui/build-stubs/katex-css-stub.css:1-7`), and `packages/ui/HANDOFF.md:231-237` makes CSS loading the host's job. Nothing about that policy changes here.
- Who renders math: `Viewer` through `BlockRenderer.tsx:124-125` (plan review, annotate, archive, the portal), and the review editor through `packages/ui/components/RenderedMarkdown.tsx:3` (markdown bodies in code review). The guide-viewer renderers and guides.show do not (1.3).
- Timing-dependent consumers: none serialize KaTeX output. There is no client-side DOM serializer (the only `innerHTML` writers are `packages/ui/utils/codeHighlight.ts:257,268` for fences); `/api/share-html` returns the author's HTML file with assets inlined (`packages/server/annotate.ts:436-455`), never the rendered DOM; URL sharing carries markdown plus annotations (`packages/ui/utils/sharing.ts`); print is `window.print()` (`packages/editor/App.tsx:4517`, `:4628`) over whatever the DOM holds, with no math rule in `packages/ui/print.css`. Annotation restore is timer-deferred (100 ms at `packages/editor/App.tsx:2060`, 120 ms at `:2122`, 100 ms at `:2397`), which today cannot race math because math is synchronous. Math annotations restore by attribute lookup on `data-math-tex` (`packages/ui/hooks/useAnnotationHighlighter.ts:590-647`, `:667-673`), not by rendered text, but the generic `findTextInDOM` fallback (`:356-462`) walks every text node under the container, KaTeX's included. Block targeting resolves math by `.math-annotatable,[data-math-tex]` (`packages/ui/utils/blockTargeting.ts:202-205`, `:223-233`).
- Where math presence is decidable ahead of render: display math is a parser block type (`packages/ui/utils/parser.ts:746-809`, `:811-866`, `type: 'math'`); inline `$...$` and `\(...\)` are only discovered inside `InlineMarkdown` (`InlineMarkdown.tsx:509-566`), so a page-level "has math" check needs a regex over paragraph content, which Workspaces already wrote (`math-lazy.ts` `MATH_HINT`).

### 2.2 Proposed mechanism: a renderer slot with an eager registration entry

A plain `import('katex')` inside `MathBlock` is ruled out by 1.1 point 2: Plannotator would paint raw TeX for one frame on every plan with math, in every runtime, for zero bytes.

Instead:

- New `packages/ui/utils/math.ts` (no katex import): a module-level renderer slot, `setMathRenderer(renderer)`, `getMathRenderer(): MathRenderer | null`, a subscribe function for `useSyncExternalStore`, and `loadMathRenderer(): Promise<MathRenderer>` whose default loader is `() => import('katex').then(m => m.default)`, idempotent, dropping the promise on rejection so the next call retries (the same shape as Workspaces' `math-lazy.ts`). A `setMathRendererLoader(fn)` seam lets a host swap the loader (Workspaces would pass a loader that imports katex and `katex/dist/katex.min.css` in one chunk; the package's default loader must NOT import the CSS, because HANDOFF option 1 and 2 hosts already serve it and would double-load).
- `MathBlock.tsx` and `InlineMath` import from `utils/math` instead of `katex`. When the slot is filled they render exactly as today (`useMemo` over `renderToString`, same options, same wrapper). When it is empty they render the same wrapper element with the trimmed TeX as a text child (design 1 from the request), subscribe to the slot, and call `loadMathRenderer()` from an effect; when it fills they re-render typeset. The placeholder keeps `data-math-tex`, `data-math-display`, `aria-label`, `className` and `data-block-id`, so block targeting and math-annotation restore work against it unchanged.
- New `packages/ui/utils/math-eager.ts`: `import katex from 'katex'; setMathRenderer(katex);`. One side-effect import of this module at the top of `packages/editor/App.tsx` and `packages/review-editor/App.tsx`. ES module evaluation runs static imports before the App module body, so the slot is filled before any render, and Plannotator's first commit is identical to today. The hook, review, OpenCode, Pi and portal builds all flow from those two entries, so they are all covered by two lines.
- `configurePlannotatorUI` grows `mathRendererLoader?: () => Promise<MathRenderer>` (`packages/ui/configure.ts:40-70`). Nothing else in the config surface changes.

This is the one place the package's "pass nothing and get today's behavior" law (`packages/ui/HANDOFF.md:526`) is bent rather than kept: a third-party host that renders `Viewer` and never imports `math-eager` now gets lazy math (one frame of TeX text, then typeset). That is precisely what the only known host asked for, and it cannot be achieved any other way, because a static `import 'katex'` anywhere on `Viewer`'s import graph is what Workspaces' bundler is measuring. It must be stated in the HANDOFF entry for this release, with the one-line opt-back (`import '@plannotator/ui/utils/math-eager'`).

### 2.3 Regression analysis

Plannotator (all runtimes, portal):

- First paint: unchanged, provided the eager import is present in both App entries. This is the single failure point of the item, and it is testable: `packages/ui/components/InlineMarkdown.test.ts:103-119` already renders `$...$` with `renderToStaticMarkup` and asserts KaTeX markup synchronously. After the change that test must import `math-eager` (or an equivalent registration) and a new sibling test must assert that WITHOUT registration the output is the placeholder with the TeX as text and the same attributes. A build-level guard should grep the built `apps/hook/dist/index.html` and `apps/review/dist/index.html` for a KaTeX marker (`katex-display` or `KaTeX parse error`) to catch a lost registration (the marker is present today in both).
- Annotation offsets, code-block highlight swap, print, export, share: unchanged, because nothing in the sync path changed for Plannotator. The `findTextInDOM` fallback sees the same DOM it sees today.
- Portal: `import('katex')` would split a chunk, but the portal imports the editor App, which now imports `math-eager`, so katex stays in the entry chunk (Rollup keeps a statically imported module in its importer's chunk; a static and a dynamic import of the same module resolves to the static placement). Verify by grepping the portal build output for a katex marker in the entry file, not a chunk.
- guides.show: not reached (1.3). Run `check:manifest` anyway; it should stay in sync.

Workspaces (lazy path):

- First-paint flash and layout shift: a display block collapses from one text line to a typeset block when the chunk lands. Workspaces already gates the first paint of a math body on the chunk (`math-lazy.ts` `useMathRenderer`) and keeps the body skeleton up; with design 1 they can keep that gate pointed at the package's `loadMathRenderer()`. Ungated secondary mounts (their artifact lightbox) get the placeholder-then-typeset behavior they already accept.
- Timing-dependent code: an annotation restore that runs before the chunk lands will `findTextInDOM` against TeX source text in the placeholder. Math annotations themselves restore by `data-math-tex`, which the placeholder carries, so `mathTargets` restore correctly. A plain text annotation whose `originalText` happens to equal TeX source is the only theoretical mismatch and it exists today for any host whose restore runs before render.
- Chunk failure: `loadMathRenderer` rejects, the placeholder stays (TeX as text, same wrapper), the next `loadMathRenderer()` call retries. That is today's Workspaces behavior and better than a blank; it is strictly not worse than the package's current "no CSS loaded" symptom in HANDOFF (`:239`).
- SSR/hydration: `useSyncExternalStore` with a server snapshot of `null` renders the placeholder on the server and typesets on the client after the chunk; no mismatch because the client's first snapshot is also `null` until the effect loads it. Plannotator has no SSR.
- Security: the placeholder is a React text child, never `dangerouslySetInnerHTML`, so TeX source cannot reach the page as markup. The loader seam accepts a host module, so the package must keep pinning `trust: false` and `throwOnError: false` on its own calls regardless of what renderer was registered (Workspaces' shim pins the same set).

### 2.4 Byte savings

- Workspaces: 253 KB raw / 75 KB gz of JS plus 28 KB raw / 8 KB gz CSS out of the document read closure (request, item 1).
- Plannotator single-file builds: zero. KaTeX stays inlined by the eager import, exactly as today (the built HTML carries `katex.mjs`, roughly 148 KB gz of the file).
- Portal: zero, same reason.

Verdict: **do, with seam** (renderer slot + `math-eager` + loader seam).

---

## 3. Item 2: Mermaid, runtime imported inside the render effect

### 3.1 Current state

- `packages/ui/components/MermaidBlock.tsx:3` (`import mermaid from 'mermaid'`), the only Mermaid JS import. Module-scope `mermaid.initialize({...})` at `MermaidBlock.tsx:7-30` with `securityLevel: 'strict'`, `theme: 'dark'` and hard-coded hex `themeVariables`; nothing reads a CSS token or the resolved mode at module load, so moving the call later cannot change its inputs.
- The render effect at `MermaidBlock.tsx:186-213` awaits `mermaid.render(...)`, normalizes the SVG, and sets state with a `cancelled` guard; errors go to `setError` (`:200-205`) and render the "Mermaid Error" panel (`:414-429`). Until `svg` is set the block shows the fenced source in a `<pre><code class="pn-code font-mono language-mermaid">` (`:524-528`, `:547`). **Rendering is already asynchronous**; the first frame is the source fence today.
- No consumer reads the SVG synchronously: print relies on whatever is in the DOM (`packages/ui/print.css:404-410` only sizes `svg`), no export reads it (2.1). The diagram container carries `data-pinpoint-ignore` (`MermaidBlock.tsx:533`).
- Only `Viewer` renders it (`packages/ui/components/Viewer.tsx:42-44`, dispatch at `:943-946`). The review editor and guides.show do not.

### 3.2 Proposed mechanism: plain dynamic import, once-initialized

```ts
let mermaidRuntime: Promise<typeof import('mermaid').default> | null = null;
function getMermaid() {
  mermaidRuntime ??= import('mermaid').then(({ default: m }) => { m.initialize(MERMAID_CONFIG); return m; });
  return mermaidRuntime;
}
```

The effect awaits `getMermaid()` then `render`. The config object is hoisted verbatim. No seam, no config, no export shape.

### 3.3 Regression analysis

- Plannotator: the module is inlined (1.1), so `import('mermaid')` resolves in a microtask; the SVG lands one microtask later than today, after a render that was already async. The first frame is the source fence in both versions. `initialize` runs on first diagram instead of at bundle load, with identical constant input. No annotation, print, export or share path reads the SVG. If the runtime import rejected (impossible when inlined; possible on the portal), the existing catch sets `error` and shows the Mermaid Error panel with the source, which is the current failure UI.
- Portal: the runtime becomes a lazy chunk beside the diagram chunks that are already lazy today (`cytoscape.esm`, `wardley`, ...). A failed fetch now also covers the runtime; the user sees the error panel plus source instead of, today, the source forever with a console error from a failed diagram chunk. Not worse.
- Existing restore edge case, unchanged by this item and recorded for honesty: a restore that runs while the source `<pre>` is still showing can match text inside it, and that text is replaced when the SVG lands. This exists today because the render is already async; the change adds one microtask to the window in Plannotator and one network fetch in Workspaces and the portal.
- guides.show: not reached. Manifest unaffected.
- Workspaces' `mermaid-lazy.ts` pins `securityLevel: 'strict'` over the config; the package's constant already has it (`MermaidBlock.tsx:9`), and a test should pin that literal (deliberately, per the testing rules: it is a security decision, not prose).

### 3.4 Byte savings

- Workspaces: 414.5 KB raw of runtime out of every read; first diagram fetches `mermaid.core` 12 KB gz plus shared runtime chunks (request, item 2).
- Plannotator single-file builds: zero. Portal: the entry chunk shrinks by the runtime (a few hundred KB gz), moved to a lazy chunk.

Verdict: **do** (no seam).

---

## 4. Item 3: username dictionary, not shipped to hosts that provide identity

### 4.1 Current state

- `packages/ui/utils/generateIdentity.ts:9` statically imports `uniqueUsernameGenerator, adjectives, nouns` from `unique-username-generator`; `generateIdentity()` at `:16-29` is synchronous and returns `adjective-noun-tater`. The installed package is CJS whose `dist/index.js:24` requires the data eagerly (about 234 KB of word lists on disk; Workspaces measures 134.5 KB raw / 28 KB gz after their minifier).
- Two static paths keep it in every closure: `packages/ui/config/settings.ts:19` (the `displayName.defaultValue` thunk at `:101-109`) and `packages/ui/utils/identity.ts:14` (`regenerateIdentity` at `:92-96`), which `packages/ui/components/Viewer.tsx` imports for `getIdentity`.
- When it runs: `configStore.ensureLoaded()` (`packages/ui/config/configStore.ts:98-113`) evaluates EVERY setting's `defaultValue` on the first `get` of ANY setting, takes `fromCookie ?? default` (`:106`) and persists a generated default with `toCookie` (`:109-111`). That first `get` is a synchronous render read: `ThemeProvider` calls `useConfigValue('themePair')` (`packages/ui/components/ThemeProvider.tsx:145`) through `useSyncExternalStore` whose snapshot is `configStore.get(key)` (`packages/ui/config/useConfig.ts:13-20`). **So the generator must return a string synchronously, during first render, and whatever it returns is written to the `plannotator-identity` cookie immediately.** A lazy import with a later swap would persist the fallback name first and then visibly change the user's identity; that is why the request's "make `generateIdentity` async" option is rejected.
- Host path: `getIdentity()` delegates to the installed provider (`identity.ts:73-75`), so a host with `identityProvider` never calls the generator at runtime; only the static import keeps the dictionary in its bundle. `packages/ui/config/configStore.lazyInit.seam.test.ts:44-75` asserts the sync first-read contract.
- Sync callers of the produced name: every `author: getIdentity()` stamp is an event handler (`Viewer.tsx:381`, `:769`; `useAnnotationHighlighter.ts:525`, `:574`; `useHtmlAnnotation.ts:742`, `:801`, `:848`, `:907`; `HtmlViewer.tsx:717`; `PlanCleanDiffView.tsx:170`), and `packages/review-editor/App.tsx:631` reads `displayName` in render. Two sites bypass the provider and read the store directly (`packages/editor/App.tsx:3761`, `packages/review-editor/App.tsx:631`); they are unchanged by this item and only noted.
- guides.show already stubs the module at build time (`read-only-stubs-plugin.ts:15`), which is the existing proof that the word list is the cost worth cutting.

### 4.2 Proposed mechanism: injectable synchronous generator with an eager default entry

- `generateIdentity.ts` drops the static import. It holds `let generator: () => string = fallbackGenerator` and exports `setIdentityGenerator(fn)` and the unchanged sync `generateIdentity()`. The fallback generates the same `adjective-noun-tater` shape from a small inline pool (sixteen adjectives, sixteen nouns, as Workspaces' shim does), so a host that passes nothing still gets a valid name of the same format. Randomness source unchanged (`Math.random`).
- New `packages/ui/utils/identity-tater.ts`: statically imports `unique-username-generator` and calls `setIdentityGenerator(realGenerator)` as a side effect. Imported once from `packages/editor/App.tsx` and `packages/review-editor/App.tsx` next to `math-eager` (a single `@plannotator/ui/utils/plannotator-defaults` module that imports both eager entries is fine and keeps the app change to one line per entry).
- Optional: `configurePlannotatorUI({ identityGenerator })` for a host that wants the full dictionary without its own provider. Not needed by Workspaces.
- `settings.ts:19` keeps importing `generateIdentity` from the same module path so the guides.show stub alias (`read-only-stubs-plugin.ts:15`) keeps matching; if the path moves, the alias moves with it.

### 4.3 Regression analysis

- Plannotator: name generation is byte-identical (same library, same config, same call) provided the eager entry is imported before first render. Same failure point and same style of guard as 2.3: a test that asserts `generateIdentity()` without registration produces the pool format, and a build grep for a distinctive dictionary word in the built HTML (present today, three hits of `uniqueUsernameGenerator`).
- Cookie and settings: unchanged. `configStore.lazyInit.seam.test.ts` passes as written because the fallback is sync.
- Settings dialog "regenerate" button (`packages/ui/components/Settings.tsx:1101`): same sync call, same result shape.
- guides.show: `settings.ts` and `generateIdentity.ts` are in the viewer graph (1.3), so `viewer.<hash>.js` changes. The item's PR must run `build:viewer`, `check:budgets` and `sync:manifest` and commit the regenerated `packages/core/guide-viewer-manifest.ts`. The stub alias may become unnecessary once the dictionary is out of `generateIdentity.ts`, but it should stay until parity is confirmed (never delete working code first).
- Workspaces: with `identityProvider` installed, nothing calls the generator; with the static import gone, the dictionary leaves the bundle. Their shim and alias row can be deleted.
- Anything relying on a specific first-run name: none found in tests (`packages/ui/utils/identity.seam.test.ts` covers delegation only).

### 4.4 Byte savings

- Workspaces: 134.5 KB raw, about 28 KB gz (request, item 3).
- Plannotator single-file builds: zero (dictionary re-registered eagerly). guides.show: zero (already stubbed). Portal: zero.

Verdict: **do, with seam** (generator slot + `identity-tater` eager entry).

---

## 5. Item 4: HTML viewer bridge script as an asset

### 5.1 Current state

- `BRIDGE_SCRIPT` is a plain template-string constant, an IIFE with no `${}` interpolation, `packages/ui/components/html-viewer/bridge-script.ts:213-4570`, 184,901 bytes. Siblings `ANNOTATION_HIGHLIGHT_CSS` (`:17`) and `LIVE_BRIDGE_BOOTSTRAP` (`:4580-4589`). Per-session values are never spliced into the text: the script reads `window.__plannotatorLiveConfig` at runtime (`:223`) and is inert in srcdoc when that global is absent (`:216-222`, `:231-245`).
- srcdoc splice: `packages/ui/components/html-viewer/srcdoc.ts:17` imports it; `buildSrcdocInjection()` at `srcdoc.ts:102-121` emits `<style>...</style><script>${BRIDGE_SCRIPT}</script>` (`:120`). `neutralizeMetaCsp()` (`:130-135`) strips any author `<meta http-equiv="content-security-policy">` precisely because it would block the inline bridge (`:123-129`). The iframe is `sandbox="allow-scripts"` with no `allow-same-origin` (`packages/ui/components/html-viewer/HtmlViewer.tsx:822-833`, pinned by `packages/ui/webmcp/iframeIsolation.test.ts:24-34`). Live mode uses `src` on the proxy with no sandbox (`HtmlViewer.tsx:819-824`).
- Live proxy: `composeLiveBridgeJs()` (`packages/shared/live-proxy-core.ts:488-502`) concatenates the JSON config prelude, the bootstrap and the script, served at `/__plannotator__/bridge.js` (`:36`) behind the `Sec-Fetch-Site` gate (`:138-140`) by both transports (`packages/server/live-proxy.ts:140-143`, `packages/shared/live-proxy-node.ts:160-168`). The server never imports `@plannotator/ui`: the Bun CLI imports the three strings (`apps/hook/server/index.ts:118-124`) and passes them in (`:1274-1280`); Pi vendors the file verbatim (`apps/pi-extension/vendor.sh:113-114`) and imports it lazily (`apps/pi-extension/plannotator-browser.ts:684-689`). **The named string exports must stay plain module exports.**
- Other srcdoc consumers, all inline today: `packages/editor/App.tsx:5576` (raw HTML annotate and the version diff), `packages/review-editor/dock/panels/ReviewPRArtifactsPanel.tsx:6,441-451` (PR HTML artifacts), `packages/ui/hooks/useLinkedDoc.ts:347-349` (linked `.html` docs), and the portal for `r: 'html'` share payloads (`packages/ui/utils/sharing.ts:31,263`, `packages/ui/hooks/useSharing.ts:162-164`).
- `/api/share-html` (`packages/server/annotate.ts:436-455`) inlines the author's assets; the bridge is never part of a shared or exported document. guides.show does not ship the html viewer (1.3). HtmlViewer is never served from `file://`.
- Version coupling: there is none. Both sides share only the `plannotator-bridge-` prefix (`bridge-script.ts:214`, `packages/ui/components/html-viewer/useHtmlAnnotation.ts:12`, `HtmlViewer.tsx:55`); unknown messages are dropped silently (`useHtmlAnnotation.ts:515-516`). Today that cannot matter because the bridge and the parent are the same bundle.
- Tests execute the string directly: `srcdoc.test.ts:53-102` (`new Function(BRIDGE_SCRIPT)()`), `htmlLiveProtocol.test.tsx:341`, plus the server tests fetching `/__plannotator__/bridge.js`.

### 5.2 Proposed mechanism: `bridgeScriptUrl` prop, inline default, shipped asset, version stamp

- `HtmlViewer` grows `bridgeScriptUrl?: string`. `buildSrcdocInjection(options)` emits `<script src="${url}"></script>` when set and the inline literal otherwise. Plannotator passes nothing; every Plannotator surface stays inline and byte-identical. A classic `<script src>` in a `sandbox="allow-scripts"` srcdoc is loadable from the host origin by absolute URL without CORS (opaque origin restricts same-origin reads, not classic script execution), and it is parser-blocking in `<head>` exactly like the inline script, so bridge-before-body ordering is preserved.
- The package ships a runnable `components/html-viewer/bridge-script.js` (the raw IIFE) generated at `prepack` from `BRIDGE_SCRIPT`, next to the TS module that stays the source of truth (it cannot go the other way: the CLI and Pi import the TS string under Bun, where `?raw` does not exist). A unit test asserts the generated file's bytes equal `BRIDGE_SCRIPT`. The `exports` map already lists `./components/html-viewer/bridge-script` (`packages/ui/package.json:5-27`); add the `.js` subpath so `?url` resolves.
- Version stamp: a `BRIDGE_PROTOCOL_VERSION` constant embedded in the script text (so the generated asset carries it) and exported for the parent; the bridge includes it in `plannotator-bridge-ready`, and the parent logs a console warning on mismatch (do not refuse: an older bridge still works for every message shape it knows). This is the only defense against a host caching an asset from a previous package version beside a newer parent chunk, which today is undetectable.

### 5.3 Regression analysis

- Plannotator: no change on any surface, because the prop is never passed and the default branch is the current code path. Live proxy: untouched (it never used srcdoc). Pi: `vendor.sh` copies the TS file; the version constant must live inside `bridge-script.ts` so the vendored copy carries it.
- Workspaces: the `<script src>` adds a network dependency the inline literal never had. Offline mid-session, a blocked asset host or a failed fetch means no bridge, so no `ready` message, no markers, no selection; the page still renders. `HtmlViewer` has no ready timeout today, so the failure is silent. Recommend the PR add a `bridgeReadyTimeoutMs` with an `onBridgeUnavailable` callback (default off, so Plannotator is unchanged) so a host can show "annotation unavailable" instead of a dead surface.
- CSP: a `script-src` delivered on the HOST page as an HTTP header is inherited by a srcdoc document; the host must allow its own asset origin (Workspaces' asset origin is same-origin, and their inline bridge would already need `'unsafe-inline'` or a nonce if they had such a header, so the asset form is easier under CSP, not harder). Author `<meta>` CSP is still neutralized by `srcdoc.ts:130-135`.
- Double-parse claim in the request: correct today and unchanged for Plannotator; the win is Workspaces-only.
- The srcdoc is rebuilt whenever `rawHtml`, theme tokens or `diffActive` change (`HtmlViewer.tsx:307-316`); with a URL the browser re-fetches from cache per rebuild. Fine with normal cache headers; note it for the host.

### 5.4 Byte savings

- Workspaces: 185 KB raw out of the viewer chunk, cacheable separately (request, item 4). HTML readers only.
- Plannotator: zero. The string stays inlined (about 52 KB gz of the built HTML).

Verdict: **do, with seam** (prop + generated asset + protocol version + optional ready timeout).

---

## 6. Item 5: Graphviz (and the general `Viewer` import graph)

### 6.1 Current state

- `packages/ui/components/GraphvizBlock.tsx:3` (`import { instance } from '@viz-js/viz'`), the only site. WASM instantiation is already deferred to first render: `vizInstancePromise ??= instance()` (`:17-22`). The render effect (`:157-194`) awaits it, renders SVG, rewrites colors to CSS variables (`:164-174`), sets state; errors show "Graphviz Error" with the source (`:181-186`, `:357-372`). The source fence is shown until `svg` is set (`:486`, `:459-463`). **Already asynchronous, same shape as Mermaid.**
- Cost: `@viz-js/viz` `lib/backend.js` is 1,174,660 bytes raw, roughly 466 KB gz, the largest single dependency in the hook build (24 unique `_viz_*` symbols in `apps/hook/dist/index.html`; absent from the review build, which does not mount `Viewer`).
- Only `Viewer` renders it (`Viewer.tsx:42`, `:945`). Not reached by guides.show or the review editor. Note: the Graphviz container lacks the `data-pinpoint-ignore` Mermaid carries (`GraphvizBlock.tsx:470-479` versus `MermaidBlock.tsx:533`); pre-existing, out of scope, recorded.

### 6.2 Proposed mechanism

`vizInstancePromise ??= import('@viz-js/viz').then(m => m.instance())`. Nothing else changes.

### 6.3 Regression analysis

Identical to 3.3: inlined in single-file builds (one extra microtask before an already-async render), a lazy chunk on the portal with the existing error panel as the failure UI, no consumer reads the SVG synchronously, guides.show unaffected. The color rewrite uses CSS variables resolved at paint (`:164-174`), so deferral cannot change theming.

### 6.4 Byte savings

- Workspaces: the 489 KB gz lazy chunk leaves the document route (their `viz-lazy.ts` header).
- Plannotator single-file builds: zero. Portal: the entry chunk drops roughly 466 KB gz into a lazy chunk, the largest portal win of the set.

Verdict: **do** (no seam). Ship with item 2 in the same PR; they are the same change.

---

## 7. Fonts (item B2 in the request)

### 7.1 Current state, verified

- The published `packages/ui/styles.css` declares zero `@font-face`, zero font `@import`, zero `data:font` or `.woff2` references. `packages/ui/styles-entry.css:1-4` says fonts are excluded on purpose; `packages/ui/README.md:109-114` and `HANDOFF.md:30` make font loading the host's job.
- `packages/ui/theme.css` only bridges tokens (`:603-604`), sets `body { font-family: var(--font-sans) }` (`:709`) and uses `var(--font-mono)` in three places (`:164`, `:419`, `:1080`). Families come from theme files: the default theme names the variable faces first, `--font-sans: 'Inter Variable', 'Inter', system-ui, sans-serif` and `--font-mono: 'Geist Mono Variable', 'Geist Mono', 'JetBrains Mono', 'Fira Code', ui-monospace, monospace` (`packages/ui/themes/plannotator.css:26-27`; same in `colorblind.css:40-41`, similar in `simple.css:58-59`).
- What Plannotator's apps load: exactly two variable families through `@fontsource-variable` imports at `packages/editor/index.css:1-2` and `packages/review-editor/index.css:1-2` (`Inter Variable` wght 100-900 in 7 subsets, `Geist Mono Variable` wght 100-900 in 3 subsets; `packages/ui/package.json:68-69`, `bun.lock:691,693`). The single-file builds inline them as data URIs (Inter about 218.5 KB decoded, Geist Mono about 57 KB). No Google Fonts `<link>` in any app `index.html`. JetBrains Mono is never loaded as a face: it is a fallback name in the token, an opt-in code-review diff font fetched at runtime from Google Fonts only when chosen (`packages/ui/utils/diffFonts.ts:13,23-34`, `packages/ui/components/Settings.tsx:125`), and a hardcoded HUD stack (`packages/ui/components/VimKeyHud.tsx:13`).
- The srcdoc forwards `--font-sans`/`--font-mono` values verbatim as `--pn-font-*` (`srcdoc.ts:43-44`, `:78-88`); `print.css:84` and `:259` use deliberate system stacks independent of the tokens.

### 7.2 Conclusion

The static Inter 400-700 and JetBrains Mono 400-600 faces in the audit were the host's own `@fontsource` imports in `apps/web/src/plannotator/plannotator.css`, which Workspaces has already removed and replaced with their variable faces (request, "Fonts"). The package already names the variable faces first in its default tokens, so "map onto the variable faces" is already the package's behavior; Plannotator is already on variable fonts; no weight, hinting or fallback-stack change occurs anywhere.

Nothing to do in the package. Two optional tidy-ups exist and are recommended AGAINST in this pass, because they change rendering for users of those themes without any byte win: putting `'... Variable'` names first in the non-default themes that name plain `'Inter'`/`'Geist Mono'` (`themes/neutral.css:26-27`, `adwaita.css:27-28`, `synthwave-84.css:28-29`, `claude-plus.css:26-27`), and dropping `"JetBrains Mono"` from `VimKeyHud.tsx:13`. The unused `@fontsource-variable/*` dependencies in `packages/ui/package.json:68-69` can stay; removing a dependency is a separate, visible package change and not an optimization.

Verdict: **no** (nothing to change; the package is already correct).

---

## 8. Item 6 (optional): the table popout's `@tanstack/react-table`

### 8.1 Current state

- `packages/ui/components/blocks/TablePopout.tsx:2-11` imports `@tanstack/react-table`; `Viewer.tsx:14` imports `TablePopout` statically and renders it only when `popoutTable` is set (`Viewer.tsx:1115-1128`), portaled into `containerRef` so the annotation hooks can walk its text nodes (`:1113-1114`; `PopoutDialog.tsx:75-76` uses Base UI's `Dialog.Portal` with that container). Opened by the table toolbar's expand button (`Viewer.tsx:1049-1050`). No tests reference it.

### 8.2 Mechanism if done

`const TablePopout = React.lazy(() => import('./blocks/TablePopout'))` in `Viewer`, wrapped in `<Suspense fallback={null}>`.

### 8.3 Regression analysis

- Plannotator: inlined, so the first expand click renders `null` for one microtask, then the dialog; Base UI's open transition starts one tick later. Not a byte win. A `Suspense` boundary inside `Viewer` also changes error propagation semantics for the subtree (a thrown promise or error inside the popout now surfaces at the boundary), which is new surface for zero gain.
- Workspaces: the popout becomes a click-time chunk fetch; a failed chunk leaves a dead expand button with no error UI unless an error boundary is added.
- The annotation-walk-into-popout behavior depends on the portal container, not on load timing, so it survives; but nothing tests it today, so a regression there would be caught only in the browser.

### 8.4 Byte savings

- Workspaces: 47.6 KB raw of `@tanstack/table-core` (request, item 6). Plannotator: zero.

Verdict: **defer**. Smallest win of the set, the only item that adds a Suspense boundary to `Viewer`, and the popout has no test coverage to prove parity against. Revisit if Workspaces' read closure guard wants it after the four shims are gone.

---

## 9. Cross-cutting regression risks, ranked

1. **A lost eager registration is a silent first-paint regression in every Plannotator runtime.** Items 1 and 3 move Plannotator's parity onto two side-effect imports in `packages/editor/App.tsx` and `packages/review-editor/App.tsx`. If either is dropped in a refactor, plans with math paint TeX for a frame and identities come from the small pool, with no error anywhere. Mitigation is the built-HTML marker check in 10.2 plus the registration tests in 10.1; both must land in the same PR as the seams.
2. **Bending the pass-nothing law for third-party hosts (items 1 and 3).** A host that renders `Viewer` without importing the eager entries gets lazy math and pool identities. Documented in HANDOFF with the opt-back import; Workspaces, the only known host, asked for exactly this.
3. **guides.show manifest drift from item 3.** `settings.ts` is in the viewer graph; the PR must regenerate `packages/core/guide-viewer-manifest.ts` or CI's `check:manifest` fails and, worse, an exported guide would pin a stale hash if the check were skipped.
4. **Bridge asset skew and offline silence (item 4, Workspaces only).** No protocol version exists today; the version stamp and optional ready timeout are the mitigation. Plannotator keeps inline and is unaffected.
5. **Portal chunk fetch failures (items 1, 2, 5).** New lazy chunks on share.plannotator.ai for Mermaid's runtime and Graphviz; KaTeX stays in the entry via the eager import. The failure UI is the existing error panel with source. Self-hosted portals behind a strict asset policy must serve the chunk files; they already must for Shiki and Mermaid diagram chunks.
6. **Pre-existing async-diagram restore window (items 2 and 5).** A restore that matches text inside the source fence before the SVG lands loses that mark when the SVG replaces it. Already true today; the change widens it by one microtask in Plannotator. Recorded, not introduced.

---

## 10. Tests that prove no regression

### 10.1 Unit and DOM-gated (`DOM_TESTS=1`, added to the explicit list at `.github/workflows/test.yml:80-158`)

- `packages/ui/utils/math.test.ts`: slot empty renders placeholder with TeX text and the full attribute set; slot filled renders KaTeX markup synchronously in the same render (no effect needed); `loadMathRenderer` is idempotent and retries after rejection; `setMathRendererLoader` is honored; pinned options (`trust: false`, `throwOnError: false`) are applied regardless of registered renderer (deliberate security pin, marked as such).
- `packages/ui/components/InlineMarkdown.test.ts:103-119` updated to import `math-eager` and keep asserting synchronous KaTeX markup; a sibling case asserts the un-registered placeholder.
- `packages/ui/utils/generateIdentity.test.ts`: without registration the name matches `/^[a-z]+-[a-z]+-tater$/`; with `identity-tater` registered the generator is the dictionary one (assert a word not in the small pool can appear, or assert the registered function identity). `configStore.lazyInit.seam.test.ts` unchanged and must still pass.
- `MermaidBlock`: a test that `securityLevel: 'strict'` is in the hoisted config (deliberate pin); the existing `normalizeMermaidSvgMarkup` test unchanged.
- `srcdoc.test.ts`: with `bridgeScriptUrl` the injection contains `<script src="...">` and not the literal; without it the literal is byte-identical to `BRIDGE_SCRIPT`; the generated `bridge-script.js` equals `BRIDGE_SCRIPT`; the `ready` message carries `BRIDGE_PROTOCOL_VERSION` (both `srcdoc.test.ts` and `htmlLiveProtocol.test.tsx` execute the script and can assert it).
- `packages/ui/webmcp/iframeIsolation.test.ts` unchanged (sandbox attribute, no `modelContext` in the bridge).
- Pi: `apps/pi-extension/server/serverAnnotate-live.test.ts:98-109` still fetches `/__plannotator__/bridge.js` from the vendored copy.

### 10.2 Build-level checks

- After `bun run --cwd apps/review build && bun run build:hook`: `apps/hook/dist/index.html` contains a KaTeX marker (`katex-display`), a Mermaid marker (`flowchart-v2`), a Graphviz marker (`viz_set_y_invert`), the dictionary marker (`uniqueUsernameGenerator`) and the bridge marker (`__plannotatorLiveConfig`); `apps/review/dist/index.html` contains the KaTeX, dictionary and bridge markers. This is the regression guard for a lost eager import. Sizes should be within a few KB of today's 21,809,726 and 17,561,818 bytes (gzip 6,799,207 and 5,613,647); a drop of hundreds of KB gz means something Plannotator relies on fell out.
- `bun run --cwd apps/guides-show build:viewer && check:budgets && check:manifest` (item 3 requires `sync:manifest` and a committed manifest).
- `bun run build:portal`: KaTeX marker in the entry chunk, not a lazy chunk; Mermaid runtime and `@viz-js/viz` in lazy chunks.
- `bun test tests/entry-assets.test.ts` after the bundle build (`test.yml:192`).
- Package: `bun run --cwd packages/ui build:css` produces a `styles.css` with zero `@font-face` and no katex CSS, as today; `bun pm pack` includes `bridge-script.js`.

### 10.3 Browser-level checklist for the implementation PR (pe-verify style)

Run on the compiled binary (`bun build apps/hook/server/index.ts --compile --outfile ~/.local/bin/plannotator`) and on `bun run dev:portal`:

1. `plannotator annotate` on a markdown file with display math, inline math, a Mermaid fence, a `dot` fence, a fenced code block and a table. Reload with DevTools paint flashing on: math must be typeset on first paint (no TeX text frame); diagrams show the source fence then the SVG, as today.
2. Annotate across a KaTeX block (mathTargets) and a plain paragraph; submit; reopen the session and confirm the draft restore lands both. Switch palette and dark/light; confirm the code-block mark survives the highlight swap.
3. Expand the table popout; annotate inside it.
4. Print preview (Cmd+P): math, SVG diagrams, code blocks present.
5. Raw HTML annotate (`plannotator annotate file.html`): pinpoint a button, drag-select text, Esc ladder, marker click. Live app (`plannotator annotate http://localhost:5173`): same, plus HMR still works.
6. Share link from the plan editor and from an HTML annotate session; open on the portal; annotations restore; math typeset.
7. Code review: open a PR with an HTML artifact panel; markdown bodies with math render typeset.
8. Guided review: generate a guide, download the portable HTML, open it from `file://` WITHOUT `--allow-file-access-from-files`, and open a guides.show share link; confirm the viewer renders and the manifest hash matches the export.
9. Settings: regenerate identity produces a dictionary name (not one of the sixteen-word pool); the `(me)` badge still matches.
10. OpenCode and Pi: `bun run build:opencode` / `build:pi`, open one plan review in each and repeat step 1.

---

## 11. Ordering, what not to do, publish plan

### 11.1 Recommended order (safest and highest value first)

1. **Items 2 and 5 together** (Mermaid, Graphviz): plain dynamic imports, no seam, no first-paint change anywhere, and the largest Workspaces and portal wins. One PR.
2. **Item 3** (identity): small, mechanical, but carries the manifest resync, so it should be its own PR with the regenerated manifest in it.
3. **Item 1** (KaTeX): the seam with the most moving parts (slot, eager entry, loader seam, placeholder rendering). Own PR, with the marker check landing in the same PR.
4. **Item 4** (bridge asset): additive prop, generated asset, protocol version. Own PR; Workspaces validates it end to end because Plannotator never exercises the new branch.
5. Item 6: deferred. Item B2 (fonts): nothing.

### 11.2 What should not be done

- Do not make `generateIdentity` async or lazy-swap the name: the cookie is written on first read (`configStore.ts:109-111`) and the user would watch their identity change.
- Do not make `MathBlock` do a bare `import('katex')`: it changes Plannotator's first paint for zero bytes (1.1).
- Do not import `katex/dist/katex.min.css` from the package's default math loader: hosts on HANDOFF options 1 and 2 would double-load, and the published `styles.css` policy stays as is.
- Do not touch theme font tokens, `VimKeyHud`, or the `@fontsource-variable` dependencies in this pass (7.2).
- Do not remove the guides.show `generateIdentity` stub alias or Workspaces' boot-closure guard until parity is confirmed in the browser.
- Do not add a `Suspense` boundary to `Viewer` for the table popout (8.3).
- Do not change `@plannotator/core`: none of the six items touch a core module (`guide-viewer-manifest.ts` is regenerated, not edited).

### 11.3 Publish plan

- `@plannotator/ui` `0.32.0` (next minor: additive seams, one documented behavior change for un-registered hosts). `@plannotator/core` stays `0.24.0` in content; only `packages/core/guide-viewer-manifest.ts` is regenerated by item 3, and that file ships in core, so core is republished as `0.25.0` alongside if the lockstep rule is applied (the repo's convention is lockstep; `d257f7fa` and `1080436d` are the precedent). Publish core first, then ui.
- Lockfile: after the version bumps run `bun install` and commit `bun.lock`; `bun pm pack` resolves `workspace:*` from the lockfile, so a stale lock would pin ui to the old core version (the `1080436d` "refresh lockfile" commit exists for this reason).
- `prepack` gains `build:bridge-asset` beside `build:css`; `files` in `packages/ui/package.json:28-52` must include the generated `bridge-script.js`.
- HANDOFF entry "Lazy renderers and eager entries (0.32.0)": the two eager imports, the `mathRendererLoader` and `identityGenerator` seams, `bridgeScriptUrl` plus `BRIDGE_PROTOCOL_VERSION`, and the explicit statement that a host rendering `Viewer` without `math-eager` gets placeholder-then-typeset math.

### 11.4 What Workspaces changes per item (from their request)

- Item 1: delete `math-lazy.ts`, `math-renderer.ts`, `katex-real.d.ts`, `katex.css` and the `katex`/`katex-real` alias rows; keep `useMathRenderer` in `routes/document.tsx` pointed at the package's `loadMathRenderer()`, and pass `mathRendererLoader` importing katex plus its CSS if they want CSS on the same chunk; remove `katex` from `apps/web/package.json` if unused.
- Item 2: delete `mermaid-lazy.ts`, `mermaid-real.d.ts`, both alias rows; restore `"@plannotator/ui > mermaid"` in `optimizeDeps.include`.
- Item 3: delete `username-generator-shim.ts` and its alias row.
- Item 4: `HtmlDocumentViewer.tsx` passes `bridgeScriptUrl` from `import bridgeUrl from "@plannotator/ui/components/html-viewer/bridge-script.js?url"`; optionally wire the ready timeout to their "annotation unavailable" state.
- Item 5: delete `viz-lazy.ts`, `viz-real.d.ts`, both alias rows.
- `check-boot-closure.mjs` stays.

### 11.5 Release-note line

`@plannotator/ui 0.32.0`: Mermaid, Graphviz, KaTeX and the username dictionary no longer ride every document read for hosts that bundle by route; the raw-HTML bridge can be served as a cacheable asset (`bridgeScriptUrl`). Plannotator's own apps register the renderers eagerly and render exactly as before; the single-file builds are unchanged in size and first paint.

---

## 12. Per-item verdict summary

| Item | Verdict | Mechanism | Workspaces saves | Plannotator single-file saves | Reaches guides.show viewer |
|---|---|---|---|---|---|
| 1 KaTeX | do, with seam | renderer slot + `math-eager` + `mathRendererLoader` | 75 KB gz JS + 8 KB gz CSS | 0 | no |
| 2 Mermaid | do | `import()` in effect, once-initialized | 414.5 KB raw runtime | 0 | no |
| 3 Identity | do, with seam | generator slot + `identity-tater` | 28 KB gz | 0 | yes (manifest resync) |
| 4 Bridge | do, with seam | `bridgeScriptUrl` + generated asset + protocol version | 185 KB raw (HTML readers) | 0 | no |
| 5 Graphviz | do | `import()` in effect | 489 KB gz lazy | 0 (portal: ~466 KB gz out of entry) | no |
| 6 Table popout | defer | (React.lazy) | 47.6 KB raw | 0 | no |
| B2 Fonts | no | nothing in the package | already taken app-side | 0 | no |
